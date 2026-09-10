\set ON_ERROR_STOP on
begin;

-- ------------------------------------------------------------------
-- T13 function / grant contract
-- ------------------------------------------------------------------
do $$
begin
  if not exists(
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname='report_snapshot'
      and pg_get_function_identity_arguments(p.oid)='p_start_date date, p_end_date date, p_bucket text, p_now timestamp with time zone'
  ) then
    raise exception 'public.report_snapshot missing';
  end if;

  if not has_function_privilege(
    'authenticated',
    'public.report_snapshot(date,date,text,timestamptz)',
    'EXECUTE'
  ) then
    raise exception 'authenticated missing report_snapshot EXECUTE';
  end if;

  if has_function_privilege(
    'anon',
    'public.report_snapshot(date,date,text,timestamptz)',
    'EXECUTE'
  ) then
    raise exception 'anon unexpectedly has report_snapshot EXECUTE';
  end if;
end $$;

-- ------------------------------------------------------------------
-- Deterministic test users. The 2099 period isolates period metrics
-- from any normal/demo 2026 data.
-- ------------------------------------------------------------------
insert into auth.users(id,email,raw_user_meta_data) values
('d1300000-0000-4000-8000-000000000001','t13-admin@example.invalid','{}'::jsonb),
('d1300000-0000-4000-8000-000000000002','t13-sales@example.invalid','{}'::jsonb),
('d1300000-0000-4000-8000-000000000003','t13-cashier@example.invalid','{}'::jsonb),
('d1300000-0000-4000-8000-000000000004','t13-tech@example.invalid','{}'::jsonb);

update public.profiles
set role_id=(select id from public.roles where code='admin'),
    is_active=true,full_name='T13 Admin'
where id='d1300000-0000-4000-8000-000000000001';

update public.profiles
set role_id=(select id from public.roles where code='sales'),
    is_active=true,full_name='T13 Sales'
where id='d1300000-0000-4000-8000-000000000002';

update public.profiles
set role_id=(select id from public.roles where code='cashier'),
    is_active=true,full_name='T13 Cashier'
where id='d1300000-0000-4000-8000-000000000003';

update public.profiles
set role_id=(select id from public.roles where code='technician'),
    is_active=true,full_name='T13 Technician'
where id='d1300000-0000-4000-8000-000000000004';

insert into public.customers(
  id,customer_code,full_name,phone,status,created_at
) values(
  'd1310000-0000-4000-8000-000000000001',
  'CUS-139001','T13 Customer','0913000001','ACTIVE',
  '2099-08-01 02:00+00'
);

insert into public.customer_devices(
  id,device_code,customer_id,device_type,brand,model,status,created_at
) values(
  'd1320000-0000-4000-8000-000000000001',
  'DEV-139001',
  'd1310000-0000-4000-8000-000000000001',
  'Laptop','Dell','T13','ACTIVE',
  '2099-08-01 02:05+00'
);

insert into public.product_categories(id,name) values(
  'd1330000-0000-4000-8000-000000000001',
  'T13 Test Category'
);

insert into public.products(
  id,sku,name,category_id,unit,sale_price,min_stock,track_serial,is_active
) values
(
  'd1340000-0000-4000-8000-000000000001',
  'T13-KNOWN','T13 Known Cost',
  'd1330000-0000-4000-8000-000000000001',
  'cái',1000,5,false,true
),
(
  'd1340000-0000-4000-8000-000000000002',
  'T13-MISS','T13 Missing Cost',
  'd1330000-0000-4000-8000-000000000001',
  'cái',500,0,false,true
),
(
  'd1340000-0000-4000-8000-000000000003',
  'T13-PART','T13 Repair Part',
  'd1330000-0000-4000-8000-000000000001',
  'cái',300,0,false,true
),
(
  'd1340000-0000-4000-8000-000000000004',
  'T13-RETURN','T13 Returned Part',
  'd1330000-0000-4000-8000-000000000001',
  'cái',150,0,false,true
);

-- ------------------------------------------------------------------
-- Sales:
-- - 1000 revenue, complete cost snapshot = 600
-- - 500 revenue, missing cost snapshot
-- - current receivable 200 (snapshot metric)
-- ------------------------------------------------------------------
insert into public.sales_orders(
  id,order_code,customer_id,status,subtotal,discount_amount,
  total_amount,paid_amount,paid_at,created_at
) values
(
  'd1350000-0000-4000-8000-000000000001',
  'SO-990801-1301',
  'd1310000-0000-4000-8000-000000000001',
  'COMPLETED',1000,0,1000,1000,
  '2099-08-05 03:00+00','2099-08-05 02:00+00'
),
(
  'd1350000-0000-4000-8000-000000000002',
  'SO-990801-1302',
  'd1310000-0000-4000-8000-000000000001',
  'PAID',500,0,500,500,
  '2099-08-06 03:00+00','2099-08-06 02:00+00'
),
(
  'd1350000-0000-4000-8000-000000000003',
  'SO-990801-1303',
  'd1310000-0000-4000-8000-000000000001',
  'PAYMENT_PENDING',300,0,300,100,
  null,'2099-08-07 02:00+00'
);

insert into public.sales_order_items(
  id,sales_order_id,product_id,sku_snapshot,product_name_snapshot,
  quantity,unit_price,discount_amount,warranty_months
) values
(
  'd1360000-0000-4000-8000-000000000001',
  'd1350000-0000-4000-8000-000000000001',
  'd1340000-0000-4000-8000-000000000001',
  'T13-KNOWN','T13 Known Cost',1,1000,0,0
),
(
  'd1360000-0000-4000-8000-000000000002',
  'd1350000-0000-4000-8000-000000000002',
  'd1340000-0000-4000-8000-000000000002',
  'T13-MISS','T13 Missing Cost',1,500,0,0
);

insert into private.sales_order_item_costs(
  sales_order_item_id,unit_cost,total_cost,captured_at
) values
(
  'd1360000-0000-4000-8000-000000000001',
  600,600,'2099-08-05 02:30+00'
),
(
  'd1360000-0000-4000-8000-000000000002',
  null,null,'2099-08-06 02:30+00'
);

-- Gross collected = 1500, refunds = 500, net = 1000.
insert into public.payments(
  id,payment_code,sales_order_id,amount,payment_method,status,
  paid_at,refunded_at,refund_note
) values
(
  'd1370000-0000-4000-8000-000000000001',
  'PAY-990805-1301',
  'd1350000-0000-4000-8000-000000000001',
  1000,'CASH','COMPLETED',
  '2099-08-05 03:10+00',null,null
),
(
  'd1370000-0000-4000-8000-000000000002',
  'PAY-990806-1302',
  'd1350000-0000-4000-8000-000000000002',
  500,'BANK_TRANSFER','REFUNDED',
  '2099-08-06 03:10+00',
  '2099-08-10 04:00+00',
  'T13 refund'
);

-- ------------------------------------------------------------------
-- Repair:
-- - known repair revenue 800, ISSUED cost 200
-- - a RETURNED part has cost 100 but MUST NOT count
-- - missing-cost repair revenue 400 must be excluded from known profit
-- ------------------------------------------------------------------
insert into public.repair_orders(
  id,repair_code,customer_id,customer_device_id,status,priority,
  reported_issue,assigned_technician_id,final_amount,completed_at,created_at
) values
(
  'd1380000-0000-4000-8000-000000000001',
  'SRV-990808-1301',
  'd1310000-0000-4000-8000-000000000001',
  'd1320000-0000-4000-8000-000000000001',
  'COMPLETED','HIGH','T13 repair known',
  'd1300000-0000-4000-8000-000000000004',
  800,'2099-08-08 05:00+00','2099-08-08 01:00+00'
),
(
  'd1380000-0000-4000-8000-000000000002',
  'SRV-990809-1302',
  'd1310000-0000-4000-8000-000000000001',
  'd1320000-0000-4000-8000-000000000001',
  'COMPLETED','NORMAL','T13 repair missing',
  'd1300000-0000-4000-8000-000000000004',
  400,'2099-08-09 05:00+00','2099-08-09 01:00+00'
);

insert into public.repair_parts(
  id,repair_order_id,product_id,quantity,unit_price,status,issued_at,returned_at
) values
(
  'd1390000-0000-4000-8000-000000000001',
  'd1380000-0000-4000-8000-000000000001',
  'd1340000-0000-4000-8000-000000000003',
  1,300,'ISSUED','2099-08-08 02:00+00',null
),
(
  'd1390000-0000-4000-8000-000000000002',
  'd1380000-0000-4000-8000-000000000001',
  'd1340000-0000-4000-8000-000000000004',
  1,150,'RETURNED','2099-08-08 02:10+00','2099-08-08 04:00+00'
),
(
  'd1390000-0000-4000-8000-000000000003',
  'd1380000-0000-4000-8000-000000000002',
  'd1340000-0000-4000-8000-000000000003',
  1,200,'ISSUED','2099-08-09 02:00+00',null
);

insert into private.repair_part_costs(
  repair_part_id,unit_cost,total_cost,captured_at
) values
(
  'd1390000-0000-4000-8000-000000000001',
  200,200,'2099-08-08 02:00+00'
),
(
  'd1390000-0000-4000-8000-000000000002',
  100,100,'2099-08-08 02:10+00'
),
(
  'd1390000-0000-4000-8000-000000000003',
  null,null,'2099-08-09 02:00+00'
);

insert into public.inventory_transactions(
  id,product_id,transaction_type,quantity,reference_type,occurred_at
) values
(
  'd13a0000-0000-4000-8000-000000000001',
  'd1340000-0000-4000-8000-000000000001',
  'RECEIVE',10,'T13_TEST','2099-08-03 01:00+00'
),
(
  'd13a0000-0000-4000-8000-000000000002',
  'd1340000-0000-4000-8000-000000000001',
  'ISSUE',3,'T13_TEST','2099-08-05 01:00+00'
);

insert into public.warranties(
  id,warranty_code,lookup_token,customer_id,customer_device_id,
  source_type,source_id,source_item_id,product_id,
  product_name_snapshot,coverage,start_date,end_date,status,created_at
) values(
  'd13b0000-0000-4000-8000-000000000001',
  'WAR-990805-1301',repeat('d',64),
  'd1310000-0000-4000-8000-000000000001',
  'd1320000-0000-4000-8000-000000000001',
  'SALE',
  'd1350000-0000-4000-8000-000000000001',
  'd1360000-0000-4000-8000-000000000001',
  'd1340000-0000-4000-8000-000000000001',
  'T13 Known Cost','T13 coverage',
  '2099-08-05','2100-08-05','ACTIVE',
  '2099-08-05 04:00+00'
);

insert into public.warranty_claims(
  id,claim_code,warranty_id,status,issue_description,received_at,created_at
) values(
  'd13c0000-0000-4000-8000-000000000001',
  'WCL-990812-1301',
  'd13b0000-0000-4000-8000-000000000001',
  'RECEIVED','T13 claim',
  '2099-08-12 03:00+00','2099-08-12 03:00+00'
);

insert into public.services(
  id,name,category,default_interval_count,default_interval_unit,
  default_price,warranty_months,is_active
) values(
  'd13d0000-0000-4000-8000-000000000001',
  'T13 Service','MAINTENANCE',1,'MONTHS',200,3,true
);

insert into public.service_schedules(
  id,service_id,customer_id,customer_device_id,status,
  interval_count,interval_unit,start_date,next_due_date,price,
  completion_count,last_completed_at,last_completion_id,created_at
) values(
  'd13d0000-0000-4000-8000-000000000002',
  'd13d0000-0000-4000-8000-000000000001',
  'd1310000-0000-4000-8000-000000000001',
  'd1320000-0000-4000-8000-000000000001',
  'ACTIVE',1,'MONTHS','2099-08-01','2099-09-05',200,
  1,'2099-08-15 03:00+00',
  'd13d0000-0000-4000-8000-000000000003',
  '2099-08-01 01:00+00'
);

insert into public.software_products(
  id,category,vendor,name,billing_model,default_term_months,is_active
) values(
  'd13e0000-0000-4000-8000-000000000001',
  'M365','Microsoft','T13 M365','SUBSCRIPTION',12,true
);

insert into public.software_licenses(
  id,license_code,software_product_id,customer_id,customer_device_id,
  status,start_date,end_date,seats,auto_renew,renewal_cost,created_at
) values(
  'd13e0000-0000-4000-8000-000000000002',
  'LIC-139001',
  'd13e0000-0000-4000-8000-000000000001',
  'd1310000-0000-4000-8000-000000000001',
  'd1320000-0000-4000-8000-000000000001',
  'ACTIVE','2099-01-01','2099-09-10',1,true,1200,
  '2099-08-02 01:00+00'
);

-- ------------------------------------------------------------------
-- Admin: full report + exact profit/cost coverage math.
-- ------------------------------------------------------------------
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1300000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"d1300000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

do $$
declare j jsonb;
begin
  j:=public.report_snapshot(
    '2099-08-01','2099-08-31','DAY','2099-08-30 12:00+00'
  );

  if (j#>>'{summary,sales,orders_paid}')::int<>2 then
    raise exception 'T13 sales orders mismatch';
  end if;
  if (j#>>'{summary,sales,revenue}')::numeric<>1500 then
    raise exception 'T13 sales revenue mismatch';
  end if;

  if (j#>>'{summary,payments,gross_collected}')::numeric<>1500 then
    raise exception 'T13 gross collection mismatch';
  end if;
  if (j#>>'{summary,payments,refunds}')::numeric<>500 then
    raise exception 'T13 refunds mismatch';
  end if;
  if (j#>>'{summary,payments,net_cash_flow}')::numeric<>1000 then
    raise exception 'T13 net cash flow mismatch';
  end if;

  if (j#>>'{summary,repairs,completed}')::int<>2 then
    raise exception 'T13 completed repairs mismatch';
  end if;
  if (j#>>'{summary,repairs,completed_revenue}')::numeric<>1200 then
    raise exception 'T13 repair revenue mismatch';
  end if;

  if (j#>>'{summary,warranty,claims_received}')::int<>1 then
    raise exception 'T13 claims received mismatch';
  end if;
  if (j#>>'{summary,service,schedules_last_completed_in_period}')::int<1 then
    raise exception 'T13 service metric missing';
  end if;
  if (j#>>'{summary,license,created}')::int<1 then
    raise exception 'T13 license metric missing';
  end if;

  if (j#>>'{summary,profit,sales,revenue_total}')::numeric<>1500
     or (j#>>'{summary,profit,sales,cost_covered_revenue}')::numeric<>1000
     or (j#>>'{summary,profit,sales,excluded_revenue_missing_cost}')::numeric<>500
     or (j#>>'{summary,profit,sales,recorded_product_cost}')::numeric<>600
     or (j#>>'{summary,profit,sales,gross_profit_known}')::numeric<>400
     or (j#>>'{summary,profit,sales,cost_coverage_revenue_pct}')::numeric<>66.67
  then
    raise exception 'T13 sales profit/coverage mismatch';
  end if;

  if (j#>>'{summary,profit,repair,revenue_total}')::numeric<>1200
     or (j#>>'{summary,profit,repair,cost_covered_revenue}')::numeric<>800
     or (j#>>'{summary,profit,repair,excluded_revenue_missing_cost}')::numeric<>400
     or (j#>>'{summary,profit,repair,recorded_parts_cost}')::numeric<>200
     or (j#>>'{summary,profit,repair,gross_profit_after_parts_known}')::numeric<>600
  then
    raise exception 'T13 repair profit/returned-part rule mismatch';
  end if;

  if (j#>>'{summary,profit,combined,revenue_total}')::numeric<>2700
     or (j#>>'{summary,profit,combined,cost_covered_revenue}')::numeric<>1800
     or (j#>>'{summary,profit,combined,gross_profit_known}')::numeric<>1000
     or (j#>>'{summary,profit,combined,cost_coverage_revenue_pct}')::numeric<>66.67
  then
    raise exception 'T13 combined profit mismatch';
  end if;

  if (j#>>'{data_quality,inventory_value_rule}') not like '%does not estimate%'
     or (j#>>'{data_quality,service_history_limit}') not like '%does not invent%'
     or (j#>>'{data_quality,license_history_limit}') not like '%does not invent%'
  then
    raise exception 'T13 data-quality limitations missing';
  end if;
end $$;

-- ------------------------------------------------------------------
-- Sales can report but cannot receive cost/profit values.
-- ------------------------------------------------------------------
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1300000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"d1300000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);

do $$
declare
  j jsonb;
  visible_text text;
begin
  j:=public.report_snapshot(
    '2099-08-01','2099-08-31','WEEK','2099-08-30 12:00+00'
  );

  if j#>'{summary,profit}' <> 'null'::jsonb then
    raise exception 'Sales role received profit payload';
  end if;
  if (j#>>'{permissions,profit}')::boolean then
    raise exception 'Sales role profit permission leaked';
  end if;

  visible_text:=(j#>'{summary}')::text||(j#>'{charts}')::text;
  if visible_text ~
    'gross_profit_known|recorded_product_cost|recorded_parts_cost|cost_covered_revenue|excluded_revenue_missing_cost'
  then
    raise exception 'Sales role received cost/profit values outside profit payload';
  end if;
end $$;

-- ------------------------------------------------------------------
-- Cashier has report.view but no Service/License view.
-- ------------------------------------------------------------------
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1300000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"d1300000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);

do $$
declare j jsonb;
begin
  j:=public.report_snapshot(
    '2099-08-01','2099-08-31','MONTH','2099-08-30 12:00+00'
  );

  if j#>'{summary,service}' <> 'null'::jsonb
     or j#>'{summary,license}' <> 'null'::jsonb
  then
    raise exception 'Cashier service/license report leaked';
  end if;

  if (j#>>'{permissions,service}')::boolean
     or (j#>>'{permissions,license}')::boolean
  then
    raise exception 'Cashier service/license permission leaked';
  end if;
end $$;

-- Technician does not have report.view.
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1300000-0000-4000-8000-000000000004',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"d1300000-0000-4000-8000-000000000004","role":"authenticated"}',
  true
);

do $$
begin
  begin
    perform public.report_snapshot(
      '2099-08-01','2099-08-31','DAY','2099-08-30 12:00+00'
    );
    raise exception 'Technician unexpectedly accessed reports';
  exception when others then
    if sqlerrm='Technician unexpectedly accessed reports' then raise; end if;
    if position('report.view' in sqlerrm)=0 then raise; end if;
  end;
end $$;

-- Input validation.
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1300000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"d1300000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

do $$
begin
  begin
    perform public.report_snapshot(
      '2099-08-31','2099-08-01','DAY','2099-08-30 12:00+00'
    );
    raise exception 'Reverse range accepted';
  exception when others then
    if sqlerrm='Reverse range accepted' then raise; end if;
    if position('on or before' in sqlerrm)=0 then raise; end if;
  end;

  begin
    perform public.report_snapshot(
      '2098-01-01','2099-08-31','DAY','2099-08-30 12:00+00'
    );
    raise exception 'Over-366 range accepted';
  exception when others then
    if sqlerrm='Over-366 range accepted' then raise; end if;
    if position('366' in sqlerrm)=0 then raise; end if;
  end;

  begin
    perform public.report_snapshot(
      '2099-08-01','2099-08-31','YEAR','2099-08-30 12:00+00'
    );
    raise exception 'Invalid bucket accepted';
  exception when others then
    if sqlerrm='Invalid bucket accepted' then raise; end if;
    if position('DAY, WEEK or MONTH' in sqlerrm)=0 then raise; end if;
  end;
end $$;

-- Anon has no EXECUTE.
reset role;
set local role anon;
do $$
begin
  begin
    perform public.report_snapshot(
      '2099-08-01','2099-08-31','DAY','2099-08-30 12:00+00'
    );
    raise exception 'Anon unexpectedly accessed reports';
  exception when insufficient_privilege then
    null;
  end;
end $$;

reset role;

do $$ begin
  raise notice 'T13 FINAL CORE CHECKS: PASS';
end $$;

rollback;
