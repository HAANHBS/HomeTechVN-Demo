-- HomeTechVN T16 — Bounded audit search + security posture snapshot.

create or replace function private.audit_search_impl(
  p_start_at timestamptz default null,
  p_end_at timestamptz default null,
  p_table_name text default null,
  p_action text default null,
  p_actor_user_id uuid default null,
  p_record_id text default null,
  p_before_id bigint default null,
  p_limit integer default 100
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_start timestamptz := coalesce(p_start_at, now() - interval '30 days');
  v_end timestamptz := coalesce(p_end_at, now());
  v_table text := nullif(btrim(p_table_name), '');
  v_action text := nullif(upper(btrim(p_action)), '');
  v_record text := nullif(btrim(p_record_id), '');
  v_limit integer := coalesce(p_limit, 100);
  v_rows jsonb;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('audit.view') then raise exception 'Missing permission audit.view'; end if;
  if v_start > v_end then raise exception 'Audit start_at must be on or before end_at'; end if;
  if v_end - v_start > interval '366 days' then raise exception 'Audit date range must not exceed 366 days'; end if;
  if v_limit < 1 or v_limit > 200 then raise exception 'Audit limit must be between 1 and 200'; end if;
  if v_action is not null and v_action not in ('INSERT','UPDATE','DELETE') then
    raise exception 'Audit action must be INSERT, UPDATE or DELETE';
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.id desc), '[]'::jsonb)
  into v_rows
  from (
    select
      a.id, a.occurred_at, a.actor_user_id,
      p.full_name as actor_name, p.email as actor_email,
      a.table_name, a.record_id, a.action, a.old_data, a.new_data
    from public.audit_logs a
    left join public.profiles p on p.id = a.actor_user_id
    where a.occurred_at >= v_start and a.occurred_at <= v_end
      and (v_table is null or a.table_name = v_table)
      and (v_action is null or a.action = v_action)
      and (p_actor_user_id is null or a.actor_user_id = p_actor_user_id)
      and (v_record is null or a.record_id = v_record)
      and (p_before_id is null or a.id < p_before_id)
    order by a.id desc
    limit v_limit
  ) x;

  return jsonb_build_object(
    'generated_at', now(),
    'start_at', v_start,
    'end_at', v_end,
    'limit', v_limit,
    'rows', v_rows,
    'next_before_id',
      case
        when jsonb_array_length(v_rows) = v_limit
          then (v_rows -> (jsonb_array_length(v_rows)-1) ->> 'id')::bigint
        else null
      end
  );
end;
$$;

revoke execute on function private.audit_search_impl(
  timestamptz,timestamptz,text,text,uuid,text,bigint,integer
) from public,anon,authenticated,service_role;
grant execute on function private.audit_search_impl(
  timestamptz,timestamptz,text,text,uuid,text,bigint,integer
) to authenticated;

create or replace function public.audit_search(
  p_start_at timestamptz default null,
  p_end_at timestamptz default null,
  p_table_name text default null,
  p_action text default null,
  p_actor_user_id uuid default null,
  p_record_id text default null,
  p_before_id bigint default null,
  p_limit integer default 100
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.audit_search_impl(
    p_start_at,p_end_at,p_table_name,p_action,p_actor_user_id,
    p_record_id,p_before_id,p_limit
  );
$$;

revoke execute on function public.audit_search(
  timestamptz,timestamptz,text,text,uuid,text,bigint,integer
) from public,anon;
grant execute on function public.audit_search(
  timestamptz,timestamptz,text,text,uuid,text,bigint,integer
) to authenticated;

create or replace function private.security_audit_snapshot_impl()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_audit_rows bigint;
  v_last_audit timestamptz;
  v_audited_tables integer;
  v_rls_tables integer;
  v_rls_without_policy integer;
  v_sequence_policy boolean;
  v_sequence_service_direct boolean;
  v_audit_guard_count integer;
  v_audit_search_path text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('audit.view') then raise exception 'Missing permission audit.view'; end if;

  select count(*),max(occurred_at)
  into v_audit_rows,v_last_audit
  from public.audit_logs;

  select count(distinct t.tgrelid)
  into v_audited_tables
  from pg_catalog.pg_trigger t
  where not t.tgisinternal
    and t.tgfoid='public.fn_audit_row()'::regprocedure;

  select count(*)
  into v_rls_tables
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where c.relkind in ('r','p')
    and c.relrowsecurity
    and n.nspname in ('public','private','public_lookup_private');

  select count(*)
  into v_rls_without_policy
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where c.relkind in ('r','p')
    and c.relrowsecurity
    and n.nspname in ('public','private','public_lookup_private')
    and not exists(
      select 1 from pg_catalog.pg_policy pol where pol.polrelid=c.oid
    );

  select exists(
    select 1 from pg_catalog.pg_policies
    where schemaname='private'
      and tablename='sequence_counters'
      and policyname='sequence_counters_no_direct_access'
  ) into v_sequence_policy;

  select
    pg_catalog.has_table_privilege('service_role','private.sequence_counters','SELECT') or
    pg_catalog.has_table_privilege('service_role','private.sequence_counters','INSERT') or
    pg_catalog.has_table_privilege('service_role','private.sequence_counters','UPDATE') or
    pg_catalog.has_table_privilege('service_role','private.sequence_counters','DELETE') or
    pg_catalog.has_table_privilege('service_role','private.sequence_counters','TRUNCATE')
  into v_sequence_service_direct;

  select count(*)
  into v_audit_guard_count
  from pg_catalog.pg_trigger
  where tgrelid='public.audit_logs'::regclass
    and not tgisinternal
    and tgname in ('trg_audit_logs_no_update_delete','trg_audit_logs_no_truncate');

  select coalesce(array_to_string(p.proconfig,','),'')
  into v_audit_search_path
  from pg_catalog.pg_proc p
  where p.oid='public.fn_audit_row()'::regprocedure;

  return jsonb_build_object(
    'generated_at',now(),
    'audit',jsonb_build_object(
      'rows',v_audit_rows,
      'last_event_at',v_last_audit,
      'audited_tables',v_audited_tables,
      'append_only_guards',v_audit_guard_count,
      'trigger_search_path',v_audit_search_path
    ),
    'rls',jsonb_build_object(
      'enabled_tables',v_rls_tables,
      'tables_without_policy',v_rls_without_policy
    ),
    'sequence_counters',jsonb_build_object(
      'deny_policy',v_sequence_policy,
      'service_role_direct_table_privilege',v_sequence_service_direct
    )
  );
end;
$$;

revoke execute on function private.security_audit_snapshot_impl()
from public,anon,authenticated,service_role;
grant execute on function private.security_audit_snapshot_impl()
to authenticated;

create or replace function public.security_audit_snapshot()
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.security_audit_snapshot_impl();
$$;

revoke execute on function public.security_audit_snapshot()
from public,anon;
grant execute on function public.security_audit_snapshot()
to authenticated;
