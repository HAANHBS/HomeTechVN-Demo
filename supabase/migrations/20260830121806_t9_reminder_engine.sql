create or replace function private.reminder_candidates(p_now timestamptz)
returns table(
  rule_id uuid, rule_code text, event_type text, source_type text, source_id uuid,
  source_label text, customer_id uuid, anchor_at timestamptz, due_at timestamptz,
  priority text, title text, message text, metadata jsonb, dedupe_key text
)
language sql stable security definer set search_path='' as $$
  select rr.id,rr.rule_code,rr.event_type,'WARRANTY'::text,w.id,w.warranty_code,w.customer_id,
         a.anchor_at,a.anchor_at+make_interval(mins=>rr.offset_minutes),rr.priority,rr.name,
         format('%s · %s · hết hạn %s',w.warranty_code,coalesce(w.product_name_snapshot,'Bảo hành'),to_char(w.end_date,'DD/MM/YYYY')),
         jsonb_build_object('warranty_code',w.warranty_code,'end_date',w.end_date,'product_name',w.product_name_snapshot),
         format('%s:%s:%s',rr.rule_code,w.id,extract(epoch from a.anchor_at)::bigint)
  from public.reminder_rules rr
  join public.warranties w on rr.event_type='WARRANTY_END' and w.status='ACTIVE'
  cross join lateral (select ((w.end_date::timestamp+interval '9 hours') at time zone 'Asia/Bangkok') as anchor_at) a
  where rr.is_active

  union all
  select rr.id,rr.rule_code,rr.event_type,'SOFTWARE_LICENSE',l.id,l.license_code,l.customer_id,
         a.anchor_at,a.anchor_at+make_interval(mins=>rr.offset_minutes),rr.priority,rr.name,
         format('%s · %s · hết hạn %s',l.license_code,concat_ws(' ',p.vendor,p.name,p.edition),to_char(l.end_date,'DD/MM/YYYY')),
         jsonb_build_object('license_code',l.license_code,'end_date',l.end_date,'product_name',p.name,'auto_renew',l.auto_renew),
         format('%s:%s:%s',rr.rule_code,l.id,extract(epoch from a.anchor_at)::bigint)
  from public.reminder_rules rr
  join public.software_licenses l on rr.event_type='LICENSE_END' and l.status in ('ACTIVE','SUSPENDED') and l.end_date is not null
  join public.software_products p on p.id=l.software_product_id
  cross join lateral (select ((l.end_date::timestamp+interval '9 hours') at time zone 'Asia/Bangkok') as anchor_at) a
  where rr.is_active

  union all
  select rr.id,rr.rule_code,rr.event_type,'SERVICE_SCHEDULE',ss.id,s.name,ss.customer_id,
         a.anchor_at,a.anchor_at+make_interval(mins=>rr.offset_minutes),rr.priority,rr.name,
         format('%s · đến hạn %s',s.name,to_char(ss.next_due_date,'DD/MM/YYYY')),
         jsonb_build_object('service_name',s.name,'next_due_date',ss.next_due_date,'completion_count',ss.completion_count),
         format('%s:%s:%s',rr.rule_code,ss.id,extract(epoch from a.anchor_at)::bigint)
  from public.reminder_rules rr
  join public.service_schedules ss on rr.event_type='SERVICE_DUE' and ss.status='ACTIVE'
  join public.services s on s.id=ss.service_id
  cross join lateral (select ((ss.next_due_date::timestamp+interval '9 hours') at time zone 'Asia/Bangkok') as anchor_at) a
  where rr.is_active

  union all
  select rr.id,rr.rule_code,rr.event_type,'REPAIR_ORDER',ro.id,ro.repair_code,ro.customer_id,
         ro.ready_at,ro.ready_at+make_interval(mins=>rr.offset_minutes),rr.priority,rr.name,
         format('%s · thiết bị đã sẵn sàng trả khách',ro.repair_code),
         jsonb_build_object('repair_code',ro.repair_code,'ready_at',ro.ready_at,'priority',ro.priority),
         format('%s:%s:%s',rr.rule_code,ro.id,extract(epoch from ro.ready_at)::bigint)
  from public.reminder_rules rr
  join public.repair_orders ro on rr.event_type='REPAIR_READY' and ro.status='READY' and ro.ready_at is not null
  where rr.is_active

  union all
  select rr.id,rr.rule_code,rr.event_type,'REPAIR_ORDER',ro.id,ro.repair_code,ro.customer_id,
         ro.awaiting_customer_at,ro.awaiting_customer_at+make_interval(mins=>rr.offset_minutes),rr.priority,rr.name,
         format('%s · khách chưa phản hồi báo giá',ro.repair_code),
         jsonb_build_object('repair_code',ro.repair_code,'awaiting_customer_at',ro.awaiting_customer_at,'approved_amount',ro.approved_amount),
         format('%s:%s:%s',rr.rule_code,ro.id,extract(epoch from ro.awaiting_customer_at)::bigint)
  from public.reminder_rules rr
  join public.repair_orders ro on rr.event_type='REPAIR_AWAITING_CUSTOMER' and ro.status='AWAITING_CUSTOMER' and ro.awaiting_customer_at is not null
  where rr.is_active

  union all
  select rr.id,rr.rule_code,rr.event_type,'REPAIR_ORDER',ro.id,ro.repair_code,ro.customer_id,
         ro.estimated_completion_at,ro.estimated_completion_at+make_interval(mins=>rr.offset_minutes),rr.priority,rr.name,
         format('%s · vượt/đến thời gian hoàn thành dự kiến',ro.repair_code),
         jsonb_build_object('repair_code',ro.repair_code,'estimated_completion_at',ro.estimated_completion_at,'status',ro.status),
         format('%s:%s:%s',rr.rule_code,ro.id,extract(epoch from ro.estimated_completion_at)::bigint)
  from public.reminder_rules rr
  join public.repair_orders ro on rr.event_type='REPAIR_ESTIMATED_COMPLETION'
    and ro.status in ('RECEIVED','DIAGNOSING','QUOTED','AWAITING_CUSTOMER','APPROVED','WAITING_PART','REPAIRING','QC')
    and ro.estimated_completion_at is not null
  where rr.is_active

  union all
  select rr.id,rr.rule_code,rr.event_type,'SALES_ORDER',so.id,so.order_code,so.customer_id,
         so.payment_pending_at,so.payment_pending_at+make_interval(mins=>rr.offset_minutes),rr.priority,rr.name,
         format('%s · còn phải thu %s',so.order_code,to_char(so.balance_due,'FM999G999G999G990')),
         jsonb_build_object('order_code',so.order_code,'balance_due',so.balance_due,'payment_pending_at',so.payment_pending_at),
         format('%s:%s:%s',rr.rule_code,so.id,extract(epoch from so.payment_pending_at)::bigint)
  from public.reminder_rules rr
  join public.sales_orders so on rr.event_type='SALES_PAYMENT_PENDING' and so.status='PAYMENT_PENDING' and so.balance_due>0 and so.payment_pending_at is not null
  where rr.is_active

  union all
  select rr.id,rr.rule_code,rr.event_type,'PRODUCT',p.product_id,p.sku,null::uuid,
         null::timestamptz,p_now+make_interval(mins=>rr.offset_minutes),rr.priority,rr.name,
         format('%s · %s · tồn %s / tối thiểu %s',p.sku,p.name,p.stock_qty,p.min_stock),
         jsonb_build_object('sku',p.sku,'product_name',p.name,'stock_qty',p.stock_qty,'min_stock',p.min_stock),
         format('%s:%s',rr.rule_code,p.product_id)
  from public.reminder_rules rr
  join public.product_inventory_summary p on rr.event_type='PRODUCT_LOW_STOCK' and p.is_active=true and p.low_stock=true
  where rr.is_active;
$$;
revoke execute on function private.reminder_candidates(timestamptz) from public,anon,authenticated;

create or replace function private.reminder_rule_create_impl(
  p_rule_code text,p_name text,p_event_type text,p_offset_minutes integer default 0,
  p_priority text default 'NORMAL',p_description text default null,p_is_active boolean default true
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_code text; v_row public.reminder_rules%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('notification.manage') then raise exception 'Missing permission notification.manage'; end if;
  v_code:=upper(btrim(p_rule_code));
  if v_code !~ '^[A-Z0-9_]+$' then raise exception 'Invalid rule_code'; end if;
  if nullif(btrim(p_name),'') is null then raise exception 'Reminder rule name is required'; end if;
  if p_event_type not in ('WARRANTY_END','LICENSE_END','SERVICE_DUE','REPAIR_READY','REPAIR_AWAITING_CUSTOMER','REPAIR_ESTIMATED_COMPLETION','SALES_PAYMENT_PENDING','PRODUCT_LOW_STOCK') then
    raise exception 'Unsupported reminder event_type';
  end if;
  if p_priority not in ('LOW','NORMAL','HIGH','URGENT') then raise exception 'Invalid reminder priority'; end if;
  insert into public.reminder_rules(rule_code,name,event_type,offset_minutes,priority,is_active,is_system,description,created_by,updated_by)
  values(v_code,btrim(p_name),p_event_type,coalesce(p_offset_minutes,0),p_priority,coalesce(p_is_active,true),false,nullif(btrim(p_description),''),v_uid,v_uid)
  returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.reminder_rule_update_impl(
  p_rule_id uuid,p_name text,p_offset_minutes integer,p_priority text,p_is_active boolean,p_description text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.reminder_rules%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('notification.manage') then raise exception 'Missing permission notification.manage'; end if;
  select * into v_row from public.reminder_rules where id=p_rule_id for update;
  if not found then raise exception 'Reminder rule not found'; end if;
  if nullif(btrim(p_name),'') is null then raise exception 'Reminder rule name is required'; end if;
  if p_priority not in ('LOW','NORMAL','HIGH','URGENT') then raise exception 'Invalid reminder priority'; end if;
  update public.reminder_rules set name=btrim(p_name),offset_minutes=coalesce(p_offset_minutes,0),priority=p_priority,
    is_active=coalesce(p_is_active,true),description=nullif(btrim(p_description),''),updated_by=v_uid,updated_at=now()
  where id=p_rule_id returning * into v_row;
  return to_jsonb(v_row);
end; $$;

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
      private.next_simple_code('REMINDER','REM',6),v_rec.rule_id,v_rec.rule_code,v_rec.event_type,v_rec.source_type,v_rec.source_id,
      v_rec.source_label,v_rec.customer_id,v_rec.anchor_at,v_rec.due_at,v_rec.priority,
      case when v_rec.due_at<=p_now then 'DUE' else 'PENDING' end,
      v_rec.title,v_rec.message,v_rec.dedupe_key,v_rec.metadata,'SYSTEM',p_now,p_now,v_run_id,v_uid,v_uid
    )
    on conflict(dedupe_key) do update set
      rule_id=excluded.rule_id,rule_code_snapshot=excluded.rule_code_snapshot,event_type=excluded.event_type,
      source_type=excluded.source_type,source_id=excluded.source_id,source_label=excluded.source_label,customer_id=excluded.customer_id,
      anchor_at=excluded.anchor_at,
      due_at=case when reminders.event_type='PRODUCT_LOW_STOCK' and reminders.status<>'RESOLVED' then reminders.due_at else excluded.due_at end,
      priority=excluded.priority,title=excluded.title,message=excluded.message,metadata=excluded.metadata,
      status=case
        when reminders.status='CANCELLED' then 'CANCELLED'
        when reminders.status='ACKNOWLEDGED' then 'ACKNOWLEDGED'
        when reminders.status='SNOOZED' and reminders.snoozed_until>p_now then 'SNOOZED'
        when reminders.status='RESOLVED' then case when excluded.due_at<=p_now then 'DUE' else 'PENDING' end
        else case when excluded.due_at<=p_now then 'DUE' else 'PENDING' end
      end,
      snoozed_until=case when reminders.status='SNOOZED' and reminders.snoozed_until>p_now then reminders.snoozed_until else null end,
      acknowledged_by=case when reminders.status='RESOLVED' then null else reminders.acknowledged_by end,
      acknowledged_at=case when reminders.status='RESOLVED' then null else reminders.acknowledged_at end,
      resolved_at=case when reminders.status='RESOLVED' then null else reminders.resolved_at end,
      resolution_reason=case when reminders.status='RESOLVED' then null else reminders.resolution_reason end,
      last_seen_at=p_now,last_seen_run_id=v_run_id,updated_by=v_uid,updated_at=now();
  end loop;

  update public.reminders r set status='RESOLVED',resolved_at=p_now,
    resolution_reason=case when exists(select 1 from public.reminder_rules rr where rr.id=r.rule_id and not rr.is_active) then 'RULE_DISABLED' else 'CONDITION_CLEARED' end,
    snoozed_until=null,updated_by=v_uid,updated_at=now()
  where r.generated_by='SYSTEM' and r.status not in ('RESOLVED','CANCELLED')
    and r.last_seen_run_id is distinct from v_run_id;
  get diagnostics v_resolved=row_count;

  select count(*) into v_active from public.reminders where status in ('PENDING','DUE','SNOOZED','ACKNOWLEDGED');
  select count(*) into v_due from public.reminders where status='DUE';
  return jsonb_build_object('run_id',v_run_id,'evaluated_at',p_now,'candidates',v_candidates,'active_reminders',v_active,'due_reminders',v_due,'auto_resolved',v_resolved);
end; $$;

create or replace function private.reminder_acknowledge_impl(p_reminder_id uuid,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.reminders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('notification.view') and not private.has_permission('notification.manage') then raise exception 'Missing permission notification.view'; end if;
  select * into v_row from public.reminders where id=p_reminder_id for update;
  if not found then raise exception 'Reminder not found'; end if;
  if v_row.status in ('RESOLVED','CANCELLED') then raise exception 'Closed reminder cannot be acknowledged'; end if;
  update public.reminders set status='ACKNOWLEDGED',acknowledged_by=v_uid,acknowledged_at=now(),snoozed_until=null,
    resolved_at=null,resolution_reason=null,operator_note=coalesce(nullif(btrim(p_note),''),operator_note),updated_by=v_uid,updated_at=now()
  where id=p_reminder_id returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.reminder_snooze_impl(p_reminder_id uuid,p_snoozed_until timestamptz,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.reminders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('notification.view') and not private.has_permission('notification.manage') then raise exception 'Missing permission notification.view'; end if;
  if p_snoozed_until is null or p_snoozed_until<=now() then raise exception 'Snooze time must be in the future'; end if;
  select * into v_row from public.reminders where id=p_reminder_id for update;
  if not found then raise exception 'Reminder not found'; end if;
  if v_row.status in ('RESOLVED','CANCELLED') then raise exception 'Closed reminder cannot be snoozed'; end if;
  update public.reminders set status='SNOOZED',snoozed_until=p_snoozed_until,acknowledged_by=null,acknowledged_at=null,
    resolved_at=null,resolution_reason=null,operator_note=coalesce(nullif(btrim(p_note),''),operator_note),updated_by=v_uid,updated_at=now()
  where id=p_reminder_id returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.reminder_resolve_impl(p_reminder_id uuid,p_reason text,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.reminders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('notification.manage') then raise exception 'Missing permission notification.manage'; end if;
  if nullif(btrim(p_reason),'') is null then raise exception 'Resolution reason is required'; end if;
  select * into v_row from public.reminders where id=p_reminder_id for update;
  if not found then raise exception 'Reminder not found'; end if;
  update public.reminders set status='RESOLVED',resolved_at=now(),resolution_reason=btrim(p_reason),snoozed_until=null,
    operator_note=coalesce(nullif(btrim(p_note),''),operator_note),updated_by=v_uid,updated_at=now()
  where id=p_reminder_id returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function public.reminder_rule_create(
  p_rule_code text,p_name text,p_event_type text,p_offset_minutes integer default 0,
  p_priority text default 'NORMAL',p_description text default null,p_is_active boolean default true
) returns jsonb language sql set search_path='' as $$ select private.reminder_rule_create_impl(p_rule_code,p_name,p_event_type,p_offset_minutes,p_priority,p_description,p_is_active); $$;
create or replace function public.reminder_rule_update(
  p_rule_id uuid,p_name text,p_offset_minutes integer,p_priority text,p_is_active boolean,p_description text default null
) returns jsonb language sql set search_path='' as $$ select private.reminder_rule_update_impl(p_rule_id,p_name,p_offset_minutes,p_priority,p_is_active,p_description); $$;
create or replace function public.reminder_generate(p_now timestamptz default now()) returns jsonb language sql set search_path='' as $$ select private.reminder_generate_impl(p_now); $$;
create or replace function public.reminder_acknowledge(p_reminder_id uuid,p_note text default null) returns jsonb language sql set search_path='' as $$ select private.reminder_acknowledge_impl(p_reminder_id,p_note); $$;
create or replace function public.reminder_snooze(p_reminder_id uuid,p_snoozed_until timestamptz,p_note text default null) returns jsonb language sql set search_path='' as $$ select private.reminder_snooze_impl(p_reminder_id,p_snoozed_until,p_note); $$;
create or replace function public.reminder_resolve(p_reminder_id uuid,p_reason text,p_note text default null) returns jsonb language sql set search_path='' as $$ select private.reminder_resolve_impl(p_reminder_id,p_reason,p_note); $$;

revoke execute on function private.reminder_rule_create_impl(text,text,text,integer,text,text,boolean) from public,anon,authenticated;
revoke execute on function private.reminder_rule_update_impl(uuid,text,integer,text,boolean,text) from public,anon,authenticated;
revoke execute on function private.reminder_generate_impl(timestamptz) from public,anon,authenticated;
revoke execute on function private.reminder_acknowledge_impl(uuid,text) from public,anon,authenticated;
revoke execute on function private.reminder_snooze_impl(uuid,timestamptz,text) from public,anon,authenticated;
revoke execute on function private.reminder_resolve_impl(uuid,text,text) from public,anon,authenticated;
grant execute on function private.reminder_rule_create_impl(text,text,text,integer,text,text,boolean) to authenticated;
grant execute on function private.reminder_rule_update_impl(uuid,text,integer,text,boolean,text) to authenticated;
grant execute on function private.reminder_generate_impl(timestamptz) to authenticated,service_role;
grant execute on function private.reminder_acknowledge_impl(uuid,text) to authenticated;
grant execute on function private.reminder_snooze_impl(uuid,timestamptz,text) to authenticated;
grant execute on function private.reminder_resolve_impl(uuid,text,text) to authenticated;

revoke execute on function public.reminder_rule_create(text,text,text,integer,text,text,boolean) from public,anon;
revoke execute on function public.reminder_rule_update(uuid,text,integer,text,boolean,text) from public,anon;
revoke execute on function public.reminder_generate(timestamptz) from public,anon;
revoke execute on function public.reminder_acknowledge(uuid,text) from public,anon;
revoke execute on function public.reminder_snooze(uuid,timestamptz,text) from public,anon;
revoke execute on function public.reminder_resolve(uuid,text,text) from public,anon;
grant execute on function public.reminder_rule_create(text,text,text,integer,text,text,boolean) to authenticated;
grant execute on function public.reminder_rule_update(uuid,text,integer,text,boolean,text) to authenticated;
grant execute on function public.reminder_generate(timestamptz) to authenticated,service_role;
grant execute on function public.reminder_acknowledge(uuid,text) to authenticated;
grant execute on function public.reminder_snooze(uuid,timestamptz,text) to authenticated;
grant execute on function public.reminder_resolve(uuid,text,text) to authenticated;

insert into public.reminder_rules(rule_code,name,event_type,offset_minutes,priority,is_active,is_system,description) values
('WARRANTY_30D','Bảo hành còn 30 ngày','WARRANTY_END',-43200,'NORMAL',true,true,'Nhắc trước 30 ngày khi bảo hành hết hạn'),
('WARRANTY_7D','Bảo hành còn 7 ngày','WARRANTY_END',-10080,'HIGH',true,true,'Nhắc trước 7 ngày khi bảo hành hết hạn'),
('LICENSE_30D','License còn 30 ngày','LICENSE_END',-43200,'NORMAL',true,true,'Nhắc trước 30 ngày khi License hết hạn'),
('LICENSE_7D','License còn 7 ngày','LICENSE_END',-10080,'HIGH',true,true,'Nhắc trước 7 ngày khi License hết hạn'),
('MAINTENANCE_7D','Bảo trì còn 7 ngày','SERVICE_DUE',-10080,'NORMAL',true,true,'Nhắc trước 7 ngày lịch dịch vụ/bảo trì'),
('REPAIR_READY','Thiết bị sẵn sàng trả khách','REPAIR_READY',0,'HIGH',true,true,'Nhắc ngay khi phiếu sửa chữa READY'),
('REPAIR_UNCOLLECTED_3D','Thiết bị chưa nhận sau 3 ngày','REPAIR_READY',4320,'HIGH',true,true,'Nhắc sau 3 ngày kể từ READY'),
('REPAIR_UNCOLLECTED_7D','Thiết bị chưa nhận sau 7 ngày','REPAIR_READY',10080,'URGENT',true,true,'Nhắc sau 7 ngày kể từ READY'),
('QUOTE_WAITING_24H','Báo giá chờ phản hồi 24 giờ','REPAIR_AWAITING_CUSTOMER',1440,'HIGH',true,true,'Nhắc sau 24 giờ chờ khách phản hồi báo giá'),
('REPAIR_OVERDUE','Phiếu sửa chữa quá dự kiến','REPAIR_ESTIMATED_COMPLETION',0,'URGENT',true,true,'Nhắc khi đạt/vượt thời gian hoàn thành dự kiến'),
('RECEIVABLE_DUE','Đơn bán còn công nợ','SALES_PAYMENT_PENDING',0,'HIGH',true,true,'Nhắc ngay khi đơn chuyển PAYMENT_PENDING và còn balance_due'),
('LOW_STOCK','Tồn kho thấp','PRODUCT_LOW_STOCK',0,'HIGH',true,true,'Nhắc khi tồn thực tế thấp hơn min_stock');
