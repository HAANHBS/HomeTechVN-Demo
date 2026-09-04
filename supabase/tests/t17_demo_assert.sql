\set ON_ERROR_STOP on

begin;
\o /dev/null

do $$
declare
  v_count integer;
  v_total numeric;
  v_paid numeric;
  v_balance numeric;
  v_stock numeric;
begin
  select count(*) into v_count
  from public.profiles p
  join public.roles r on r.id=p.role_id
  where p.is_active
    and lower(p.email) in (
      'demo.admin@hometechvn.example',
      'demo.manager@hometechvn.example',
      'demo.sales@hometechvn.example',
      'demo.technician@hometechvn.example',
      'demo.cashier@hometechvn.example'
    );
  if v_count<>5 then raise exception 'T17 DEMO FAIL: expected 5 active demo profiles, got %',v_count; end if;

  select count(*) into v_count
  from public.customers
  where full_name in ('Nguyen Van An','Tran Thi Binh','Cong ty TNHH Minh Phat','Pham Van Cuong');
  if v_count<>4 then raise exception 'T17 DEMO FAIL: expected 4 demo customers, got %',v_count; end if;

  select count(*) into v_count
  from public.customer_devices
  where serial_number in ('DEMO-LAP-SN-001','DEMO-PRN-001','DEMO-PC-001','DEMO-HP-READY-001');
  if v_count<>4 then raise exception 'T17 DEMO FAIL: expected 4 demo devices, got %',v_count; end if;

  select count(*) into v_count
  from public.products
  where sku in ('DEMO-LAP-7490','DEMO-PSU-24V','DEMO-MOUSE-WL','DEMO-TONER-B2000');
  if v_count<>4 then raise exception 'T17 DEMO FAIL: expected 4 demo products, got %',v_count; end if;

  select total_amount,paid_amount,balance_due
  into v_total,v_paid,v_balance
  from public.sales_orders
  where note='T17 DEMO SALE COMPLETED' and status='COMPLETED';

  if v_total is null then raise exception 'T17 DEMO FAIL: completed sale missing'; end if;
  if v_paid<>v_total or v_balance<>0 then
    raise exception 'T17 DEMO FAIL: completed sale payment mismatch total=% paid=% balance=%',v_total,v_paid,v_balance;
  end if;

  select count(*) into v_count
  from public.sales_order_items soi
  join public.sales_orders so on so.id=soi.sales_order_id
  where so.note='T17 DEMO SALE COMPLETED';
  if v_count<>2 then raise exception 'T17 DEMO FAIL: completed sale expected 2 items, got %',v_count; end if;

  if not exists(
    select 1 from public.sales_orders
    where note='T17 DEMO RECEIVABLE'
      and status='PAYMENT_PENDING'
      and paid_amount=100000
      and balance_due=560000
      and payment_pending_at is not null
  ) then
    raise exception 'T17 DEMO FAIL: receivable fixture must be PAYMENT_PENDING with partial payment';
  end if;

  if not exists(
    select 1
    from public.payments p
    join public.sales_orders so on so.id=p.sales_order_id
    where so.note='T17 DEMO RECEIVABLE'
      and p.status='COMPLETED'
      and p.amount=100000
      and p.reference_no='DEMO-AR-001'
  ) then
    raise exception 'T17 DEMO FAIL: receivable partial-payment record missing';
  end if;

  if not exists(
    select 1
    from public.warranties
    where note='T17 DEMO SALE WARRANTY'
      and source_type='SALE'
      and status='ACTIVE'
      and lookup_token ~ '^[0-9a-f]{64}$'
  ) then raise exception 'T17 DEMO FAIL: sale warranty missing/invalid'; end if;

  if not exists(
    select 1
    from public.warranty_claims
    where issue_description='May thinh thoang mat nguon'
      and status='CLOSED'
      and qc_passed=true
  ) then raise exception 'T17 DEMO FAIL: closed warranty claim missing'; end if;

  if not exists(
    select 1 from public.repair_orders
    where intake_note='T17 DEMO REPAIR COMPLETED' and status='COMPLETED'
  ) then raise exception 'T17 DEMO FAIL: completed repair missing'; end if;

  if not exists(
    select 1 from public.warranties
    where note='T17 DEMO REPAIR WARRANTY'
      and source_type='REPAIR'
      and status='ACTIVE'
  ) then raise exception 'T17 DEMO FAIL: repair warranty missing'; end if;

  if not exists(
    select 1 from public.repair_orders
    where intake_note='T17 DEMO REPAIR READY' and status='READY' and ready_at is not null
  ) then raise exception 'T17 DEMO FAIL: READY repair missing'; end if;

  if not exists(
    select 1 from public.service_schedules
    where note='T17 DEMO SERVICE SCHEDULE'
      and status='ACTIVE'
      and next_due_date between current_date and current_date+7
  ) then raise exception 'T17 DEMO FAIL: due service schedule missing'; end if;

  if not exists(
    select 1 from public.software_licenses
    where note='T17 DEMO LICENSE EXPIRING'
      and status='ACTIVE'
      and end_date between current_date and current_date+7
      and secret_ref='vault://hometechvn/demo/m365/minhphat'
  ) then raise exception 'T17 DEMO FAIL: expiring license missing/secret_ref invalid'; end if;

  select coalesce(sum(
    case
      when t.transaction_type in ('RECEIVE','ADJUST_IN','RETURN_IN') then t.quantity
      else -t.quantity
    end
  ),0)
  into v_stock
  from public.inventory_transactions t
  join public.products p on p.id=t.product_id
  where p.sku='DEMO-PSU-24V';

  if v_stock<>9 then raise exception 'T17 DEMO FAIL: repair part stock expected 9, got %',v_stock; end if;

  if not exists(
    select 1 from public.inventory_units iu
    join public.products p on p.id=iu.product_id
    where p.sku='DEMO-LAP-7490'
      and iu.serial_number='DEMO-LAP-SN-001'
      and iu.status='OUT'
  ) then raise exception 'T17 DEMO FAIL: sold serialized unit not OUT'; end if;

  select count(*) into v_count
  from public.reminders
  where source_type in ('WARRANTY','SOFTWARE_LICENSE','SERVICE_SCHEDULE','REPAIR_ORDER','SALES_ORDER','PRODUCT')
    and (
      source_label like '%DEMO%'
      or source_id in (
        select id from public.repair_orders where intake_note like 'T17 DEMO%'
        union all select id from public.sales_orders where note like 'T17 DEMO%'
        union all select id from public.warranties where note like 'T17 DEMO%'
        union all select id from public.service_schedules where note like 'T17 DEMO%'
        union all select id from public.software_licenses where note like 'T17 DEMO%'
        union all select id from public.products where sku like 'DEMO-%'
      )
    );
  if v_count<5 then raise exception 'T17 DEMO FAIL: expected >=5 integrated reminders, got %',v_count; end if;

  if not exists(
    select 1
    from public.reminders r
    join public.sales_orders so on so.id=r.source_id
    where r.rule_code_snapshot='RECEIVABLE_DUE'
      and r.source_type='SALES_ORDER'
      and so.note='T17 DEMO RECEIVABLE'
  ) then
    raise exception 'T17 DEMO FAIL: RECEIVABLE_DUE reminder missing';
  end if;

  select count(*) into v_count
  from public.notifications
  where channel='IN_APP' and status='SENT';
  if v_count<1 then raise exception 'T17 DEMO FAIL: expected IN_APP notifications'; end if;

  if not exists(
    select 1 from public.settings
    where key='demo.t17.dataset'
      and value->>'stage'='T17'
      and value->>'mode'='LOCAL_ONLY'
  ) then raise exception 'T17 DEMO FAIL: dataset marker missing'; end if;

  select count(*) into v_count
  from public.audit_logs
  where table_name in (
    'customers','customer_devices','products','sales_orders','repair_orders',
    'warranties','warranty_claims','service_schedules','software_licenses',
    'reminders','notifications'
  );
  if v_count<25 then raise exception 'T17 DEMO FAIL: audit coverage too small: %',v_count; end if;
end $$;

-- Verify role mapping exactly.
do $$
declare
  v_bad integer;
begin
  select count(*) into v_bad
  from (values
    ('demo.admin@hometechvn.example','admin'),
    ('demo.manager@hometechvn.example','manager'),
    ('demo.sales@hometechvn.example','sales'),
    ('demo.technician@hometechvn.example','technician'),
    ('demo.cashier@hometechvn.example','cashier')
  ) expected(email,role_code)
  left join public.profiles p on lower(p.email)=expected.email
  left join public.roles r on r.id=p.role_id
  where r.code is distinct from expected.role_code or coalesce(p.is_active,false)=false;

  if v_bad<>0 then raise exception 'T17 DEMO FAIL: demo role mapping mismatch count=%',v_bad; end if;
end $$;

-- Dashboard, Reports, Security snapshot must work for Demo Admin.
select set_config(
  'request.jwt.claim.sub',
  (select id::text from public.profiles where lower(email)='demo.admin@hometechvn.example'),
  true
);
do $$
declare
  v_role text;
begin
  select r.code into v_role
  from public.profiles p
  join public.roles r on r.id=p.role_id
  where lower(p.email)='demo.admin@hometechvn.example';

  if v_role is distinct from 'admin' then
    raise exception 'T17 ASSERT PRIVILEGED ROLE MAP FAIL: expected admin, got %',v_role;
  end if;
end $$;
set local role authenticated;
\echo [T17 SQL PHASE] ASSERT_ADMIN_RPC_CONTEXT
do $$
begin
  if auth.uid() is null then
    raise exception 'T17 ASSERT AUTH/PERMISSION CONTEXT FAIL: admin auth.uid is null';
  end if;
  if not private.has_permission('report.view') or not private.has_permission('audit.view') then
    raise exception 'T17 ASSERT AUTH/PERMISSION CONTEXT FAIL: admin report/audit permission missing';
  end if;
end $$;

do $$
declare
  v_dashboard jsonb;
  v_report jsonb;
  v_security jsonb;
begin
  v_dashboard:=public.dashboard_snapshot(30,now());
  if v_dashboard is null or jsonb_typeof(v_dashboard)<>'object' then
    raise exception 'T17 DEMO FAIL: dashboard_snapshot invalid';
  end if;

  v_report:=public.report_snapshot(current_date-30,current_date,'DAY',now());
  if v_report is null or jsonb_typeof(v_report)<>'object' then
    raise exception 'T17 DEMO FAIL: report_snapshot invalid';
  end if;

  v_security:=public.security_audit_snapshot();
  if coalesce((v_security#>>'{rls,tables_without_policy}')::int,-1)<>0 then
    raise exception 'T17 DEMO FAIL: security snapshot RLS gap';
  end if;
end $$;

reset role;

-- Public Warranty security contract:
-- 1) privileged test harness obtains the fixture token;
-- 2) anon cannot SELECT public.warranties;
-- 3) anon may only execute public.warranty_public_lookup(token).
select set_config(
  't17.public_warranty_token',
  (select lookup_token
   from public.warranties
   where note='T17 DEMO SALE WARRANTY'),
  true
);

do $$
begin
  if current_setting('t17.public_warranty_token',true) is null then
    raise exception 'T17 DEMO FAIL: public warranty fixture token missing';
  end if;
end $$;

set local role anon;
\echo [T17 SQL PHASE] ASSERT_ANON_PUBLIC_WARRANTY_RPC

do $$
declare
  v_token text:=current_setting('t17.public_warranty_token',true);
  v_lookup jsonb;
begin
  v_lookup:=public.warranty_public_lookup(v_token);

  if coalesce((v_lookup->>'found')::boolean,false)<>true then
    raise exception 'T17 DEMO FAIL: public warranty lookup not found';
  end if;

  if v_lookup ? 'customer_id'
     or v_lookup ? 'source_id'
     or v_lookup ? 'lookup_token'
     or v_lookup ? 'created_by'
     or v_lookup ? 'updated_by'
  then
    raise exception 'T17 DEMO FAIL: public warranty leaked internal fields';
  end if;
end $$;

reset role;

\o
do $$ begin
  raise notice 'T17 DEMO INTEGRATION CHECKS: PASS';
end $$;

rollback;
