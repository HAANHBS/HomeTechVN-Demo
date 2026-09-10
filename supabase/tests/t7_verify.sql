\set ON_ERROR_STOP on
begin;

do $$
declare v_tables int; v_policies int; v_direct boolean;
begin
  select count(*) into v_tables from information_schema.tables where table_schema='public' and table_name in ('warranties','warranty_claims','warranty_status_history');
  if v_tables<>3 then raise exception 'T7 table count expected 3, got %',v_tables; end if;
  select count(*) into v_policies from pg_policies where schemaname='public' and tablename in ('warranties','warranty_claims','warranty_status_history');
  if v_policies<>3 then raise exception 'T7 policy count expected 3, got %',v_policies; end if;
  if has_table_privilege('anon','public.warranties','SELECT') then raise exception 'anon must not SELECT warranties'; end if;
  if has_function_privilege('anon','public.warranty_public_lookup_server(text)','EXECUTE') then raise exception 'anon must not execute server lookup'; end if;
  if has_function_privilege('authenticated','public.warranty_public_lookup_server(text)','EXECUTE') then raise exception 'authenticated must not execute server lookup'; end if;
  if not has_function_privilege('service_role','public.warranty_public_lookup_server(text)','EXECUTE') then raise exception 'service_role needs server lookup'; end if;
  select has_table_privilege('authenticated','public.warranties','INSERT') into v_direct;
  if v_direct then raise exception 'authenticated must not INSERT warranties directly'; end if;
  select has_table_privilege('authenticated','public.warranty_claims','UPDATE') into v_direct;
  if v_direct then raise exception 'authenticated must not UPDATE claims directly'; end if;
end $$;

insert into auth.users(id,email,raw_user_meta_data) values('79797979-7979-4979-8979-797979797979','t7-local-verify@example.invalid','{}'::jsonb);
update public.profiles set role_id=(select id from public.roles where code='admin'),is_active=true,full_name='T7 Local Verify' where id='79797979-7979-4979-8979-797979797979';
set local role authenticated;
select set_config('request.jwt.claim.sub','79797979-7979-4979-8979-797979797979',true);

insert into public.customers(full_name,phone) values('T7 LOCAL CUSTOMER','0911222333');
insert into public.customer_devices(customer_id,device_type,brand,model,serial_number)
select id,'Laptop','Dell','T7 Local','DEV-T7-LOCAL' from public.customers where full_name='T7 LOCAL CUSTOMER';
insert into public.product_categories(name,description) values('T7 LOCAL CATEGORY','T7');
insert into public.products(sku,name,category_id,unit,sale_price,track_serial,warranty_months)
select 'T7-LOCAL-SERIAL','T7 Local Serial',id,'cai',3000000,true,12 from public.product_categories where name='T7 LOCAL CATEGORY';
select public.inventory_receive(id,1,2200000,array['T7-LOCAL-SN-001'],'T7 seed','VERIFY',null,'T7') from public.products where sku='T7-LOCAL-SERIAL';

reset role;
update public.profiles set role_id=(select id from public.roles where code='sales') where id='79797979-7979-4979-8979-797979797979';
set local role authenticated;
select set_config('request.jwt.claim.sub','79797979-7979-4979-8979-797979797979',true);
select public.sale_create((select id from public.customers where full_name='T7 LOCAL CUSTOMER'),'T7 local sale');
select public.sale_add_item((select id from public.sales_orders where note='T7 local sale'),(select id from public.products where sku='T7-LOCAL-SERIAL'),1,3000000,0,array[(select id from public.inventory_units where serial_number='T7-LOCAL-SN-001')]);
select public.sale_confirm((select id from public.sales_orders where note='T7 local sale'));

reset role;
update public.profiles set role_id=(select id from public.roles where code='cashier') where id='79797979-7979-4979-8979-797979797979';
set local role authenticated;
select set_config('request.jwt.claim.sub','79797979-7979-4979-8979-797979797979',true);
select public.sale_record_payment((select id from public.sales_orders where note='T7 local sale'),3000000,'CASH',null,'T7 local payment');

reset role;
update public.profiles set role_id=(select id from public.roles where code='sales') where id='79797979-7979-4979-8979-797979797979';
set local role authenticated;
select set_config('request.jwt.claim.sub','79797979-7979-4979-8979-797979797979',true);
select public.sale_deliver((select id from public.sales_orders where note='T7 local sale'));
select public.warranty_create_sale(
  (select i.id from public.sales_order_items i join public.sales_orders o on o.id=i.sales_order_id where o.note='T7 local sale'),
  (select id from public.inventory_units where serial_number='T7-LOCAL-SN-001'),
  (select id from public.customer_devices where serial_number='DEV-T7-LOCAL'),
  current_date,12,'Bao hanh 12 thang','T7 local warranty'
);

do $$ declare v public.warranties%rowtype; begin
  select * into v from public.warranties where note='T7 local warranty';
  if v.warranty_code !~ '^WAR-[0-9]{6}-[0-9]{4}$' then raise exception 'Bad warranty code %',v.warranty_code; end if;
  if length(v.lookup_token)<>64 or v.lookup_token !~ '^[0-9a-f]{64}$' then raise exception 'Bad opaque lookup token'; end if;
  if v.end_date <> (v.start_date + interval '12 months' - interval '1 day')::date then raise exception 'Bad warranty date range'; end if;
end $$;

reset role;
update public.profiles set role_id=(select id from public.roles where code='cashier') where id='79797979-7979-4979-8979-797979797979';
set local role authenticated;
select set_config('request.jwt.claim.sub','79797979-7979-4979-8979-797979797979',true);
do $$ declare v_count int; begin select count(*) into v_count from public.warranties; if v_count<>1 then raise exception 'Cashier warranty view failed'; end if; end $$;
do $$ begin
  perform public.warranty_claim_create((select id from public.warranties where note='T7 local warranty'),'Denied',null,null,null);
  raise exception 'Cashier unexpectedly created warranty claim';
exception when others then
  if sqlerrm='Cashier unexpectedly created warranty claim' then raise; end if;
  if position('warranty.manage' in sqlerrm)=0 then raise; end if;
end $$;

reset role;
update public.profiles set role_id=(select id from public.roles where code='technician') where id='79797979-7979-4979-8979-797979797979';
set local role authenticated;
select set_config('request.jwt.claim.sub','79797979-7979-4979-8979-797979797979',true);
select public.warranty_claim_create((select id from public.warranties where note='T7 local warranty'),'Khong len nguon','Vo nguyen ven','Bao hanh','79797979-7979-4979-8979-797979797979');
select public.warranty_claim_start_checking((select id from public.warranty_claims where issue_description='Khong len nguon'),'79797979-7979-4979-8979-797979797979','Kiem tra');
select public.warranty_claim_decide((select id from public.warranty_claims where issue_description='Khong len nguon'),true,'Du dieu kien');
select public.warranty_claim_start_service((select id from public.warranty_claims where issue_description='Khong len nguon'),'Sua main');
select public.warranty_claim_start_qc((select id from public.warranty_claims where issue_description='Khong len nguon'));
select public.warranty_claim_record_qc((select id from public.warranty_claims where issue_description='Khong len nguon'),false,'QC fail',null);
select public.warranty_claim_update_service((select id from public.warranty_claims where issue_description='Khong len nguon'),'Sua lai','On dinh');
select public.warranty_claim_start_qc((select id from public.warranty_claims where issue_description='Khong len nguon'));
select public.warranty_claim_record_qc((select id from public.warranty_claims where issue_description='Khong len nguon'),true,'QC pass','Hoan tat');
select public.warranty_claim_mark_returned((select id from public.warranty_claims where issue_description='Khong len nguon'),'Da tra');
select public.warranty_claim_close((select id from public.warranty_claims where issue_description='Khong len nguon'),'Dong claim');

do $$ declare v public.warranty_claims%rowtype; v_hist int; begin
  select * into v from public.warranty_claims where issue_description='Khong len nguon';
  if v.status<>'CLOSED' then raise exception 'Main claim not CLOSED'; end if;
  if v.claim_code !~ '^WCL-[0-9]{6}-[0-9]{4}$' then raise exception 'Bad claim code %',v.claim_code; end if;
  select count(*) into v_hist from public.warranty_status_history where warranty_claim_id=v.id;
  if v_hist<>10 then raise exception 'Claim history expected 10, got %',v_hist; end if;
end $$;

select public.warranty_void((select id from public.warranties where note='T7 local warranty'),'Local verify void');
do $$ begin
  perform public.warranty_claim_create((select id from public.warranties where note='T7 local warranty'),'After void',null,null,null);
  raise exception 'VOID warranty accepted claim';
exception when others then
  if sqlerrm='VOID warranty accepted claim' then raise; end if;
  if position('VOID' in sqlerrm)=0 then raise; end if;
end $$;

reset role;
set local role service_role;
do $$ declare v jsonb; v_token text; begin
  select lookup_token into v_token from public.warranties where note='T7 local warranty';
  select public.warranty_public_lookup_server(v_token) into v;
  if not coalesce((v->>'found')::boolean,false) then raise exception 'Server payload not found'; end if;
  if v->>'phone_masked'<>'091***333' then raise exception 'Phone mask wrong: %',v->>'phone_masked'; end if;
  if v->>'serial_masked'<>'T7-****001' then raise exception 'Serial mask wrong: %',v->>'serial_masked'; end if;
  if v ? 'customer_id' or v ? 'source_id' or v ? 'inventory_unit_id' then raise exception 'Server payload leaked internal IDs'; end if;
  if v->>'status'<>'VOID' then raise exception 'Server payload status wrong'; end if;
end $$;
reset role;

select
  (select status from public.warranty_claims where issue_description='Khong len nguon') as claim_status,
  (select status from public.warranties where note='T7 local warranty') as warranty_status,
  (select count(*) from public.warranty_status_history) as history_rows;

do $$ begin raise notice 'T7 FINAL CORE CHECKS: PASS'; end $$;
rollback;
