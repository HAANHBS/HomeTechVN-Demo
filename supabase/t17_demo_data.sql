\set ON_ERROR_STOP on

begin;
\o /dev/null

-- T17 local demo data.
-- PRECONDITION: login-capable demo users were created through LOCAL Auth signup API.
-- This file intentionally contains no passwords and no API/service-role keys.

do $$
declare
  v_missing integer;
begin
  select count(*) into v_missing
  from (values
    ('demo.admin@hometechvn.example'),
    ('demo.manager@hometechvn.example'),
    ('demo.sales@hometechvn.example'),
    ('demo.technician@hometechvn.example'),
    ('demo.cashier@hometechvn.example')
  ) as e(email)
  where not exists (select 1 from auth.users u where lower(u.email)=e.email);

  if v_missing<>0 then
    raise exception 'T17 demo Auth users missing: %',v_missing;
  end if;
end $$;

-- Activate and map five real login-capable local demo users.
update public.profiles p
set role_id=r.id,
    is_active=true,
    full_name=case lower(p.email)
      when 'demo.admin@hometechvn.example' then 'Demo Admin'
      when 'demo.manager@hometechvn.example' then 'Demo Quan ly'
      when 'demo.sales@hometechvn.example' then 'Demo Ban hang'
      when 'demo.technician@hometechvn.example' then 'Demo Ky thuat'
      when 'demo.cashier@hometechvn.example' then 'Demo Thu ngan'
      else p.full_name
    end
from public.roles r
where (lower(p.email),r.code) in (
  ('demo.admin@hometechvn.example','admin'),
  ('demo.manager@hometechvn.example','manager'),
  ('demo.sales@hometechvn.example','sales'),
  ('demo.technician@hometechvn.example','technician'),
  ('demo.cashier@hometechvn.example','cashier')
);

-- ---------------------------------------------------------------------------
-- Admin: catalog + initial inventory + reference services/software.
-- ---------------------------------------------------------------------------
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
    raise exception 'T17 PRIVILEGED ROLE MAP FAIL: ADMIN_CATALOG expected admin, got %',v_role;
  end if;
end $$;
set local role authenticated;

\echo [T17 SQL PHASE] ADMIN_CATALOG
do $$
begin
  if auth.uid() is null then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: ADMIN_CATALOG auth.uid is null';
  end if;
  if not private.has_permission('product.manage') then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: ADMIN_CATALOG missing permission product.manage';
  end if;
end $$;

insert into public.product_categories(name,description,sort_order)
values
  ('Laptop Demo','T17 demo laptop & may tinh',10),
  ('Linh kien Demo','T17 demo linh kien sua chua',20),
  ('Phu kien Demo','T17 demo phu kien ban le',30),
  ('Muc in Demo','T17 demo vat tu may in',40);

insert into public.products(
  sku,name,category_id,brand,model,unit,sale_price,min_stock,
  track_serial,warranty_months,description
)
select 'DEMO-LAP-7490','Dell Latitude 7490 Demo',id,'Dell','Latitude 7490','cai',
       6500000,1,true,12,'Laptop serial dung cho luong ban hang + bao hanh'
from public.product_categories where name='Laptop Demo';

insert into public.products(
  sku,name,category_id,brand,model,unit,sale_price,min_stock,
  track_serial,warranty_months,description
)
select 'DEMO-PSU-24V','Nguon 24V may in Demo',id,'OEM','24V-5A','cai',
       350000,2,false,3,'Linh kien bulk dung cho luong sua chua'
from public.product_categories where name='Linh kien Demo';

insert into public.products(
  sku,name,category_id,brand,model,unit,sale_price,min_stock,
  track_serial,warranty_months,description
)
select 'DEMO-MOUSE-WL','Chuot khong day Demo',id,'Logitech','M185','cai',
       220000,3,false,6,'Phu kien bulk'
from public.product_categories where name='Phu kien Demo';

insert into public.products(
  sku,name,category_id,brand,model,unit,sale_price,min_stock,
  track_serial,warranty_months,description
)
select 'DEMO-TONER-B2000','Muc Brother B2000 Demo',id,'OEM','TN-B022','hop',
       180000,5,false,0,'Co y ton duoi min_stock de tao reminder'
from public.product_categories where name='Muc in Demo';

select public.inventory_receive(
  id,3,4800000,
  array['DEMO-LAP-SN-001','DEMO-LAP-SN-002','DEMO-LAP-SN-003'],
  'T17 DEMO receive laptop','T17_DEMO',null,'Kho chinh'
)
from public.products where sku='DEMO-LAP-7490';

select public.inventory_receive(
  id,10,210000,null,
  'T17 DEMO receive repair part','T17_DEMO',null,'Kho linh kien'
)
from public.products where sku='DEMO-PSU-24V';

select public.inventory_receive(
  id,12,135000,null,
  'T17 DEMO receive accessories','T17_DEMO',null,'Kho chinh'
)
from public.products where sku='DEMO-MOUSE-WL';

select public.inventory_receive(
  id,2,100000,null,
  'T17 DEMO low stock fixture','T17_DEMO',null,'Kho muc'
)
from public.products where sku='DEMO-TONER-B2000';

select public.service_create(
  'Bao tri may tinh dinh ky Demo',
  'MAINTENANCE',
  'Ve sinh, kiem tra nhiet do, SMART va cap nhat phan mem',
  3,'MONTHS',350000,1
);

select public.software_product_create(
  'M365','Microsoft','Microsoft 365 Business Demo','Standard',
  'SUBSCRIPTION',12,'T17 demo recurring software'
);

-- ---------------------------------------------------------------------------
-- Sales: CRM + devices.
-- ---------------------------------------------------------------------------
reset role;
select set_config(
  'request.jwt.claim.sub',
  (select id::text from public.profiles where lower(email)='demo.sales@hometechvn.example'),
  true
);
do $$
declare
  v_role text;
begin
  select r.code into v_role
  from public.profiles p
  join public.roles r on r.id=p.role_id
  where lower(p.email)='demo.sales@hometechvn.example';

  if v_role is distinct from 'sales' then
    raise exception 'T17 PRIVILEGED ROLE MAP FAIL: SALES_CRM_AND_SALES expected sales, got %',v_role;
  end if;
end $$;
set local role authenticated;

\echo [T17 SQL PHASE] SALES_CRM_AND_SALES
do $$
begin
  if auth.uid() is null then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: SALES_CRM_AND_SALES auth.uid is null';
  end if;
  if not private.has_permission('sale.create') then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: SALES_CRM_AND_SALES missing permission sale.create';
  end if;
end $$;

insert into public.customers(full_name,customer_type,phone,email,address,birthday)
values
  ('Nguyen Van An','INDIVIDUAL','0912 345 678','an.demo@example.com','Nhu Thanh, Thanh Hoa',date '1988-05-12'),
  ('Tran Thi Binh','INDIVIDUAL','0988 112 233','binh.demo@example.com','Nong Cong, Thanh Hoa',date '1992-09-20'),
  ('Cong ty TNHH Minh Phat','BUSINESS','0237 388 8999','minhphat.demo@example.com','Thanh Hoa','2000-01-01'),
  ('Pham Van Cuong','INDIVIDUAL','0977 456 789','cuong.demo@example.com','Nhu Thanh, Thanh Hoa',date '1985-03-15');

insert into public.customer_devices(
  customer_id,device_type,brand,model,serial_number,color,condition_notes,purchase_date
)
select id,'Laptop','Dell','Latitude 7490','DEMO-LAP-SN-001','Den','May ban tu HomeTechVN Demo',current_date
from public.customers where full_name='Nguyen Van An';

insert into public.customer_devices(
  customer_id,device_type,brand,model,serial_number,color,condition_notes
)
select id,'Printer','Brother','HL-B2000D','DEMO-PRN-001','Den','Khong len nguon'
from public.customers where full_name='Tran Thi Binh';

insert into public.customer_devices(
  customer_id,device_type,brand,model,serial_number,condition_notes
)
select id,'Desktop','Dell','OptiPlex 7080','DEMO-PC-001','May van phong can bao tri dinh ky'
from public.customers where full_name='Cong ty TNHH Minh Phat';

insert into public.customer_devices(
  customer_id,device_type,brand,model,serial_number,condition_notes
)
select id,'Laptop','HP','ProBook 440 G8','DEMO-HP-READY-001','Phieu sua de trang thai READY'
from public.customers where full_name='Pham Van Cuong';

insert into public.customer_notes(customer_id,note_type,content,is_pinned)
select id,'IMPORTANT','Khach demo uu tien lien he qua dien thoai.',true
from public.customers where full_name='Nguyen Van An';

-- ---------------------------------------------------------------------------
-- Completed sale crossing Sales -> Inventory -> Cashier -> Checklist -> Warranty.
-- ---------------------------------------------------------------------------
select public.sale_create(
  (select id from public.customers where full_name='Nguyen Van An'),
  'T17 DEMO SALE COMPLETED'
);

select public.sale_add_item(
  (select id from public.sales_orders where note='T17 DEMO SALE COMPLETED'),
  (select id from public.products where sku='DEMO-LAP-7490'),
  1,6500000,200000,
  array[(select id from public.inventory_units where serial_number='DEMO-LAP-SN-001')]
);

select public.sale_add_item(
  (select id from public.sales_orders where note='T17 DEMO SALE COMPLETED'),
  (select id from public.products where sku='DEMO-MOUSE-WL'),
  1,220000,0,'{}'::uuid[]
);

select public.sale_confirm(
  (select id from public.sales_orders where note='T17 DEMO SALE COMPLETED')
);

-- ---------------------------------------------------------------------------
-- Receivable fixture: Sales creates/confirms the order. Cashier will record a
-- partial payment in the next phase, which is the only supported workflow
-- transition from CONFIRMED -> PAYMENT_PENDING.
-- ---------------------------------------------------------------------------
select public.sale_create(
  (select id from public.customers where full_name='Cong ty TNHH Minh Phat'),
  'T17 DEMO RECEIVABLE'
);
select public.sale_add_item(
  (select id from public.sales_orders where note='T17 DEMO RECEIVABLE'),
  (select id from public.products where sku='DEMO-MOUSE-WL'),
  3,220000,0,'{}'::uuid[]
);
select public.sale_confirm(
  (select id from public.sales_orders where note='T17 DEMO RECEIVABLE')
);

-- ---------------------------------------------------------------------------
-- Cashier pays the completed-sale fixture and partially pays receivable.
-- ---------------------------------------------------------------------------
reset role;
select set_config(
  'request.jwt.claim.sub',
  (select id::text from public.profiles where lower(email)='demo.cashier@hometechvn.example'),
  true
);
do $$
declare
  v_role text;
begin
  select r.code into v_role
  from public.profiles p
  join public.roles r on r.id=p.role_id
  where lower(p.email)='demo.cashier@hometechvn.example';

  if v_role is distinct from 'cashier' then
    raise exception 'T17 PRIVILEGED ROLE MAP FAIL: CASHIER_PAYMENT expected cashier, got %',v_role;
  end if;
end $$;
set local role authenticated;

\echo [T17 SQL PHASE] CASHIER_PAYMENT
do $$
begin
  if auth.uid() is null then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: CASHIER_PAYMENT auth.uid is null';
  end if;
  if not private.has_permission('payment.create') then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: CASHIER_PAYMENT missing permission payment.create';
  end if;
end $$;

select public.sale_record_payment(
  (select id from public.sales_orders where note='T17 DEMO SALE COMPLETED'),
  (select total_amount from public.sales_orders where note='T17 DEMO SALE COMPLETED'),
  'BANK_TRANSFER','DEMO-TXN-001','T17 DEMO full payment'
);

-- A non-zero PARTIAL payment is required by the T4 state machine to enter
-- PAYMENT_PENDING and set payment_pending_at for the RECEIVABLE_DUE reminder.
select public.sale_record_payment(
  (select id from public.sales_orders where note='T17 DEMO RECEIVABLE'),
  100000,
  'BANK_TRANSFER','DEMO-AR-001','T17 DEMO partial receivable payment'
);

-- ---------------------------------------------------------------------------
-- Sales completes delivery checklist and order.
-- ---------------------------------------------------------------------------
reset role;
select set_config(
  'request.jwt.claim.sub',
  (select id::text from public.profiles where lower(email)='demo.sales@hometechvn.example'),
  true
);
do $$
declare
  v_role text;
begin
  select r.code into v_role
  from public.profiles p
  join public.roles r on r.id=p.role_id
  where lower(p.email)='demo.sales@hometechvn.example';

  if v_role is distinct from 'sales' then
    raise exception 'T17 PRIVILEGED ROLE MAP FAIL: SALES_DELIVERY_WARRANTY expected sales, got %',v_role;
  end if;
end $$;
set local role authenticated;

\echo [T17 SQL PHASE] SALES_DELIVERY_WARRANTY
do $$
begin
  if auth.uid() is null then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: SALES_DELIVERY_WARRANTY auth.uid is null';
  end if;
  if not private.has_permission('warranty.manage') then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: SALES_DELIVERY_WARRANTY missing permission warranty.manage';
  end if;
end $$;

select public.sale_set_checklist_item((select id from public.sales_orders where note='T17 DEMO SALE COMPLETED'),'customer_identity',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T17 DEMO SALE COMPLETED'),'contact_phone',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T17 DEMO SALE COMPLETED'),'product_quantity',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T17 DEMO SALE COMPLETED'),'product_configuration',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T17 DEMO SALE COMPLETED'),'serial_numbers',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T17 DEMO SALE COMPLETED'),'physical_condition',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T17 DEMO SALE COMPLETED'),'functionality_test',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T17 DEMO SALE COMPLETED'),'price_discount',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T17 DEMO SALE COMPLETED'),'warranty_terms',true);
select public.sale_deliver((select id from public.sales_orders where note='T17 DEMO SALE COMPLETED'));
select public.sale_set_checklist_item((select id from public.sales_orders where note='T17 DEMO SALE COMPLETED'),'customer_delivery_confirmation',true);
select public.sale_complete((select id from public.sales_orders where note='T17 DEMO SALE COMPLETED'));

select public.warranty_create_sale(
  (select soi.id
   from public.sales_order_items soi
   join public.sales_orders so on so.id=soi.sales_order_id
   join public.products p on p.id=soi.product_id
   where so.note='T17 DEMO SALE COMPLETED' and p.sku='DEMO-LAP-7490'),
  (select id from public.inventory_units where serial_number='DEMO-LAP-SN-001'),
  (select d.id
   from public.customer_devices d
   join public.customers c on c.id=d.customer_id
   where c.full_name='Nguyen Van An' and d.serial_number='DEMO-LAP-SN-001'),
  current_date-23,
  1,
  'Bao hanh phan cung theo dieu kien demo',
  'T17 DEMO SALE WARRANTY'
);

-- ---------------------------------------------------------------------------
-- Warranty claim: sale warranty -> technician lifecycle -> CLOSED.
-- ---------------------------------------------------------------------------
select public.warranty_claim_create(
  (select id from public.warranties where note='T17 DEMO SALE WARRANTY'),
  'May thinh thoang mat nguon',
  'Ngoai hinh con nguyen',
  'Kiem tra bao hanh',
  (select id from public.profiles where lower(email)='demo.technician@hometechvn.example')
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  (select id::text from public.profiles where lower(email)='demo.technician@hometechvn.example'),
  true
);
do $$
declare
  v_role text;
begin
  select r.code into v_role
  from public.profiles p
  join public.roles r on r.id=p.role_id
  where lower(p.email)='demo.technician@hometechvn.example';

  if v_role is distinct from 'technician' then
    raise exception 'T17 PRIVILEGED ROLE MAP FAIL: TECH_WARRANTY_CLAIM expected technician, got %',v_role;
  end if;
end $$;
set local role authenticated;

\echo [T17 SQL PHASE] TECH_WARRANTY_CLAIM
do $$
begin
  if auth.uid() is null then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: TECH_WARRANTY_CLAIM auth.uid is null';
  end if;
  if not private.has_permission('warranty.manage') then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: TECH_WARRANTY_CLAIM missing permission warranty.manage';
  end if;
end $$;

select public.warranty_claim_start_checking(
  (select id from public.warranty_claims where issue_description='May thinh thoang mat nguon'),
  (select id from public.profiles where lower(email)='demo.technician@hometechvn.example'),
  'T17 DEMO checking'
);
select public.warranty_claim_decide(
  (select id from public.warranty_claims where issue_description='May thinh thoang mat nguon'),
  true,'Du dieu kien bao hanh'
);
select public.warranty_claim_start_service(
  (select id from public.warranty_claims where issue_description='May thinh thoang mat nguon'),
  'Ve sinh socket nguon va cap nhat BIOS'
);
select public.warranty_claim_start_qc(
  (select id from public.warranty_claims where issue_description='May thinh thoang mat nguon')
);
select public.warranty_claim_record_qc(
  (select id from public.warranty_claims where issue_description='May thinh thoang mat nguon'),
  true,'Stress test 60 phut dat','Hoat dong on dinh'
);
select public.warranty_claim_mark_returned(
  (select id from public.warranty_claims where issue_description='May thinh thoang mat nguon'),
  'Da tra khach'
);
select public.warranty_claim_close(
  (select id from public.warranty_claims where issue_description='May thinh thoang mat nguon'),
  'T17 DEMO closed'
);

-- ---------------------------------------------------------------------------
-- Repair #1: completed with inventory part and repair warranty.
-- ---------------------------------------------------------------------------
reset role;
select set_config(
  'request.jwt.claim.sub',
  (select id::text from public.profiles where lower(email)='demo.sales@hometechvn.example'),
  true
);
do $$
declare
  v_role text;
begin
  select r.code into v_role
  from public.profiles p
  join public.roles r on r.id=p.role_id
  where lower(p.email)='demo.sales@hometechvn.example';

  if v_role is distinct from 'sales' then
    raise exception 'T17 PRIVILEGED ROLE MAP FAIL: SALES_REPAIR_CREATE expected sales, got %',v_role;
  end if;
end $$;
set local role authenticated;

\echo [T17 SQL PHASE] SALES_REPAIR_CREATE
do $$
begin
  if auth.uid() is null then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: SALES_REPAIR_CREATE auth.uid is null';
  end if;
  if not private.has_permission('repair.create') then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: SALES_REPAIR_CREATE missing permission repair.create';
  end if;
end $$;

select public.repair_create(
  (select id from public.customers where full_name='Tran Thi Binh'),
  (select d.id from public.customer_devices d join public.customers c on c.id=d.customer_id
   where c.full_name='Tran Thi Binh' and d.serial_number='DEMO-PRN-001'),
  'May in khong len nguon',
  'Vo binh thuong',
  array['Day nguon'],
  'Kiem tra va bao gia truoc',
  'HIGH',
  'T17 DEMO REPAIR COMPLETED'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  (select id::text from public.profiles where lower(email)='demo.technician@hometechvn.example'),
  true
);
do $$
declare
  v_role text;
begin
  select r.code into v_role
  from public.profiles p
  join public.roles r on r.id=p.role_id
  where lower(p.email)='demo.technician@hometechvn.example';

  if v_role is distinct from 'technician' then
    raise exception 'T17 PRIVILEGED ROLE MAP FAIL: TECH_REPAIR_COMPLETED expected technician, got %',v_role;
  end if;
end $$;
set local role authenticated;

\echo [T17 SQL PHASE] TECH_REPAIR_COMPLETED
do $$
begin
  if auth.uid() is null then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: TECH_REPAIR_COMPLETED auth.uid is null';
  end if;
  if not private.has_permission('repair.update') then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: TECH_REPAIR_COMPLETED missing permission repair.update';
  end if;
end $$;

select public.repair_start_diagnosis(
  (select id from public.repair_orders where intake_note='T17 DEMO REPAIR COMPLETED')
);
select public.repair_add_diagnostic(
  (select id from public.repair_orders where intake_note='T17 DEMO REPAIR COMPLETED'),
  'Khong co nguon','Nguon 24V hong','Can thay nguon','Thay nguon + QC'
);
select public.repair_create_quote(
  (select id from public.repair_orders where intake_note='T17 DEMO REPAIR COMPLETED'),
  250000,350000,0,current_date+5,'T17 DEMO REPAIR QUOTE'
);
select public.repair_submit_quote(
  (select id from public.repair_quotes where note='T17 DEMO REPAIR QUOTE')
);
select public.repair_customer_decision(
  (select id from public.repair_orders where intake_note='T17 DEMO REPAIR COMPLETED'),
  true,'Khach demo dong y'
);
select public.repair_plan_part(
  (select id from public.repair_orders where intake_note='T17 DEMO REPAIR COMPLETED'),
  (select id from public.products where sku='DEMO-PSU-24V'),
  1,350000,'{}'::uuid[],'Nguon thay the'
);
select public.repair_issue_part(
  (select rp.id
   from public.repair_parts rp
   join public.repair_orders ro on ro.id=rp.repair_order_id
   where ro.intake_note='T17 DEMO REPAIR COMPLETED')
);
select public.repair_start_repair(
  (select id from public.repair_orders where intake_note='T17 DEMO REPAIR COMPLETED')
);
select public.repair_start_qc(
  (select id from public.repair_orders where intake_note='T17 DEMO REPAIR COMPLETED')
);
select public.repair_record_qc(
  (select id from public.repair_orders where intake_note='T17 DEMO REPAIR COMPLETED'),
  true,'Nguon on dinh, in test dat','QC PASS'
);
select public.repair_mark_returned(
  (select id from public.repair_orders where intake_note='T17 DEMO REPAIR COMPLETED')
);
select public.repair_complete(
  (select id from public.repair_orders where intake_note='T17 DEMO REPAIR COMPLETED')
);
select public.warranty_create_repair(
  (select id from public.repair_orders where intake_note='T17 DEMO REPAIR COMPLETED'),
  current_date,3,'Bao hanh phan da sua','T17 DEMO REPAIR WARRANTY'
);

-- ---------------------------------------------------------------------------
-- Repair #2: leave at READY to generate ready/uncollected reminders.
-- ---------------------------------------------------------------------------
reset role;
select set_config(
  'request.jwt.claim.sub',
  (select id::text from public.profiles where lower(email)='demo.sales@hometechvn.example'),
  true
);
do $$
declare
  v_role text;
begin
  select r.code into v_role
  from public.profiles p
  join public.roles r on r.id=p.role_id
  where lower(p.email)='demo.sales@hometechvn.example';

  if v_role is distinct from 'sales' then
    raise exception 'T17 PRIVILEGED ROLE MAP FAIL: SALES_REPAIR_READY_CREATE expected sales, got %',v_role;
  end if;
end $$;
set local role authenticated;

\echo [T17 SQL PHASE] SALES_REPAIR_READY_CREATE
do $$
begin
  if auth.uid() is null then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: SALES_REPAIR_READY_CREATE auth.uid is null';
  end if;
  if not private.has_permission('repair.create') then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: SALES_REPAIR_READY_CREATE missing permission repair.create';
  end if;
end $$;

select public.repair_create(
  (select id from public.customers where full_name='Pham Van Cuong'),
  (select d.id from public.customer_devices d join public.customers c on c.id=d.customer_id
   where c.full_name='Pham Van Cuong' and d.serial_number='DEMO-HP-READY-001'),
  'May nong va tu tat',
  'Ngoai hinh kha',
  array['Sac'],
  'Ve sinh va kiem tra nhiet',
  'NORMAL',
  'T17 DEMO REPAIR READY'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  (select id::text from public.profiles where lower(email)='demo.technician@hometechvn.example'),
  true
);
do $$
declare
  v_role text;
begin
  select r.code into v_role
  from public.profiles p
  join public.roles r on r.id=p.role_id
  where lower(p.email)='demo.technician@hometechvn.example';

  if v_role is distinct from 'technician' then
    raise exception 'T17 PRIVILEGED ROLE MAP FAIL: TECH_REPAIR_READY expected technician, got %',v_role;
  end if;
end $$;
set local role authenticated;

\echo [T17 SQL PHASE] TECH_REPAIR_READY
do $$
begin
  if auth.uid() is null then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: TECH_REPAIR_READY auth.uid is null';
  end if;
  if not private.has_permission('repair.qc') then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: TECH_REPAIR_READY missing permission repair.qc';
  end if;
end $$;

select public.repair_start_diagnosis((select id from public.repair_orders where intake_note='T17 DEMO REPAIR READY'));
select public.repair_add_diagnostic(
  (select id from public.repair_orders where intake_note='T17 DEMO REPAIR READY'),
  'Nong/tat','Keo tan nhiet kho','Bao tri','Ve sinh + keo moi'
);
select public.repair_create_quote(
  (select id from public.repair_orders where intake_note='T17 DEMO REPAIR READY'),
  300000,0,0,current_date+3,'T17 DEMO READY QUOTE'
);
select public.repair_submit_quote((select id from public.repair_quotes where note='T17 DEMO READY QUOTE'));
select public.repair_customer_decision(
  (select id from public.repair_orders where intake_note='T17 DEMO REPAIR READY'),
  true,'Dong y'
);
select public.repair_start_repair((select id from public.repair_orders where intake_note='T17 DEMO REPAIR READY'));
select public.repair_start_qc((select id from public.repair_orders where intake_note='T17 DEMO REPAIR READY'));
select public.repair_record_qc(
  (select id from public.repair_orders where intake_note='T17 DEMO REPAIR READY'),
  true,'Nhiet do dat','San sang tra khach'
);

-- ---------------------------------------------------------------------------
-- Recurring service + expiring software license.
-- ---------------------------------------------------------------------------
reset role;
select set_config(
  'request.jwt.claim.sub',
  (select id::text from public.profiles where lower(email)='demo.sales@hometechvn.example'),
  true
);
do $$
declare
  v_role text;
begin
  select r.code into v_role
  from public.profiles p
  join public.roles r on r.id=p.role_id
  where lower(p.email)='demo.sales@hometechvn.example';

  if v_role is distinct from 'sales' then
    raise exception 'T17 PRIVILEGED ROLE MAP FAIL: SALES_RECURRING expected sales, got %',v_role;
  end if;
end $$;
set local role authenticated;

\echo [T17 SQL PHASE] SALES_RECURRING
do $$
begin
  if auth.uid() is null then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: SALES_RECURRING auth.uid is null';
  end if;
  if not private.has_permission('service.manage') then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: SALES_RECURRING missing permission service.manage';
  end if;
end $$;

select public.service_schedule_create(
  (select id from public.services where name='Bao tri may tinh dinh ky Demo'),
  (select id from public.customers where full_name='Cong ty TNHH Minh Phat'),
  (select d.id from public.customer_devices d join public.customers c on c.id=d.customer_id
   where c.full_name='Cong ty TNHH Minh Phat' and d.serial_number='DEMO-PC-001'),
  current_date-83,
  current_date+7,
  3,'MONTHS',350000,current_date+365,
  'T17 DEMO SERVICE SCHEDULE'
);

select public.software_license_create(
  (select id from public.software_products where name='Microsoft 365 Business Demo'),
  (select id from public.customers where full_name='Cong ty TNHH Minh Phat'),
  (select d.id from public.customer_devices d join public.customers c on c.id=d.customer_id
   where c.full_name='Cong ty TNHH Minh Phat' and d.serial_number='DEMO-PC-001'),
  current_date-358,
  current_date+7,
  5,
  'it@minhphat.demo',
  'vault://hometechvn/demo/m365/minhphat',
  true,
  4200000,
  'T17 DEMO LICENSE EXPIRING'
);

-- ---------------------------------------------------------------------------
-- Reminder + Notification integration.
-- Only Admin/Manager holds notification.manage.
-- ---------------------------------------------------------------------------
reset role;
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
    raise exception 'T17 PRIVILEGED ROLE MAP FAIL: ADMIN_REMINDER_NOTIFICATION expected admin, got %',v_role;
  end if;
end $$;
set local role authenticated;

\echo [T17 SQL PHASE] ADMIN_REMINDER_NOTIFICATION
do $$
begin
  if auth.uid() is null then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: ADMIN_REMINDER_NOTIFICATION auth.uid is null';
  end if;
  if not private.has_permission('notification.manage') then
    raise exception 'T17 AUTH/PERMISSION CONTEXT FAIL: ADMIN_REMINDER_NOTIFICATION missing permission notification.manage';
  end if;
end $$;

select public.reminder_generate(now());
select public.notification_prepare(now());

-- Leave a marker in ordinary settings so snapshots/search can identify dataset.

insert into public.settings(key,value,description,is_sensitive)
values(
  'demo.t17.dataset',
  jsonb_build_object(
    'stage','T17',
    'loaded_at',now(),
    'mode','LOCAL_ONLY',
    'contains_real_customer_data',false
  ),
  'T17 local demo integration dataset marker',
  false
)
on conflict (key) do update
set value=excluded.value,
    description=excluded.description,
    is_sensitive=false,
    updated_at=now();

reset role;
\o
\echo [T17 SQL PHASE] DATASET_COMPLETE

commit;
