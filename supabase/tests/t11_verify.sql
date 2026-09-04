\set ON_ERROR_STOP on
begin;

-- Function/grant contract.
do $$
begin
  if not exists(
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='dashboard_snapshot'
  ) then raise exception 'dashboard_snapshot missing'; end if;

  if not has_function_privilege('authenticated','public.dashboard_snapshot(integer,timestamptz)','EXECUTE') then
    raise exception 'authenticated missing dashboard_snapshot EXECUTE';
  end if;

  if has_function_privilege('anon','public.dashboard_snapshot(integer,timestamptz)','EXECUTE') then
    raise exception 'anon unexpectedly has dashboard_snapshot EXECUTE';
  end if;
end $$;

-- Deterministic local data.
insert into auth.users(id,email,raw_user_meta_data) values
('b1100000-0000-4000-8000-000000000001','t11-admin@example.invalid','{}'::jsonb),
('b1100000-0000-4000-8000-000000000002','t11-cashier@example.invalid','{}'::jsonb),
('b1100000-0000-4000-8000-000000000003','t11-tech@example.invalid','{}'::jsonb);

update public.profiles set role_id=(select id from public.roles where code='admin'),is_active=true,full_name='T11 Admin' where id='b1100000-0000-4000-8000-000000000001';
update public.profiles set role_id=(select id from public.roles where code='cashier'),is_active=true,full_name='T11 Cashier' where id='b1100000-0000-4000-8000-000000000002';
update public.profiles set role_id=(select id from public.roles where code='technician'),is_active=true,full_name='T11 Technician' where id='b1100000-0000-4000-8000-000000000003';

insert into public.customers(id,customer_code,full_name,phone,status,created_at) values
('b1110000-0000-4000-8000-000000000001','CUS-119001','T11 Customer','0911000001','ACTIVE','2026-08-30 03:00+00');
insert into public.customer_devices(id,device_code,customer_id,device_type,status) values
('b1120000-0000-4000-8000-000000000001','DEV-119001','b1110000-0000-4000-8000-000000000001','Laptop','ACTIVE');

insert into public.sales_orders(id,order_code,customer_id,status,subtotal,total_amount,paid_amount,payment_pending_at,created_at) values
('b1130000-0000-4000-8000-000000000001','SO-260830-9901','b1110000-0000-4000-8000-000000000001','PAYMENT_PENDING',1000000,1000000,400000,'2026-08-30 04:00+00','2026-08-30 04:00+00'),
('b1130000-0000-4000-8000-000000000002','SO-260830-9902','b1110000-0000-4000-8000-000000000001','COMPLETED',2000000,2000000,2000000,null,'2026-08-30 05:00+00');
insert into public.payments(id,payment_code,sales_order_id,amount,payment_method,status,paid_at) values
('b1140000-0000-4000-8000-000000000001','PAY-260830-9901','b1130000-0000-4000-8000-000000000002',2000000,'CASH','COMPLETED','2026-08-30 05:05+00');

insert into public.repair_orders(id,repair_code,customer_id,customer_device_id,status,priority,reported_issue,estimated_completion_at,created_at) values
('b1150000-0000-4000-8000-000000000001','SRV-260830-9901','b1110000-0000-4000-8000-000000000001','b1120000-0000-4000-8000-000000000001','REPAIRING','HIGH','T11 repair','2026-08-30 02:00+00','2026-08-29 03:00+00'),
('b1150000-0000-4000-8000-000000000002','SRV-260830-9902','b1110000-0000-4000-8000-000000000001','b1120000-0000-4000-8000-000000000001','READY','NORMAL','T11 ready',null,'2026-08-30 03:00+00');

insert into public.product_categories(id,name) values('b1160000-0000-4000-8000-000000000001','T11 Category');
insert into public.products(id,sku,name,category_id,unit,sale_price,min_stock,track_serial,is_active) values
('b1170000-0000-4000-8000-000000000001','T11-LOW','T11 Low Stock','b1160000-0000-4000-8000-000000000001','cái',100000,5,false,true);

insert into public.warranties(id,warranty_code,lookup_token,customer_id,source_type,source_id,source_item_id,product_name_snapshot,coverage,start_date,end_date,status) values
('b1180000-0000-4000-8000-000000000001','WAR-260830-9901',repeat('b',64),'b1110000-0000-4000-8000-000000000001','SALE','b1130000-0000-4000-8000-000000000002','b1170000-0000-4000-8000-000000000001','T11 Product','T11 coverage','2026-08-01','2026-09-05','ACTIVE');

insert into public.services(id,name,category,default_interval_count,default_interval_unit,default_price,warranty_months,is_active) values
('b1190000-0000-4000-8000-000000000001','T11 Service','MAINTENANCE',1,'MONTHS',0,3,true);
insert into public.service_schedules(id,service_id,customer_id,status,interval_count,interval_unit,start_date,next_due_date,price) values
('b1190000-0000-4000-8000-000000000002','b1190000-0000-4000-8000-000000000001','b1110000-0000-4000-8000-000000000001','ACTIVE',1,'MONTHS','2026-08-01','2026-09-03',0);

insert into public.software_products(id,category,name,billing_model,default_term_months,is_active) values
('b1200000-0000-4000-8000-000000000001','M365','T11 M365','SUBSCRIPTION',12,true);
insert into public.software_licenses(id,license_code,software_product_id,customer_id,status,start_date,end_date,seats) values
('b1200000-0000-4000-8000-000000000002','LIC-119001','b1200000-0000-4000-8000-000000000001','b1110000-0000-4000-8000-000000000001','ACTIVE','2026-01-01','2026-09-06',1);

insert into public.reminder_rules(id,rule_code,name,event_type,offset_minutes,priority,is_active,is_system,staff_channels,customer_channels) values
('b1210000-0000-4000-8000-000000000001','T11_RULE','T11 Reminder','WARRANTY_END',0,'URGENT',true,false,array['IN_APP']::text[],array[]::text[]);
insert into public.reminders(id,reminder_code,rule_id,rule_code_snapshot,event_type,source_type,source_id,source_label,customer_id,due_at,priority,status,title,message,dedupe_key) values
('b1210000-0000-4000-8000-000000000002','REM-119001','b1210000-0000-4000-8000-000000000001','T11_RULE','WARRANTY_END','WARRANTY','b1180000-0000-4000-8000-000000000001','WAR-260830-9901','b1110000-0000-4000-8000-000000000001','2026-08-30 01:00+00','URGENT','DUE','T11 urgent','T11 reminder body','T11:1');
insert into public.notifications(id,notification_code,reminder_id,channel,provider,audience,recipient_profile_id,body,status,scheduled_at,next_attempt_at,sent_at,delivery_key) values
('b1220000-0000-4000-8000-000000000001','NTF-119001','b1210000-0000-4000-8000-000000000002','IN_APP','IN_APP','STAFF','b1100000-0000-4000-8000-000000000001','T11 inapp','SENT','2026-08-30 01:00+00','2026-08-30 01:00+00','2026-08-30 01:00+00','T11:inapp');

-- Admin sees all permitted KPI sections.
set local role authenticated;
select set_config('request.jwt.claim.sub','b1100000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"b1100000-0000-4000-8000-000000000001","role":"authenticated"}',true);

do $$
declare j jsonb;
begin
  j:=public.dashboard_snapshot(30,'2026-08-30 12:00+00');
  if (j#>>'{kpis,sales,orders_period}')::int<>2 then raise exception 'Admin sales order KPI mismatch'; end if;
  if (j#>>'{kpis,sales,sales_value_period}')::numeric<>2000000 then raise exception 'Admin sales value KPI mismatch'; end if;
  if (j#>>'{kpis,sales,payments_received_period}')::numeric<>2000000 then raise exception 'Admin payment KPI mismatch'; end if;
  if (j#>>'{kpis,repairs,open}')::int<>2 then raise exception 'Admin repair open KPI mismatch'; end if;
  if (j#>>'{kpis,repairs,overdue}')::int<>1 then raise exception 'Admin repair overdue KPI mismatch'; end if;
  if (j#>>'{kpis,inventory,low_stock}')::int<>1 then raise exception 'Admin low stock KPI mismatch'; end if;
  if (j#>>'{kpis,warranty,expiring_7d}')::int<>1 then raise exception 'Admin warranty KPI mismatch'; end if;
  if (j#>>'{kpis,service,due_7d}')::int<>1 then raise exception 'Admin service KPI mismatch'; end if;
  if (j#>>'{kpis,license,expiring_7d}')::int<>1 then raise exception 'Admin license KPI mismatch'; end if;
  if (j#>>'{kpis,reminders,urgent_due}')::int<>1 then raise exception 'Admin reminder KPI mismatch'; end if;
  if jsonb_array_length(j#>'{charts,sales_daily}')<>30 then raise exception 'Sales daily series expected 30 days'; end if;
  if jsonb_array_length(j#>'{attention,low_stock}')<>1 then raise exception 'Low stock attention mismatch'; end if;
end $$;

-- Cashier has dashboard.view but Service/License sections stay hidden.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b1100000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"b1100000-0000-4000-8000-000000000002","role":"authenticated"}',true);

do $$
declare j jsonb;
begin
  j:=public.dashboard_snapshot(7,'2026-08-30 12:00+00');
  if j#>'{kpis,service}' <> 'null'::jsonb then raise exception 'Cashier service KPI should be JSON null'; end if;
  if j#>'{kpis,license}' <> 'null'::jsonb then raise exception 'Cashier license KPI should be JSON null'; end if;
  if (j#>>'{permissions,service}')::boolean then raise exception 'Cashier service permission leaked'; end if;
  if not (j#>>'{permissions,sales}')::boolean then raise exception 'Cashier sales should be visible'; end if;
end $$;

-- Technician has sale.view but no payment.view: payment totals must not leak.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b1100000-0000-4000-8000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"b1100000-0000-4000-8000-000000000003","role":"authenticated"}',true);

do $$
declare j jsonb;
begin
  j:=public.dashboard_snapshot(90,'2026-08-30 12:00+00');
  if (j#>>'{permissions,payments}')::boolean then raise exception 'Technician payment permission leaked'; end if;
  if (j#>'{kpis,sales}') ? 'payments_received_period' then raise exception 'Technician payment KPI unexpectedly present'; end if;

  begin
    perform public.dashboard_snapshot(14,'2026-08-30 12:00+00');
    raise exception 'Invalid period unexpectedly accepted';
  exception when others then
    if sqlerrm='Invalid period unexpectedly accepted' then raise; end if;
    if position('7, 30 or 90' in sqlerrm)=0 then raise; end if;
  end;
end $$;

reset role;

do $$ begin
  raise notice 'T11 FINAL CORE CHECKS: PASS';
end $$;

rollback;
