begin;

do $$
begin
  if not exists (
    select 1
    from public.settings
    where key = 'demo.t20.hosted'
      and value->>'mode' = 'HOSTED_DEMO'
      and coalesce((value->>'contains_real_customer_data')::boolean, true) = false
  ) then
    raise exception 'T21_DEMO_SAFETY_GATE';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  (
    select p.id::text
    from public.profiles p
    join public.roles r on r.id = p.role_id
    where p.is_active
      and r.code = 'admin'
    order by p.created_at
    limit 1
  ),
  true
);

set local role authenticated;

do $$
declare
  v_customer_id uuid;
  v_device_id uuid;
begin
  insert into public.customers(full_name, customer_type, phone, address, status)
  values ('Khach hang T21 Rollback', 'INDIVIDUAL', '0900000021', 'Dia chi gia lap T21', 'ACTIVE')
  returning id into v_customer_id;

  insert into public.customer_devices(customer_id, device_type, brand, model, serial_number, status)
  values (v_customer_id, 'Laptop', 'Demo', 'T21', 'T21-ROLLBACK-SERIAL', 'ACTIVE')
  returning id into v_device_id;

  if not exists (
    select 1 from public.customers
    where id = v_customer_id and customer_code is not null
  ) then
    raise exception 'T21 customer quick-create contract failed';
  end if;

  if not exists (
    select 1 from public.customer_devices
    where id = v_device_id
      and customer_id = v_customer_id
      and device_code is not null
  ) then
    raise exception 'T21 device quick-create contract failed';
  end if;

  raise notice 'T21 HOSTED QUICK CUSTOMER/DEVICE ACCEPTANCE: PASS';
end;
$$;

reset role;
rollback;

select 'T21 HOSTED FAKE-DATA ROLLBACK: PASS' as result
where not exists (
  select 1 from public.customers where full_name = 'Khach hang T21 Rollback'
);
