-- HomeTechVN T1 FINAL verification
-- Schema state expected after all 3 T1 migrations + seed.

do $$
declare
  v_missing text[];
  v_count integer;
begin
  -- 6 exposed public core tables
  select array_agg(x.table_name)
  into v_missing
  from (
    values
      ('roles'),
      ('permissions'),
      ('role_permissions'),
      ('profiles'),
      ('settings'),
      ('audit_logs')
  ) as x(table_name)
  where not exists (
    select 1
    from information_schema.tables t
    where t.table_schema = 'public'
      and t.table_name = x.table_name
  );

  if v_missing is not null then
    raise exception 'T1 FAIL: missing public tables: %', v_missing;
  end if;

  -- Internal counter table must be private.
  if not exists (
    select 1
    from information_schema.tables
    where table_schema = 'private'
      and table_name = 'sequence_counters'
  ) then
    raise exception 'T1 FAIL: private.sequence_counters missing';
  end if;

  select count(*) into v_count
  from public.roles
  where code in ('admin','manager','sales','technician','cashier');

  if v_count <> 5 then
    raise exception 'T1 FAIL: expected 5 system roles, got %', v_count;
  end if;

  select count(*) into v_count from public.permissions;
  if v_count <> 46 then
    raise exception 'T1 FAIL: expected 46 permissions, got %', v_count;
  end if;

  if exists (
    select 1
    from public.settings
    where is_sensitive = true
      and value is not null
  ) then
    raise exception 'T1 FAIL: sensitive setting contains plaintext value';
  end if;

  if exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where (
      (n.nspname = 'public' and c.relname in (
        'roles','permissions','role_permissions',
        'profiles','settings','audit_logs'
      ))
      or
      (n.nspname = 'private' and c.relname = 'sequence_counters')
    )
    and c.relrowsecurity = false
  ) then
    raise exception 'T1 FAIL: one or more T1 tables have RLS disabled';
  end if;

  if to_regprocedure('public.has_permission(text)') is not null
     or to_regprocedure('public.current_role_code()') is not null
     or to_regprocedure('public.is_admin()') is not null
     or to_regprocedure('public.next_simple_code(text,text,integer)') is not null
     or to_regprocedure('public.next_daily_code(text,text,date,integer)') is not null
  then
    raise exception 'T1 FAIL: obsolete public helper RPC still exists';
  end if;

  if to_regprocedure('private.has_permission(text)') is null
     or to_regprocedure('private.next_simple_code(text,text,integer)') is null
     or to_regprocedure('private.next_daily_code(text,text,date,integer)') is null
  then
    raise exception 'T1 FAIL: private helper functions missing';
  end if;

  if not exists (
    select 1
    from public.role_permissions rp
    join public.roles r on r.id = rp.role_id
    join public.permissions p on p.id = rp.permission_id
    where r.code = 'admin'
      and p.code = 'user.manage'
  ) then
    raise exception 'T1 FAIL: admin missing user.manage';
  end if;

  if exists (
    select 1
    from public.role_permissions rp
    join public.roles r on r.id = rp.role_id
    join public.permissions p on p.id = rp.permission_id
    where r.code = 'sales'
      and p.code in ('cost_price.view','report.profit','user.manage')
  ) then
    raise exception 'T1 FAIL: sales has forbidden permission';
  end if;

  raise notice 'T1 FINAL CORE CHECKS: PASS';
end
$$;

-- Generator test. ROLLBACK prevents test counters consuming real codes.
begin;

select
  private.next_simple_code('customer_test', 'CUS', 6) as simple_code_1,
  private.next_simple_code('customer_test', 'CUS', 6) as simple_code_2,
  private.next_daily_code('repair_test', 'SRV', date '2026-08-29', 4) as daily_code_1,
  private.next_daily_code('repair_test', 'SRV', date '2026-08-29', 4) as daily_code_2;

rollback;

-- Human-readable summary.
select 'roles' as item, count(*)::text as result from public.roles
union all
select 'permissions', count(*)::text from public.permissions
union all
select 'role_permissions', count(*)::text from public.role_permissions
union all
select 'public_core_tables', count(*)::text
from information_schema.tables
where table_schema='public'
  and table_name in (
    'roles','permissions','role_permissions',
    'profiles','settings','audit_logs'
  )
union all
select 'private_counter_table', count(*)::text
from information_schema.tables
where table_schema='private'
  and table_name='sequence_counters';
