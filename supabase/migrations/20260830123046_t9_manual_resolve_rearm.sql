create or replace function private.reminder_generate_impl(p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid(); v_role text:=coalesce(auth.jwt()->>'role',''); v_run_id uuid:=gen_random_uuid();
  v_rec record; v_candidates integer:=0; v_active integer; v_due integer; v_resolved integer;
begin
  if v_role<>'service_role' then
    if v_uid is null then raise exception 'Authentication required'; end if;
    if not private.has_permission('notification.manage') then raise exception 'Missing permission notification.manage'; end if;
  end if;
  if p_now is null then p_now:=now(); end if;
  if not pg_try_advisory_xact_lock(hashtext('hometechvn.reminder_generate')) then
    raise exception 'Reminder generation already running';
  end if;

  for v_rec in select * from private.reminder_candidates(p_now)
  loop
    v_candidates:=v_candidates+1;
    insert into public.reminders(
      reminder_code,rule_id,rule_code_snapshot,event_type,source_type,source_id,source_label,customer_id,
      anchor_at,due_at,priority,status,title,message,dedupe_key,metadata,generated_by,
      first_seen_at,last_seen_at,last_seen_run_id,created_by,updated_by
    ) values(
      private.next_simple_code('REMINDER','REM',6),v_rec.rule_id,v_rec.rule_code,v_rec.event_type,
      v_rec.source_type,v_rec.source_id,v_rec.source_label,v_rec.customer_id,v_rec.anchor_at,v_rec.due_at,
      v_rec.priority,case when v_rec.due_at<=p_now then 'DUE' else 'PENDING' end,
      v_rec.title,v_rec.message,v_rec.dedupe_key,v_rec.metadata,'SYSTEM',p_now,p_now,v_run_id,v_uid,v_uid
    )
    on conflict(dedupe_key) do update set
      rule_id=excluded.rule_id,
      rule_code_snapshot=excluded.rule_code_snapshot,
      event_type=excluded.event_type,
      source_type=excluded.source_type,
      source_id=excluded.source_id,
      source_label=excluded.source_label,
      customer_id=excluded.customer_id,
      anchor_at=excluded.anchor_at,
      due_at=case
        when reminders.event_type='PRODUCT_LOW_STOCK' and reminders.status<>'RESOLVED'
          then reminders.due_at
        else excluded.due_at
      end,
      priority=excluded.priority,
      title=excluded.title,
      message=excluded.message,
      metadata=excluded.metadata,
      status=case
        when reminders.status='CANCELLED' then 'CANCELLED'
        when reminders.status='ACKNOWLEDGED' then 'ACKNOWLEDGED'
        when reminders.status='SNOOZED' and reminders.snoozed_until>p_now then 'SNOOZED'
        when reminders.status='RESOLVED'
             and coalesce(reminders.resolution_reason,'') like 'MANUAL:%'
          then 'RESOLVED'
        when reminders.status='RESOLVED'
          then case when excluded.due_at<=p_now then 'DUE' else 'PENDING' end
        else case when excluded.due_at<=p_now then 'DUE' else 'PENDING' end
      end,
      snoozed_until=case
        when reminders.status='SNOOZED' and reminders.snoozed_until>p_now
          then reminders.snoozed_until
        else null
      end,
      acknowledged_by=case
        when reminders.status='RESOLVED'
             and coalesce(reminders.resolution_reason,'') not like 'MANUAL:%'
          then null
        else reminders.acknowledged_by
      end,
      acknowledged_at=case
        when reminders.status='RESOLVED'
             and coalesce(reminders.resolution_reason,'') not like 'MANUAL:%'
          then null
        else reminders.acknowledged_at
      end,
      resolved_at=case
        when reminders.status='RESOLVED'
             and coalesce(reminders.resolution_reason,'') like 'MANUAL:%'
          then reminders.resolved_at
        when reminders.status='RESOLVED'
          then null
        else reminders.resolved_at
      end,
      resolution_reason=case
        when reminders.status='RESOLVED'
             and coalesce(reminders.resolution_reason,'') like 'MANUAL:%'
          then reminders.resolution_reason
        when reminders.status='RESOLVED'
          then null
        else reminders.resolution_reason
      end,
      last_seen_at=p_now,
      last_seen_run_id=v_run_id,
      updated_by=v_uid,
      updated_at=now();
  end loop;

  update public.reminders r
  set status='RESOLVED',
      resolved_at=coalesce(r.resolved_at,p_now),
      resolution_reason=case
        when exists(
          select 1 from public.reminder_rules rr
          where rr.id=r.rule_id and not rr.is_active
        ) then 'RULE_DISABLED'
        else 'CONDITION_CLEARED'
      end,
      snoozed_until=null,
      updated_by=v_uid,
      updated_at=now()
  where r.generated_by='SYSTEM'
    and r.status<>'CANCELLED'
    and r.last_seen_run_id is distinct from v_run_id
    and (
      r.status<>'RESOLVED'
      or coalesce(r.resolution_reason,'') like 'MANUAL:%'
    );
  get diagnostics v_resolved=row_count;

  select count(*) into v_active
  from public.reminders
  where status in ('PENDING','DUE','SNOOZED','ACKNOWLEDGED');

  select count(*) into v_due
  from public.reminders
  where status='DUE';

  return jsonb_build_object(
    'run_id',v_run_id,
    'evaluated_at',p_now,
    'candidates',v_candidates,
    'active_reminders',v_active,
    'due_reminders',v_due,
    'auto_resolved',v_resolved
  );
end; $$;

create or replace function private.reminder_resolve_impl(
  p_reminder_id uuid,
  p_reason text,
  p_note text default null
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid();
  v_row public.reminders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('notification.manage') then
    raise exception 'Missing permission notification.manage';
  end if;
  if nullif(btrim(p_reason),'') is null then
    raise exception 'Resolution reason is required';
  end if;

  select * into v_row
  from public.reminders
  where id=p_reminder_id
  for update;
  if not found then raise exception 'Reminder not found'; end if;

  update public.reminders
  set status='RESOLVED',
      resolved_at=now(),
      resolution_reason='MANUAL:'||btrim(p_reason),
      snoozed_until=null,
      operator_note=coalesce(nullif(btrim(p_note),''),operator_note),
      updated_by=v_uid,
      updated_at=now()
  where id=p_reminder_id
  returning * into v_row;

  return to_jsonb(v_row);
end; $$;
