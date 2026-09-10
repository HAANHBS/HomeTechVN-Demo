\set ON_ERROR_STOP on
begin;

-- ------------------------------------------------------------------
-- T4 schema/security baseline
-- ------------------------------------------------------------------
do $$
declare
  v_missing integer;
  v_rls_missing integer;
  v_rpc_count integer;
  v_security_invoker boolean;
  v_direct boolean;
begin
  select count(*) into v_missing
  from (values ('sales_orders'),('sales_order_items'),('payments')) expected(name)
  where not exists (
    select 1 from information_schema.tables t
    where t.table_schema='public' and t.table_name=expected.name
  );
  if v_missing<>0 then raise exception 'Missing T4 public tables: %',v_missing; end if;

  if not exists (
    select 1 from information_schema.tables
    where table_schema='private' and table_name='sales_order_item_costs'
  ) then raise exception 'Missing private.sales_order_item_costs'; end if;

  select count(*) into v_rls_missing
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relname in ('sales_orders','sales_order_items','payments')
    and not c.relrowsecurity;
  if v_rls_missing<>0 then raise exception 'T4 RLS missing on % table(s)',v_rls_missing; end if;

  select count(*) into v_rpc_count
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in (
    'sale_create','sale_update_draft','sale_add_item','sale_update_item',
    'sale_remove_item','sale_set_checklist_item','sale_confirm',
    'sale_record_payment','sale_refund_payment','sale_deliver','sale_complete','sale_cancel'
  );
  if v_rpc_count<>12 then raise exception 'T4 RPC count expected 12, got %',v_rpc_count; end if;

  select coalesce('security_invoker=true'=any(c.reloptions),false) into v_security_invoker
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname='sales_order_summary';
  if not coalesce(v_security_invoker,false) then raise exception 'sales_order_summary is not security_invoker'; end if;

  select has_table_privilege('authenticated','public.sales_orders','INSERT') into v_direct;
  if v_direct then raise exception 'authenticated must not INSERT sales_orders directly'; end if;
  select has_table_privilege('authenticated','public.sales_orders','UPDATE') into v_direct;
  if v_direct then raise exception 'authenticated must not UPDATE sales_orders directly'; end if;
  select has_table_privilege('authenticated','public.payments','INSERT') into v_direct;
  if v_direct then raise exception 'authenticated must not INSERT payments directly'; end if;
  select has_table_privilege('authenticated','private.sales_order_item_costs','SELECT') into v_direct;
  if v_direct then raise exception 'authenticated must not SELECT private sales cost snapshots'; end if;
end $$;

-- ------------------------------------------------------------------
-- Temporary Auth user and test stock. Entire test rolls back.
-- ------------------------------------------------------------------
insert into auth.users(id,email,raw_user_meta_data)
values('44444444-4444-4444-8444-444444444444','t4-local-verify@example.invalid','{}'::jsonb);

update public.profiles
set role_id=(select id from public.roles where code='admin'),
    is_active=true,
    full_name='T4 Local Verify'
where id='44444444-4444-4444-8444-444444444444';

set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);

insert into public.customers(full_name,phone,address)
values('T4 LOCAL VERIFY CUSTOMER','0911222333','Thanh Hoa');

insert into public.product_categories(name,description,sort_order)
values('T4 LOCAL VERIFY CATEGORY','T4 local verification',1);

insert into public.products(sku,name,category_id,brand,model,unit,sale_price,min_stock,track_serial,warranty_months)
select 'T4-LOCAL-BULK','T4 Local Bulk',id,'T4','BULK','cai',150000,2,false,12
from public.product_categories where name='T4 LOCAL VERIFY CATEGORY';

insert into public.products(sku,name,category_id,brand,model,unit,sale_price,min_stock,track_serial,warranty_months)
select 'T4-LOCAL-SERIAL','T4 Local Serial',id,'T4','SERIAL','cai',2500000,1,true,24
from public.product_categories where name='T4 LOCAL VERIFY CATEGORY';

select public.inventory_receive(id,20,100000,null,'T4 local seed','VERIFY',null,'Kho T4')
from public.products where sku='T4-LOCAL-BULK';
select public.inventory_receive(id,3,1800000,array['T4-LOCAL-SN-001','T4-LOCAL-SN-002','T4-LOCAL-SN-003'],'T4 local serial seed','VERIFY',null,'Kho T4')
from public.products where sku='T4-LOCAL-SERIAL';

-- ------------------------------------------------------------------
-- Sales role: create/edit/confirm but cannot collect payment.
-- ------------------------------------------------------------------
reset role;
update public.profiles set role_id=(select id from public.roles where code='sales')
where id='44444444-4444-4444-8444-444444444444';
set local role authenticated;

select public.sale_create(
  (select id from public.customers where full_name='T4 LOCAL VERIFY CUSTOMER'),
  'T4 lifecycle'
);

select public.sale_add_item(
  (select id from public.sales_orders where note='T4 lifecycle'),
  (select id from public.products where sku='T4-LOCAL-BULK'),
  2,150000,10000,'{}'::uuid[]
);
select public.sale_add_item(
  (select id from public.sales_orders where note='T4 lifecycle'),
  (select id from public.products where sku='T4-LOCAL-SERIAL'),
  1,2500000,0,
  array[(select id from public.inventory_units where serial_number='T4-LOCAL-SN-001')]
);
select public.sale_update_draft(
  (select id from public.sales_orders where note='T4 lifecycle'),
  (select id from public.customers where full_name='T4 LOCAL VERIFY CUSTOMER'),
  50000,
  'T4 lifecycle'
);
select public.sale_confirm((select id from public.sales_orders where note='T4 lifecycle'));

do $$
begin
  perform public.sale_record_payment(
    (select id from public.sales_orders where note='T4 lifecycle'),1000,'CASH',null,null
  );
  raise exception 'Sales payment unexpectedly succeeded';
exception when others then
  if sqlerrm='Sales payment unexpectedly succeeded' then raise; end if;
  if position('Missing permission payment.create' in sqlerrm)=0 then raise; end if;
end $$;

do $$
begin
  perform public.sale_set_checklist_item(
    (select id from public.sales_orders where note='T4 lifecycle'),'payment_confirmed',true
  );
  raise exception 'Manual payment_confirmed unexpectedly succeeded';
exception when others then
  if sqlerrm='Manual payment_confirmed unexpectedly succeeded' then raise; end if;
  if position('payment_confirmed is managed by payment workflow' in sqlerrm)=0 then raise; end if;
end $$;

-- ------------------------------------------------------------------
-- Cashier: can pay, cannot deliver/edit sale.
-- ------------------------------------------------------------------
reset role;
update public.profiles set role_id=(select id from public.roles where code='cashier')
where id='44444444-4444-4444-8444-444444444444';
set local role authenticated;

do $$
begin
  perform public.sale_deliver((select id from public.sales_orders where note='T4 lifecycle'));
  raise exception 'Cashier delivery unexpectedly succeeded';
exception when others then
  if sqlerrm='Cashier delivery unexpectedly succeeded' then raise; end if;
  if position('Missing permission sale.update' in sqlerrm)=0 then raise; end if;
end $$;

select public.sale_record_payment(
  (select id from public.sales_orders where note='T4 lifecycle'),
  (select total_amount from public.sales_orders where note='T4 lifecycle'),
  'CASH',null,'T4 full payment'
);

-- ------------------------------------------------------------------
-- Sales: checklist, delivery, completion gate.
-- ------------------------------------------------------------------
reset role;
update public.profiles set role_id=(select id from public.roles where code='sales')
where id='44444444-4444-4444-8444-444444444444';
set local role authenticated;

select public.sale_set_checklist_item((select id from public.sales_orders where note='T4 lifecycle'),'customer_identity',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T4 lifecycle'),'contact_phone',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T4 lifecycle'),'product_quantity',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T4 lifecycle'),'product_configuration',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T4 lifecycle'),'serial_numbers',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T4 lifecycle'),'physical_condition',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T4 lifecycle'),'functionality_test',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T4 lifecycle'),'price_discount',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T4 lifecycle'),'warranty_terms',true);
select public.sale_deliver((select id from public.sales_orders where note='T4 lifecycle'));

do $$
begin
  perform public.sale_complete((select id from public.sales_orders where note='T4 lifecycle'));
  raise exception 'Completion unexpectedly succeeded with incomplete checklist';
exception when others then
  if sqlerrm='Completion unexpectedly succeeded with incomplete checklist' then raise; end if;
  if position('Required sales checklist is incomplete' in sqlerrm)=0 then raise; end if;
end $$;

select public.sale_set_checklist_item(
  (select id from public.sales_orders where note='T4 lifecycle'),
  'customer_delivery_confirmation',true
);
select public.sale_complete((select id from public.sales_orders where note='T4 lifecycle'));

-- ------------------------------------------------------------------
-- Cancel path: stock and selected Serial must be restored.
-- ------------------------------------------------------------------
select public.sale_create(
  (select id from public.customers where full_name='T4 LOCAL VERIFY CUSTOMER'),
  'T4 cancel'
);
select public.sale_add_item(
  (select id from public.sales_orders where note='T4 cancel'),
  (select id from public.products where sku='T4-LOCAL-BULK'),3,150000,0,'{}'::uuid[]
);
select public.sale_add_item(
  (select id from public.sales_orders where note='T4 cancel'),
  (select id from public.products where sku='T4-LOCAL-SERIAL'),1,2500000,0,
  array[(select id from public.inventory_units where serial_number='T4-LOCAL-SN-002')]
);
select public.sale_confirm((select id from public.sales_orders where note='T4 cancel'));

reset role;
update public.profiles set role_id=(select id from public.roles where code='manager')
where id='44444444-4444-4444-8444-444444444444';
set local role authenticated;
select public.sale_cancel((select id from public.sales_orders where note='T4 cancel'),'T4 local cancel');

-- ------------------------------------------------------------------
-- Refund path: pay -> refund -> cancel.
-- ------------------------------------------------------------------
reset role;
update public.profiles set role_id=(select id from public.roles where code='sales')
where id='44444444-4444-4444-8444-444444444444';
set local role authenticated;
select public.sale_create(
  (select id from public.customers where full_name='T4 LOCAL VERIFY CUSTOMER'),
  'T4 refund'
);
select public.sale_add_item(
  (select id from public.sales_orders where note='T4 refund'),
  (select id from public.products where sku='T4-LOCAL-BULK'),1,150000,0,'{}'::uuid[]
);
select public.sale_confirm((select id from public.sales_orders where note='T4 refund'));

reset role;
update public.profiles set role_id=(select id from public.roles where code='cashier')
where id='44444444-4444-4444-8444-444444444444';
set local role authenticated;
select public.sale_record_payment(
  (select id from public.sales_orders where note='T4 refund'),
  150000,'BANK_TRANSFER','T4-REF','T4 refund payment'
);
select public.sale_refund_payment(
  (select id from public.payments where note='T4 refund payment'),
  'T4 local refund'
);

-- authenticated must not access private cost snapshots.
do $$
begin
  perform 1 from private.sales_order_item_costs limit 1;
  raise exception 'authenticated unexpectedly read private cost table';
exception when insufficient_privilege then null;
end $$;

reset role;
update public.profiles set role_id=(select id from public.roles where code='manager')
where id='44444444-4444-4444-8444-444444444444';
set local role authenticated;
select public.sale_cancel((select id from public.sales_orders where note='T4 refund'),'T4 cancel after refund');

-- ------------------------------------------------------------------
-- Internal assertions (postgres) and final result.
-- ------------------------------------------------------------------
reset role;
do $$
declare
  v_lifecycle public.sales_orders%rowtype;
  v_cancel public.sales_orders%rowtype;
  v_refund public.sales_orders%rowtype;
  v_bulk_stock numeric;
  v_serial_sold text;
  v_serial_cancel text;
  v_cost_rows integer;
  v_payment_code text;
begin
  select * into v_lifecycle from public.sales_orders where note='T4 lifecycle';
  if v_lifecycle.status<>'COMPLETED' then raise exception 'Lifecycle expected COMPLETED, got %',v_lifecycle.status; end if;
  if v_lifecycle.paid_amount<>v_lifecycle.total_amount then raise exception 'Lifecycle payment mismatch'; end if;
  if jsonb_array_length(v_lifecycle.checklist)<>16 then raise exception 'Checklist count expected 16'; end if;
  if v_lifecycle.order_code !~ '^SO-[0-9]{6}-[0-9]{4}$' then raise exception 'Bad SO code %',v_lifecycle.order_code; end if;

  select * into v_cancel from public.sales_orders where note='T4 cancel';
  if v_cancel.status<>'CANCELLED' then raise exception 'Cancel path expected CANCELLED'; end if;
  select * into v_refund from public.sales_orders where note='T4 refund';
  if v_refund.status<>'CANCELLED' or v_refund.paid_amount<>0 then raise exception 'Refund/cancel path invalid'; end if;

  select stock_qty into v_bulk_stock from public.product_inventory_summary where sku='T4-LOCAL-BULK';
  if v_bulk_stock<>18 then raise exception 'Bulk stock expected 18, got %',v_bulk_stock; end if;
  select status into v_serial_sold from public.inventory_units where serial_number='T4-LOCAL-SN-001';
  select status into v_serial_cancel from public.inventory_units where serial_number='T4-LOCAL-SN-002';
  if v_serial_sold<>'OUT' then raise exception 'Sold Serial expected OUT'; end if;
  if v_serial_cancel<>'IN_STOCK' then raise exception 'Cancelled Serial expected IN_STOCK'; end if;

  select count(*) into v_cost_rows
  from private.sales_order_item_costs c
  join public.sales_order_items i on i.id=c.sales_order_item_id
  where i.sales_order_id=v_lifecycle.id;
  if v_cost_rows<>2 then raise exception 'Lifecycle cost snapshot expected 2 rows, got %',v_cost_rows; end if;

  select payment_code into v_payment_code from public.payments where note='T4 full payment';
  if v_payment_code !~ '^PAY-[0-9]{6}-[0-9]{4}$' then raise exception 'Bad PAY code %',v_payment_code; end if;
end $$;

select
  'T4 FINAL CORE CHECKS: PASS' as result,
  (select status from public.sales_orders where note='T4 lifecycle') as lifecycle_status,
  (select status from public.sales_orders where note='T4 cancel') as cancel_status,
  (select status from public.sales_orders where note='T4 refund') as refund_status,
  (select stock_qty from public.product_inventory_summary where sku='T4-LOCAL-BULK') as bulk_stock,
  (select status from public.inventory_units where serial_number='T4-LOCAL-SN-001') as sold_serial_status,
  (select status from public.inventory_units where serial_number='T4-LOCAL-SN-002') as cancelled_serial_status,
  (select count(*) from jsonb_array_elements((select checklist from public.sales_orders where note='T4 lifecycle'))) as checklist_count;

rollback;
