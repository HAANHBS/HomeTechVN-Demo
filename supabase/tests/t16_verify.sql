\set ON_ERROR_STOP on
begin;

do $$
declare
  v_cfg text;
begin
  if not exists(
    select 1 from pg_policies
    where schemaname='private'
      and tablename='sequence_counters'
      and policyname='sequence_counters_no_direct_access'
  ) then
    raise exception 'T16 FAIL: sequence deny policy missing';
  end if;

  if has_table_privilege('service_role','private.sequence_counters','SELECT')
     or has_table_privilege('service_role','private.sequence_counters','INSERT')
     or has_table_privilege('service_role','private.sequence_counters','UPDATE')
     or has_table_privilege('service_role','private.sequence_counters','DELETE')
     or has_table_privilege('service_role','private.sequence_counters','TRUNCATE')
  then
    raise exception 'T16 FAIL: service_role has direct sequence privilege';
  end if;

  if not has_function_privilege(
    'authenticated',
    'public.audit_search(timestamptz,timestamptz,text,text,uuid,text,bigint,integer)',
    'EXECUTE'
  ) then
    raise exception 'T16 FAIL: authenticated missing audit_search EXECUTE';
  end if;

  if has_function_privilege(
    'anon',
    'public.audit_search(timestamptz,timestamptz,text,text,uuid,text,bigint,integer)',
    'EXECUTE'
  ) then
    raise exception 'T16 FAIL: anon has audit_search EXECUTE';
  end if;

  select coalesce(array_to_string(proconfig,','),'')
  into v_cfg
  from pg_proc
  where oid='public.fn_audit_row()'::regprocedure;

  if v_cfg not like '%search_path=""%' then
    raise exception 'T16 FAIL: fn_audit_row search_path not empty: %',v_cfg;
  end if;

  if exists(
    select 1
    from pg_constraint
    where conrelid='public.audit_logs'::regclass
      and conname='audit_logs_actor_user_id_fkey'
  ) then
    raise exception 'T16 FAIL: audit actor FK still rewrites/blocks immutable history';
  end if;

  if (
    select count(*)
    from pg_trigger
    where tgrelid='public.audit_logs'::regclass
      and not tgisinternal
      and tgname in ('trg_audit_logs_no_update_delete','trg_audit_logs_no_truncate')
  )<>2 then
    raise exception 'T16 FAIL: audit immutable triggers missing';
  end if;
end $$;

-- Helper remains usable by privileged internal code after direct grants revoked.
do $$
declare v_code text;
begin
  v_code:=private.next_simple_code('T16_SQL_VERIFY','T16',6);
  if v_code !~ '^T16-[0-9]{6}$' then
    raise exception 'T16 FAIL: private sequence helper broken';
  end if;
end $$;

-- Create deterministic Admin + Sales test identities.
insert into auth.users(id,email,raw_user_meta_data) values
('d1600000-0000-4000-8000-000000000001','t16-admin@example.invalid','{}'::jsonb),
('d1600000-0000-4000-8000-000000000002','t16-sales@example.invalid','{}'::jsonb),
('d1600000-0000-4000-8000-000000000003','t16-actor-history@example.invalid','{}'::jsonb);

update public.profiles
set role_id=(select id from public.roles where code='admin'),
    is_active=true,full_name='T16 Admin'
where id='d1600000-0000-4000-8000-000000000001';

update public.profiles
set role_id=(select id from public.roles where code='sales'),
    is_active=true,full_name='T16 Sales'
where id='d1600000-0000-4000-8000-000000000002';

update public.profiles
set role_id=(select id from public.roles where code='admin'),
    is_active=true,full_name='T16 Actor History'
where id='d1600000-0000-4000-8000-000000000003';

insert into public.settings(key,value,description,is_sensitive)
values(
  't16.audit.fixture',
  jsonb_build_object('value','before'),
  'T16 audit fixture',
  false
);

update public.settings
set value=jsonb_build_object('value','after')
where key='t16.audit.fixture';

-- Audit history itself cannot be changed, even by a high privilege SQL session.
do $$
begin
  begin
    update public.audit_logs
    set table_name=table_name
    where id=(select min(id) from public.audit_logs);
    raise exception 'T16 FAIL: audit UPDATE unexpectedly succeeded';
  exception when others then
    if sqlerrm='T16 FAIL: audit UPDATE unexpectedly succeeded' then raise; end if;
    if position('append-only' in sqlerrm)=0 then raise; end if;
  end;

  begin
    delete from public.audit_logs
    where id=(select min(id) from public.audit_logs);
    raise exception 'T16 FAIL: audit DELETE unexpectedly succeeded';
  exception when others then
    if sqlerrm='T16 FAIL: audit DELETE unexpectedly succeeded' then raise; end if;
    if position('append-only' in sqlerrm)=0 then raise; end if;
  end;

  begin
    execute 'truncate table public.audit_logs';
    raise exception 'T16 FAIL: audit TRUNCATE unexpectedly succeeded';
  exception when others then
    if sqlerrm='T16 FAIL: audit TRUNCATE unexpectedly succeeded' then raise; end if;
    if position('append-only' in sqlerrm)=0 then raise; end if;
  end;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub','d1600000-0000-4000-8000-000000000001',true);

do $$
declare j jsonb; s jsonb;
begin
  j:=public.audit_search(
    now()-interval '1 day',now(),'settings','UPDATE',null,'t16.audit.fixture',null,50
  );

  if jsonb_array_length(j->'rows')<1 then
    raise exception 'T16 FAIL: Admin audit_search returned no fixture';
  end if;

  s:=public.security_audit_snapshot();

  if coalesce((s#>>'{sequence_counters,deny_policy}')::boolean,false)<>true then
    raise exception 'T16 FAIL: snapshot sequence policy false';
  end if;
  if coalesce((s#>>'{sequence_counters,service_role_direct_table_privilege}')::boolean,true)<>false then
    raise exception 'T16 FAIL: snapshot direct sequence privilege true';
  end if;
  if (s#>>'{audit,append_only_guards}')::int<>2 then
    raise exception 'T16 FAIL: snapshot audit guard count';
  end if;
end $$;

reset role;

-- Deleting an Auth user must not rewrite or block immutable audit history.
set local role authenticated;
select set_config('request.jwt.claim.sub','d1600000-0000-4000-8000-000000000003',true);

insert into public.settings(key,value,description,is_sensitive)
values(
  't16.actor.history.fixture',
  jsonb_build_object('preserve',true),
  'T16 actor lifecycle fixture',
  false
);

reset role;
select set_config('request.jwt.claim.sub','',true);
delete from auth.users
where id='d1600000-0000-4000-8000-000000000003';

do $$
declare v_count integer;
begin
  select count(*) into v_count
  from public.audit_logs
  where actor_user_id='d1600000-0000-4000-8000-000000000003'
    and table_name='settings'
    and record_id='t16.actor.history.fixture'
    and action='INSERT';

  if v_count<>1 then
    raise exception 'T16 FAIL: actor UUID history not preserved after Auth-user deletion';
  end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub','d1600000-0000-4000-8000-000000000002',true);

do $$
begin
  begin
    perform public.audit_search(now()-interval '1 day',now(),null,null,null,null,null,10);
    raise exception 'T16 FAIL: Sales unexpectedly accessed audit';
  exception when others then
    if sqlerrm='T16 FAIL: Sales unexpectedly accessed audit' then raise; end if;
    if position('audit.view' in sqlerrm)=0 then raise; end if;
  end;
end $$;

reset role;

do $$ begin
  raise notice 'T16 SECURITY CORE CHECKS: PASS';
end $$;

rollback;
