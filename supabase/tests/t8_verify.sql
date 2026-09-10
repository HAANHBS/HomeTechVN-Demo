\set ON_ERROR_STOP on
begin;

do $$
declare
  v_tables integer;
  v_bad_columns integer;
  v_direct boolean;
begin
  select count(*) into v_tables
  from information_schema.tables
  where table_schema='public'
    and table_name in ('services','service_schedules','software_products','software_licenses');
  if v_tables<>4 then raise exception 'T8 table count expected 4, got %',v_tables; end if;

  select count(*) into v_bad_columns
  from information_schema.columns
  where table_schema='public' and table_name='software_licenses'
    and lower(column_name) in ('license_key','product_key','password','secret_value','secret_key');
  if v_bad_columns<>0 then raise exception 'Plaintext secret column exists in software_licenses'; end if;

  select has_table_privilege('authenticated','public.service_schedules','INSERT') into v_direct;
  if v_direct then raise exception 'authenticated must not INSERT service_schedules directly'; end if;
  select has_table_privilege('authenticated','public.service_schedules','UPDATE') into v_direct;
  if v_direct then raise exception 'authenticated must not UPDATE service_schedules directly'; end if;
  select has_table_privilege('authenticated','public.software_licenses','INSERT') into v_direct;
  if v_direct then raise exception 'authenticated must not INSERT software_licenses directly'; end if;
  select has_table_privilege('authenticated','public.software_licenses','UPDATE') into v_direct;
  if v_direct then raise exception 'authenticated must not UPDATE software_licenses directly'; end if;
end $$;

insert into auth.users(id,email,raw_user_meta_data)
values('88888888-8888-4888-8888-888888888888','t8-local-verify@example.invalid','{}'::jsonb);

update public.profiles
set role_id=(select id from public.roles where code='admin'),
    is_active=true,
    full_name='T8 Local Verify'
where id='88888888-8888-4888-8888-888888888888';

set local role authenticated;
select set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',true);

insert into public.customers(full_name,phone,address)
values('T8 LOCAL CUSTOMER','0988777666','Thanh Hoa');

insert into public.customer_devices(customer_id,device_type,brand,model,serial_number,status)
select id,'Laptop','Dell','Latitude T8','T8-LOCAL-SERIAL-001','ACTIVE'
from public.customers where full_name='T8 LOCAL CUSTOMER';

select public.service_create(
  'T8 Local Maintenance','MAINTENANCE','T8 local service',
  1,'MONTHS',300000,3
);

select public.software_product_create(
  'M365','Microsoft','T8 Local Microsoft 365','Standard',
  'SUBSCRIPTION',12,'T8 local software'
);

-- Sales owns day-to-day Service/License management.
reset role;
update public.profiles
set role_id=(select id from public.roles where code='sales')
where id='88888888-8888-4888-8888-888888888888';
set local role authenticated;
select set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',true);

select public.service_schedule_create(
  (select id from public.services where name='T8 Local Maintenance'),
  (select id from public.customers where full_name='T8 LOCAL CUSTOMER'),
  (select id from public.customer_devices where serial_number='T8-LOCAL-SERIAL-001'),
  date '2026-08-30',date '2026-08-30',
  1,'MONTHS',300000,date '2027-12-31','T8 local schedule'
);

-- First recurring occurrence and its SERVICE warranty.
select public.service_schedule_complete(
  (select ss.id from public.service_schedules ss
   join public.customers c on c.id=ss.customer_id
   where c.full_name='T8 LOCAL CUSTOMER'),
  'T8 completion 1'
);
select public.warranty_create_service(
  (select ss.id from public.service_schedules ss
   join public.customers c on c.id=ss.customer_id
   where c.full_name='T8 LOCAL CUSTOMER'),
  null,null,'T8 service warranty 1'
);

-- Second occurrence must get a distinct completion id and can get another warranty.
select public.service_schedule_complete(
  (select ss.id from public.service_schedules ss
   join public.customers c on c.id=ss.customer_id
   where c.full_name='T8 LOCAL CUSTOMER'),
  'T8 completion 2'
);
select public.warranty_create_service(
  (select ss.id from public.service_schedules ss
   join public.customers c on c.id=ss.customer_id
   where c.full_name='T8 LOCAL CUSTOMER'),
  null,null,'T8 service warranty 2'
);

-- Plaintext product/license key is rejected.
do $$
begin
  perform public.software_license_create(
    (select id from public.software_products where name='T8 Local Microsoft 365'),
    (select id from public.customers where full_name='T8 LOCAL CUSTOMER'),
    null,date '2026-08-30',null,1,
    'user@example.com','AAAAA-BBBBB-CCCCC-DDDDD',
    true,2500000,'bad plaintext secret'
  );
  raise exception 'Plaintext secret unexpectedly accepted';
exception when others then
  if sqlerrm='Plaintext secret unexpectedly accepted' then raise; end if;
  if position('external secret reference URI' in sqlerrm)=0 then raise; end if;
end $$;

select public.software_license_create(
  (select id from public.software_products where name='T8 Local Microsoft 365'),
  (select id from public.customers where full_name='T8 LOCAL CUSTOMER'),
  (select id from public.customer_devices where serial_number='T8-LOCAL-SERIAL-001'),
  date '2026-08-30',null,3,
  'user@example.com','vault://hometechvn/licenses/t8-local-m365',
  true,2500000,'T8 local license'
);

do $$
declare v_code text; v_end date;
begin
  select license_code,end_date into v_code,v_end
  from public.software_licenses where note='T8 local license';
  if v_code !~ '^LIC-[0-9]{6}$' then raise exception 'Invalid license code %',v_code; end if;
  if v_end<>date '2027-08-29' then raise exception 'Initial end date expected 2027-08-29, got %',v_end; end if;
end $$;

select public.software_license_renew(
  (select id from public.software_licenses where note='T8 local license'),
  12,2600000,'T8 renewed'
);
select public.software_license_set_status(
  (select id from public.software_licenses where note='T8 renewed'),
  'SUSPENDED','T8 suspend'
);
select public.software_license_set_status(
  (select id from public.software_licenses where note='T8 renewed'),
  'ACTIVE',null
);

-- Technician has read-only access.
reset role;
update public.profiles
set role_id=(select id from public.roles where code='technician')
where id='88888888-8888-4888-8888-888888888888';
set local role authenticated;
select set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',true);

do $$
declare v_services integer; v_licenses integer;
begin
  select count(*) into v_services from public.services;
  select count(*) into v_licenses from public.software_licenses;
  if v_services<1 or v_licenses<1 then raise exception 'Technician read access failed'; end if;
end $$;

do $$
begin
  perform public.service_create('T8 Denied Service','OTHER',null,1,'MONTHS',0,0);
  raise exception 'Technician unexpectedly managed service';
exception when others then
  if sqlerrm='Technician unexpectedly managed service' then raise; end if;
  if position('service.manage' in sqlerrm)=0 then raise; end if;
end $$;

do $$
begin
  perform public.software_license_renew(
    (select id from public.software_licenses where note='T8 renewed'),
    12,null,null
  );
  raise exception 'Technician unexpectedly managed license';
exception when others then
  if sqlerrm='Technician unexpectedly managed license' then raise; end if;
  if position('license.manage' in sqlerrm)=0 then raise; end if;
end $$;

-- Cashier has no Service/License view or manage permission.
reset role;
update public.profiles
set role_id=(select id from public.roles where code='cashier')
where id='88888888-8888-4888-8888-888888888888';
set local role authenticated;
select set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',true);

do $$
declare v_services integer; v_schedules integer; v_products integer; v_licenses integer;
begin
  select count(*) into v_services from public.services;
  select count(*) into v_schedules from public.service_schedules;
  select count(*) into v_products from public.software_products;
  select count(*) into v_licenses from public.software_licenses;
  if v_services<>0 or v_schedules<>0 or v_products<>0 or v_licenses<>0 then
    raise exception 'Cashier unexpectedly sees T8 data';
  end if;
end $$;

do $$
begin
  perform public.software_product_create('OTHER','','T8 Denied Software',null,'ONE_TIME',null,null);
  raise exception 'Cashier unexpectedly managed software';
exception when others then
  if sqlerrm='Cashier unexpectedly managed software' then raise; end if;
  if position('license.manage' in sqlerrm)=0 then raise; end if;
end $$;

-- Manager can close workflows; PAUSED schedule cannot complete.
reset role;
update public.profiles
set role_id=(select id from public.roles where code='manager')
where id='88888888-8888-4888-8888-888888888888';
set local role authenticated;
select set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',true);

select public.software_license_set_status(
  (select id from public.software_licenses where note='T8 renewed'),
  'CANCELLED','T8 cancel license'
);

select public.service_schedule_set_status(
  (select ss.id from public.service_schedules ss
   join public.customers c on c.id=ss.customer_id
   where c.full_name='T8 LOCAL CUSTOMER'),
  'PAUSED','T8 pause'
);

do $$
begin
  perform public.service_schedule_complete(
    (select ss.id from public.service_schedules ss
     join public.customers c on c.id=ss.customer_id
     where c.full_name='T8 LOCAL CUSTOMER'),
    null
  );
  raise exception 'Paused schedule unexpectedly completed';
exception when others then
  if sqlerrm='Paused schedule unexpectedly completed' then raise; end if;
  if position('Only ACTIVE' in sqlerrm)=0 then raise; end if;
end $$;

reset role;

do $$
declare
  v_schedule public.service_schedules%rowtype;
  v_license public.software_licenses%rowtype;
  v_warranty_count integer;
  v_completion_ids integer;
  v_expected_renewed_end date;
  v_direct boolean;
begin
  select ss.* into v_schedule
  from public.service_schedules ss
  join public.customers c on c.id=ss.customer_id
  where c.full_name='T8 LOCAL CUSTOMER';

  if v_schedule.completion_count<>2 then
    raise exception 'Completion count expected 2, got %',v_schedule.completion_count;
  end if;
  if v_schedule.next_due_date<>date '2026-10-30' then
    raise exception 'Next due expected 2026-10-30, got %',v_schedule.next_due_date;
  end if;
  if v_schedule.status<>'PAUSED' then raise exception 'Schedule should be PAUSED'; end if;

  select count(*),count(distinct source_item_id)
  into v_warranty_count,v_completion_ids
  from public.warranties
  where source_type='SERVICE' and source_id=v_schedule.id;
  if v_warranty_count<>2 or v_completion_ids<>2 then
    raise exception 'Expected 2 SERVICE warranties with distinct completion ids';
  end if;

  select * into v_license
  from public.software_licenses
  where cancelled_reason='T8 cancel license';

  if v_license.license_code !~ '^LIC-[0-9]{6}$' then raise exception 'Bad license code'; end if;
  if v_license.status<>'CANCELLED' then raise exception 'License should be CANCELLED'; end if;
  if v_license.secret_ref<>'vault://hometechvn/licenses/t8-local-m365' then raise exception 'secret_ref mismatch'; end if;

  v_expected_renewed_end :=
    (greatest(date '2027-08-29', current_date) + make_interval(months=>12) - interval '1 day')::date;
  if v_license.end_date<>v_expected_renewed_end then
    raise exception 'Renewed end date expected %, got %',v_expected_renewed_end,v_license.end_date;
  end if;

  select has_table_privilege('authenticated','public.services','INSERT') into v_direct;
  if v_direct then raise exception 'Direct service INSERT unexpectedly granted'; end if;
  select has_table_privilege('authenticated','public.software_licenses','UPDATE') into v_direct;
  if v_direct then raise exception 'Direct license UPDATE unexpectedly granted'; end if;
end $$;

select
  (select completion_count from public.service_schedules ss join public.customers c on c.id=ss.customer_id where c.full_name='T8 LOCAL CUSTOMER') as completion_count,
  (select count(*) from public.warranties w join public.service_schedules s on s.id=w.source_id where w.source_type='SERVICE' and s.customer_id=(select id from public.customers where full_name='T8 LOCAL CUSTOMER')) as service_warranties,
  (select license_code from public.software_licenses where cancelled_reason='T8 cancel license') as license_code,
  (select status from public.software_licenses where cancelled_reason='T8 cancel license') as license_status;

do $$ begin
  raise notice 'T8 FINAL CORE CHECKS: PASS';
end $$;

rollback;
