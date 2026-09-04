-- HomeTechVN T20 hosted demo dataset.
-- Fictional data only. No passwords, API keys, or real customer information.
-- One-shot safety: refuses any non-empty business database.

begin;

do $$
declare
  v_admin_count integer;
  v_business_rows bigint;
begin
  select count(*) into v_admin_count
  from public.profiles p
  join public.roles r on r.id=p.role_id
  where p.is_active and r.code='admin';

  if v_admin_count <> 1 then
    raise exception 'T20 hosted demo requires exactly one active Admin profile; found %',v_admin_count;
  end if;

  select
    (select count(*) from public.customers)
    +(select count(*) from public.products)
    +(select count(*) from public.sales_orders)
    +(select count(*) from public.repair_orders)
    +(select count(*) from public.warranties)
    +(select count(*) from public.service_schedules)
    +(select count(*) from public.software_licenses)
  into v_business_rows;

  if v_business_rows <> 0 then
    raise exception 'T20 hosted demo refuses a non-empty business database; found % rows',v_business_rows;
  end if;
end $$;

select set_config(
  'request.jwt.claim.sub',
  (select p.id::text
   from public.profiles p
   join public.roles r on r.id=p.role_id
   where p.is_active and r.code='admin'
   order by p.created_at
   limit 1),
  true
);
set local role authenticated;

do $$
begin
  if auth.uid() is null then raise exception 'T20 hosted demo auth context is missing'; end if;
  if not private.has_permission('product.manage')
     or not private.has_permission('sale.create')
     or not private.has_permission('repair.update')
     or not private.has_permission('warranty.manage')
  then raise exception 'T20 hosted demo Admin permissions are incomplete'; end if;
end $$;

insert into public.product_categories(name,description,sort_order)
values
  ('Laptop Demo','T20 fictional laptop catalog',10),
  ('Linh kien Demo','T20 fictional repair parts',20),
  ('Phu kien Demo','T20 fictional accessories',30);

insert into public.products(
  sku,name,category_id,brand,model,unit,sale_price,min_stock,
  track_serial,warranty_months,description
)
select 'DEMO-LAP-T20','Laptop HomeTechVN Demo',id,'DemoBrand','T20-Pro','cai',
       12500000,1,true,12,'San pham hoan toan gia dinh'
from public.product_categories where name='Laptop Demo';

insert into public.products(
  sku,name,category_id,brand,model,unit,sale_price,min_stock,
  track_serial,warranty_months,description
)
select 'DEMO-PSU-T20','Nguon may in Demo 24V',id,'DemoBrand','24V-5A','cai',
       350000,2,false,3,'Linh kien hoan toan gia dinh'
from public.product_categories where name='Linh kien Demo';

insert into public.products(
  sku,name,category_id,brand,model,unit,sale_price,min_stock,
  track_serial,warranty_months,description
)
select 'DEMO-MOUSE-T20','Chuot khong day Demo',id,'DemoBrand','M20','cai',
       220000,3,false,6,'Phu kien hoan toan gia dinh'
from public.product_categories where name='Phu kien Demo';

select public.inventory_receive(
  id,2,9000000,array['DEMO-T20-SN-001','DEMO-T20-SN-002'],
  'T20 HOSTED DEMO laptop receipt','T20_DEMO',null,'Kho demo'
)
from public.products where sku='DEMO-LAP-T20';

select public.inventory_receive(
  id,8,210000,null,
  'T20 HOSTED DEMO repair-part receipt','T20_DEMO',null,'Kho demo'
)
from public.products where sku='DEMO-PSU-T20';

select public.inventory_receive(
  id,12,135000,null,
  'T20 HOSTED DEMO accessory receipt','T20_DEMO',null,'Kho demo'
)
from public.products where sku='DEMO-MOUSE-T20';

insert into public.customers(full_name,customer_type,phone,email,address)
values
  ('Khach Demo 101','INDIVIDUAL','0900000101','demo101@invalid.example','Dia chi demo 101'),
  ('Khach Demo 102','INDIVIDUAL','0900000102','demo102@invalid.example','Dia chi demo 102'),
  ('Cong ty Demo 103','BUSINESS','0900000103','demo103@invalid.example','Dia chi demo 103');

insert into public.customer_devices(
  customer_id,device_type,brand,model,serial_number,color,condition_notes,purchase_date
)
select id,'Laptop','DemoBrand','T20-Pro','DEMO-T20-SN-001','Den',
       'Thiet bi gia dinh cho luong ban hang',current_date
from public.customers where full_name='Khach Demo 101';

insert into public.customer_devices(
  customer_id,device_type,brand,model,serial_number,color,condition_notes
)
select id,'Printer','DemoBrand','Printer-T20','DEMO-T20-PRN-001','Den',
       'Thiet bi gia dinh cho luong sua chua'
from public.customers where full_name='Khach Demo 102';

select public.sale_create(
  (select id from public.customers where full_name='Khach Demo 101'),
  'T20 HOSTED DEMO RECEIVABLE'
);
select public.sale_add_item(
  (select id from public.sales_orders where note='T20 HOSTED DEMO RECEIVABLE'),
  (select id from public.products where sku='DEMO-MOUSE-T20'),
  2,220000,0,'{}'::uuid[]
);
select public.sale_confirm(
  (select id from public.sales_orders where note='T20 HOSTED DEMO RECEIVABLE')
);
select public.sale_record_payment(
  (select id from public.sales_orders where note='T20 HOSTED DEMO RECEIVABLE'),
  100000,'BANK_TRANSFER','DEMO-T20-PAY-001','Thanh toan gia dinh'
);

select public.repair_create(
  (select id from public.customers where full_name='Khach Demo 102'),
  (select d.id from public.customer_devices d
   join public.customers c on c.id=d.customer_id
   where c.full_name='Khach Demo 102' and d.serial_number='DEMO-T20-PRN-001'),
  'May in demo khong len nguon','Vo may demo binh thuong',
  array['Day nguon demo'],'Kiem tra va bao gia','HIGH',
  'T20 HOSTED DEMO REPAIR'
);
select public.repair_start_diagnosis(
  (select id from public.repair_orders where intake_note='T20 HOSTED DEMO REPAIR')
);
select public.repair_add_diagnostic(
  (select id from public.repair_orders where intake_note='T20 HOSTED DEMO REPAIR'),
  'Khong co nguon','Nguon demo hong','Can thay nguon demo','Thay nguon va QC'
);
select public.repair_create_quote(
  (select id from public.repair_orders where intake_note='T20 HOSTED DEMO REPAIR'),
  250000,350000,0,current_date+5,'T20 HOSTED DEMO QUOTE'
);
select public.repair_submit_quote(
  (select id from public.repair_quotes where note='T20 HOSTED DEMO QUOTE')
);
select public.repair_customer_decision(
  (select id from public.repair_orders where intake_note='T20 HOSTED DEMO REPAIR'),
  true,'Khach demo dong y'
);
select public.repair_plan_part(
  (select id from public.repair_orders where intake_note='T20 HOSTED DEMO REPAIR'),
  (select id from public.products where sku='DEMO-PSU-T20'),
  1,350000,'{}'::uuid[],'Nguon demo thay the'
);
select public.repair_issue_part(
  (select rp.id from public.repair_parts rp
   join public.repair_orders ro on ro.id=rp.repair_order_id
   where ro.intake_note='T20 HOSTED DEMO REPAIR')
);
select public.repair_start_repair(
  (select id from public.repair_orders where intake_note='T20 HOSTED DEMO REPAIR')
);

select public.service_create(
  'Bao tri dinh ky T20 Demo','MAINTENANCE',
  'Dich vu hoan toan gia dinh',3,'MONTHS',350000,1
);
select public.service_schedule_create(
  (select id from public.services where name='Bao tri dinh ky T20 Demo'),
  (select id from public.customers where full_name='Cong ty Demo 103'),
  null,current_date,current_date+30,3,'MONTHS',350000,null,
  'T20 HOSTED DEMO SERVICE'
);

select public.software_product_create(
  'OFFICE','DemoVendor','Office T20 Demo','Standard',
  'SUBSCRIPTION',12,'San pham phan mem gia dinh'
);
select public.software_license_create(
  (select id from public.software_products where name='Office T20 Demo'),
  (select id from public.customers where full_name='Cong ty Demo 103'),
  null,current_date,current_date+30,5,'demo-license@invalid.example',
  null,false,1200000,'T20 HOSTED DEMO LICENSE'
);

select public.reminder_generate(now());
select public.notification_prepare(now());

insert into public.settings(key,value,description,is_sensitive)
values(
  'demo.t20.hosted',
  jsonb_build_object(
    'stage','T20',
    'loaded_at',now(),
    'mode','HOSTED_DEMO',
    'contains_real_customer_data',false
  ),
  'T20 hosted demo dataset marker',
  false
)
on conflict (key) do update
set value=excluded.value,
    description=excluded.description,
    is_sensitive=false,
    updated_at=now();

reset role;
commit;
