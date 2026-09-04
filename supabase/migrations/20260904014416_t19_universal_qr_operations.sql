-- HomeTechVN T19 - Universal QR Operations
-- T1-T18 migrations stay locked. QR is a routing capability, never an authorization bypass.

begin;

insert into public.permissions(code,name,module,description)
values
  ('qr.issue','Tao ma QR nghiep vu','qr','Tao QR cho tai nguyen ma nguoi dung duoc phep truy cap'),
  ('qr.revoke','Thu hoi ma QR nghiep vu','qr','Thu hoi QR noi bo da phat hanh')
on conflict (code) do update
set name=excluded.name,module=excluded.module,description=excluded.description;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r
join public.permissions p on p.code='qr.issue'
where r.code in ('admin','manager','sales','technician','cashier')
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r
join public.permissions p on p.code='qr.revoke'
where r.code in ('admin','manager')
on conflict do nothing;

create table private.qr_codes (
  id uuid primary key default gen_random_uuid(),
  token_hash bytea not null unique,
  resource_type text not null check (resource_type in (
    'CUSTOMER','DEVICE','PRODUCT','INVENTORY_UNIT','SALES_ORDER','PAYMENT',
    'REPAIR_ORDER','WARRANTY','WARRANTY_CLAIM','SERVICE_SCHEDULE',
    'SOFTWARE_LICENSE','CHECKLIST_RUN','REMINDER','NOTIFICATION'
  )),
  resource_id uuid,
  intent text not null default 'VIEW' check (intent in ('CREATE','VIEW','EDIT','PAY')),
  label_snapshot text not null,
  created_by uuid references public.profiles(id) on delete set null,
  expires_at timestamptz,
  revoked_at timestamptz,
  revoked_by uuid references public.profiles(id) on delete set null,
  use_count bigint not null default 0 check (use_count>=0),
  last_used_at timestamptz,
  created_at timestamptz not null default now(),
  constraint qr_codes_create_target check (
    (intent='CREATE' and resource_id is null) or
    (intent<>'CREATE' and resource_id is not null)
  ),
  constraint qr_codes_pay_target check (intent<>'PAY' or resource_type='SALES_ORDER'),
  constraint qr_codes_expiry check (expires_at is null or expires_at>created_at)
);

create index idx_qr_codes_resource on private.qr_codes(resource_type,resource_id)
where resource_id is not null;
create index idx_qr_codes_active_expiry on private.qr_codes(expires_at)
where revoked_at is null;

create table private.qr_action_events (
  id bigint generated always as identity primary key,
  qr_code_id uuid not null references private.qr_codes(id) on delete restrict,
  actor_user_id uuid references public.profiles(id) on delete set null,
  event_type text not null check (event_type in ('ISSUED','RESOLVED','REVOKED')),
  resource_type text not null,
  resource_id uuid,
  occurred_at timestamptz not null default now()
);

create index idx_qr_action_events_code_time on private.qr_action_events(qr_code_id,occurred_at desc);
create index idx_qr_action_events_actor_time on private.qr_action_events(actor_user_id,occurred_at desc)
where actor_user_id is not null;

alter table private.qr_codes enable row level security;
alter table private.qr_action_events enable row level security;

-- These tables are reachable only through the SECURITY DEFINER QR API.  Keep an
-- explicit deny-all policy on each table so the security posture snapshot can
-- distinguish an intentionally closed table from an unfinished RLS setup.
create policy qr_codes_no_direct_access
on private.qr_codes
for all
to public
using (false)
with check (false);

create policy qr_action_events_no_direct_access
on private.qr_action_events
for all
to public
using (false)
with check (false);

revoke all on table private.qr_codes,private.qr_action_events from public,anon,authenticated;
grant all on table private.qr_codes,private.qr_action_events to service_role;
grant usage,select on sequence private.qr_action_events_id_seq to service_role;

create or replace function private.qr_required_permission(p_type text,p_action text)
returns text
language sql
immutable
security invoker
set search_path=''
as $$
  select case upper(p_type)
    when 'CUSTOMER' then case upper(p_action) when 'CREATE' then 'customer.create' when 'EDIT' then 'customer.update' else 'customer.view' end
    when 'DEVICE' then case upper(p_action) when 'CREATE' then 'device.create' when 'EDIT' then 'device.update' else 'device.view' end
    when 'PRODUCT' then case upper(p_action) when 'CREATE' then 'product.manage' when 'EDIT' then 'product.manage' else 'product.view' end
    when 'INVENTORY_UNIT' then case upper(p_action) when 'CREATE' then 'inventory.receive' when 'EDIT' then 'inventory.adjust' else 'inventory.view' end
    when 'SALES_ORDER' then case upper(p_action) when 'CREATE' then 'sale.create' when 'EDIT' then 'sale.update' when 'PAY' then 'payment.create' else 'sale.view' end
    when 'PAYMENT' then case upper(p_action) when 'CREATE' then 'payment.create' when 'EDIT' then 'payment.update' else 'payment.view' end
    when 'REPAIR_ORDER' then case upper(p_action) when 'CREATE' then 'repair.create' when 'EDIT' then 'repair.update' else 'repair.view' end
    when 'WARRANTY' then case when upper(p_action) in ('CREATE','EDIT') then 'warranty.manage' else 'warranty.view' end
    when 'WARRANTY_CLAIM' then case when upper(p_action) in ('CREATE','EDIT') then 'warranty.manage' else 'warranty.view' end
    when 'SERVICE_SCHEDULE' then case when upper(p_action) in ('CREATE','EDIT') then 'service.manage' else 'service.view' end
    when 'SOFTWARE_LICENSE' then case when upper(p_action) in ('CREATE','EDIT') then 'license.manage' else 'license.view' end
    when 'CHECKLIST_RUN' then case when upper(p_action)='EDIT' then 'checklist.run' else 'checklist.run' end
    when 'REMINDER' then case when upper(p_action) in ('CREATE','EDIT') then 'notification.manage' else 'notification.view' end
    when 'NOTIFICATION' then case when upper(p_action)='EDIT' then 'notification.manage' else 'notification.view' end
    else null
  end;
$$;

create or replace function private.qr_route(p_type text)
returns text
language sql
immutable
security invoker
set search_path=''
as $$
  select case upper(p_type)
    when 'CUSTOMER' then 'crm' when 'DEVICE' then 'crm'
    when 'PRODUCT' then 'inventory' when 'INVENTORY_UNIT' then 'inventory'
    when 'SALES_ORDER' then 'sales' when 'PAYMENT' then 'sales'
    when 'REPAIR_ORDER' then 'repair'
    when 'WARRANTY' then 'warranty' when 'WARRANTY_CLAIM' then 'warranty'
    when 'SERVICE_SCHEDULE' then 'service-license' when 'SOFTWARE_LICENSE' then 'service-license'
    when 'CHECKLIST_RUN' then 'checklist'
    when 'REMINDER' then 'reminders' when 'NOTIFICATION' then 'notifications'
    else null
  end;
$$;

create or replace function private.qr_find_resource(p_type text,p_reference text)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_type text:=upper(btrim(coalesce(p_type,'')));
  v_ref text:=btrim(coalesce(p_reference,''));
  v_id uuid;
  v_label text;
  v_uuid uuid;
begin
  if v_ref ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    v_uuid:=v_ref::uuid;
  end if;

  case v_type
    when 'CUSTOMER' then select id,customer_code into v_id,v_label from public.customers where id=v_uuid or upper(customer_code)=upper(v_ref) limit 1;
    when 'DEVICE' then select id,device_code into v_id,v_label from public.customer_devices where id=v_uuid or upper(device_code)=upper(v_ref) limit 1;
    when 'PRODUCT' then select id,sku into v_id,v_label from public.products where id=v_uuid or upper(sku)=upper(v_ref) limit 1;
    when 'INVENTORY_UNIT' then select id,serial_number into v_id,v_label from public.inventory_units where id=v_uuid or lower(serial_number)=lower(v_ref) or lower(coalesce(asset_tag,''))=lower(v_ref) limit 1;
    when 'SALES_ORDER' then select id,order_code into v_id,v_label from public.sales_orders where id=v_uuid or upper(order_code)=upper(v_ref) limit 1;
    when 'PAYMENT' then select id,payment_code into v_id,v_label from public.payments where id=v_uuid or upper(payment_code)=upper(v_ref) limit 1;
    when 'REPAIR_ORDER' then select id,repair_code into v_id,v_label from public.repair_orders where id=v_uuid or upper(repair_code)=upper(v_ref) limit 1;
    when 'WARRANTY' then select id,warranty_code into v_id,v_label from public.warranties where id=v_uuid or upper(warranty_code)=upper(v_ref) limit 1;
    when 'WARRANTY_CLAIM' then select id,claim_code into v_id,v_label from public.warranty_claims where id=v_uuid or upper(claim_code)=upper(v_ref) limit 1;
    when 'SERVICE_SCHEDULE' then select id,'SERVICE-'||left(id::text,8) into v_id,v_label from public.service_schedules where id=v_uuid limit 1;
    when 'SOFTWARE_LICENSE' then select id,license_code into v_id,v_label from public.software_licenses where id=v_uuid or upper(license_code)=upper(v_ref) limit 1;
    when 'CHECKLIST_RUN' then select id,'CHECKLIST-'||left(id::text,8) into v_id,v_label from public.checklist_runs where id=v_uuid limit 1;
    when 'REMINDER' then select id,reminder_code into v_id,v_label from public.reminders where id=v_uuid or upper(reminder_code)=upper(v_ref) limit 1;
    when 'NOTIFICATION' then select id,'NOTICE-'||left(id::text,8) into v_id,v_label from public.notifications where id=v_uuid limit 1;
    else raise exception 'Unsupported QR resource type';
  end case;

  if v_id is null then raise exception 'QR resource not found'; end if;
  return jsonb_build_object('id',v_id,'label',v_label);
end;
$$;

create or replace function private.qr_issue_impl(
  p_resource_type text,
  p_reference text default null,
  p_intent text default 'VIEW',
  p_expires_at timestamptz default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_type text:=upper(btrim(coalesce(p_resource_type,'')));
  v_intent text:=upper(btrim(coalesce(p_intent,'VIEW')));
  v_permission text;
  v_resource jsonb;
  v_resource_id uuid;
  v_label text;
  v_token text;
  v_id uuid;
begin
  perform private.fn_assert_active_or_privileged();
  if not private.has_permission('qr.issue') then raise exception 'Missing permission qr.issue'; end if;
  if v_intent not in ('CREATE','VIEW','EDIT','PAY') then raise exception 'Unsupported QR intent'; end if;
  if v_intent='PAY' and v_type<>'SALES_ORDER' then raise exception 'PAY QR requires SALES_ORDER'; end if;

  v_permission:=private.qr_required_permission(v_type,v_intent);
  if v_permission is null or not private.has_permission(v_permission) then
    raise exception 'Missing permission for QR target';
  end if;

  if v_intent='CREATE' then
    if nullif(btrim(coalesce(p_reference,'')),'') is not null then raise exception 'CREATE QR must not include a resource reference'; end if;
    v_label:='CREATE-'||v_type;
  else
    v_resource:=private.qr_find_resource(v_type,p_reference);
    v_resource_id:=(v_resource->>'id')::uuid;
    v_label:=v_resource->>'label';
  end if;

  if p_expires_at is not null and (p_expires_at<=now() or p_expires_at>now()+interval '10 years') then
    raise exception 'QR expiry must be in the future and at most 10 years';
  end if;

  loop
    v_token:=encode(extensions.gen_random_bytes(32),'hex');
    begin
      insert into private.qr_codes(token_hash,resource_type,resource_id,intent,label_snapshot,created_by,expires_at)
      values(extensions.digest(v_token,'sha256'),v_type,v_resource_id,v_intent,v_label,auth.uid(),p_expires_at)
      returning id into v_id;
      exit;
    exception when unique_violation then null;
    end;
  end loop;

  insert into private.qr_action_events(qr_code_id,actor_user_id,event_type,resource_type,resource_id)
  values(v_id,auth.uid(),'ISSUED',v_type,v_resource_id);

  return jsonb_build_object('token',v_token,'path','/?qr='||v_token,'resource_type',v_type,'resource_id',v_resource_id,'intent',v_intent,'label',v_label,'expires_at',p_expires_at);
end;
$$;

create or replace function private.qr_resolve_impl(p_token text)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_code private.qr_codes%rowtype;
  v_view_permission text;
  v_actions text[]:='{}'::text[];
  v_balance numeric;
begin
  perform private.fn_assert_active_or_privileged();
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then return jsonb_build_object('found',false); end if;

  select * into v_code from private.qr_codes
  where token_hash=extensions.digest(lower(p_token),'sha256')
    and revoked_at is null and (expires_at is null or expires_at>now());
  if not found then return jsonb_build_object('found',false); end if;

  v_view_permission:=private.qr_required_permission(v_code.resource_type,case when v_code.intent='CREATE' then 'CREATE' else 'VIEW' end);
  if v_view_permission is null or not private.has_permission(v_view_permission) then raise exception 'QR target is not permitted for current user'; end if;

  if v_code.intent='CREATE' then
    v_actions:=array['CREATE'];
  else
    v_actions:=array['VIEW'];
    if v_code.intent='EDIT' and private.has_permission(private.qr_required_permission(v_code.resource_type,'EDIT')) then
      v_actions:=array_append(v_actions,'EDIT');
    end if;
    if v_code.intent='PAY' and v_code.resource_type='SALES_ORDER' and private.has_permission('payment.create') then
      select balance_due into v_balance from public.sales_orders where id=v_code.resource_id;
      if coalesce(v_balance,0)>0 then v_actions:=array_append(v_actions,'PAY'); end if;
    end if;
  end if;

  update private.qr_codes set use_count=use_count+1,last_used_at=now() where id=v_code.id;
  insert into private.qr_action_events(qr_code_id,actor_user_id,event_type,resource_type,resource_id)
  values(v_code.id,auth.uid(),'RESOLVED',v_code.resource_type,v_code.resource_id);

  return jsonb_build_object(
    'found',true,'resource_type',v_code.resource_type,'resource_id',v_code.resource_id,
    'intent',v_code.intent,'label',v_code.label_snapshot,'route',private.qr_route(v_code.resource_type),
    'allowed_actions',to_jsonb(v_actions),'expires_at',v_code.expires_at
  );
end;
$$;

create or replace function private.qr_revoke_impl(p_token text)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare v_code private.qr_codes%rowtype;
begin
  perform private.fn_assert_active_or_privileged();
  if not private.has_permission('qr.revoke') then raise exception 'Missing permission qr.revoke'; end if;
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then return jsonb_build_object('revoked',false); end if;
  update private.qr_codes set revoked_at=now(),revoked_by=auth.uid()
  where token_hash=extensions.digest(lower(p_token),'sha256') and revoked_at is null
  returning * into v_code;
  if not found then return jsonb_build_object('revoked',false); end if;
  insert into private.qr_action_events(qr_code_id,actor_user_id,event_type,resource_type,resource_id)
  values(v_code.id,auth.uid(),'REVOKED',v_code.resource_type,v_code.resource_id);
  return jsonb_build_object('revoked',true,'label',v_code.label_snapshot);
end;
$$;

create or replace function public.qr_issue(p_resource_type text,p_reference text default null,p_intent text default 'VIEW',p_expires_at timestamptz default null)
returns jsonb language sql volatile security definer set search_path=''
as $$ select private.qr_issue_impl(p_resource_type,p_reference,p_intent,p_expires_at); $$;
create or replace function public.qr_resolve(p_token text)
returns jsonb language sql volatile security definer set search_path=''
as $$ select private.qr_resolve_impl(p_token); $$;
create or replace function public.qr_revoke(p_token text)
returns jsonb language sql volatile security definer set search_path=''
as $$ select private.qr_revoke_impl(p_token); $$;

revoke execute on function private.qr_required_permission(text,text) from public,anon,authenticated;
revoke execute on function private.qr_route(text) from public,anon,authenticated;
revoke execute on function private.qr_find_resource(text,text) from public,anon,authenticated;
revoke execute on function private.qr_issue_impl(text,text,text,timestamptz) from public,anon,authenticated;
revoke execute on function private.qr_resolve_impl(text) from public,anon,authenticated;
revoke execute on function private.qr_revoke_impl(text) from public,anon,authenticated;

revoke execute on function public.qr_issue(text,text,text,timestamptz) from public,anon;
revoke execute on function public.qr_resolve(text) from public,anon;
revoke execute on function public.qr_revoke(text) from public,anon;
grant execute on function public.qr_issue(text,text,text,timestamptz) to authenticated;
grant execute on function public.qr_resolve(text) to authenticated;
grant execute on function public.qr_revoke(text) to authenticated;

commit;
