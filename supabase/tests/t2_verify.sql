\set ON_ERROR_STOP on

begin;

do $$
declare
  v_count integer;
  v_default text;
  v_types jsonb;
begin
  select count(*) into v_count
  from information_schema.tables
  where table_schema='public'
    and table_name in ('customers','customer_devices','customer_notes');
  if v_count <> 3 then
    raise exception 'T2 FAIL: expected 3 CRM tables, got %', v_count;
  end if;

  if exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relname in ('customers','customer_devices','customer_notes')
      and c.relrowsecurity=false
  ) then
    raise exception 'T2 FAIL: RLS disabled on one or more CRM tables';
  end if;

  select count(*) into v_count
  from pg_policies
  where schemaname='public'
    and tablename in ('customers','customer_devices','customer_notes');
  if v_count <> 9 then
    raise exception 'T2 FAIL: expected 9 CRM policies, got %', v_count;
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public'
      and tablename='settings'
      and policyname='settings_select'
  ) then
    raise exception 'T2 FAIL: effective settings_select policy missing';
  end if;

  -- T3 consolidates the T2 device-types SELECT policy into settings_select.
  -- Verify behavior rather than requiring the old policy name to remain forever.
  if not exists (
    select 1 from public.settings
    where key='crm.device_types'
  ) then
    raise exception 'T2 FAIL: crm.device_types setting missing';
  end if;

  if not has_table_privilege('authenticated','public.customers','SELECT')
     or not has_table_privilege('authenticated','public.customers','INSERT')
     or not has_table_privilege('authenticated','public.customers','UPDATE')
     or has_table_privilege('authenticated','public.customers','DELETE') then
    raise exception 'T2 FAIL: customers authenticated grants invalid';
  end if;

  if has_table_privilege('anon','public.customers','SELECT')
     or has_table_privilege('anon','public.customer_devices','SELECT')
     or has_table_privilege('anon','public.customer_notes','SELECT') then
    raise exception 'T2 FAIL: anon can access CRM tables';
  end if;

  select column_default into v_default
  from information_schema.columns
  where table_schema='public' and table_name='customers' and column_name='customer_code';
  if v_default is null then
    raise exception 'T2 FAIL: customer_code default missing';
  end if;

  select column_default into v_default
  from information_schema.columns
  where table_schema='public' and table_name='customer_devices' and column_name='device_code';
  if v_default is null then
    raise exception 'T2 FAIL: device_code default missing';
  end if;

  select value into v_types from public.settings where key='crm.device_types';
  if v_types is null or jsonb_typeof(v_types) <> 'array' or jsonb_array_length(v_types) <> 12 then
    raise exception 'T2 FAIL: crm.device_types must contain 12 defaults';
  end if;

  if to_regprocedure('private.fn_t2_customer_before_write()') is null
     or to_regprocedure('private.fn_t2_device_before_write()') is null
     or to_regprocedure('private.fn_t2_note_before_write()') is null then
    raise exception 'T2 FAIL: one or more private T2 trigger functions missing';
  end if;
end
$$;

insert into public.customers(full_name, phone, email, address)
values ('  T2 VERIFY CUSTOMER  ', '+84 912.345.678', 'VERIFY@EXAMPLE.COM', '  Thanh Hoa  ');

insert into public.customer_devices(customer_id, device_type, brand, model, serial_number)
select id, 'Laptop', ' Dell ', ' Latitude 7480 ', ' T2-VERIFY-SN '
from public.customers
where full_name='T2 VERIFY CUSTOMER';

insert into public.customer_notes(customer_id, note_type, content, is_pinned)
select id, 'IMPORTANT', '  T2 verify note  ', true
from public.customers
where full_name='T2 VERIFY CUSTOMER';

update public.customers
set address='Nhu Thanh, Thanh Hoa'
where full_name='T2 VERIFY CUSTOMER';

update public.customer_devices
set model='Latitude 7480 Updated'
where serial_number='T2-VERIFY-SN';

update public.customer_notes
set content='T2 verify note updated'
where content='T2 verify note';

do $$
declare
  c public.customers%rowtype;
  d public.customer_devices%rowtype;
  n public.customer_notes%rowtype;
  v_count integer;
begin
  select * into strict c from public.customers where full_name='T2 VERIFY CUSTOMER';
  select * into strict d from public.customer_devices where customer_id=c.id;
  select * into strict n from public.customer_notes where customer_id=c.id;

  if c.customer_code !~ '^CUS-[0-9]{6}$' then
    raise exception 'T2 FAIL: invalid customer code %', c.customer_code;
  end if;
  if c.phone_normalized <> '0912345678' then
    raise exception 'T2 FAIL: phone normalization got %', c.phone_normalized;
  end if;
  if c.email <> 'verify@example.com' then
    raise exception 'T2 FAIL: email normalization got %', c.email;
  end if;
  if c.address <> 'Nhu Thanh, Thanh Hoa' then
    raise exception 'T2 FAIL: customer update failed';
  end if;

  if d.device_code !~ '^DEV-[0-9]{6}$' then
    raise exception 'T2 FAIL: invalid device code %', d.device_code;
  end if;
  if d.brand <> 'Dell' or d.serial_number <> 'T2-VERIFY-SN' then
    raise exception 'T2 FAIL: device trim/normalization failed';
  end if;
  if d.model <> 'Latitude 7480 Updated' then
    raise exception 'T2 FAIL: device update failed';
  end if;

  if n.content <> 'T2 verify note updated' or n.is_pinned is not true then
    raise exception 'T2 FAIL: note insert/update failed';
  end if;

  begin
    update public.customers set customer_code='CUS-999999' where id=c.id;
    raise exception 'T2 FAIL: customer_code mutation was not blocked';
  exception when others then
    if sqlerrm <> 'customer_code is immutable' then
      raise;
    end if;
  end;

  begin
    update public.customer_devices set device_code='DEV-999999' where id=d.id;
    raise exception 'T2 FAIL: device_code mutation was not blocked';
  exception when others then
    if sqlerrm <> 'device_code is immutable' then
      raise;
    end if;
  end;

  select count(*) into v_count
  from public.audit_logs
  where table_name='customers'
    and new_data->>'full_name'='T2 VERIFY CUSTOMER'
    and action in ('INSERT','UPDATE');
  if v_count < 2 then
    raise exception 'T2 FAIL: customer audit rows missing';
  end if;

  select count(*) into v_count
  from public.role_permissions rp
  join public.roles r on r.id=rp.role_id
  join public.permissions p on p.id=rp.permission_id
  where r.code='technician'
    and p.code in ('customer.view','device.view','device.update');
  if v_count <> 3 then
    raise exception 'T2 FAIL: technician baseline permission matrix changed';
  end if;

  if exists (
    select 1
    from public.role_permissions rp
    join public.roles r on r.id=rp.role_id
    join public.permissions p on p.id=rp.permission_id
    where r.code='technician'
      and p.code in ('customer.create','customer.update','device.create')
  ) then
    raise exception 'T2 FAIL: technician has forbidden create/update permissions';
  end if;
end
$$;

select
  'T2 FINAL CORE CHECKS: PASS' as result,
  (select customer_code from public.customers where full_name='T2 VERIFY CUSTOMER') as customer_code,
  (select device_code from public.customer_devices where serial_number='T2-VERIFY-SN') as device_code,
  (select phone_normalized from public.customers where full_name='T2 VERIFY CUSTOMER') as normalized_phone;

rollback;
