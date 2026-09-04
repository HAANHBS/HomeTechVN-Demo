-- HomeTechVN T4 - Sales
-- T1/T2/T3 migrations are locked; this migration only adds T4 objects.

create table public.sales_orders (
  id uuid primary key default gen_random_uuid(),
  order_code text not null default '',
  customer_id uuid not null references public.customers(id) on delete restrict,
  status text not null default 'DRAFT'
    check (status in ('DRAFT','CONFIRMED','PAYMENT_PENDING','PAID','DELIVERED','COMPLETED','CANCELLED')),
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  discount_amount numeric(14,2) not null default 0 check (discount_amount >= 0),
  total_amount numeric(14,2) not null default 0 check (total_amount >= 0),
  paid_amount numeric(14,2) not null default 0 check (paid_amount >= 0),
  balance_due numeric(14,2) generated always as (greatest(total_amount - paid_amount, 0)) stored,
  note text,
  checklist jsonb not null default
  '[
    {"key":"customer_identity","label":"Đối chiếu thông tin khách hàng","required":true,"checked":false},
    {"key":"contact_phone","label":"Xác nhận số điện thoại liên hệ","required":true,"checked":false},
    {"key":"product_quantity","label":"Đối chiếu sản phẩm và số lượng","required":true,"checked":false},
    {"key":"product_configuration","label":"Đối chiếu model/cấu hình hàng giao","required":true,"checked":false},
    {"key":"serial_numbers","label":"Đối chiếu Serial/Asset Tag khi có","required":false,"checked":false},
    {"key":"accessories","label":"Đối chiếu phụ kiện đi kèm","required":false,"checked":false},
    {"key":"physical_condition","label":"Kiểm tra ngoại hình trước bàn giao","required":true,"checked":false},
    {"key":"functionality_test","label":"Kiểm tra hoạt động trước bàn giao","required":true,"checked":false},
    {"key":"price_discount","label":"Xác nhận giá bán và giảm giá","required":true,"checked":false},
    {"key":"payment_confirmed","label":"Xác nhận thanh toán","required":true,"checked":false},
    {"key":"receipt_invoice","label":"Giao phiếu/hoá đơn khi áp dụng","required":false,"checked":false},
    {"key":"warranty_terms","label":"Thông báo điều kiện và thời hạn bảo hành","required":true,"checked":false},
    {"key":"warranty_document","label":"Giao thông tin/QR bảo hành khi áp dụng","required":false,"checked":false},
    {"key":"software_license","label":"Bàn giao bản quyền/phần mềm khi áp dụng","required":false,"checked":false},
    {"key":"data_backup_handover","label":"Xác nhận dữ liệu/backup khi áp dụng","required":false,"checked":false},
    {"key":"customer_delivery_confirmation","label":"Khách xác nhận đã nhận đủ hàng","required":true,"checked":false}
  ]'::jsonb,
  stock_issued_at timestamptz,
  confirmed_at timestamptz,
  payment_pending_at timestamptz,
  paid_at timestamptz,
  delivered_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancelled_reason text,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sales_orders_order_code_unique unique(order_code),
  constraint sales_orders_discount_lte_subtotal check (discount_amount <= subtotal),
  constraint sales_orders_paid_lte_total check (paid_amount <= total_amount)
);

create table public.sales_order_items (
  id uuid primary key default gen_random_uuid(),
  sales_order_id uuid not null references public.sales_orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  sku_snapshot text not null,
  product_name_snapshot text not null,
  quantity numeric(12,3) not null check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  discount_amount numeric(14,2) not null default 0 check (discount_amount >= 0),
  line_total numeric(14,2) generated always as (
    greatest((quantity * unit_price) - discount_amount, 0)
  ) stored,
  warranty_months integer not null default 0 check (warranty_months >= 0),
  inventory_unit_ids uuid[] not null default '{}'::uuid[],
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sales_order_items_discount_lte_line check (discount_amount <= quantity * unit_price)
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  payment_code text not null default '',
  sales_order_id uuid not null references public.sales_orders(id) on delete restrict,
  amount numeric(14,2) not null check (amount > 0),
  payment_method text not null
    check (payment_method in ('CASH','BANK_TRANSFER','CARD','EWALLET','OTHER')),
  status text not null default 'COMPLETED'
    check (status in ('COMPLETED','REFUNDED')),
  reference_no text,
  note text,
  paid_at timestamptz not null default now(),
  refunded_at timestamptz,
  refund_note text,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payments_payment_code_unique unique(payment_code),
  constraint payments_refund_fields check (
    (status='COMPLETED' and refunded_at is null)
    or
    (status='REFUNDED' and refunded_at is not null)
  )
);

create table private.sales_order_item_costs (
  sales_order_item_id uuid primary key references public.sales_order_items(id) on delete cascade,
  unit_cost numeric(14,2),
  total_cost numeric(14,2),
  captured_at timestamptz not null default now(),
  check (unit_cost is null or unit_cost >= 0),
  check (total_cost is null or total_cost >= 0)
);

revoke all on table private.sales_order_item_costs from public, anon, authenticated;
grant all on table private.sales_order_item_costs to service_role;

create index idx_sales_orders_customer_created on public.sales_orders(customer_id, created_at desc);
create index idx_sales_orders_status_created on public.sales_orders(status, created_at desc);
create index idx_sales_orders_created_by on public.sales_orders(created_by);
create index idx_sales_orders_updated_by on public.sales_orders(updated_by);
create index idx_sales_order_items_order on public.sales_order_items(sales_order_id);
create index idx_sales_order_items_product on public.sales_order_items(product_id);
create index idx_sales_order_items_created_by on public.sales_order_items(created_by);
create index idx_sales_order_items_updated_by on public.sales_order_items(updated_by);
create index idx_payments_order_paid on public.payments(sales_order_id, paid_at desc);
create index idx_payments_status on public.payments(status);
create index idx_payments_created_by on public.payments(created_by);
create index idx_payments_updated_by on public.payments(updated_by);

create trigger trg_sales_orders_updated_at
before update on public.sales_orders
for each row execute function public.fn_set_updated_at();

create trigger trg_sales_order_items_updated_at
before update on public.sales_order_items
for each row execute function public.fn_set_updated_at();

create trigger trg_payments_updated_at
before update on public.payments
for each row execute function public.fn_set_updated_at();

create trigger trg_sales_orders_audit
after insert or update or delete on public.sales_orders
for each row execute function public.fn_audit_row();

create trigger trg_sales_order_items_audit
after insert or update or delete on public.sales_order_items
for each row execute function public.fn_audit_row();

create trigger trg_payments_audit
after insert or update or delete on public.payments
for each row execute function public.fn_audit_row();

alter table public.sales_orders enable row level security;
alter table public.sales_order_items enable row level security;
alter table public.payments enable row level security;

create policy sales_orders_select on public.sales_orders
for select to authenticated
using ((select private.has_permission('sale.view')));

create policy sales_order_items_select on public.sales_order_items
for select to authenticated
using ((select private.has_permission('sale.view')));

create policy payments_select on public.payments
for select to authenticated
using ((select private.has_permission('payment.view')));

revoke all on public.sales_orders, public.sales_order_items, public.payments from anon, authenticated;
grant select on public.sales_orders, public.sales_order_items to authenticated;
grant select on public.payments to authenticated;

create or replace function private.sale_latest_unit_cost(p_product_id uuid)
returns numeric
language sql
stable
security definer
set search_path=''
as $$
  select c.unit_cost
  from public.inventory_transactions t
  join private.inventory_transaction_costs c on c.transaction_id=t.id
  where t.product_id=p_product_id
    and t.transaction_type in ('RECEIVE','ADJUST_IN','RETURN_IN')
  order by t.occurred_at desc, t.created_at desc
  limit 1;
$$;

create or replace function private.sale_recalc_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  v_subtotal numeric(14,2);
  v_discount numeric(14,2);
begin
  select coalesce(sum(quantity*unit_price),0), coalesce(sum(discount_amount),0)
    into v_subtotal, v_discount
  from public.sales_order_items
  where sales_order_id=p_order_id;

  update public.sales_orders
  set subtotal=v_subtotal,
      total_amount=greatest(v_subtotal - v_discount - discount_amount,0),
      updated_at=now()
  where id=p_order_id;
end;
$$;

create or replace function private.sale_set_checklist_system(
  p_order_id uuid,
  p_key text,
  p_checked boolean,
  p_actor uuid
) returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  v_exists boolean;
  v_new jsonb;
begin
  select exists(
    select 1 from jsonb_array_elements(checklist) x
    where x->>'key'=p_key
  ) into v_exists
  from public.sales_orders where id=p_order_id;

  if not coalesce(v_exists,false) then
    raise exception 'Unknown checklist key %', p_key;
  end if;

  select jsonb_agg(
    case when elem->>'key'=p_key then
      (elem || jsonb_build_object(
        'checked',p_checked,
        'checked_at',case when p_checked then to_jsonb(now()) else 'null'::jsonb end,
        'checked_by',case when p_checked and p_actor is not null then to_jsonb(p_actor::text) else 'null'::jsonb end
      ))
    else elem end
    order by ord
  )
  into v_new
  from public.sales_orders o,
       jsonb_array_elements(o.checklist) with ordinality t(elem,ord)
  where o.id=p_order_id;

  update public.sales_orders
  set checklist=v_new, updated_by=p_actor, updated_at=now()
  where id=p_order_id;
end;
$$;

create or replace function private.sale_checklist_complete(p_order_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_order public.sales_orders%rowtype;
  v_required_missing integer;
  v_serial_required boolean;
  v_serial_checked boolean;
begin
  select * into v_order from public.sales_orders where id=p_order_id;
  if not found then return false; end if;

  select count(*) into v_required_missing
  from jsonb_array_elements(v_order.checklist) x
  where coalesce((x->>'required')::boolean,false)=true
    and coalesce((x->>'checked')::boolean,false)=false;

  select exists(
    select 1
    from public.sales_order_items i
    join public.products p on p.id=i.product_id
    where i.sales_order_id=p_order_id and p.track_serial=true
  ) into v_serial_required;

  select coalesce((x->>'checked')::boolean,false)
  into v_serial_checked
  from jsonb_array_elements(v_order.checklist) x
  where x->>'key'='serial_numbers'
  limit 1;

  return v_required_missing=0
    and (not v_serial_required or coalesce(v_serial_checked,false));
end;
$$;

create or replace function private.sale_create_impl(
  p_customer_id uuid,
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_id uuid;
  v_code text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('sale.create') then raise exception 'Missing permission sale.create'; end if;
  if not exists(select 1 from public.customers where id=p_customer_id and status='ACTIVE') then
    raise exception 'Customer not found or inactive';
  end if;

  v_code:=private.next_daily_code('SALES_ORDER','SO',null,4);
  insert into public.sales_orders(order_code,customer_id,note,created_by,updated_by)
  values(v_code,p_customer_id,nullif(btrim(p_note),''),v_uid,v_uid)
  returning id into v_id;

  return jsonb_build_object('id',v_id,'order_code',v_code,'status','DRAFT');
end;
$$;

create or replace function private.sale_update_draft_impl(
  p_order_id uuid,
  p_customer_id uuid,
  p_discount_amount numeric default 0,
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_order public.sales_orders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('sale.update') then raise exception 'Missing permission sale.update'; end if;
  if p_discount_amount is null or p_discount_amount<0 then raise exception 'discount_amount cannot be negative'; end if;
  if not exists(select 1 from public.customers where id=p_customer_id and status='ACTIVE') then
    raise exception 'Customer not found or inactive';
  end if;

  select * into v_order from public.sales_orders where id=p_order_id for update;
  if not found then raise exception 'Sales order not found'; end if;
  if v_order.status<>'DRAFT' then raise exception 'Only DRAFT order can be edited'; end if;
  if p_discount_amount>v_order.subtotal then raise exception 'Order discount exceeds subtotal'; end if;

  update public.sales_orders
  set customer_id=p_customer_id,
      discount_amount=p_discount_amount,
      total_amount=greatest(subtotal-p_discount_amount,0),
      note=nullif(btrim(p_note),''),
      updated_by=v_uid,
      updated_at=now()
  where id=p_order_id
  returning * into v_order;

  return to_jsonb(v_order);
end;
$$;

create or replace function private.sale_add_item_impl(
  p_order_id uuid,
  p_product_id uuid,
  p_quantity numeric,
  p_unit_price numeric default null,
  p_discount_amount numeric default 0,
  p_inventory_unit_ids uuid[] default '{}'::uuid[]
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_order public.sales_orders%rowtype;
  v_product public.products%rowtype;
  v_item public.sales_order_items%rowtype;
  v_price numeric(14,2);
  v_unit_count integer:=coalesce(array_length(p_inventory_unit_ids,1),0);
  v_distinct_count integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('sale.update') then raise exception 'Missing permission sale.update'; end if;
  if p_quantity is null or p_quantity<=0 then raise exception 'quantity must be greater than zero'; end if;
  if p_discount_amount is null or p_discount_amount<0 then raise exception 'discount_amount cannot be negative'; end if;

  select * into v_order from public.sales_orders where id=p_order_id for update;
  if not found then raise exception 'Sales order not found'; end if;
  if v_order.status<>'DRAFT' then raise exception 'Items can only change in DRAFT'; end if;

  select * into v_product from public.products where id=p_product_id and is_active=true;
  if not found then raise exception 'Product not found or inactive'; end if;

  v_price:=coalesce(p_unit_price,v_product.sale_price);
  if v_price<0 then raise exception 'unit_price cannot be negative'; end if;
  if p_discount_amount>p_quantity*v_price then raise exception 'Item discount exceeds line amount'; end if;

  if v_product.track_serial then
    if trunc(p_quantity)<>p_quantity then raise exception 'Serialized quantity must be an integer'; end if;
    if v_unit_count not in (0,p_quantity::integer) then
      raise exception 'inventory_unit_ids must be empty or match serialized quantity';
    end if;
    if v_unit_count>0 then
      select count(distinct x) into v_distinct_count
      from unnest(p_inventory_unit_ids) u(x) where x is not null;
      if v_distinct_count<>v_unit_count then raise exception 'inventory_unit_ids contain null or duplicate values'; end if;
      if (select count(*) from public.inventory_units u
          where u.id=any(p_inventory_unit_ids) and u.product_id=p_product_id and u.status='IN_STOCK')<>v_unit_count then
        raise exception 'One or more serialized units are unavailable';
      end if;
    end if;
  elsif v_unit_count>0 then
    raise exception 'Non-serialized product cannot use inventory_unit_ids';
  end if;

  insert into public.sales_order_items(
    sales_order_id,product_id,sku_snapshot,product_name_snapshot,quantity,unit_price,
    discount_amount,warranty_months,inventory_unit_ids,created_by,updated_by
  ) values(
    p_order_id,p_product_id,v_product.sku,v_product.name,p_quantity,v_price,
    p_discount_amount,v_product.warranty_months,coalesce(p_inventory_unit_ids,'{}'::uuid[]),v_uid,v_uid
  ) returning * into v_item;

  perform private.sale_recalc_order(p_order_id);
  return to_jsonb(v_item);
end;
$$;

create or replace function private.sale_update_item_impl(
  p_item_id uuid,
  p_quantity numeric,
  p_unit_price numeric,
  p_discount_amount numeric default 0,
  p_inventory_unit_ids uuid[] default '{}'::uuid[]
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_item public.sales_order_items%rowtype;
  v_order public.sales_orders%rowtype;
  v_product public.products%rowtype;
  v_unit_count integer:=coalesce(array_length(p_inventory_unit_ids,1),0);
  v_distinct_count integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('sale.update') then raise exception 'Missing permission sale.update'; end if;
  if p_quantity is null or p_quantity<=0 then raise exception 'quantity must be greater than zero'; end if;
  if p_unit_price is null or p_unit_price<0 then raise exception 'unit_price cannot be negative'; end if;
  if p_discount_amount is null or p_discount_amount<0 or p_discount_amount>p_quantity*p_unit_price then
    raise exception 'Invalid item discount';
  end if;

  select * into v_item from public.sales_order_items where id=p_item_id for update;
  if not found then raise exception 'Sales item not found'; end if;
  select * into v_order from public.sales_orders where id=v_item.sales_order_id for update;
  if v_order.status<>'DRAFT' then raise exception 'Items can only change in DRAFT'; end if;
  select * into v_product from public.products where id=v_item.product_id;

  if v_product.track_serial then
    if trunc(p_quantity)<>p_quantity then raise exception 'Serialized quantity must be an integer'; end if;
    if v_unit_count not in (0,p_quantity::integer) then raise exception 'inventory_unit_ids must be empty or match serialized quantity'; end if;
    if v_unit_count>0 then
      select count(distinct x) into v_distinct_count from unnest(p_inventory_unit_ids) u(x) where x is not null;
      if v_distinct_count<>v_unit_count then raise exception 'inventory_unit_ids contain null or duplicate values'; end if;
      if (select count(*) from public.inventory_units u
          where u.id=any(p_inventory_unit_ids) and u.product_id=v_item.product_id and u.status='IN_STOCK')<>v_unit_count then
        raise exception 'One or more serialized units are unavailable';
      end if;
    end if;
  elsif v_unit_count>0 then
    raise exception 'Non-serialized product cannot use inventory_unit_ids';
  end if;

  update public.sales_order_items
  set quantity=p_quantity,unit_price=p_unit_price,discount_amount=p_discount_amount,
      inventory_unit_ids=coalesce(p_inventory_unit_ids,'{}'::uuid[]),
      updated_by=v_uid,updated_at=now()
  where id=p_item_id
  returning * into v_item;

  perform private.sale_recalc_order(v_item.sales_order_id);
  return to_jsonb(v_item);
end;
$$;

create or replace function private.sale_remove_item_impl(p_item_id uuid)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_order_id uuid;
  v_status text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('sale.update') then raise exception 'Missing permission sale.update'; end if;

  select sales_order_id into v_order_id from public.sales_order_items where id=p_item_id for update;
  if not found then raise exception 'Sales item not found'; end if;
  select status into v_status from public.sales_orders where id=v_order_id for update;
  if v_status<>'DRAFT' then raise exception 'Items can only change in DRAFT'; end if;

  delete from public.sales_order_items where id=p_item_id;
  perform private.sale_recalc_order(v_order_id);
  return true;
end;
$$;

create or replace function private.sale_set_checklist_item_impl(
  p_order_id uuid,
  p_key text,
  p_checked boolean
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_status text;
  v_checklist jsonb;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('sale.update') then raise exception 'Missing permission sale.update'; end if;

  select status into v_status from public.sales_orders where id=p_order_id for update;
  if not found then raise exception 'Sales order not found'; end if;
  if v_status in ('COMPLETED','CANCELLED') then raise exception 'Checklist is locked for completed/cancelled order'; end if;

  perform private.sale_set_checklist_system(p_order_id,p_key,p_checked,v_uid);
  select checklist into v_checklist from public.sales_orders where id=p_order_id;
  return v_checklist;
end;
$$;

create or replace function private.sale_confirm_impl(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_order public.sales_orders%rowtype;
  v_item public.sales_order_items%rowtype;
  v_product public.products%rowtype;
  v_unit_id uuid;
  v_tx_id uuid;
  v_stock numeric(14,3);
  v_unit_count integer;
  v_distinct_count integer;
  v_cost numeric(14,2);
  v_affected integer;
  v_item_count integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('sale.update') then raise exception 'Missing permission sale.update'; end if;

  select * into v_order from public.sales_orders where id=p_order_id for update;
  if not found then raise exception 'Sales order not found'; end if;
  if v_order.status<>'DRAFT' then raise exception 'Only DRAFT order can be confirmed'; end if;

  select count(*) into v_item_count from public.sales_order_items where sales_order_id=p_order_id;
  if v_item_count=0 then raise exception 'Sales order has no items'; end if;
  if v_order.discount_amount>v_order.subtotal then raise exception 'Order discount exceeds subtotal'; end if;

  for v_item in
    select * from public.sales_order_items where sales_order_id=p_order_id order by created_at,id
  loop
    select * into v_product from public.products where id=v_item.product_id for update;
    if not found or not v_product.is_active then raise exception 'Product % unavailable',v_item.product_id; end if;

    v_cost:=private.sale_latest_unit_cost(v_item.product_id);
    insert into private.sales_order_item_costs(sales_order_item_id,unit_cost,total_cost)
    values(v_item.id,v_cost,case when v_cost is null then null else v_cost*v_item.quantity end)
    on conflict(sales_order_item_id) do update
      set unit_cost=excluded.unit_cost,total_cost=excluded.total_cost,captured_at=now();

    if v_product.track_serial then
      if trunc(v_item.quantity)<>v_item.quantity then raise exception 'Serialized quantity must be integer'; end if;
      v_unit_count:=coalesce(array_length(v_item.inventory_unit_ids,1),0);
      if v_unit_count<>v_item.quantity::integer then
        raise exception 'Select exactly % serial unit(s) for %',v_item.quantity,v_item.sku_snapshot;
      end if;
      select count(distinct x) into v_distinct_count
      from unnest(v_item.inventory_unit_ids) u(x) where x is not null;
      if v_distinct_count<>v_unit_count then raise exception 'Duplicate/null serialized unit selection'; end if;

      foreach v_unit_id in array v_item.inventory_unit_ids loop
        update public.inventory_units
        set status='OUT',issued_at=now(),updated_by=v_uid,updated_at=now()
        where id=v_unit_id and product_id=v_item.product_id and status='IN_STOCK';
        get diagnostics v_affected=row_count;
        if v_affected<>1 then raise exception 'Inventory unit % unavailable',v_unit_id; end if;

        insert into public.inventory_transactions(
          product_id,inventory_unit_id,transaction_type,quantity,reference_type,reference_id,note,occurred_at,created_by
        ) values(
          v_item.product_id,v_unit_id,'ISSUE',1,'SALE',p_order_id,'Sale '||v_order.order_code,now(),v_uid
        ) returning id into v_tx_id;
      end loop;
    else
      select coalesce(sum(case when transaction_type in ('RECEIVE','ADJUST_IN','RETURN_IN') then quantity else -quantity end),0)
      into v_stock
      from public.inventory_transactions where product_id=v_item.product_id;

      if v_stock<v_item.quantity then
        raise exception 'Insufficient stock for %: available %, requested %',v_item.sku_snapshot,v_stock,v_item.quantity;
      end if;

      insert into public.inventory_transactions(
        product_id,transaction_type,quantity,reference_type,reference_id,note,occurred_at,created_by
      ) values(
        v_item.product_id,'ISSUE',v_item.quantity,'SALE',p_order_id,'Sale '||v_order.order_code,now(),v_uid
      );
    end if;
  end loop;

  update public.sales_orders
  set status=case when total_amount=0 then 'PAID' else 'CONFIRMED' end,
      stock_issued_at=now(),
      confirmed_at=now(),
      paid_at=case when total_amount=0 then now() else null end,
      updated_by=v_uid,
      updated_at=now()
  where id=p_order_id
  returning * into v_order;

  if v_order.total_amount=0 then
    perform private.sale_set_checklist_system(p_order_id,'payment_confirmed',true,v_uid);
  end if;

  return to_jsonb(v_order);
end;
$$;

create or replace function private.sale_record_payment_impl(
  p_order_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_reference_no text default null,
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_order public.sales_orders%rowtype;
  v_payment public.payments%rowtype;
  v_new_paid numeric(14,2);
  v_code text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('payment.create') then raise exception 'Missing permission payment.create'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Payment amount must be greater than zero'; end if;
  if p_payment_method not in ('CASH','BANK_TRANSFER','CARD','EWALLET','OTHER') then raise exception 'Invalid payment method'; end if;

  select * into v_order from public.sales_orders where id=p_order_id for update;
  if not found then raise exception 'Sales order not found'; end if;
  if v_order.status not in ('CONFIRMED','PAYMENT_PENDING') then raise exception 'Order is not awaiting payment'; end if;
  if v_order.paid_amount+p_amount>v_order.total_amount then raise exception 'Payment exceeds balance due'; end if;

  v_code:=private.next_daily_code('PAYMENT','PAY',null,4);
  insert into public.payments(
    payment_code,sales_order_id,amount,payment_method,status,reference_no,note,paid_at,created_by,updated_by
  ) values(
    v_code,p_order_id,p_amount,p_payment_method,'COMPLETED',nullif(btrim(p_reference_no),''),nullif(btrim(p_note),''),now(),v_uid,v_uid
  ) returning * into v_payment;

  select coalesce(sum(amount),0) into v_new_paid
  from public.payments
  where sales_order_id=p_order_id and status='COMPLETED';

  update public.sales_orders
  set paid_amount=v_new_paid,
      status=case when v_new_paid=total_amount then 'PAID' else 'PAYMENT_PENDING' end,
      payment_pending_at=coalesce(payment_pending_at,now()),
      paid_at=case when v_new_paid=total_amount then now() else null end,
      updated_by=v_uid,updated_at=now()
  where id=p_order_id
  returning * into v_order;

  if v_new_paid=v_order.total_amount then
    perform private.sale_set_checklist_system(p_order_id,'payment_confirmed',true,v_uid);
  end if;

  return jsonb_build_object('payment',to_jsonb(v_payment),'order',to_jsonb(v_order));
end;
$$;

create or replace function private.sale_refund_payment_impl(
  p_payment_id uuid,
  p_refund_note text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_payment public.payments%rowtype;
  v_order public.sales_orders%rowtype;
  v_new_paid numeric(14,2);
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('payment.update') then raise exception 'Missing permission payment.update'; end if;
  if nullif(btrim(p_refund_note),'') is null then raise exception 'Refund note is required'; end if;

  select * into v_payment from public.payments where id=p_payment_id for update;
  if not found then raise exception 'Payment not found'; end if;
  if v_payment.status<>'COMPLETED' then raise exception 'Only completed payment can be refunded'; end if;

  select * into v_order from public.sales_orders where id=v_payment.sales_order_id for update;
  if v_order.status in ('DELIVERED','COMPLETED','CANCELLED') then
    raise exception 'Payment cannot be refunded after delivery/completion/cancellation';
  end if;

  update public.payments
  set status='REFUNDED',refunded_at=now(),refund_note=btrim(p_refund_note),updated_by=v_uid,updated_at=now()
  where id=p_payment_id
  returning * into v_payment;

  select coalesce(sum(amount),0) into v_new_paid
  from public.payments
  where sales_order_id=v_order.id and status='COMPLETED';

  update public.sales_orders
  set paid_amount=v_new_paid,
      status=case when v_new_paid=0 then 'CONFIRMED'
                  when v_new_paid=total_amount then 'PAID'
                  else 'PAYMENT_PENDING' end,
      paid_at=case when v_new_paid=total_amount then paid_at else null end,
      updated_by=v_uid,updated_at=now()
  where id=v_order.id
  returning * into v_order;

  if v_new_paid<>v_order.total_amount then
    perform private.sale_set_checklist_system(v_order.id,'payment_confirmed',false,v_uid);
  end if;

  return jsonb_build_object('payment',to_jsonb(v_payment),'order',to_jsonb(v_order));
end;
$$;

create or replace function private.sale_deliver_impl(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_order public.sales_orders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('sale.update') then raise exception 'Missing permission sale.update'; end if;

  select * into v_order from public.sales_orders where id=p_order_id for update;
  if not found then raise exception 'Sales order not found'; end if;
  if v_order.status<>'PAID' then raise exception 'Only PAID order can be delivered'; end if;
  if v_order.paid_amount<>v_order.total_amount then raise exception 'Order payment is incomplete'; end if;

  update public.sales_orders
  set status='DELIVERED',delivered_at=now(),updated_by=v_uid,updated_at=now()
  where id=p_order_id
  returning * into v_order;

  return to_jsonb(v_order);
end;
$$;

create or replace function private.sale_complete_impl(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_order public.sales_orders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('sale.update') then raise exception 'Missing permission sale.update'; end if;

  select * into v_order from public.sales_orders where id=p_order_id for update;
  if not found then raise exception 'Sales order not found'; end if;
  if v_order.status<>'DELIVERED' then raise exception 'Only DELIVERED order can be completed'; end if;
  if v_order.paid_amount<>v_order.total_amount then raise exception 'Order payment is incomplete'; end if;
  if not private.sale_checklist_complete(p_order_id) then raise exception 'Required sales checklist is incomplete'; end if;

  update public.sales_orders
  set status='COMPLETED',completed_at=now(),updated_by=v_uid,updated_at=now()
  where id=p_order_id
  returning * into v_order;

  return to_jsonb(v_order);
end;
$$;

create or replace function private.sale_cancel_impl(
  p_order_id uuid,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_order public.sales_orders%rowtype;
  v_item public.sales_order_items%rowtype;
  v_product public.products%rowtype;
  v_unit_id uuid;
  v_tx record;
  v_affected integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('sale.cancel') then raise exception 'Missing permission sale.cancel'; end if;
  if nullif(btrim(p_reason),'') is null then raise exception 'Cancellation reason is required'; end if;

  select * into v_order from public.sales_orders where id=p_order_id for update;
  if not found then raise exception 'Sales order not found'; end if;
  if v_order.status not in ('DRAFT','CONFIRMED','PAYMENT_PENDING') then
    raise exception 'Order cannot be cancelled in status %',v_order.status;
  end if;
  if v_order.paid_amount<>0 then raise exception 'Refund all payments before cancelling order'; end if;

  if v_order.stock_issued_at is not null then
    for v_item in select * from public.sales_order_items where sales_order_id=p_order_id loop
      select * into v_product from public.products where id=v_item.product_id for update;
      if v_product.track_serial then
        for v_tx in
          select inventory_unit_id
          from public.inventory_transactions
          where reference_type='SALE' and reference_id=p_order_id
            and product_id=v_item.product_id and transaction_type='ISSUE'
            and inventory_unit_id is not null
        loop
          v_unit_id:=v_tx.inventory_unit_id;
          update public.inventory_units
          set status='IN_STOCK',issued_at=null,updated_by=v_uid,updated_at=now()
          where id=v_unit_id and product_id=v_item.product_id and status='OUT';
          get diagnostics v_affected=row_count;
          if v_affected<>1 then raise exception 'Cannot restore inventory unit %',v_unit_id; end if;
          insert into public.inventory_transactions(
            product_id,inventory_unit_id,transaction_type,quantity,reference_type,reference_id,note,occurred_at,created_by
          ) values(
            v_item.product_id,v_unit_id,'RETURN_IN',1,'SALE_CANCEL',p_order_id,'Cancel '||v_order.order_code,now(),v_uid
          );
        end loop;
      else
        insert into public.inventory_transactions(
          product_id,transaction_type,quantity,reference_type,reference_id,note,occurred_at,created_by
        ) values(
          v_item.product_id,'RETURN_IN',v_item.quantity,'SALE_CANCEL',p_order_id,'Cancel '||v_order.order_code,now(),v_uid
        );
      end if;
    end loop;
  end if;

  update public.sales_orders
  set status='CANCELLED',cancelled_at=now(),cancelled_reason=btrim(p_reason),updated_by=v_uid,updated_at=now()
  where id=p_order_id
  returning * into v_order;

  return to_jsonb(v_order);
end;
$$;

-- Public RPC wrappers: permission checks live in private implementations.
create or replace function public.sale_create(p_customer_id uuid,p_note text default null)
returns jsonb language sql set search_path='' as $$
  select private.sale_create_impl(p_customer_id,p_note);
$$;

create or replace function public.sale_update_draft(
  p_order_id uuid,p_customer_id uuid,p_discount_amount numeric default 0,p_note text default null
) returns jsonb language sql set search_path='' as $$
  select private.sale_update_draft_impl(p_order_id,p_customer_id,p_discount_amount,p_note);
$$;

create or replace function public.sale_add_item(
  p_order_id uuid,p_product_id uuid,p_quantity numeric,p_unit_price numeric default null,
  p_discount_amount numeric default 0,p_inventory_unit_ids uuid[] default '{}'::uuid[]
) returns jsonb language sql set search_path='' as $$
  select private.sale_add_item_impl(p_order_id,p_product_id,p_quantity,p_unit_price,p_discount_amount,p_inventory_unit_ids);
$$;

create or replace function public.sale_update_item(
  p_item_id uuid,p_quantity numeric,p_unit_price numeric,p_discount_amount numeric default 0,
  p_inventory_unit_ids uuid[] default '{}'::uuid[]
) returns jsonb language sql set search_path='' as $$
  select private.sale_update_item_impl(p_item_id,p_quantity,p_unit_price,p_discount_amount,p_inventory_unit_ids);
$$;

create or replace function public.sale_remove_item(p_item_id uuid)
returns boolean language sql set search_path='' as $$
  select private.sale_remove_item_impl(p_item_id);
$$;

create or replace function public.sale_set_checklist_item(p_order_id uuid,p_key text,p_checked boolean)
returns jsonb language sql set search_path='' as $$
  select private.sale_set_checklist_item_impl(p_order_id,p_key,p_checked);
$$;

create or replace function public.sale_confirm(p_order_id uuid)
returns jsonb language sql set search_path='' as $$
  select private.sale_confirm_impl(p_order_id);
$$;

create or replace function public.sale_record_payment(
  p_order_id uuid,p_amount numeric,p_payment_method text,p_reference_no text default null,p_note text default null
) returns jsonb language sql set search_path='' as $$
  select private.sale_record_payment_impl(p_order_id,p_amount,p_payment_method,p_reference_no,p_note);
$$;

create or replace function public.sale_refund_payment(p_payment_id uuid,p_refund_note text)
returns jsonb language sql set search_path='' as $$
  select private.sale_refund_payment_impl(p_payment_id,p_refund_note);
$$;

create or replace function public.sale_deliver(p_order_id uuid)
returns jsonb language sql set search_path='' as $$
  select private.sale_deliver_impl(p_order_id);
$$;

create or replace function public.sale_complete(p_order_id uuid)
returns jsonb language sql set search_path='' as $$
  select private.sale_complete_impl(p_order_id);
$$;

create or replace function public.sale_cancel(p_order_id uuid,p_reason text)
returns jsonb language sql set search_path='' as $$
  select private.sale_cancel_impl(p_order_id,p_reason);
$$;

revoke execute on function private.sale_latest_unit_cost(uuid) from public,anon,authenticated;
revoke execute on function private.sale_recalc_order(uuid) from public,anon,authenticated;
revoke execute on function private.sale_set_checklist_system(uuid,text,boolean,uuid) from public,anon,authenticated;
revoke execute on function private.sale_checklist_complete(uuid) from public,anon,authenticated;
revoke execute on function private.sale_create_impl(uuid,text) from public,anon,authenticated;
revoke execute on function private.sale_update_draft_impl(uuid,uuid,numeric,text) from public,anon,authenticated;
revoke execute on function private.sale_add_item_impl(uuid,uuid,numeric,numeric,numeric,uuid[]) from public,anon,authenticated;
revoke execute on function private.sale_update_item_impl(uuid,numeric,numeric,numeric,uuid[]) from public,anon,authenticated;
revoke execute on function private.sale_remove_item_impl(uuid) from public,anon,authenticated;
revoke execute on function private.sale_set_checklist_item_impl(uuid,text,boolean) from public,anon,authenticated;
revoke execute on function private.sale_confirm_impl(uuid) from public,anon,authenticated;
revoke execute on function private.sale_record_payment_impl(uuid,numeric,text,text,text) from public,anon,authenticated;
revoke execute on function private.sale_refund_payment_impl(uuid,text) from public,anon,authenticated;
revoke execute on function private.sale_deliver_impl(uuid) from public,anon,authenticated;
revoke execute on function private.sale_complete_impl(uuid) from public,anon,authenticated;
revoke execute on function private.sale_cancel_impl(uuid,text) from public,anon,authenticated;

revoke execute on function public.sale_create(uuid,text) from public,anon;
revoke execute on function public.sale_update_draft(uuid,uuid,numeric,text) from public,anon;
revoke execute on function public.sale_add_item(uuid,uuid,numeric,numeric,numeric,uuid[]) from public,anon;
revoke execute on function public.sale_update_item(uuid,numeric,numeric,numeric,uuid[]) from public,anon;
revoke execute on function public.sale_remove_item(uuid) from public,anon;
revoke execute on function public.sale_set_checklist_item(uuid,text,boolean) from public,anon;
revoke execute on function public.sale_confirm(uuid) from public,anon;
revoke execute on function public.sale_record_payment(uuid,numeric,text,text,text) from public,anon;
revoke execute on function public.sale_refund_payment(uuid,text) from public,anon;
revoke execute on function public.sale_deliver(uuid) from public,anon;
revoke execute on function public.sale_complete(uuid) from public,anon;
revoke execute on function public.sale_cancel(uuid,text) from public,anon;

grant execute on function public.sale_create(uuid,text) to authenticated;
grant execute on function public.sale_update_draft(uuid,uuid,numeric,text) to authenticated;
grant execute on function public.sale_add_item(uuid,uuid,numeric,numeric,numeric,uuid[]) to authenticated;
grant execute on function public.sale_update_item(uuid,numeric,numeric,numeric,uuid[]) to authenticated;
grant execute on function public.sale_remove_item(uuid) to authenticated;
grant execute on function public.sale_set_checklist_item(uuid,text,boolean) to authenticated;
grant execute on function public.sale_confirm(uuid) to authenticated;
grant execute on function public.sale_record_payment(uuid,numeric,text,text,text) to authenticated;
grant execute on function public.sale_refund_payment(uuid,text) to authenticated;
grant execute on function public.sale_deliver(uuid) to authenticated;
grant execute on function public.sale_complete(uuid) to authenticated;
grant execute on function public.sale_cancel(uuid,text) to authenticated;

create view public.sales_order_summary
with (security_invoker=true)
as
select
  o.id,o.order_code,o.customer_id,c.customer_code,c.full_name as customer_name,c.phone,
  o.status,o.subtotal,o.discount_amount,o.total_amount,o.paid_amount,o.balance_due,
  o.stock_issued_at,o.confirmed_at,o.paid_at,o.delivered_at,o.completed_at,o.cancelled_at,
  o.created_at,o.updated_at,
  (select count(*) from public.sales_order_items i where i.sales_order_id=o.id) as item_count,
  (select count(*) from jsonb_array_elements(o.checklist) x
    where coalesce((x->>'required')::boolean,false)=true) as required_checklist_count,
  (select count(*) from jsonb_array_elements(o.checklist) x
    where coalesce((x->>'required')::boolean,false)=true
      and coalesce((x->>'checked')::boolean,false)=true) as required_checked_count
from public.sales_orders o
join public.customers c on c.id=o.customer_id;

revoke all on public.sales_order_summary from anon,authenticated;
grant select on public.sales_order_summary to authenticated;
