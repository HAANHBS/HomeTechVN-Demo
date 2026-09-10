\set ON_ERROR_STOP on
begin;

-- T6 schema / system template assertions.
do $$
declare
  v_tables integer;
  v_items integer;
  v_direct boolean;
begin
  select count(*) into v_tables
  from information_schema.tables
  where table_schema='public'
    and table_name in ('checklist_templates','checklist_template_items','checklist_runs','checklist_run_items');
  if v_tables<>4 then raise exception 'T6 checklist table count expected 4, got %',v_tables; end if;

  select count(*) into v_items
  from public.checklist_template_items i
  join public.checklist_templates t on t.id=i.template_id
  where t.template_code='SALES_DELIVERY' and t.version=1 and t.is_system=true;
  if v_items<>16 then raise exception 'SALES_DELIVERY must have 16 items, got %',v_items; end if;

  if not exists(select 1 from public.checklist_templates where template_code='SALES_DELIVERY' and version=1 and is_active and is_system) then
    raise exception 'SALES_DELIVERY v1 system template is not active';
  end if;

  select has_table_privilege('authenticated','public.checklist_runs','INSERT') into v_direct;
  if v_direct then raise exception 'authenticated must not INSERT checklist_runs directly'; end if;
  select has_table_privilege('authenticated','public.checklist_run_items','UPDATE') into v_direct;
  if v_direct then raise exception 'authenticated must not UPDATE checklist_run_items directly'; end if;
  select has_table_privilege('authenticated','public.checklist_templates','INSERT') into v_direct;
  if v_direct then raise exception 'authenticated must not INSERT checklist_templates directly'; end if;
end $$;

insert into auth.users(id,email,raw_user_meta_data)
values('68686868-6868-4868-8868-686868686868','t6-local-verify@example.invalid','{}'::jsonb);

update public.profiles
set role_id=(select id from public.roles where code='admin'),
    is_active=true,
    full_name='T6 Local Verify'
where id='68686868-6868-4868-8868-686868686868';

set local role authenticated;
select set_config('request.jwt.claim.sub','68686868-6868-4868-8868-686868686868',true);

-- Seed a serialized sales case using Admin permissions.
insert into public.customers(full_name,phone) values('T6 LOCAL CUSTOMER','0912686868');
insert into public.product_categories(name,description) values('T6 LOCAL CATEGORY','T6');
insert into public.products(sku,name,category_id,unit,sale_price,track_serial,warranty_months)
select 'T6-LOCAL-SERIAL','T6 Local Serial',id,'cai',2000000,true,24
from public.product_categories where name='T6 LOCAL CATEGORY';
select public.inventory_receive(
  id,2,1500000,array['T6-LOCAL-SN-01','T6-LOCAL-SN-02'],
  'T6 local seed','VERIFY',null,'T6'
) from public.products where sku='T6-LOCAL-SERIAL';

-- Sales: create order, issue serial and start checklist.
reset role;
update public.profiles
set role_id=(select id from public.roles where code='sales')
where id='68686868-6868-4868-8868-686868686868';
set local role authenticated;
select set_config('request.jwt.claim.sub','68686868-6868-4868-8868-686868686868',true);

select public.sale_create(
  (select id from public.customers where full_name='T6 LOCAL CUSTOMER'),
  'T6 local sale'
);
select public.sale_add_item(
  (select id from public.sales_orders where note='T6 local sale'),
  (select id from public.products where sku='T6-LOCAL-SERIAL'),
  1,2000000,0,
  array[(select id from public.inventory_units where serial_number='T6-LOCAL-SN-01')]
);
select public.sale_confirm((select id from public.sales_orders where note='T6 local sale'));
select public.checklist_run_start(
  (select id from public.checklist_templates where template_code='SALES_DELIVERY' and is_active),
  'SALES_ORDER',
  (select id from public.sales_orders where note='T6 local sale'),
  'T6 local delivery'
);

do $$
declare v_run uuid; v_total int; v_required int;
begin
  select id into v_run
  from public.checklist_runs
  where entity_type='SALES_ORDER'
    and entity_id=(select id from public.sales_orders where note='T6 local sale');

  select count(*),count(*) filter(where required)
  into v_total,v_required
  from public.checklist_run_items where run_id=v_run;

  if v_total<>16 then raise exception 'Expected 16 run items, got %',v_total; end if;
  if v_required<>11 then raise exception 'Serialized sale expected 11 required items, got %',v_required; end if;
end $$;

-- System-managed payment cannot be manually checked.
do $$
begin
  perform public.checklist_run_set_item(
    (select i.id
     from public.checklist_run_items i
     join public.checklist_runs r on r.id=i.run_id
     where r.entity_id=(select id from public.sales_orders where note='T6 local sale')
       and i.item_key='payment_confirmed'),
    true,null
  );
  raise exception 'payment_confirmed unexpectedly editable';
exception when others then
  if sqlerrm='payment_confirmed unexpectedly editable' then raise; end if;
  if position('system managed' in lower(sqlerrm))=0 then raise; end if;
end $$;

-- T6 -> T4 bridge: check all required except payment.
select public.checklist_run_set_item(i.id,true,'local verify')
from public.checklist_run_items i
join public.checklist_runs r on r.id=i.run_id
where r.entity_id=(select id from public.sales_orders where note='T6 local sale')
  and i.required
  and i.item_key<>'payment_confirmed';

do $$
declare v_legacy_checked boolean;
begin
  select coalesce((x->>'checked')::boolean,false)
  into v_legacy_checked
  from public.sales_orders o,
       jsonb_array_elements(o.checklist) x
  where o.note='T6 local sale' and x->>'key'='customer_identity';
  if not coalesce(v_legacy_checked,false) then raise exception 'T6 item did not sync to T4 Sales JSON'; end if;
end $$;

-- Cannot complete before payment.
do $$
begin
  perform public.checklist_run_complete(
    (select id from public.checklist_runs where entity_id=(select id from public.sales_orders where note='T6 local sale'))
  );
  raise exception 'Checklist completed before payment';
exception when others then
  if sqlerrm='Checklist completed before payment' then raise; end if;
  if position('incomplete' in lower(sqlerrm))=0 then raise; end if;
end $$;

-- Cashier pays, but cannot run/checklist.
reset role;
update public.profiles
set role_id=(select id from public.roles where code='cashier')
where id='68686868-6868-4868-8868-686868686868';
set local role authenticated;
select set_config('request.jwt.claim.sub','68686868-6868-4868-8868-686868686868',true);

select public.sale_record_payment(
  (select id from public.sales_orders where note='T6 local sale'),
  2000000,'CASH',null,'T6 local payment'
);

do $$
declare v_visible int;
begin
  select count(*) into v_visible from public.checklist_runs;
  if v_visible<>0 then raise exception 'Cashier unexpectedly sees checklist runs: %',v_visible; end if;
end $$;

do $$
begin
  perform public.checklist_run_start(
    (select id from public.checklist_templates where template_code='SALES_DELIVERY' and is_active),
    'SALES_ORDER',
    (select id from public.sales_orders where note='T6 local sale'),
    null
  );
  raise exception 'Cashier unexpectedly started checklist';
exception when others then
  if sqlerrm='Cashier unexpectedly started checklist' then raise; end if;
  if position('checklist.run' in sqlerrm)=0 then raise; end if;
end $$;

-- Sales sees automatic payment sync and completes.
reset role;
update public.profiles
set role_id=(select id from public.roles where code='sales')
where id='68686868-6868-4868-8868-686868686868';
set local role authenticated;
select set_config('request.jwt.claim.sub','68686868-6868-4868-8868-686868686868',true);

select public.checklist_run_refresh(
  (select id from public.checklist_runs where entity_id=(select id from public.sales_orders where note='T6 local sale'))
);

do $$
declare v_payment boolean;
begin
  select i.checked into v_payment
  from public.checklist_run_items i
  join public.checklist_runs r on r.id=i.run_id
  where r.entity_id=(select id from public.sales_orders where note='T6 local sale')
    and i.item_key='payment_confirmed';
  if not coalesce(v_payment,false) then raise exception 'Payment did not sync to checklist'; end if;
end $$;

select public.checklist_run_complete(
  (select id from public.checklist_runs where entity_id=(select id from public.sales_orders where note='T6 local sale'))
);

-- Refund must invalidate a completed checklist automatically.
reset role;
update public.profiles
set role_id=(select id from public.roles where code='cashier')
where id='68686868-6868-4868-8868-686868686868';
set local role authenticated;
select set_config('request.jwt.claim.sub','68686868-6868-4868-8868-686868686868',true);

select public.sale_refund_payment(
  (select id from public.payments where note='T6 local payment'),
  'T6 local refund'
);

reset role;
do $$
declare v_status text; v_payment boolean;
begin
  select status into v_status
  from public.checklist_runs
  where entity_id=(select id from public.sales_orders where note='T6 local sale');

  select i.checked into v_payment
  from public.checklist_run_items i
  join public.checklist_runs r on r.id=i.run_id
  where r.entity_id=(select id from public.sales_orders where note='T6 local sale')
    and i.item_key='payment_confirmed';

  if v_status<>'OPEN' then raise exception 'Refund should reopen checklist, got %',v_status; end if;
  if coalesce(v_payment,true) then raise exception 'Refund should clear payment_confirmed'; end if;
end $$;

-- Manager manages versioned templates.
update public.profiles
set role_id=(select id from public.roles where code='manager')
where id='68686868-6868-4868-8868-686868686868';
set local role authenticated;
select set_config('request.jwt.claim.sub','68686868-6868-4868-8868-686868686868',true);

select public.checklist_template_create('T6_LOCAL_GENERIC','T6 Local Generic','GENERIC','GENERIC','verify');
select public.checklist_template_add_item(
  (select id from public.checklist_templates where template_code='T6_LOCAL_GENERIC' and version=1),
  'required_one','Mục bắt buộc',1,'ALWAYS',false,null
);
select public.checklist_template_add_item(
  (select id from public.checklist_templates where template_code='T6_LOCAL_GENERIC' and version=1),
  'optional_one','Mục tùy chọn',2,'OPTIONAL',false,null
);
select public.checklist_template_activate(
  (select id from public.checklist_templates where template_code='T6_LOCAL_GENERIC' and version=1)
);

-- Technician can run but cannot manage templates.
reset role;
update public.profiles
set role_id=(select id from public.roles where code='technician')
where id='68686868-6868-4868-8868-686868686868';
set local role authenticated;
select set_config('request.jwt.claim.sub','68686868-6868-4868-8868-686868686868',true);

do $$
begin
  perform public.checklist_template_create('T6_DENIED','Denied','GENERIC','GENERIC',null);
  raise exception 'Technician unexpectedly managed templates';
exception when others then
  if sqlerrm='Technician unexpectedly managed templates' then raise; end if;
  if position('checklist.manage' in sqlerrm)=0 then raise; end if;
end $$;

select public.checklist_run_start(
  (select id from public.checklist_templates where template_code='T6_LOCAL_GENERIC' and is_active),
  'GENERIC','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','generic verify'
);
select public.checklist_run_set_item(
  (select i.id from public.checklist_run_items i join public.checklist_runs r on r.id=i.run_id
   where r.entity_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' and i.item_key='required_one'),
  true,'done'
);
select public.checklist_run_complete(
  (select id from public.checklist_runs where entity_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')
);

reset role;

do $$
begin
  if (select status from public.checklist_runs where entity_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')<>'COMPLETED' then
    raise exception 'Generic checklist did not complete';
  end if;
end $$;

select
  16 as sales_template_items,
  (select count(*) from public.checklist_run_items i join public.checklist_runs r on r.id=i.run_id
   where r.entity_id=(select id from public.sales_orders where note='T6 local sale') and i.required) as sales_required_items,
  (select status from public.checklist_runs where entity_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb') as generic_status,
  (select status from public.checklist_runs where entity_id=(select id from public.sales_orders where note='T6 local sale')) as sales_run_after_refund;

do $$ begin
  raise notice 'T6 FINAL CORE CHECKS: PASS';
end $$;

rollback;
