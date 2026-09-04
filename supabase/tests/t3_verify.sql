\set ON_ERROR_STOP on

begin;

-- -----------------------------------------------------------------------------
-- Structural checks
-- -----------------------------------------------------------------------------
do $$
declare
  v_count integer;
  v_secdef boolean;
begin
  select count(*) into v_count
  from information_schema.tables
  where table_schema='public'
    and table_name in ('product_categories','products','inventory_units','inventory_transactions');
  if v_count <> 4 then
    raise exception 'T3 FAIL: expected 4 public inventory tables, got %', v_count;
  end if;

  if not exists (
    select 1 from information_schema.tables
    where table_schema='private' and table_name='inventory_transaction_costs'
  ) then
    raise exception 'T3 FAIL: private.inventory_transaction_costs missing';
  end if;

  if exists (
    select 1
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where (
      (n.nspname='public' and c.relname in ('product_categories','products','inventory_units','inventory_transactions'))
      or (n.nspname='private' and c.relname='inventory_transaction_costs')
    )
    and c.relrowsecurity=false
  ) then
    raise exception 'T3 FAIL: RLS disabled on a T3 table';
  end if;

  select count(*) into v_count
  from pg_policies
  where schemaname='public'
    and tablename in ('product_categories','products','inventory_units','inventory_transactions');
  if v_count <> 8 then
    raise exception 'T3 FAIL: expected 8 public T3 policies, got %', v_count;
  end if;

  select count(*) into v_count
  from pg_policies
  where schemaname='private'
    and tablename='inventory_transaction_costs'
    and policyname='inventory_transaction_costs_select';
  if v_count <> 1 then
    raise exception 'T3 FAIL: private cost RLS policy missing';
  end if;

  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='inventory_transactions_view'
      and c.relkind='v' and c.reloptions @> array['security_invoker=true']
  ) then
    raise exception 'T3 FAIL: inventory_transactions_view is not security_invoker';
  end if;

  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='product_inventory_summary'
      and c.relkind='v' and c.reloptions @> array['security_invoker=true']
  ) then
    raise exception 'T3 FAIL: product_inventory_summary is not security_invoker';
  end if;

  if to_regprocedure('public.inventory_receive(uuid,numeric,numeric,text[],text,text,uuid,text)') is null
     or to_regprocedure('public.inventory_issue(uuid,numeric,uuid[],text,text,uuid)') is null
     or to_regprocedure('public.inventory_adjust(uuid,numeric,text,numeric,text[],uuid[],text)') is null then
    raise exception 'T3 FAIL: one or more public inventory RPCs missing';
  end if;

  select p.prosecdef into v_secdef
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='inventory_receive';
  if v_secdef is distinct from false then
    raise exception 'T3 FAIL: public inventory_receive must be SECURITY INVOKER';
  end if;

  if to_regprocedure('private.inventory_receive_impl(uuid,numeric,numeric,text[],text,text,uuid,text)') is null
     or to_regprocedure('private.inventory_issue_impl(uuid,numeric,uuid[],text,text,uuid)') is null
     or to_regprocedure('private.inventory_adjust_impl(uuid,numeric,text,numeric,text[],uuid[],text)') is null then
    raise exception 'T3 FAIL: private inventory implementations missing';
  end if;

  if not has_table_privilege('authenticated','public.products','SELECT')
     or not has_table_privilege('authenticated','public.products','INSERT')
     or not has_table_privilege('authenticated','public.products','UPDATE')
     or has_table_privilege('authenticated','public.products','DELETE') then
    raise exception 'T3 FAIL: products authenticated grants invalid';
  end if;

  if not has_table_privilege('authenticated','public.inventory_units','SELECT')
     or has_table_privilege('authenticated','public.inventory_units','INSERT')
     or has_table_privilege('authenticated','public.inventory_units','UPDATE')
     or has_table_privilege('authenticated','public.inventory_units','DELETE') then
    raise exception 'T3 FAIL: inventory_units direct-write grants invalid';
  end if;

  if not has_table_privilege('authenticated','public.inventory_transactions','SELECT')
     or has_table_privilege('authenticated','public.inventory_transactions','INSERT')
     or has_table_privilege('authenticated','public.inventory_transactions','UPDATE')
     or has_table_privilege('authenticated','public.inventory_transactions','DELETE') then
    raise exception 'T3 FAIL: inventory_transactions direct-write grants invalid';
  end if;

  if has_table_privilege('anon','public.products','SELECT')
     or has_table_privilege('anon','public.inventory_units','SELECT')
     or has_table_privilege('anon','public.inventory_transactions','SELECT') then
    raise exception 'T3 FAIL: anon can access T3 inventory objects';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='products'
      and column_name in ('cost_price','purchase_cost','unit_cost')
  ) then
    raise exception 'T3 FAIL: sensitive cost column leaked into public.products';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='inventory_transactions'
      and column_name='unit_cost'
  ) then
    raise exception 'T3 FAIL: unit_cost leaked into public.inventory_transactions';
  end if;

  -- T3 consolidates the two T2 Settings SELECT policies into one equivalent policy.
  select count(*) into v_count
  from pg_policies
  where schemaname='public' and tablename='settings'
    and roles @> array['authenticated']::name[] and cmd='SELECT';
  if v_count <> 1 then
    raise exception 'T3 FAIL: settings should have exactly one authenticated SELECT policy, got %', v_count;
  end if;
end
$$;

-- -----------------------------------------------------------------------------
-- Create an isolated test Auth user. Everything is rolled back at the end.
-- -----------------------------------------------------------------------------
insert into auth.users(id,email,raw_user_meta_data)
values(
  '33333333-3333-4333-8333-333333333333',
  't3-local-verify@example.invalid',
  '{}'::jsonb
);

update public.profiles
set role_id=(select id from public.roles where code='admin'),
    is_active=true,
    full_name='T3 Verify User'
where id='33333333-3333-4333-8333-333333333333';

set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);

-- -----------------------------------------------------------------------------
-- Catalog + bulk stock
-- -----------------------------------------------------------------------------
insert into public.product_categories(name,description,sort_order)
values('  T3 VERIFY CATEGORY  ','  T3 verify category  ',1);

insert into public.products(
  sku,name,category_id,brand,model,barcode,unit,sale_price,min_stock,
  track_serial,warranty_months
)
select
  ' t3-bulk ','  T3 Bulk Product  ',id,' TestBrand ',' BulkModel ','T3-BARCODE-BULK',
  ' cái ',150000,3,false,12
from public.product_categories
where name='T3 VERIFY CATEGORY';

select public.inventory_receive(
  id,10,100000,null,'T3 receive','VERIFY',null,'Kho 1'
)
from public.products where sku='T3-BULK';

select public.inventory_issue(
  id,2,null,'T3 issue','VERIFY',null
)
from public.products where sku='T3-BULK';

select public.inventory_adjust(
  id,-1,'T3 adjustment out',null,null,null,null
)
from public.products where sku='T3-BULK';

-- -----------------------------------------------------------------------------
-- Serialized stock
-- -----------------------------------------------------------------------------
insert into public.products(
  sku,name,unit,sale_price,min_stock,track_serial,warranty_months
)
values('T3-SERIAL','T3 Serialized Product','cái',2500000,1,true,24);

select public.inventory_receive(
  id,2,2000000,array[' T3-SN-A ','T3-SN-B'],'T3 serialized receive','VERIFY',null,'Kho Serial'
)
from public.products where sku='T3-SERIAL';

select public.inventory_issue(
  p.id,1,array[u.id],'T3 serialized issue','VERIFY',null
)
from public.products p
join public.inventory_units u
  on u.product_id=p.id and u.serial_number='T3-SN-A'
where p.sku='T3-SERIAL';

-- -----------------------------------------------------------------------------
-- Core data checks
-- -----------------------------------------------------------------------------
do $$
declare
  v_bulk public.product_inventory_summary%rowtype;
  v_serial public.product_inventory_summary%rowtype;
  v_count integer;
  v_product_id uuid;
begin
  select * into strict v_bulk
  from public.product_inventory_summary where sku='T3-BULK';
  select * into strict v_serial
  from public.product_inventory_summary where sku='T3-SERIAL';

  if v_bulk.stock_qty <> 7 then
    raise exception 'T3 FAIL: bulk stock expected 7, got %', v_bulk.stock_qty;
  end if;
  if v_bulk.last_unit_cost <> 100000 then
    raise exception 'T3 FAIL: bulk last cost expected 100000, got %', v_bulk.last_unit_cost;
  end if;
  if v_bulk.low_stock is not false then
    raise exception 'T3 FAIL: bulk low_stock should be false';
  end if;

  if v_serial.stock_qty <> 1 then
    raise exception 'T3 FAIL: serialized stock expected 1, got %', v_serial.stock_qty;
  end if;
  if v_serial.last_unit_cost <> 2000000 then
    raise exception 'T3 FAIL: serial last cost expected 2000000, got %', v_serial.last_unit_cost;
  end if;
  if v_serial.low_stock is not true then
    raise exception 'T3 FAIL: serialized low_stock should be true at min_stock=1';
  end if;

  select count(*) into v_count
  from public.inventory_units u
  join public.products p on p.id=u.product_id
  where p.sku='T3-SERIAL' and u.status='IN_STOCK' and u.issued_at is null;
  if v_count <> 1 then
    raise exception 'T3 FAIL: expected 1 serialized unit IN_STOCK, got %', v_count;
  end if;

  select count(*) into v_count
  from public.inventory_units u
  join public.products p on p.id=u.product_id
  where p.sku='T3-SERIAL' and u.status='OUT' and u.issued_at is not null;
  if v_count <> 1 then
    raise exception 'T3 FAIL: expected 1 serialized unit OUT, got %', v_count;
  end if;

  select id into strict v_product_id from public.products where sku='T3-BULK';

  begin
    perform public.inventory_issue(v_product_id,100,null,'must fail',null,null);
    raise exception 'T3 FAIL: insufficient stock issue was not blocked';
  exception when others then
    if position('Insufficient stock' in sqlerrm)=0 then raise; end if;
  end;

  begin
    update public.products set sku='T3-BULK-CHANGED' where id=v_product_id;
    raise exception 'T3 FAIL: SKU mutation was not blocked';
  exception when others then
    if sqlerrm <> 'sku is immutable' then raise; end if;
  end;

  begin
    update public.products set track_serial=true where id=v_product_id;
    raise exception 'T3 FAIL: track_serial change after inventory was not blocked';
  exception when others then
    if sqlerrm <> 'track_serial cannot change after inventory exists' then raise; end if;
  end;

  select count(*) into v_count
  from public.audit_logs
  where table_name='products'
    and new_data->>'sku' in ('T3-BULK','T3-SERIAL')
    and action='INSERT';
  if v_count <> 2 then
    raise exception 'T3 FAIL: product audit INSERT rows expected 2, got %', v_count;
  end if;
end
$$;

-- -----------------------------------------------------------------------------
-- Role matrix and DB-level cost masking
-- -----------------------------------------------------------------------------
reset role;
create temporary table t3_role_results(
  role_code text primary key,
  product_view boolean,
  inventory_view boolean,
  can_receive boolean,
  can_issue boolean,
  can_adjust boolean,
  can_view_cost boolean,
  visible_stock numeric,
  visible_cost numeric
) on commit drop;
grant select,insert on t3_role_results to authenticated;

update public.profiles
set role_id=(select id from public.roles where code='manager')
where id='33333333-3333-4333-8333-333333333333';
set local role authenticated;
insert into t3_role_results
select 'manager',
  private.has_permission('product.view'),
  private.has_permission('inventory.view'),
  private.has_permission('inventory.receive'),
  private.has_permission('inventory.issue'),
  private.has_permission('inventory.adjust'),
  private.has_permission('cost_price.view'),
  stock_qty,last_unit_cost
from public.product_inventory_summary where sku='T3-BULK';

reset role;
update public.profiles
set role_id=(select id from public.roles where code='sales')
where id='33333333-3333-4333-8333-333333333333';
set local role authenticated;
insert into t3_role_results
select 'sales',
  private.has_permission('product.view'),
  private.has_permission('inventory.view'),
  private.has_permission('inventory.receive'),
  private.has_permission('inventory.issue'),
  private.has_permission('inventory.adjust'),
  private.has_permission('cost_price.view'),
  stock_qty,last_unit_cost
from public.product_inventory_summary where sku='T3-BULK';

-- Sales must still be able to read the T2 device type setting after policy consolidation.
do $$
begin
  if not exists (select 1 from public.settings where key='crm.device_types') then
    raise exception 'T3 FAIL: sales/device.view lost crm.device_types access';
  end if;

  begin
    perform public.inventory_receive(
      (select product_id from public.product_inventory_summary where sku='T3-BULK'),
      1,null,null,'must fail',null,null,null
    );
    raise exception 'T3 FAIL: sales inventory_receive was not blocked';
  exception when others then
    if position('Missing permission inventory.receive' in sqlerrm)=0 then raise; end if;
  end;

  begin
    insert into public.inventory_transactions(product_id,transaction_type,quantity)
    select product_id,'RECEIVE',1 from public.product_inventory_summary where sku='T3-BULK';
    raise exception 'T3 FAIL: direct ledger INSERT was not blocked';
  exception when insufficient_privilege then
    null;
  end;
end
$$;

reset role;
update public.profiles
set role_id=(select id from public.roles where code='technician')
where id='33333333-3333-4333-8333-333333333333';
set local role authenticated;
insert into t3_role_results
select 'technician',
  private.has_permission('product.view'),
  private.has_permission('inventory.view'),
  private.has_permission('inventory.receive'),
  private.has_permission('inventory.issue'),
  private.has_permission('inventory.adjust'),
  private.has_permission('cost_price.view'),
  stock_qty,last_unit_cost
from public.product_inventory_summary where sku='T3-BULK';

reset role;
update public.profiles
set role_id=(select id from public.roles where code='cashier')
where id='33333333-3333-4333-8333-333333333333';
set local role authenticated;
insert into t3_role_results
select 'cashier',
  private.has_permission('product.view'),
  private.has_permission('inventory.view'),
  private.has_permission('inventory.receive'),
  private.has_permission('inventory.issue'),
  private.has_permission('inventory.adjust'),
  private.has_permission('cost_price.view'),
  stock_qty,last_unit_cost
from public.product_inventory_summary where sku='T3-BULK';

reset role;
do $$
declare
  m t3_role_results%rowtype;
  s t3_role_results%rowtype;
  t t3_role_results%rowtype;
  c t3_role_results%rowtype;
begin
  select * into strict m from t3_role_results where role_code='manager';
  select * into strict s from t3_role_results where role_code='sales';
  select * into strict t from t3_role_results where role_code='technician';
  select * into strict c from t3_role_results where role_code='cashier';

  if not (m.can_receive and m.can_issue and m.can_adjust and m.can_view_cost)
     or m.visible_cost <> 100000 then
    raise exception 'T3 FAIL: manager inventory/cost matrix invalid';
  end if;

  if s.can_receive or s.can_issue or s.can_adjust or s.can_view_cost
     or s.visible_cost is not null or s.visible_stock <> 7 then
    raise exception 'T3 FAIL: sales inventory/cost matrix invalid';
  end if;

  if t.can_receive or not t.can_issue or t.can_adjust or t.can_view_cost
     or t.visible_cost is not null or t.visible_stock <> 7 then
    raise exception 'T3 FAIL: technician inventory/cost matrix invalid';
  end if;

  if c.can_receive or c.can_issue or c.can_adjust or c.can_view_cost
     or c.visible_cost is not null or c.visible_stock <> 7 then
    raise exception 'T3 FAIL: cashier inventory/cost matrix invalid';
  end if;
end
$$;

-- No-profile UID must see no catalog or inventory rows.
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
do $$
begin
  if (select count(*) from public.products where sku like 'T3-%') <> 0 then
    raise exception 'T3 FAIL: no-profile UID can read products';
  end if;
  if (select count(*) from public.product_inventory_summary where sku like 'T3-%') <> 0 then
    raise exception 'T3 FAIL: no-profile UID can read inventory summary';
  end if;
end
$$;

reset role;
select
  'T3 FINAL CORE CHECKS: PASS' as result,
  (select stock_qty from public.product_inventory_summary where sku='T3-BULK') as bulk_stock,
  (select stock_qty from public.product_inventory_summary where sku='T3-SERIAL') as serial_stock,
  (select jsonb_agg(to_jsonb(r) order by role_code) from t3_role_results r) as role_matrix;

rollback;
