\set ON_ERROR_STOP on
begin;

-- ------------------------------------------------------------------
-- HomeTechVN T5: Repair core verification (rollback-safe)
-- ------------------------------------------------------------------

do $$
declare
  v_count integer;
  v_rls integer;
  v_direct boolean;
begin
  select count(*) into v_count
  from information_schema.tables
  where table_schema='public'
    and table_name in ('repair_orders','repair_diagnostics','repair_quotes','repair_parts','repair_status_history');
  if v_count<>5 then raise exception 'T5 tables expected 5, got %',v_count; end if;

  select count(*) into v_rls
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in ('repair_orders','repair_diagnostics','repair_quotes','repair_parts','repair_status_history') and c.relrowsecurity;
  if v_rls<>5 then raise exception 'T5 RLS tables expected 5, got %',v_rls; end if;

  if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='repair_order_summary' and 'security_invoker=true'=any(coalesce(c.reloptions,'{}'::text[]))) then
    raise exception 'repair_order_summary must be security_invoker';
  end if;

  select has_table_privilege('authenticated','public.repair_orders','INSERT') into v_direct;
  if v_direct then raise exception 'authenticated must not directly INSERT repair_orders'; end if;
  select has_table_privilege('authenticated','public.repair_parts','UPDATE') into v_direct;
  if v_direct then raise exception 'authenticated must not directly UPDATE repair_parts'; end if;
end $$;

insert into auth.users(id,email,raw_user_meta_data)
values('55555555-5555-4555-8555-555555555555','t5-local-verify@example.invalid','{}'::jsonb);
update public.profiles
set role_id=(select id from public.roles where code='admin'),is_active=true,full_name='T5 Local Verify'
where id='55555555-5555-4555-8555-555555555555';

set local role authenticated;
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);

-- Seed reference data as admin.
insert into public.customers(full_name,phone,address) values('T5 LOCAL CUSTOMER','0911555777','Thanh Hoa');
insert into public.customer_devices(customer_id,device_type,brand,model,serial_number,condition_notes)
select id,'Laptop','Dell','Latitude T5','T5-LOCAL-DEVICE','Không lên nguồn' from public.customers where full_name='T5 LOCAL CUSTOMER';
insert into public.product_categories(name,description,sort_order) values('T5 LOCAL CATEGORY','T5 verification',1);
insert into public.products(sku,name,category_id,brand,model,unit,sale_price,min_stock,track_serial,warranty_months)
select 'T5-LOCAL-BULK','T5 Local Bulk Part',id,'T5','BULK','cai',120000,1,false,3 from public.product_categories where name='T5 LOCAL CATEGORY';
insert into public.products(sku,name,category_id,brand,model,unit,sale_price,min_stock,track_serial,warranty_months)
select 'T5-LOCAL-SERIAL','T5 Local Serial Part',id,'T5','SERIAL','cai',900000,1,true,6 from public.product_categories where name='T5 LOCAL CATEGORY';
select public.inventory_receive(id,10,70000,null,'T5 verify seed','VERIFY',null,'Kho T5') from public.products where sku='T5-LOCAL-BULK';
select public.inventory_receive(id,2,600000,array['T5-LOCAL-PART-1','T5-LOCAL-PART-2'],'T5 verify seed','VERIFY',null,'Kho T5') from public.products where sku='T5-LOCAL-SERIAL';

-- Sales: can receive, cannot diagnose.
reset role;
update public.profiles set role_id=(select id from public.roles where code='sales') where id='55555555-5555-4555-8555-555555555555';
set local role authenticated;
select public.repair_create(
  (select id from public.customers where full_name='T5 LOCAL CUSTOMER'),
  (select id from public.customer_devices where serial_number='T5-LOCAL-DEVICE'),
  'Máy không lên nguồn','Trầy nhẹ nắp A',array['Sạc 65W'],'Cần lấy sớm','HIGH','T5 MAIN'
);
do $$ begin
  perform public.repair_start_diagnosis((select id from public.repair_orders where intake_note='T5 MAIN'));
  raise exception 'Sales diagnose unexpectedly succeeded';
exception when others then
  if sqlerrm='Sales diagnose unexpectedly succeeded' then raise; end if;
  if position('Missing permission repair.diagnose' in sqlerrm)=0 then raise; end if;
end $$;

-- Technician lifecycle including WAITING_PART and QC fail/pass.
reset role;
update public.profiles set role_id=(select id from public.roles where code='technician') where id='55555555-5555-4555-8555-555555555555';
set local role authenticated;
select public.repair_start_diagnosis((select id from public.repair_orders where intake_note='T5 MAIN'));
select public.repair_add_diagnostic((select id from public.repair_orders where intake_note='T5 MAIN'),'Không kích nguồn','Hỏng IC nguồn và cáp DC','Cần thay linh kiện','Thay linh kiện và QC');
select public.repair_create_quote((select id from public.repair_orders where intake_note='T5 MAIN'),300000,1140000,40000,current_date+7,'T5 MAIN QUOTE');
select public.repair_submit_quote((select id from public.repair_quotes where note='T5 MAIN QUOTE'));
select public.repair_customer_decision((select id from public.repair_orders where intake_note='T5 MAIN'),true,'Khách đồng ý');
select public.repair_plan_part((select id from public.repair_orders where intake_note='T5 MAIN'),(select id from public.products where sku='T5-LOCAL-BULK'),2,120000,'{}'::uuid[],'IC nguồn + cáp');
select public.repair_plan_part((select id from public.repair_orders where intake_note='T5 MAIN'),(select id from public.products where sku='T5-LOCAL-SERIAL'),1,900000,array[(select id from public.inventory_units where serial_number='T5-LOCAL-PART-1')],'Board serial');
select public.repair_issue_part((select rp.id from public.repair_parts rp join public.products p on p.id=rp.product_id where rp.repair_order_id=(select id from public.repair_orders where intake_note='T5 MAIN') and p.sku='T5-LOCAL-BULK'));
select public.repair_issue_part((select rp.id from public.repair_parts rp join public.products p on p.id=rp.product_id where rp.repair_order_id=(select id from public.repair_orders where intake_note='T5 MAIN') and p.sku='T5-LOCAL-SERIAL'));
select public.repair_waiting_part((select id from public.repair_orders where intake_note='T5 MAIN'),'Chờ keo tản nhiệt');
select public.repair_start_repair((select id from public.repair_orders where intake_note='T5 MAIN'));
select public.repair_start_qc((select id from public.repair_orders where intake_note='T5 MAIN'));
select public.repair_record_qc((select id from public.repair_orders where intake_note='T5 MAIN'),false,'Nguồn lên nhưng sạc chưa ổn định','Xử lý lại jack DC');
select public.repair_start_qc((select id from public.repair_orders where intake_note='T5 MAIN'));
select public.repair_record_qc((select id from public.repair_orders where intake_note='T5 MAIN'),true,'Nguồn/sạc/pin/stress đạt','QC PASS');
select public.repair_mark_returned((select id from public.repair_orders where intake_note='T5 MAIN'));
select public.repair_complete((select id from public.repair_orders where intake_note='T5 MAIN'));

do $$ begin
  perform public.repair_cancel((select id from public.repair_orders where intake_note='T5 MAIN'),'forbidden');
  raise exception 'Technician cancel unexpectedly succeeded';
exception when others then
  if sqlerrm='Technician cancel unexpectedly succeeded' then raise; end if;
  if position('Missing permission repair.cancel' in sqlerrm)=0 then raise; end if;
end $$;

-- Cancellation restores issued bulk and serialized parts.
select public.repair_create((select id from public.customers where full_name='T5 LOCAL CUSTOMER'),(select id from public.customer_devices where serial_number='T5-LOCAL-DEVICE'),'Test hủy sau xuất vật tư',null,'{}'::text[],null,'NORMAL','T5 CANCEL');
select public.repair_start_diagnosis((select id from public.repair_orders where intake_note='T5 CANCEL'));
select public.repair_add_diagnostic((select id from public.repair_orders where intake_note='T5 CANCEL'),'', 'Cần thay vật tư','test cancel','');
select public.repair_create_quote((select id from public.repair_orders where intake_note='T5 CANCEL'),100000,1020000,0,current_date+7,'T5 CANCEL QUOTE');
select public.repair_submit_quote((select id from public.repair_quotes where note='T5 CANCEL QUOTE'));
select public.repair_customer_decision((select id from public.repair_orders where intake_note='T5 CANCEL'),true,'OK');
select public.repair_plan_part((select id from public.repair_orders where intake_note='T5 CANCEL'),(select id from public.products where sku='T5-LOCAL-BULK'),1,120000,'{}'::uuid[],null);
select public.repair_plan_part((select id from public.repair_orders where intake_note='T5 CANCEL'),(select id from public.products where sku='T5-LOCAL-SERIAL'),1,900000,array[(select id from public.inventory_units where serial_number='T5-LOCAL-PART-2')],null);
select public.repair_issue_part((select rp.id from public.repair_parts rp join public.products p on p.id=rp.product_id where rp.repair_order_id=(select id from public.repair_orders where intake_note='T5 CANCEL') and p.sku='T5-LOCAL-BULK'));
select public.repair_issue_part((select rp.id from public.repair_parts rp join public.products p on p.id=rp.product_id where rp.repair_order_id=(select id from public.repair_orders where intake_note='T5 CANCEL') and p.sku='T5-LOCAL-SERIAL'));
reset role;
update public.profiles set role_id=(select id from public.roles where code='manager') where id='55555555-5555-4555-8555-555555555555';
set local role authenticated;
select public.repair_cancel((select id from public.repair_orders where intake_note like 'T5 CANCEL%'),'Khách hủy sau khi duyệt');

-- Rejection + warranty transfer/resume/no-fix special paths.
reset role;
update public.profiles set role_id=(select id from public.roles where code='technician') where id='55555555-5555-4555-8555-555555555555';
set local role authenticated;
select public.repair_create((select id from public.customers where full_name='T5 LOCAL CUSTOMER'),(select id from public.customer_devices where serial_number='T5-LOCAL-DEVICE'),'Test reject',null,'{}'::text[],null,'NORMAL','T5 REJECT');
select public.repair_start_diagnosis((select id from public.repair_orders where intake_note='T5 REJECT'));
select public.repair_add_diagnostic((select id from public.repair_orders where intake_note='T5 REJECT'),'', 'Chi phí cao','Báo giá',null);
select public.repair_create_quote((select id from public.repair_orders where intake_note='T5 REJECT'),500000,500000,0,current_date+3,'T5 REJECT QUOTE');
select public.repair_submit_quote((select id from public.repair_quotes where note='T5 REJECT QUOTE'));
select public.repair_customer_decision((select id from public.repair_orders where intake_note='T5 REJECT'),false,'Khách không sửa');

select public.repair_create((select id from public.customers where full_name='T5 LOCAL CUSTOMER'),(select id from public.customer_devices where serial_number='T5-LOCAL-DEVICE'),'Test warranty transfer',null,'{}'::text[],null,'NORMAL','T5 WARRANTY');
select public.repair_start_diagnosis((select id from public.repair_orders where intake_note='T5 WARRANTY'));
select public.repair_add_diagnostic((select id from public.repair_orders where intake_note='T5 WARRANTY'),'', 'Nghi lỗi thuộc hãng','Chuyển hãng',null);
select public.repair_warranty_transfer((select id from public.repair_orders where intake_note='T5 WARRANTY'),'Chuyển trung tâm hãng');
select public.repair_resume_warranty((select id from public.repair_orders where intake_note='T5 WARRANTY'));
select public.repair_no_fix((select id from public.repair_orders where intake_note='T5 WARRANTY'),'Không có linh kiện');

-- Patch behavior: only ISSUED can return; RETURNED can be replanned.
select public.repair_create((select id from public.customers where full_name='T5 LOCAL CUSTOMER'),(select id from public.customer_devices where serial_number='T5-LOCAL-DEVICE'),'Test replan',null,'{}'::text[],null,'NORMAL','T5 REPLAN');
select public.repair_start_diagnosis((select id from public.repair_orders where intake_note='T5 REPLAN'));
select public.repair_add_diagnostic((select id from public.repair_orders where intake_note='T5 REPLAN'),'', 'diag','replan',null);
select public.repair_create_quote((select id from public.repair_orders where intake_note='T5 REPLAN'),10000,120000,0,null,'T5 REPLAN QUOTE');
select public.repair_submit_quote((select id from public.repair_quotes where note='T5 REPLAN QUOTE'));
select public.repair_customer_decision((select id from public.repair_orders where intake_note='T5 REPLAN'),true,'OK');
select public.repair_plan_part((select id from public.repair_orders where intake_note='T5 REPLAN'),(select id from public.products where sku='T5-LOCAL-BULK'),1,120000,'{}'::uuid[],'first plan');
do $$ begin
  perform public.repair_return_part((select id from public.repair_parts where repair_order_id=(select id from public.repair_orders where intake_note='T5 REPLAN')),null);
  raise exception 'PLANNED part return unexpectedly succeeded';
exception when others then
  if sqlerrm='PLANNED part return unexpectedly succeeded' then raise; end if;
  if position('Only ISSUED repair part can be returned' in sqlerrm)=0 then raise; end if;
end $$;
select public.repair_issue_part((select id from public.repair_parts where repair_order_id=(select id from public.repair_orders where intake_note='T5 REPLAN')));
select public.repair_return_part((select id from public.repair_parts where repair_order_id=(select id from public.repair_orders where intake_note='T5 REPLAN')),'return for replan');
select public.repair_plan_part((select id from public.repair_orders where intake_note='T5 REPLAN'),(select id from public.products where sku='T5-LOCAL-BULK'),2,120000,'{}'::uuid[],'replanned');

-- Cashier view-only and client table/private cost protection.
reset role;
update public.profiles set role_id=(select id from public.roles where code='cashier') where id='55555555-5555-4555-8555-555555555555';
set local role authenticated;
do $$ begin
  perform public.repair_create((select id from public.customers where full_name='T5 LOCAL CUSTOMER'),(select id from public.customer_devices where serial_number='T5-LOCAL-DEVICE'),'cashier create',null,'{}'::text[],null,'NORMAL',null);
  raise exception 'Cashier create unexpectedly succeeded';
exception when others then
  if sqlerrm='Cashier create unexpectedly succeeded' then raise; end if;
  if position('Missing permission repair.create' in sqlerrm)=0 then raise; end if;
end $$;
do $$ begin
  insert into public.repair_orders(customer_id,customer_device_id,reported_issue)
  values((select id from public.customers limit 1),(select id from public.customer_devices limit 1),'Direct write');
  raise exception 'Direct repair write unexpectedly succeeded';
exception when insufficient_privilege then null; end $$;
do $$ begin
  perform 1 from private.repair_part_costs limit 1;
  raise exception 'Private repair cost unexpectedly readable';
exception when insufficient_privilege then null; end $$;

reset role;

do $$
declare
  v_main public.repair_orders%rowtype;
  v_bulk numeric;
  v_used text;
  v_restored text;
  v_qc integer;
  v_cost integer;
  v_hist integer;
  v_replan public.repair_parts%rowtype;
begin
  select * into v_main from public.repair_orders where intake_note='T5 MAIN';
  if v_main.status<>'COMPLETED' or v_main.qc_passed is distinct from true then raise exception 'Main lifecycle failed'; end if;
  if v_main.repair_code !~ '^SRV-[0-9]{6}-[0-9]{4}$' then raise exception 'Bad repair_code %',v_main.repair_code; end if;
  if v_main.approved_amount<>1400000 or v_main.final_amount<>1400000 then raise exception 'Approved/final amount wrong'; end if;
  if (select status from public.repair_orders where intake_note like 'T5 CANCEL%')<>'CANCELLED' then raise exception 'Cancel path failed'; end if;
  if (select status from public.repair_orders where intake_note='T5 REJECT')<>'CUSTOMER_REJECTED' then raise exception 'Reject path failed'; end if;
  if (select status from public.repair_orders where intake_note='T5 WARRANTY')<>'NO_FIX' then raise exception 'Warranty/no-fix path failed'; end if;
  select stock_qty into v_bulk from public.product_inventory_summary where sku='T5-LOCAL-BULK';
  if v_bulk<>8 then raise exception 'Bulk stock expected 8, got %',v_bulk; end if;
  select status into v_used from public.inventory_units where serial_number='T5-LOCAL-PART-1';
  select status into v_restored from public.inventory_units where serial_number='T5-LOCAL-PART-2';
  if v_used<>'OUT' or v_restored<>'IN_STOCK' then raise exception 'Serial statuses wrong %, %',v_used,v_restored; end if;
  select count(*) into v_qc from public.repair_diagnostics where repair_order_id=v_main.id and stage='QC';
  if v_qc<>2 then raise exception 'Expected 2 QC rows, got %',v_qc; end if;
  select count(*) into v_cost from private.repair_part_costs c join public.repair_parts p on p.id=c.repair_part_id where p.repair_order_id=v_main.id;
  if v_cost<>2 then raise exception 'Expected 2 repair cost snapshots, got %',v_cost; end if;
  select count(*) into v_hist from public.repair_status_history where repair_order_id=v_main.id;
  if v_hist<10 then raise exception 'Repair status history too short: %',v_hist; end if;
  select * into v_replan from public.repair_parts where repair_order_id=(select id from public.repair_orders where intake_note='T5 REPLAN');
  if v_replan.status<>'PLANNED' or v_replan.quantity<>2 then raise exception 'Repair part replan guard failed'; end if;
end $$;

select
  (select status from public.repair_orders where intake_note='T5 MAIN') as lifecycle_status,
  (select status from public.repair_orders where intake_note like 'T5 CANCEL%') as cancel_status,
  (select status from public.repair_orders where intake_note='T5 REJECT') as reject_status,
  (select status from public.repair_orders where intake_note='T5 WARRANTY') as warranty_final_status,
  (select stock_qty from public.product_inventory_summary where sku='T5-LOCAL-BULK') as bulk_stock,
  (select status from public.inventory_units where serial_number='T5-LOCAL-PART-1') as used_serial,
  (select status from public.inventory_units where serial_number='T5-LOCAL-PART-2') as restored_serial;

do $$ begin raise notice 'T5 FINAL CORE CHECKS: PASS'; end $$;
rollback;
