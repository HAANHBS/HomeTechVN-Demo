\set ON_ERROR_STOP on
begin;

do $$
declare
  v_tables integer;
  v_rules integer;
  v_direct boolean;
begin
  select count(*) into v_tables
  from information_schema.tables
  where table_schema='public' and table_name in ('reminder_rules','reminders');
  if v_tables<>2 then raise exception 'T9 reminder table count expected 2, got %',v_tables; end if;

  select count(*) into v_rules from public.reminder_rules where is_system=true;
  if v_rules<>12 then raise exception 'T9 system rules expected 12, got %',v_rules; end if;

  select has_table_privilege('authenticated','public.reminder_rules','INSERT') into v_direct;
  if v_direct then raise exception 'authenticated must not INSERT reminder_rules directly'; end if;
  select has_table_privilege('authenticated','public.reminders','INSERT') into v_direct;
  if v_direct then raise exception 'authenticated must not INSERT reminders directly'; end if;
  select has_table_privilege('authenticated','public.reminders','UPDATE') into v_direct;
  if v_direct then raise exception 'authenticated must not UPDATE reminders directly'; end if;

  if not has_function_privilege('service_role','private.reminder_generate_impl(timestamptz)','EXECUTE') then
    raise exception 'service_role missing reminder_generate_impl EXECUTE';
  end if;
  if not has_schema_privilege('service_role','private','USAGE') then
    raise exception 'service_role missing private schema USAGE';
  end if;
end $$;

insert into auth.users(id,email,raw_user_meta_data)
values('99999999-9999-4999-8999-999999999999','t9-local-verify@example.invalid','{}'::jsonb);

update public.profiles
set role_id=(select id from public.roles where code='admin'),
    is_active=true,
    full_name='T9 Local Verify'
where id='99999999-9999-4999-8999-999999999999';

insert into public.customers(id,customer_code,full_name,phone,status)
values('90000000-0000-4000-8000-000000000001','CUS-990001','T9 LOCAL CUSTOMER','0999000001','ACTIVE');

insert into public.customer_devices(id,device_code,customer_id,device_type,brand,model,serial_number,status)
values('90000000-0000-4000-8000-000000000002','DEV-990001','90000000-0000-4000-8000-000000000001','Laptop','Dell','T9','T9-LOCAL-SN','ACTIVE');

insert into public.services(id,name,category,default_interval_count,default_interval_unit,default_price,warranty_months,is_active)
values('90000000-0000-4000-8000-000000000003','T9 Local Maintenance','MAINTENANCE',1,'MONTHS',0,3,true);

insert into public.service_schedules(
  id,service_id,customer_id,customer_device_id,status,interval_count,interval_unit,start_date,next_due_date,price
) values(
  '90000000-0000-4000-8000-000000000004',
  '90000000-0000-4000-8000-000000000003',
  '90000000-0000-4000-8000-000000000001',
  '90000000-0000-4000-8000-000000000002',
  'ACTIVE',1,'MONTHS','2026-08-01','2026-09-06',0
);

insert into public.warranties(
  id,warranty_code,lookup_token,customer_id,customer_device_id,source_type,source_id,source_item_id,
  product_name_snapshot,serial_snapshot,coverage,start_date,end_date,status
) values(
  '90000000-0000-4000-8000-000000000005','WAR-260830-9901',repeat('a',64),
  '90000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002',
  'SERVICE','90000000-0000-4000-8000-000000000004','90000000-0000-4000-8000-000000000099',
  'T9 Warranty Item','T9-WAR-SN','T9 coverage','2026-08-01','2026-09-29','ACTIVE'
);

insert into public.software_products(id,category,vendor,name,billing_model,default_term_months,is_active)
values('90000000-0000-4000-8000-000000000006','M365','Microsoft','T9 M365','SUBSCRIPTION',12,true);

insert into public.software_licenses(
  id,license_code,software_product_id,customer_id,customer_device_id,status,start_date,end_date,seats,secret_ref
) values(
  '90000000-0000-4000-8000-000000000007','LIC-990001',
  '90000000-0000-4000-8000-000000000006','90000000-0000-4000-8000-000000000001',
  '90000000-0000-4000-8000-000000000002','ACTIVE','2026-01-01','2026-09-29',1,'vault://t9/license'
);

insert into public.repair_orders(id,repair_code,customer_id,customer_device_id,status,reported_issue,ready_at)
values(
  '90000000-0000-4000-8000-000000000008','SRV-260830-9901',
  '90000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002',
  'READY','T9 ready','2026-08-26 12:00+00'
);

insert into public.repair_orders(id,repair_code,customer_id,customer_device_id,status,reported_issue,awaiting_customer_at)
values(
  '90000000-0000-4000-8000-000000000009','SRV-260830-9902',
  '90000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002',
  'AWAITING_CUSTOMER','T9 quote','2026-08-29 06:00+00'
);

insert into public.repair_orders(id,repair_code,customer_id,customer_device_id,status,reported_issue,estimated_completion_at)
values(
  '90000000-0000-4000-8000-000000000010','SRV-260830-9903',
  '90000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002',
  'REPAIRING','T9 overdue','2026-08-30 11:00+00'
);

insert into public.sales_orders(id,order_code,customer_id,status,subtotal,total_amount,paid_amount,payment_pending_at)
values(
  '90000000-0000-4000-8000-000000000011','SO-260830-9901',
  '90000000-0000-4000-8000-000000000001','PAYMENT_PENDING',
  1000000,1000000,500000,'2026-08-30 11:00+00'
);

insert into public.product_categories(id,name)
values('90000000-0000-4000-8000-000000000012','T9 LOCAL CAT');

insert into public.products(id,sku,name,category_id,unit,sale_price,min_stock,track_serial,is_active)
values(
  '90000000-0000-4000-8000-000000000013','T9-LOW','T9 Low Stock',
  '90000000-0000-4000-8000-000000000012','cái',100000,5,false,true
);

set local role authenticated;
select set_config('request.jwt.claim.sub','99999999-9999-4999-8999-999999999999',true);
select set_config('request.jwt.claims','{"sub":"99999999-9999-4999-8999-999999999999","role":"authenticated"}',true);

select public.reminder_generate('2026-08-30 12:00+00'::timestamptz);

do $$
declare v_count integer; v_due integer; v_pending integer;
begin
  select count(*) into v_count from public.reminders;
  select count(*) into v_due from public.reminders where status='DUE';
  select count(*) into v_pending from public.reminders where status='PENDING';

  if v_count<>12 then raise exception 'Expected 12 reminders, got %',v_count; end if;
  if v_due<>9 or v_pending<>3 then
    raise exception 'Expected due/pending 9/3, got %/%',v_due,v_pending;
  end if;
  if exists(select 1 from public.reminders where reminder_code !~ '^REM-[0-9]{6}$') then
    raise exception 'Invalid REM code';
  end if;
  if (select count(distinct dedupe_key) from public.reminders)<>12 then
    raise exception 'Dedupe keys are not unique';
  end if;
end $$;

-- Idempotent rerun.
select public.reminder_generate('2026-08-30 12:05+00'::timestamptz);
do $$ begin
  if (select count(*) from public.reminders)<>12 then
    raise exception 'Generator duplicated reminders';
  end if;
end $$;

-- Sales: view/ack/snooze, but cannot manage rules/generator.
reset role;
update public.profiles
set role_id=(select id from public.roles where code='sales')
where id='99999999-9999-4999-8999-999999999999';
set local role authenticated;
select set_config('request.jwt.claim.sub','99999999-9999-4999-8999-999999999999',true);
select set_config('request.jwt.claims','{"sub":"99999999-9999-4999-8999-999999999999","role":"authenticated"}',true);

select public.reminder_acknowledge(
  (select id from public.reminders where rule_code_snapshot='QUOTE_WAITING_24H'),
  'Đã gọi khách'
);

select public.reminder_snooze(
  (select id from public.reminders where rule_code_snapshot='LOW_STOCK'),
  now()+interval '4 hours',
  'Chờ nhập hàng'
);

do $$
begin
  begin
    perform public.reminder_generate('2026-08-30 12:10+00');
    raise exception 'Sales unexpectedly ran generator';
  exception when others then
    if sqlerrm='Sales unexpectedly ran generator' then raise; end if;
    if position('notification.manage' in sqlerrm)=0 then raise; end if;
  end;

  begin
    perform public.reminder_rule_update(
      (select id from public.reminder_rules where rule_code='LOW_STOCK'),
      'Denied',0,'HIGH',true,null
    );
    raise exception 'Sales unexpectedly managed reminder rules';
  exception when others then
    if sqlerrm='Sales unexpectedly managed reminder rules' then raise; end if;
    if position('notification.manage' in sqlerrm)=0 then raise; end if;
  end;
end $$;

-- Manager: disable rule -> auto-resolve, re-enable -> same row reopens.
reset role;
update public.profiles
set role_id=(select id from public.roles where code='manager')
where id='99999999-9999-4999-8999-999999999999';
set local role authenticated;
select set_config('request.jwt.claim.sub','99999999-9999-4999-8999-999999999999',true);
select set_config('request.jwt.claims','{"sub":"99999999-9999-4999-8999-999999999999","role":"authenticated"}',true);

select public.reminder_rule_update(
  (select id from public.reminder_rules where rule_code='LOW_STOCK'),
  'Tồn kho thấp',0,'HIGH',false,'disabled verify'
);
select public.reminder_generate('2026-08-30 12:15+00');

do $$ begin
  if (select status from public.reminders where rule_code_snapshot='LOW_STOCK')<>'RESOLVED' then
    raise exception 'Disabled rule did not resolve reminder';
  end if;
  if (select resolution_reason from public.reminders where rule_code_snapshot='LOW_STOCK')<>'RULE_DISABLED' then
    raise exception 'Wrong rule-disabled resolution reason';
  end if;
end $$;

select public.reminder_rule_update(
  (select id from public.reminder_rules where rule_code='LOW_STOCK'),
  'Tồn kho thấp',0,'HIGH',true,'enabled verify'
);
select public.reminder_generate('2026-08-30 12:20+00');

do $$ begin
  if (select count(*) from public.reminders where rule_code_snapshot='LOW_STOCK')<>1 then
    raise exception 'LOW_STOCK duplicated after re-enable';
  end if;
  if (select status from public.reminders where rule_code_snapshot='LOW_STOCK')<>'DUE' then
    raise exception 'LOW_STOCK did not reopen DUE';
  end if;
end $$;

-- Manual resolve remains closed while the condition persists.
select public.reminder_resolve(
  (select id from public.reminders where rule_code_snapshot='LOW_STOCK'),
  'Đã ghi nhận',
  'manual resolve verify'
);
select public.reminder_generate('2026-08-30 12:20:30+00');

do $$ begin
  if (select status from public.reminders where rule_code_snapshot='LOW_STOCK')<>'RESOLVED' then
    raise exception 'Manual resolve reopened while condition still persisted';
  end if;
  if (select resolution_reason from public.reminders where rule_code_snapshot='LOW_STOCK') not like 'MANUAL:%' then
    raise exception 'Manual resolve marker missing';
  end if;
end $$;

-- Condition clears -> re-arm the resolved reminder.
select public.inventory_receive(
  '90000000-0000-4000-8000-000000000013',
  10,1000,null,'T9 verifier stock clear','VERIFY',null,'T9 rearm'
);
select public.reminder_generate('2026-08-30 12:21+00');

do $$ begin
  if (select resolution_reason from public.reminders where rule_code_snapshot='LOW_STOCK')<>'CONDITION_CLEARED' then
    raise exception 'Manual reminder did not re-arm after condition clear';
  end if;
end $$;

-- Condition returns -> same row reopens, still no duplicate.
select public.inventory_issue(
  '90000000-0000-4000-8000-000000000013',
  10,null,'T9 verifier stock low','VERIFY',null
);
select public.reminder_generate('2026-08-30 12:21:30+00');

do $$ begin
  if (select status from public.reminders where rule_code_snapshot='LOW_STOCK')<>'DUE' then
    raise exception 'Reappeared low-stock condition did not reopen reminder';
  end if;
  if (select count(*) from public.reminders where rule_code_snapshot='LOW_STOCK')<>1 then
    raise exception 'Manual re-arm created a duplicate reminder';
  end if;
end $$;

-- Source condition clears -> all READY-derived reminders auto-resolve.
reset role;
update public.repair_orders
set status='RETURNED',returned_at='2026-08-30 12:21+00'
where id='90000000-0000-4000-8000-000000000008';

set local role authenticated;
select set_config('request.jwt.claim.sub','99999999-9999-4999-8999-999999999999',true);
select set_config('request.jwt.claims','{"sub":"99999999-9999-4999-8999-999999999999","role":"authenticated"}',true);
select public.reminder_generate('2026-08-30 12:22+00');

do $$ begin
  if (
    select count(*) from public.reminders
    where source_id='90000000-0000-4000-8000-000000000008'
      and status='RESOLVED'
  )<>3 then
    raise exception 'READY reminders did not auto-resolve';
  end if;
end $$;

-- Service role path for future Cloudflare Worker.
reset role;
set local role service_role;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select public.reminder_generate('2026-08-30 12:25+00');

reset role;

do $$
begin
  if (select status from public.reminders where rule_code_snapshot='QUOTE_WAITING_24H')<>'ACKNOWLEDGED' then
    raise exception 'Acknowledged state was not preserved';
  end if;
  if (select count(*) from public.reminders)<>12 then
    raise exception 'Final reminder count expected 12';
  end if;
  if (select count(*) from public.reminders where source_type='WARRANTY')<>2 then
    raise exception 'Warranty 30/7 reminders missing';
  end if;
  if (select count(*) from public.reminders where source_type='SOFTWARE_LICENSE')<>2 then
    raise exception 'License 30/7 reminders missing';
  end if;
  if (select count(*) from public.reminders where rule_code_snapshot like 'REPAIR_UNCOLLECTED_%')<>2 then
    raise exception 'Uncollected 3/7 reminders missing';
  end if;
end $$;

select
  (select count(*) from public.reminder_rules where is_system) as system_rules,
  (select count(*) from public.reminders) as reminder_count,
  (select count(*) from public.reminders where status='RESOLVED') as resolved_count,
  (select status from public.reminders where rule_code_snapshot='QUOTE_WAITING_24H') as quote_status;

do $$ begin
  raise notice 'T9 FINAL CORE CHECKS: PASS';
end $$;

rollback;
