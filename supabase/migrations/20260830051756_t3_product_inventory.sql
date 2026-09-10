-- HomeTechVN T3 — Product + Inventory
-- T1/T2 migrations are locked. This migration adds T3 objects only.

create table public.product_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint product_categories_name_not_blank check (btrim(name) <> ''),
  constraint product_categories_sort_order_nonnegative check (sort_order >= 0)
);

create unique index uq_product_categories_name_lower
  on public.product_categories (lower(name));
create index idx_product_categories_active_sort
  on public.product_categories (is_active, sort_order, name);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  sku text not null,
  name text not null,
  category_id uuid references public.product_categories(id) on delete restrict,
  brand text,
  model text,
  barcode text,
  unit text not null default 'cái',
  description text,
  sale_price numeric(14,2) not null default 0,
  min_stock numeric(14,3) not null default 0,
  track_serial boolean not null default false,
  warranty_months integer not null default 0,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint products_sku_not_blank check (btrim(sku) <> ''),
  constraint products_name_not_blank check (btrim(name) <> ''),
  constraint products_unit_not_blank check (btrim(unit) <> ''),
  constraint products_sale_price_nonnegative check (sale_price >= 0),
  constraint products_min_stock_nonnegative check (min_stock >= 0),
  constraint products_warranty_months_nonnegative check (warranty_months >= 0)
);

create unique index uq_products_sku_lower on public.products (lower(sku));
create unique index uq_products_barcode on public.products (barcode) where barcode is not null;
create index idx_products_category on public.products (category_id);
create index idx_products_name_lower on public.products (lower(name) text_pattern_ops);
create index idx_products_brand_model_lower on public.products (lower(brand), lower(model));
create index idx_products_active on public.products (is_active);

create table public.inventory_units (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  serial_number text not null,
  asset_tag text,
  status text not null default 'IN_STOCK'
    check (status in ('IN_STOCK','OUT')),
  location text,
  received_at timestamptz not null default now(),
  issued_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint inventory_units_serial_not_blank check (btrim(serial_number) <> ''),
  constraint inventory_units_serial_length check (char_length(serial_number) <= 200),
  constraint inventory_units_out_has_issued_at check (
    (status = 'IN_STOCK' and issued_at is null)
    or (status = 'OUT' and issued_at is not null)
  )
);

create unique index uq_inventory_units_product_serial_lower
  on public.inventory_units (product_id, lower(serial_number));
create index idx_inventory_units_serial_lower on public.inventory_units (lower(serial_number));
create index idx_inventory_units_product_status on public.inventory_units (product_id, status);
create index idx_inventory_units_asset_tag on public.inventory_units (asset_tag) where asset_tag is not null;

create table public.inventory_transactions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  inventory_unit_id uuid references public.inventory_units(id) on delete restrict,
  transaction_type text not null
    check (transaction_type in ('RECEIVE','ISSUE','ADJUST_IN','ADJUST_OUT','RETURN_IN','RETURN_OUT')),
  quantity numeric(14,3) not null,
  reference_type text,
  reference_id uuid,
  note text,
  occurred_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint inventory_transactions_quantity_positive check (quantity > 0),
  constraint inventory_transactions_reference_type_length check (
    reference_type is null or char_length(reference_type) <= 40
  )
);

create index idx_inventory_transactions_product_occurred
  on public.inventory_transactions (product_id, occurred_at desc);
create index idx_inventory_transactions_unit_occurred
  on public.inventory_transactions (inventory_unit_id, occurred_at desc)
  where inventory_unit_id is not null;
create index idx_inventory_transactions_reference
  on public.inventory_transactions (reference_type, reference_id)
  where reference_id is not null;
create index idx_inventory_transactions_type_occurred
  on public.inventory_transactions (transaction_type, occurred_at desc);

-- Cost data is intentionally separated from public inventory data.
-- Sales/Technician/Cashier must not be able to read purchase cost.
create table private.inventory_transaction_costs (
  transaction_id uuid primary key references public.inventory_transactions(id) on delete restrict,
  unit_cost numeric(14,2) not null,
  created_at timestamptz not null default now(),
  constraint inventory_transaction_costs_nonnegative check (unit_cost >= 0)
);

create index idx_inventory_transaction_costs_created_at
  on private.inventory_transaction_costs (created_at desc);

alter table private.inventory_transaction_costs enable row level security;

create policy inventory_transaction_costs_select
on private.inventory_transaction_costs for select
to authenticated
using ((select private.has_permission('cost_price.view')));

-- Catalog normalization / audit fields.
create or replace function private.fn_t3_category_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  new.name := btrim(new.name);
  new.description := nullif(btrim(new.description), '');

  if tg_op = 'INSERT' then
    if v_uid is not null then
      new.created_by := v_uid;
      new.updated_by := v_uid;
    end if;
  else
    new.created_by := old.created_by;
    if v_uid is not null then
      new.updated_by := v_uid;
    end if;
  end if;

  return new;
end;
$$;

create or replace function private.fn_t3_product_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_has_inventory boolean;
begin
  new.sku := upper(btrim(new.sku));
  new.name := btrim(new.name);
  new.brand := nullif(btrim(new.brand), '');
  new.model := nullif(btrim(new.model), '');
  new.barcode := nullif(btrim(new.barcode), '');
  new.unit := btrim(new.unit);
  new.description := nullif(btrim(new.description), '');

  if tg_op = 'INSERT' then
    if v_uid is not null then
      new.created_by := v_uid;
      new.updated_by := v_uid;
    end if;
  else
    if new.sku is distinct from old.sku then
      raise exception 'sku is immutable';
    end if;

    if new.track_serial is distinct from old.track_serial then
      select exists (
        select 1 from public.inventory_transactions t
        where t.product_id = old.id
        limit 1
      ) or exists (
        select 1 from public.inventory_units u
        where u.product_id = old.id
        limit 1
      ) into v_has_inventory;

      if v_has_inventory then
        raise exception 'track_serial cannot change after inventory exists';
      end if;
    end if;

    new.created_by := old.created_by;
    if v_uid is not null then
      new.updated_by := v_uid;
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.fn_t3_category_before_write() from public, anon, authenticated;
revoke all on function private.fn_t3_product_before_write() from public, anon, authenticated;

create trigger trg_product_categories_before_write
before insert or update on public.product_categories
for each row execute function private.fn_t3_category_before_write();

create trigger trg_products_before_write
before insert or update on public.products
for each row execute function private.fn_t3_product_before_write();

create trigger trg_product_categories_updated_at
before update on public.product_categories
for each row execute function public.fn_set_updated_at();

create trigger trg_products_updated_at
before update on public.products
for each row execute function public.fn_set_updated_at();

create trigger trg_product_categories_audit
after insert or update or delete on public.product_categories
for each row execute function public.fn_audit_row();

create trigger trg_products_audit
after insert or update or delete on public.products
for each row execute function public.fn_audit_row();

create trigger trg_inventory_units_audit
after insert or update or delete on public.inventory_units
for each row execute function public.fn_audit_row();

-- Private inventory operation implementations. These are SECURITY DEFINER by design,
-- live outside the exposed schema, bind authorization to auth.uid(), and validate
-- permissions before writing any inventory ledger row.
create or replace function private.inventory_receive_impl(
  p_product_id uuid,
  p_quantity numeric,
  p_unit_cost numeric default null,
  p_serial_numbers text[] default null,
  p_note text default null,
  p_reference_type text default null,
  p_reference_id uuid default null,
  p_location text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_product public.products%rowtype;
  v_serial text;
  v_unit_id uuid;
  v_tx_id uuid;
  v_tx_ids uuid[] := array[]::uuid[];
  v_unit_ids uuid[] := array[]::uuid[];
  v_serial_count integer := coalesce(array_length(p_serial_numbers, 1), 0);
  v_distinct_count integer;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;
  if not private.has_permission('inventory.receive') then
    raise exception 'Missing permission inventory.receive';
  end if;
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'quantity must be greater than zero';
  end if;
  if p_unit_cost is not null and p_unit_cost < 0 then
    raise exception 'unit_cost cannot be negative';
  end if;
  if p_unit_cost is not null and not private.has_permission('cost_price.view') then
    raise exception 'Missing permission cost_price.view';
  end if;

  select * into v_product
  from public.products
  where id = p_product_id
  for update;

  if not found then
    raise exception 'Product not found';
  end if;
  if not v_product.is_active then
    raise exception 'Product is inactive';
  end if;

  if v_product.track_serial then
    if trunc(p_quantity) <> p_quantity then
      raise exception 'Serialized quantity must be an integer';
    end if;
    if v_serial_count <> p_quantity::integer then
      raise exception 'Serialized quantity must equal serial_numbers count';
    end if;

    select count(distinct lower(btrim(x)))
    into v_distinct_count
    from unnest(p_serial_numbers) as s(x)
    where nullif(btrim(x), '') is not null;

    if v_distinct_count <> v_serial_count then
      raise exception 'serial_numbers contain blank or duplicate values';
    end if;

    foreach v_serial in array p_serial_numbers loop
      v_serial := btrim(v_serial);

      insert into public.inventory_units(
        product_id, serial_number, status, location, received_at,
        created_by, updated_by
      ) values (
        p_product_id, v_serial, 'IN_STOCK', nullif(btrim(p_location), ''), now(),
        v_uid, v_uid
      ) returning id into v_unit_id;

      insert into public.inventory_transactions(
        product_id, inventory_unit_id, transaction_type, quantity,
        reference_type, reference_id, note, occurred_at, created_by
      ) values (
        p_product_id, v_unit_id, 'RECEIVE', 1,
        nullif(btrim(p_reference_type), ''), p_reference_id,
        nullif(btrim(p_note), ''), now(), v_uid
      ) returning id into v_tx_id;

      if p_unit_cost is not null then
        insert into private.inventory_transaction_costs(transaction_id, unit_cost)
        values (v_tx_id, p_unit_cost);
      end if;

      v_unit_ids := array_append(v_unit_ids, v_unit_id);
      v_tx_ids := array_append(v_tx_ids, v_tx_id);
    end loop;
  else
    if v_serial_count > 0 then
      raise exception 'Non-serialized product cannot receive serial_numbers';
    end if;

    insert into public.inventory_transactions(
      product_id, transaction_type, quantity,
      reference_type, reference_id, note, occurred_at, created_by
    ) values (
      p_product_id, 'RECEIVE', p_quantity,
      nullif(btrim(p_reference_type), ''), p_reference_id,
      nullif(btrim(p_note), ''), now(), v_uid
    ) returning id into v_tx_id;

    if p_unit_cost is not null then
      insert into private.inventory_transaction_costs(transaction_id, unit_cost)
      values (v_tx_id, p_unit_cost);
    end if;

    v_tx_ids := array_append(v_tx_ids, v_tx_id);
  end if;

  return jsonb_build_object(
    'product_id', p_product_id,
    'quantity', p_quantity,
    'transaction_ids', to_jsonb(v_tx_ids),
    'inventory_unit_ids', to_jsonb(v_unit_ids)
  );
end;
$$;

create or replace function private.inventory_issue_impl(
  p_product_id uuid,
  p_quantity numeric,
  p_inventory_unit_ids uuid[] default null,
  p_note text default null,
  p_reference_type text default null,
  p_reference_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_product public.products%rowtype;
  v_unit_id uuid;
  v_tx_id uuid;
  v_tx_ids uuid[] := array[]::uuid[];
  v_unit_count integer := coalesce(array_length(p_inventory_unit_ids, 1), 0);
  v_distinct_count integer;
  v_stock numeric(14,3);
  v_affected integer;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;
  if not private.has_permission('inventory.issue') then
    raise exception 'Missing permission inventory.issue';
  end if;
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'quantity must be greater than zero';
  end if;

  select * into v_product
  from public.products
  where id = p_product_id
  for update;

  if not found then
    raise exception 'Product not found';
  end if;

  if v_product.track_serial then
    if trunc(p_quantity) <> p_quantity then
      raise exception 'Serialized quantity must be an integer';
    end if;
    if v_unit_count <> p_quantity::integer then
      raise exception 'Serialized quantity must equal inventory_unit_ids count';
    end if;

    select count(distinct x)
    into v_distinct_count
    from unnest(p_inventory_unit_ids) as u(x)
    where x is not null;

    if v_distinct_count <> v_unit_count then
      raise exception 'inventory_unit_ids contain null or duplicate values';
    end if;

    foreach v_unit_id in array p_inventory_unit_ids loop
      update public.inventory_units
      set status = 'OUT', issued_at = now(), updated_by = v_uid, updated_at = now()
      where id = v_unit_id
        and product_id = p_product_id
        and status = 'IN_STOCK';

      get diagnostics v_affected = row_count;
      if v_affected <> 1 then
        raise exception 'Inventory unit % is unavailable', v_unit_id;
      end if;

      insert into public.inventory_transactions(
        product_id, inventory_unit_id, transaction_type, quantity,
        reference_type, reference_id, note, occurred_at, created_by
      ) values (
        p_product_id, v_unit_id, 'ISSUE', 1,
        nullif(btrim(p_reference_type), ''), p_reference_id,
        nullif(btrim(p_note), ''), now(), v_uid
      ) returning id into v_tx_id;

      v_tx_ids := array_append(v_tx_ids, v_tx_id);
    end loop;
  else
    if v_unit_count > 0 then
      raise exception 'Non-serialized product cannot issue inventory_unit_ids';
    end if;

    select coalesce(sum(
      case
        when transaction_type in ('RECEIVE','ADJUST_IN','RETURN_IN') then quantity
        else -quantity
      end
    ), 0)
    into v_stock
    from public.inventory_transactions
    where product_id = p_product_id;

    if v_stock < p_quantity then
      raise exception 'Insufficient stock: available %, requested %', v_stock, p_quantity;
    end if;

    insert into public.inventory_transactions(
      product_id, transaction_type, quantity,
      reference_type, reference_id, note, occurred_at, created_by
    ) values (
      p_product_id, 'ISSUE', p_quantity,
      nullif(btrim(p_reference_type), ''), p_reference_id,
      nullif(btrim(p_note), ''), now(), v_uid
    ) returning id into v_tx_id;

    v_tx_ids := array_append(v_tx_ids, v_tx_id);
  end if;

  return jsonb_build_object(
    'product_id', p_product_id,
    'quantity', p_quantity,
    'transaction_ids', to_jsonb(v_tx_ids)
  );
end;
$$;

create or replace function private.inventory_adjust_impl(
  p_product_id uuid,
  p_quantity_delta numeric,
  p_note text,
  p_unit_cost numeric default null,
  p_serial_numbers text[] default null,
  p_inventory_unit_ids uuid[] default null,
  p_location text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_product public.products%rowtype;
  v_abs_qty numeric := abs(p_quantity_delta);
  v_tx_type text;
  v_serial_count integer := coalesce(array_length(p_serial_numbers, 1), 0);
  v_unit_count integer := coalesce(array_length(p_inventory_unit_ids, 1), 0);
  v_distinct_count integer;
  v_serial text;
  v_unit_id uuid;
  v_tx_id uuid;
  v_tx_ids uuid[] := array[]::uuid[];
  v_unit_ids uuid[] := array[]::uuid[];
  v_stock numeric(14,3);
  v_affected integer;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;
  if not private.has_permission('inventory.adjust') then
    raise exception 'Missing permission inventory.adjust';
  end if;
  if p_quantity_delta is null or p_quantity_delta = 0 then
    raise exception 'quantity_delta must be non-zero';
  end if;
  if nullif(btrim(p_note), '') is null then
    raise exception 'Adjustment note is required';
  end if;
  if p_unit_cost is not null and p_unit_cost < 0 then
    raise exception 'unit_cost cannot be negative';
  end if;
  if p_unit_cost is not null and not private.has_permission('cost_price.view') then
    raise exception 'Missing permission cost_price.view';
  end if;

  select * into v_product
  from public.products
  where id = p_product_id
  for update;

  if not found then
    raise exception 'Product not found';
  end if;

  v_tx_type := case when p_quantity_delta > 0 then 'ADJUST_IN' else 'ADJUST_OUT' end;

  if v_product.track_serial then
    if trunc(v_abs_qty) <> v_abs_qty then
      raise exception 'Serialized adjustment quantity must be an integer';
    end if;

    if p_quantity_delta > 0 then
      if v_unit_count > 0 then
        raise exception 'ADJUST_IN serialized product uses serial_numbers, not inventory_unit_ids';
      end if;
      if v_serial_count <> v_abs_qty::integer then
        raise exception 'ADJUST_IN quantity must equal serial_numbers count';
      end if;

      select count(distinct lower(btrim(x)))
      into v_distinct_count
      from unnest(p_serial_numbers) as s(x)
      where nullif(btrim(x), '') is not null;

      if v_distinct_count <> v_serial_count then
        raise exception 'serial_numbers contain blank or duplicate values';
      end if;

      foreach v_serial in array p_serial_numbers loop
        v_serial := btrim(v_serial);

        insert into public.inventory_units(
          product_id, serial_number, status, location, received_at,
          created_by, updated_by
        ) values (
          p_product_id, v_serial, 'IN_STOCK', nullif(btrim(p_location), ''), now(),
          v_uid, v_uid
        ) returning id into v_unit_id;

        insert into public.inventory_transactions(
          product_id, inventory_unit_id, transaction_type, quantity,
          note, occurred_at, created_by
        ) values (
          p_product_id, v_unit_id, v_tx_type, 1,
          btrim(p_note), now(), v_uid
        ) returning id into v_tx_id;

        if p_unit_cost is not null then
          insert into private.inventory_transaction_costs(transaction_id, unit_cost)
          values (v_tx_id, p_unit_cost);
        end if;

        v_unit_ids := array_append(v_unit_ids, v_unit_id);
        v_tx_ids := array_append(v_tx_ids, v_tx_id);
      end loop;
    else
      if v_serial_count > 0 then
        raise exception 'ADJUST_OUT serialized product uses inventory_unit_ids, not serial_numbers';
      end if;
      if p_unit_cost is not null then
        raise exception 'unit_cost is not valid for ADJUST_OUT';
      end if;
      if v_unit_count <> v_abs_qty::integer then
        raise exception 'ADJUST_OUT quantity must equal inventory_unit_ids count';
      end if;

      select count(distinct x)
      into v_distinct_count
      from unnest(p_inventory_unit_ids) as u(x)
      where x is not null;

      if v_distinct_count <> v_unit_count then
        raise exception 'inventory_unit_ids contain null or duplicate values';
      end if;

      foreach v_unit_id in array p_inventory_unit_ids loop
        update public.inventory_units
        set status = 'OUT', issued_at = now(), updated_by = v_uid, updated_at = now()
        where id = v_unit_id
          and product_id = p_product_id
          and status = 'IN_STOCK';

        get diagnostics v_affected = row_count;
        if v_affected <> 1 then
          raise exception 'Inventory unit % is unavailable', v_unit_id;
        end if;

        insert into public.inventory_transactions(
          product_id, inventory_unit_id, transaction_type, quantity,
          note, occurred_at, created_by
        ) values (
          p_product_id, v_unit_id, v_tx_type, 1,
          btrim(p_note), now(), v_uid
        ) returning id into v_tx_id;

        v_tx_ids := array_append(v_tx_ids, v_tx_id);
      end loop;
    end if;
  else
    if v_serial_count > 0 or v_unit_count > 0 then
      raise exception 'Non-serialized adjustment cannot use serial_numbers or inventory_unit_ids';
    end if;

    if p_quantity_delta < 0 then
      if p_unit_cost is not null then
        raise exception 'unit_cost is not valid for ADJUST_OUT';
      end if;

      select coalesce(sum(
        case
          when transaction_type in ('RECEIVE','ADJUST_IN','RETURN_IN') then quantity
          else -quantity
        end
      ), 0)
      into v_stock
      from public.inventory_transactions
      where product_id = p_product_id;

      if v_stock < v_abs_qty then
        raise exception 'Insufficient stock: available %, requested adjustment %', v_stock, v_abs_qty;
      end if;
    end if;

    insert into public.inventory_transactions(
      product_id, transaction_type, quantity,
      note, occurred_at, created_by
    ) values (
      p_product_id, v_tx_type, v_abs_qty,
      btrim(p_note), now(), v_uid
    ) returning id into v_tx_id;

    if p_quantity_delta > 0 and p_unit_cost is not null then
      insert into private.inventory_transaction_costs(transaction_id, unit_cost)
      values (v_tx_id, p_unit_cost);
    end if;

    v_tx_ids := array_append(v_tx_ids, v_tx_id);
  end if;

  return jsonb_build_object(
    'product_id', p_product_id,
    'quantity_delta', p_quantity_delta,
    'transaction_ids', to_jsonb(v_tx_ids),
    'inventory_unit_ids', to_jsonb(v_unit_ids)
  );
end;
$$;

-- Private helpers are callable only by signed-in users through the public wrappers.
-- They still perform their own auth.uid() and permission checks before any write.
grant usage on schema private to authenticated;
grant execute on function private.inventory_receive_impl(uuid,numeric,numeric,text[],text,text,uuid,text) to authenticated;
grant execute on function private.inventory_issue_impl(uuid,numeric,uuid[],text,text,uuid) to authenticated;
grant execute on function private.inventory_adjust_impl(uuid,numeric,text,numeric,text[],uuid[],text) to authenticated;
revoke all on function private.inventory_receive_impl(uuid,numeric,numeric,text[],text,text,uuid,text) from public, anon;
revoke all on function private.inventory_issue_impl(uuid,numeric,uuid[],text,text,uuid) from public, anon;
revoke all on function private.inventory_adjust_impl(uuid,numeric,text,numeric,text[],uuid[],text) from public, anon;

-- Public wrappers are SECURITY INVOKER and contain no elevated privileges.
create or replace function public.inventory_receive(
  p_product_id uuid,
  p_quantity numeric,
  p_unit_cost numeric default null,
  p_serial_numbers text[] default null,
  p_note text default null,
  p_reference_type text default null,
  p_reference_id uuid default null,
  p_location text default null
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.inventory_receive_impl(
    p_product_id, p_quantity, p_unit_cost, p_serial_numbers,
    p_note, p_reference_type, p_reference_id, p_location
  );
$$;

create or replace function public.inventory_issue(
  p_product_id uuid,
  p_quantity numeric,
  p_inventory_unit_ids uuid[] default null,
  p_note text default null,
  p_reference_type text default null,
  p_reference_id uuid default null
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.inventory_issue_impl(
    p_product_id, p_quantity, p_inventory_unit_ids,
    p_note, p_reference_type, p_reference_id
  );
$$;

create or replace function public.inventory_adjust(
  p_product_id uuid,
  p_quantity_delta numeric,
  p_note text,
  p_unit_cost numeric default null,
  p_serial_numbers text[] default null,
  p_inventory_unit_ids uuid[] default null,
  p_location text default null
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.inventory_adjust_impl(
    p_product_id, p_quantity_delta, p_note, p_unit_cost,
    p_serial_numbers, p_inventory_unit_ids, p_location
  );
$$;

revoke execute on function public.inventory_receive(uuid,numeric,numeric,text[],text,text,uuid,text) from public, anon;
revoke execute on function public.inventory_issue(uuid,numeric,uuid[],text,text,uuid) from public, anon;
revoke execute on function public.inventory_adjust(uuid,numeric,text,numeric,text[],uuid[],text) from public, anon;
grant execute on function public.inventory_receive(uuid,numeric,numeric,text[],text,text,uuid,text) to authenticated;
grant execute on function public.inventory_issue(uuid,numeric,uuid[],text,text,uuid) to authenticated;
grant execute on function public.inventory_adjust(uuid,numeric,text,numeric,text[],uuid[],text) to authenticated;

-- RLS for public catalog/inventory tables.
alter table public.product_categories enable row level security;
alter table public.products enable row level security;
alter table public.inventory_units enable row level security;
alter table public.inventory_transactions enable row level security;

create policy product_categories_select
on public.product_categories for select
to authenticated
using ((select private.has_permission('product.view')));

create policy product_categories_insert
on public.product_categories for insert
to authenticated
with check ((select private.has_permission('product.manage')));

create policy product_categories_update
on public.product_categories for update
to authenticated
using ((select private.has_permission('product.manage')))
with check ((select private.has_permission('product.manage')));

create policy products_select
on public.products for select
to authenticated
using ((select private.has_permission('product.view')));

create policy products_insert
on public.products for insert
to authenticated
with check ((select private.has_permission('product.manage')));

create policy products_update
on public.products for update
to authenticated
using ((select private.has_permission('product.manage')))
with check ((select private.has_permission('product.manage')));

create policy inventory_units_select
on public.inventory_units for select
to authenticated
using ((select private.has_permission('inventory.view')));

create policy inventory_transactions_select
on public.inventory_transactions for select
to authenticated
using ((select private.has_permission('inventory.view')));

-- Direct inventory writes are intentionally not exposed. Inventory mutations go
-- through the validated RPC functions above so serialized units and ledger rows
-- are committed atomically.
grant select, insert, update on public.product_categories to authenticated, service_role;
grant select, insert, update on public.products to authenticated, service_role;
grant select on public.inventory_units to authenticated, service_role;
grant select on public.inventory_transactions to authenticated, service_role;
revoke insert, update, delete on public.inventory_units from public, anon, authenticated;
revoke insert, update, delete on public.inventory_transactions from public, anon, authenticated;
revoke delete on public.product_categories from public, anon, authenticated, service_role;
revoke delete on public.products from public, anon, authenticated, service_role;
revoke all on public.product_categories from anon;
revoke all on public.products from anon;
revoke all on public.inventory_units from anon;
revoke all on public.inventory_transactions from anon;

-- Cost rows remain in an unexposed schema. Authenticated users may SELECT only;
-- private-table RLS makes rows visible exclusively to cost_price.view roles.
grant select on private.inventory_transaction_costs to authenticated, service_role;
revoke insert, update, delete on private.inventory_transaction_costs from public, anon, authenticated;

-- Safe read models. SECURITY INVOKER ensures underlying RLS remains active.
create view public.inventory_transactions_view
with (security_invoker = true)
as
select
  t.id,
  t.product_id,
  t.inventory_unit_id,
  t.transaction_type,
  t.quantity,
  t.reference_type,
  t.reference_id,
  t.note,
  t.occurred_at,
  t.created_by,
  t.created_at,
  c.unit_cost
from public.inventory_transactions t
left join private.inventory_transaction_costs c
  on c.transaction_id = t.id;

create view public.product_inventory_summary
with (security_invoker = true)
as
with movement as (
  select
    t.product_id,
    coalesce(sum(
      case
        when t.transaction_type in ('RECEIVE','ADJUST_IN','RETURN_IN') then t.quantity
        else -t.quantity
      end
    ), 0)::numeric(14,3) as ledger_stock
  from public.inventory_transactions t
  group by t.product_id
), serial_stock as (
  select
    u.product_id,
    count(*) filter (where u.status = 'IN_STOCK')::numeric(14,3) as unit_stock
  from public.inventory_units u
  group by u.product_id
)
select
  p.id as product_id,
  p.sku,
  p.name,
  p.category_id,
  p.brand,
  p.model,
  p.unit,
  p.sale_price,
  p.min_stock,
  p.track_serial,
  p.is_active,
  case
    when p.track_serial then coalesce(s.unit_stock, 0)
    else coalesce(m.ledger_stock, 0)
  end::numeric(14,3) as stock_qty,
  (
    case
      when p.track_serial then coalesce(s.unit_stock, 0)
      else coalesce(m.ledger_stock, 0)
    end <= p.min_stock
  ) as low_stock,
  latest_cost.unit_cost as last_unit_cost
from public.products p
left join movement m on m.product_id = p.id
left join serial_stock s on s.product_id = p.id
left join lateral (
  select c.unit_cost
  from public.inventory_transactions tx
  join private.inventory_transaction_costs c on c.transaction_id = tx.id
  where tx.product_id = p.id
    and tx.transaction_type in ('RECEIVE','ADJUST_IN','RETURN_IN')
  order by tx.occurred_at desc, tx.created_at desc
  limit 1
) latest_cost on true;

grant select on public.inventory_transactions_view to authenticated, service_role;
grant select on public.product_inventory_summary to authenticated, service_role;
revoke all on public.inventory_transactions_view from anon;
revoke all on public.product_inventory_summary from anon;
