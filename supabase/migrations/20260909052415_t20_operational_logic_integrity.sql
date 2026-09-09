-- HomeTechVN T20 - operational integrity, automatic sale warranty activation,
-- product/warranty scanning, and workflow prerequisite hardening.
-- Locked migrations #1-#38 are unchanged; this is migration #39.

begin;

-- ---------------------------------------------------------------------------
-- Payment and order-total integrity.
-- ---------------------------------------------------------------------------

create unique index ux_payments_method_reference_normalized
on public.payments(payment_method,upper(btrim(reference_no)))
where nullif(btrim(reference_no),'') is not null;

create index idx_inventory_units_asset_tag_lower
on public.inventory_units(lower(asset_tag))
where asset_tag is not null;

create index idx_customer_devices_asset_tag_lower
on public.customer_devices(lower(asset_tag))
where asset_tag is not null;

create index idx_warranties_code_upper
on public.warranties(upper(warranty_code));

create index idx_warranties_serial_lower
on public.warranties(lower(serial_snapshot))
where serial_snapshot is not null;

create or replace function private.sale_payment_ledger_total(p_order_id uuid)
returns numeric
language sql
volatile
security definer
set search_path=''
as $$
  select coalesce(sum(p.amount),0)::numeric(14,2)
  from public.payments p
  where p.sales_order_id=p_order_id
    and p.status='COMPLETED';
$$;

create or replace function private.sale_assert_reference_available(
  p_payment_method text,
  p_reference_no text,
  p_payment_id uuid default null
) returns void
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if nullif(btrim(coalesce(p_reference_no,'')),'') is null then return; end if;

  if exists(
    select 1
    from public.payments p
    where p.payment_method=p_payment_method
      and upper(btrim(p.reference_no))=upper(btrim(p_reference_no))
      and (p_payment_id is null or p.id<>p_payment_id)
  ) then
    raise exception using
      errcode='23505',
      message=format(
        'PAYMENT_REFERENCE_DUPLICATE: Mã giao dịch %s đã được sử dụng cho phương thức %s.',
        btrim(p_reference_no),p_payment_method
      );
  end if;
end;
$$;

create or replace function private.sale_assert_order_total_consistency(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  v_order public.sales_orders%rowtype;
  v_subtotal numeric(14,2);
  v_item_discount numeric(14,2);
  v_expected_total numeric(14,2);
begin
  select * into v_order from public.sales_orders where id=p_order_id;
  if not found then return; end if;

  select coalesce(sum(i.quantity*i.unit_price),0)::numeric(14,2),
         coalesce(sum(i.discount_amount),0)::numeric(14,2)
  into v_subtotal,v_item_discount
  from public.sales_order_items i
  where i.sales_order_id=p_order_id;

  v_expected_total:=greatest(v_subtotal-v_item_discount-v_order.discount_amount,0)::numeric(14,2);
  if v_order.subtotal<>v_subtotal or v_order.total_amount<>v_expected_total then
    raise exception using
      errcode='23514',
      message=format(
        'SALE_TOTAL_MISMATCH: Đơn %s có subtotal/total %s/%s nhưng tính từ dòng hàng phải là %s/%s.',
        v_order.order_code,v_order.subtotal,v_order.total_amount,v_subtotal,v_expected_total
      );
  end if;
end;
$$;

create or replace function private.sale_assert_payment_consistency(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  v_order public.sales_orders%rowtype;
  v_ledger_paid numeric(14,2);
begin
  select * into v_order from public.sales_orders where id=p_order_id;
  if not found then return; end if;

  v_ledger_paid:=private.sale_payment_ledger_total(p_order_id);
  if v_order.paid_amount<>v_ledger_paid then
    raise exception using
      errcode='23514',
      message=format(
        'PAYMENT_LEDGER_MISMATCH: Đơn %s ghi đã thu %s nhưng sổ thanh toán là %s.',
        v_order.order_code,v_order.paid_amount,v_ledger_paid
      );
  end if;

  if v_ledger_paid>v_order.total_amount then
    raise exception using
      errcode='23514',
      message=format(
        'PAYMENT_EXCEEDS_SALE_TOTAL: Đơn %s có tổng thu %s vượt giá bán %s.',
        v_order.order_code,v_ledger_paid,v_order.total_amount
      );
  end if;

  if v_order.status in ('DRAFT','CONFIRMED','CANCELLED') and v_ledger_paid<>0 then
    raise exception 'PAYMENT_STATUS_MISMATCH: Đơn % trạng thái % phải có số thu bằng 0.',v_order.order_code,v_order.status;
  elsif v_order.status='PAYMENT_PENDING'
        and not (v_ledger_paid>0 and v_ledger_paid<v_order.total_amount) then
    raise exception 'PAYMENT_STATUS_MISMATCH: Đơn % PAYMENT_PENDING phải thu lớn hơn 0 và nhỏ hơn giá bán.',v_order.order_code;
  elsif v_order.status in ('PAID','DELIVERED','COMPLETED')
        and v_ledger_paid<>v_order.total_amount then
    raise exception 'PAYMENT_STATUS_MISMATCH: Đơn % trạng thái % phải thu đúng giá bán %.',v_order.order_code,v_order.status,v_order.total_amount;
  end if;
end;
$$;

create or replace function private.sale_order_total_from_item_trigger()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if tg_op='DELETE' then
    perform private.sale_assert_order_total_consistency(old.sales_order_id);
  elsif tg_op='INSERT' then
    perform private.sale_assert_order_total_consistency(new.sales_order_id);
  else
    perform private.sale_assert_order_total_consistency(old.sales_order_id);
    if new.sales_order_id is distinct from old.sales_order_id then
      perform private.sale_assert_order_total_consistency(new.sales_order_id);
    end if;
  end if;
  return null;
end;
$$;

create or replace function private.sale_order_total_from_order_trigger()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  perform private.sale_assert_order_total_consistency(new.id);
  return null;
end;
$$;

create or replace function private.sale_payment_consistency_from_payment_trigger()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if tg_op='DELETE' then
    perform private.sale_assert_payment_consistency(old.sales_order_id);
  elsif tg_op='INSERT' then
    perform private.sale_assert_payment_consistency(new.sales_order_id);
  else
    perform private.sale_assert_payment_consistency(old.sales_order_id);
    if new.sales_order_id is distinct from old.sales_order_id then
      perform private.sale_assert_payment_consistency(new.sales_order_id);
    end if;
  end if;
  return null;
end;
$$;

create or replace function private.sale_payment_consistency_from_order_trigger()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  perform private.sale_assert_payment_consistency(new.id);
  return null;
end;
$$;

drop trigger if exists trg_sales_items_deferred_total_consistency on public.sales_order_items;
create constraint trigger trg_sales_items_deferred_total_consistency
after insert or update or delete on public.sales_order_items
deferrable initially deferred
for each row execute function private.sale_order_total_from_item_trigger();

drop trigger if exists trg_sales_orders_deferred_total_consistency on public.sales_orders;
create constraint trigger trg_sales_orders_deferred_total_consistency
after insert or update on public.sales_orders
deferrable initially deferred
for each row execute function private.sale_order_total_from_order_trigger();

drop trigger if exists trg_payments_deferred_consistency on public.payments;
create constraint trigger trg_payments_deferred_consistency
after insert or update or delete on public.payments
deferrable initially deferred
for each row execute function private.sale_payment_consistency_from_payment_trigger();

drop trigger if exists trg_sales_orders_deferred_payment_consistency on public.sales_orders;
create constraint trigger trg_sales_orders_deferred_payment_consistency
after insert or update on public.sales_orders
deferrable initially deferred
for each row execute function private.sale_payment_consistency_from_order_trigger();

do $$
declare
  v_bad_order text;
begin
  select o.order_code into v_bad_order
  from public.sales_orders o
  where o.subtotal<>(
          select coalesce(sum(i.quantity*i.unit_price),0)::numeric(14,2)
          from public.sales_order_items i where i.sales_order_id=o.id
        )
     or o.total_amount<>greatest(
          (select coalesce(sum(i.quantity*i.unit_price-i.discount_amount),0)::numeric(14,2)
           from public.sales_order_items i where i.sales_order_id=o.id)-o.discount_amount,
          0
        )
     or o.paid_amount<>private.sale_payment_ledger_total(o.id)
     or private.sale_payment_ledger_total(o.id)>o.total_amount
     or (o.status in ('DRAFT','CONFIRMED','CANCELLED') and private.sale_payment_ledger_total(o.id)<>0)
     or (o.status='PAYMENT_PENDING' and not (
          private.sale_payment_ledger_total(o.id)>0
          and private.sale_payment_ledger_total(o.id)<o.total_amount
        ))
     or (o.status in ('PAID','DELIVERED','COMPLETED') and private.sale_payment_ledger_total(o.id)<>o.total_amount)
  order by o.created_at,o.id
  limit 1;

  if v_bad_order is not null then
    raise exception 'T20_PREEXISTING_SALE_INTEGRITY_ERROR: Đơn % phải được đối soát trước migration #39.',v_bad_order;
  end if;
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
  v_ledger_paid numeric(14,2);
  v_balance_due numeric(14,2);
  v_code text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('payment.create') then raise exception 'Missing permission payment.create'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Số tiền thu phải lớn hơn 0'; end if;
  if p_payment_method not in ('CASH','BANK_TRANSFER','CARD','EWALLET','OTHER') then raise exception 'Phương thức thanh toán không hợp lệ'; end if;

  select * into v_order from public.sales_orders where id=p_order_id for update;
  if not found then raise exception 'Không tìm thấy đơn bán'; end if;
  if v_order.status not in ('CONFIRMED','PAYMENT_PENDING') then raise exception 'Đơn không ở bước chờ thanh toán'; end if;

  v_ledger_paid:=private.sale_payment_ledger_total(p_order_id);
  if v_order.paid_amount<>v_ledger_paid then
    raise exception 'PAYMENT_LEDGER_MISMATCH: Số đã thu trên đơn (%) không khớp sổ thanh toán (%).',v_order.paid_amount,v_ledger_paid;
  end if;

  v_balance_due:=(v_order.total_amount-v_ledger_paid)::numeric(14,2);
  if v_balance_due<=0 then raise exception 'Đơn không còn số tiền phải thu'; end if;
  if p_amount<>v_balance_due then
    raise exception 'PAYMENT_AMOUNT_MUST_MATCH_BALANCE: Phải thu đúng số còn lại là %, không được ghi %.',v_balance_due,p_amount;
  end if;

  perform private.sale_assert_reference_available(p_payment_method,p_reference_no,null);
  v_code:=private.next_daily_code('PAYMENT','PAY',null,4);
  insert into public.payments(
    payment_code,sales_order_id,amount,payment_method,status,reference_no,note,paid_at,created_by,updated_by
  ) values(
    v_code,p_order_id,v_balance_due,p_payment_method,'COMPLETED',nullif(btrim(p_reference_no),''),nullif(btrim(p_note),''),now(),v_uid,v_uid
  ) returning * into v_payment;

  update public.sales_orders
  set paid_amount=total_amount,status='PAID',payment_pending_at=coalesce(payment_pending_at,now()),
      paid_at=now(),updated_by=v_uid,updated_at=now()
  where id=p_order_id
  returning * into v_order;

  perform private.sale_set_checklist_system(p_order_id,'payment_confirmed',true,v_uid);
  return jsonb_build_object('payment',to_jsonb(v_payment),'order',to_jsonb(v_order));
end;
$$;

create or replace function private.sale_record_partial_payment_impl(
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
  v_ledger_paid numeric(14,2);
  v_balance_due numeric(14,2);
  v_new_paid numeric(14,2);
  v_code text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('payment.create') then raise exception 'Missing permission payment.create'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Số tiền thu một phần phải lớn hơn 0'; end if;
  if nullif(btrim(p_note),'') is null then raise exception 'Thu một phần bắt buộc ghi lý do/cam kết công nợ'; end if;
  if p_payment_method not in ('CASH','BANK_TRANSFER','CARD','EWALLET','OTHER') then raise exception 'Phương thức thanh toán không hợp lệ'; end if;

  select * into v_order from public.sales_orders where id=p_order_id for update;
  if not found then raise exception 'Không tìm thấy đơn bán'; end if;
  if v_order.status not in ('CONFIRMED','PAYMENT_PENDING') then raise exception 'Đơn không ở bước chờ thanh toán'; end if;

  v_ledger_paid:=private.sale_payment_ledger_total(p_order_id);
  if v_order.paid_amount<>v_ledger_paid then
    raise exception 'PAYMENT_LEDGER_MISMATCH: Số đã thu trên đơn (%) không khớp sổ thanh toán (%).',v_order.paid_amount,v_ledger_paid;
  end if;

  v_balance_due:=(v_order.total_amount-v_ledger_paid)::numeric(14,2);
  if p_amount>=v_balance_due then
    raise exception 'PARTIAL_PAYMENT_MUST_BE_LESS_THAN_BALANCE: Thu một phần phải nhỏ hơn số còn lại %. Muốn thu đủ hãy dùng luồng Thu tiền chuẩn.',v_balance_due;
  end if;

  perform private.sale_assert_reference_available(p_payment_method,p_reference_no,null);
  v_code:=private.next_daily_code('PAYMENT','PAY',null,4);
  insert into public.payments(
    payment_code,sales_order_id,amount,payment_method,status,reference_no,note,paid_at,created_by,updated_by
  ) values(
    v_code,p_order_id,p_amount,p_payment_method,'COMPLETED',nullif(btrim(p_reference_no),''),btrim(p_note),now(),v_uid,v_uid
  ) returning * into v_payment;

  v_new_paid:=(v_ledger_paid+p_amount)::numeric(14,2);
  update public.sales_orders
  set paid_amount=v_new_paid,status='PAYMENT_PENDING',payment_pending_at=coalesce(payment_pending_at,now()),
      paid_at=null,updated_by=v_uid,updated_at=now()
  where id=p_order_id
  returning * into v_order;

  perform private.sale_set_checklist_system(p_order_id,'payment_confirmed',false,v_uid);
  return jsonb_build_object('payment',to_jsonb(v_payment),'order',to_jsonb(v_order));
end;
$$;

create or replace function public.sale_record_partial_payment(
  p_order_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_reference_no text default null,
  p_note text default null
) returns jsonb
language sql
security definer
set search_path=''
as $$
  select private.sale_record_partial_payment_impl(p_order_id,p_amount,p_payment_method,p_reference_no,p_note);
$$;

-- ---------------------------------------------------------------------------
-- Automatic sale warranty activation and coverage consistency.
-- ---------------------------------------------------------------------------

create or replace function private.warranty_activate_sale_impl(p_order_id uuid,p_actor uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_order public.sales_orders%rowtype;
  v_item record;
  v_unit public.inventory_units%rowtype;
  v_unit_id uuid;
  v_device_id uuid;
  v_start date;
  v_end date;
  v_code text;
  v_created integer:=0;
  v_existing integer:=0;
begin
  select * into v_order from public.sales_orders where id=p_order_id for update;
  if not found then raise exception 'Không tìm thấy đơn bán'; end if;
  if v_order.status not in ('DELIVERED','COMPLETED') then
    raise exception 'WARRANTY_ACTIVATION_REQUIRES_HANDOVER: Đơn % chưa bàn giao.',v_order.order_code;
  end if;

  v_start:=coalesce(v_order.delivered_at,v_order.completed_at,now())::date;
  for v_item in
    select i.*,p.track_serial
    from public.sales_order_items i
    join public.products p on p.id=i.product_id
    where i.sales_order_id=p_order_id and i.warranty_months>0
    order by i.created_at,i.id
  loop
    v_end:=(v_start+make_interval(months=>v_item.warranty_months)-interval '1 day')::date;
    if v_item.track_serial then
      if trunc(v_item.quantity)<>v_item.quantity
         or cardinality(v_item.inventory_unit_ids)<>v_item.quantity::integer then
        raise exception 'WARRANTY_SERIAL_ASSIGNMENT_MISMATCH: Dòng % chưa đủ Serial đã bán.',v_item.sku_snapshot;
      end if;

      foreach v_unit_id in array v_item.inventory_unit_ids loop
        select * into strict v_unit
        from public.inventory_units
        where id=v_unit_id and product_id=v_item.product_id;

        if exists(
          select 1 from public.warranties w
          where w.source_type='SALE' and w.source_id=p_order_id
            and w.source_item_id=v_item.id and w.inventory_unit_id=v_unit_id
        ) then
          v_existing:=v_existing+1;
          continue;
        end if;

        select d.id into v_device_id
        from public.customer_devices d
        where d.customer_id=v_order.customer_id
          and lower(coalesce(d.serial_number,''))=lower(v_unit.serial_number)
        order by (d.status='ACTIVE') desc,d.created_at desc
        limit 1;

        v_code:=private.next_daily_code('WARRANTY','WAR',null,4);
        insert into public.warranties(
          warranty_code,customer_id,customer_device_id,source_type,source_id,source_item_id,
          product_id,inventory_unit_id,product_name_snapshot,serial_snapshot,coverage,
          start_date,end_date,status,note,created_by,updated_by
        ) values(
          v_code,v_order.customer_id,v_device_id,'SALE',p_order_id,v_item.id,
          v_item.product_id,v_unit_id,v_item.product_name_snapshot,v_unit.serial_number,
          'Bảo hành tiêu chuẩn theo đơn '||v_order.order_code,v_start,v_end,
          case when v_end<current_date then 'EXPIRED' else 'ACTIVE' end,
          'AUTO_SALE_HANDOVER',p_actor,p_actor
        );
        v_created:=v_created+1;
      end loop;
    else
      if exists(
        select 1 from public.warranties w
        where w.source_type='SALE' and w.source_id=p_order_id
          and w.source_item_id=v_item.id and w.inventory_unit_id is null
      ) then
        v_existing:=v_existing+1;
      else
        v_code:=private.next_daily_code('WARRANTY','WAR',null,4);
        insert into public.warranties(
          warranty_code,customer_id,source_type,source_id,source_item_id,product_id,
          product_name_snapshot,coverage,start_date,end_date,status,note,created_by,updated_by
        ) values(
          v_code,v_order.customer_id,'SALE',p_order_id,v_item.id,v_item.product_id,
          v_item.product_name_snapshot,'Bảo hành tiêu chuẩn theo đơn '||v_order.order_code,
          v_start,v_end,case when v_end<current_date then 'EXPIRED' else 'ACTIVE' end,
          'AUTO_SALE_HANDOVER',p_actor,p_actor
        );
        v_created:=v_created+1;
      end if;
    end if;
  end loop;

  return jsonb_build_object('order_id',p_order_id,'created',v_created,'existing',v_existing);
end;
$$;

create or replace function private.warranty_sale_missing_count(p_order_id uuid)
returns integer
language sql
volatile
security definer
set search_path=''
as $$
  with serial_expected as (
    select i.id as item_id,u.unit_id
    from public.sales_order_items i
    join public.products p on p.id=i.product_id and p.track_serial
    cross join lateral unnest(i.inventory_unit_ids) u(unit_id)
    where i.sales_order_id=p_order_id and i.warranty_months>0
  ), nonserial_expected as (
    select i.id as item_id
    from public.sales_order_items i
    join public.products p on p.id=i.product_id and not p.track_serial
    where i.sales_order_id=p_order_id and i.warranty_months>0
  ), missing as (
    select 1
    from serial_expected e
    where not exists(
      select 1 from public.warranties w
      where w.source_type='SALE' and w.source_id=p_order_id
        and w.source_item_id=e.item_id and w.inventory_unit_id=e.unit_id
    )
    union all
    select 1
    from nonserial_expected e
    where not exists(
      select 1 from public.warranties w
      where w.source_type='SALE' and w.source_id=p_order_id
        and w.source_item_id=e.item_id and w.inventory_unit_id is null
    )
  )
  select count(*)::integer from missing;
$$;

create or replace function private.warranty_assert_sale_coverage(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  v_order public.sales_orders%rowtype;
  v_missing integer;
begin
  select * into v_order from public.sales_orders where id=p_order_id;
  if not found or v_order.status not in ('DELIVERED','COMPLETED') then return; end if;
  v_missing:=private.warranty_sale_missing_count(p_order_id);
  if v_missing<>0 then
    raise exception using
      errcode='23514',
      message=format(
        'WARRANTY_COVERAGE_MISSING: Đơn %s còn %s sản phẩm/Serial chưa có hồ sơ bảo hành.',
        v_order.order_code,v_missing
      );
  end if;
end;
$$;

create or replace function private.warranty_sale_consistency_from_order_trigger()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  perform private.warranty_assert_sale_coverage(new.id);
  return null;
end;
$$;

create or replace function private.warranty_sale_consistency_from_warranty_trigger()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if tg_op<>'INSERT' and old.source_type='SALE' then
    perform private.warranty_assert_sale_coverage(old.source_id);
  end if;
  if tg_op<>'DELETE' and new.source_type='SALE'
     and (tg_op='INSERT' or new.source_id is distinct from old.source_id) then
    perform private.warranty_assert_sale_coverage(new.source_id);
  end if;
  return null;
end;
$$;

-- Existing delivered/completed orders are made consistent once, using their
-- recorded delivery date. This is idempotent and does not touch orders in flight.
do $$
declare
  v_order record;
begin
  for v_order in
    select id,coalesce(updated_by,created_by) as actor
    from public.sales_orders
    where status in ('DELIVERED','COMPLETED')
    order by created_at,id
  loop
    perform private.warranty_activate_sale_impl(v_order.id,v_order.actor);
  end loop;
end;
$$;

drop trigger if exists trg_sales_orders_deferred_warranty_coverage on public.sales_orders;
create constraint trigger trg_sales_orders_deferred_warranty_coverage
after update of status on public.sales_orders
deferrable initially deferred
for each row execute function private.warranty_sale_consistency_from_order_trigger();

drop trigger if exists trg_warranties_deferred_sale_coverage on public.warranties;
create constraint trigger trg_warranties_deferred_sale_coverage
after insert or update or delete on public.warranties
deferrable initially deferred
for each row execute function private.warranty_sale_consistency_from_warranty_trigger();

-- Manual warranty creation now updates the automatically-created entitlement
-- for the same sold item/serial instead of creating a duplicate.
create or replace function private.warranty_create_sale_impl(
  p_sales_order_item_id uuid,
  p_inventory_unit_id uuid default null,
  p_customer_device_id uuid default null,
  p_start_date date default current_date,
  p_warranty_months integer default null,
  p_coverage text default 'Bao hanh tieu chuan',
  p_note text default null
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
  v_unit public.inventory_units%rowtype;
  v_months integer;
  v_code text;
  v_device_id uuid;
  v_end date;
  v_row public.warranties%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if;
  select * into v_item from public.sales_order_items where id=p_sales_order_item_id;
  if not found then raise exception 'Sales order item not found'; end if;
  select * into v_order from public.sales_orders where id=v_item.sales_order_id;
  if v_order.status not in ('DELIVERED','COMPLETED') then raise exception 'Sale must be DELIVERED or COMPLETED before warranty creation'; end if;
  select * into v_product from public.products where id=v_item.product_id;

  if p_customer_device_id is not null and not exists(
    select 1 from public.customer_devices d where d.id=p_customer_device_id and d.customer_id=v_order.customer_id
  ) then raise exception 'Customer device does not belong to sale customer'; end if;

  if v_product.track_serial then
    if p_inventory_unit_id is null then raise exception 'Serialized sale warranty requires inventory_unit_id'; end if;
    if not (p_inventory_unit_id=any(v_item.inventory_unit_ids)) then raise exception 'Inventory unit is not part of this sales item'; end if;
    select * into v_unit from public.inventory_units where id=p_inventory_unit_id and product_id=v_item.product_id;
    if not found then raise exception 'Inventory unit not found'; end if;
  elsif p_inventory_unit_id is not null then
    raise exception 'Non-serialized product must not use inventory_unit_id';
  end if;

  v_months:=coalesce(p_warranty_months,v_item.warranty_months);
  if v_months is null or v_months<=0 then raise exception 'Warranty months must be greater than zero'; end if;
  if p_start_date is null then raise exception 'Warranty start_date is required'; end if;
  if nullif(btrim(p_coverage),'') is null then raise exception 'Warranty coverage is required'; end if;
  v_end:=(p_start_date+make_interval(months=>v_months)-interval '1 day')::date;

  v_device_id:=p_customer_device_id;
  if v_device_id is null and p_inventory_unit_id is not null then
    select d.id into v_device_id
    from public.customer_devices d
    where d.customer_id=v_order.customer_id
      and lower(coalesce(d.serial_number,''))=lower(v_unit.serial_number)
    order by (d.status='ACTIVE') desc,d.created_at desc
    limit 1;
  end if;

  select * into v_row
  from public.warranties w
  where w.source_type='SALE' and w.source_id=v_order.id and w.source_item_id=v_item.id
    and w.inventory_unit_id is not distinct from p_inventory_unit_id
  for update;

  if found then
    if v_row.status='VOID' then raise exception 'Cannot edit a VOID warranty'; end if;
    update public.warranties
    set customer_device_id=coalesce(v_device_id,customer_device_id),
        product_id=v_item.product_id,
        product_name_snapshot=v_item.product_name_snapshot,
        serial_snapshot=case when p_inventory_unit_id is null then null else v_unit.serial_number end,
        coverage=btrim(p_coverage),start_date=p_start_date,end_date=v_end,
        status=case when v_end<current_date then 'EXPIRED' else 'ACTIVE' end,
        note=coalesce(nullif(btrim(p_note),''),note),updated_by=v_uid,updated_at=now()
    where id=v_row.id
    returning * into v_row;
  else
    v_code:=private.next_daily_code('WARRANTY','WAR',null,4);
    insert into public.warranties(
      warranty_code,customer_id,customer_device_id,source_type,source_id,source_item_id,
      product_id,inventory_unit_id,product_name_snapshot,serial_snapshot,coverage,
      start_date,end_date,status,note,created_by,updated_by
    ) values(
      v_code,v_order.customer_id,v_device_id,'SALE',v_order.id,v_item.id,
      v_item.product_id,p_inventory_unit_id,v_item.product_name_snapshot,
      case when p_inventory_unit_id is null then null else v_unit.serial_number end,
      btrim(p_coverage),p_start_date,v_end,
      case when v_end<current_date then 'EXPIRED' else 'ACTIVE' end,
      nullif(btrim(p_note),''),v_uid,v_uid
    ) returning * into v_row;
  end if;
  return to_jsonb(v_row);
end;
$$;

create or replace function private.warranty_activate_sale_manual_impl(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('warranty.manage') and not private.has_permission('sale.update') then
    raise exception 'Missing permission warranty.manage or sale.update';
  end if;
  return private.warranty_activate_sale_impl(p_order_id,v_uid);
end;
$$;

create or replace function public.warranty_activate_sale(p_order_id uuid)
returns jsonb
language sql
security definer
set search_path=''
as $$
  select private.warranty_activate_sale_manual_impl(p_order_id);
$$;

create or replace function private.sale_handover_blockers(p_order_id uuid)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  with order_row as (
    select o.checklist,
           exists(
             select 1 from public.sales_order_items i
             join public.products p on p.id=i.product_id
             where i.sales_order_id=o.id and p.track_serial
           ) as serial_required
    from public.sales_orders o where o.id=p_order_id
  ), missing as (
    select elem->>'key' as item_key,elem->>'label' as label,ord
    from order_row o,
         jsonb_array_elements(o.checklist) with ordinality x(elem,ord)
    where coalesce((elem->>'checked')::boolean,false)=false
      and elem->>'key'<>'customer_delivery_confirmation'
      and (
        coalesce((elem->>'required')::boolean,false)=true
        or (elem->>'key'='serial_numbers' and o.serial_required)
      )
  )
  select coalesce(
    jsonb_agg(jsonb_build_object(
      'code','CHECKLIST_'||upper(item_key),'label',label,
      'department',case when item_key='payment_confirmed' then 'THU NGÂN' else 'BÁN HÀNG / KỸ THUẬT' end,
      'action',case when item_key='payment_confirmed' then 'Thu đủ số tiền còn lại' else 'Hoàn thành mục kiểm tra trước bàn giao' end
    ) order by ord),
    '[]'::jsonb
  )
  from missing;
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
  v_ledger_paid numeric(14,2);
  v_blockers jsonb;
  v_blocker_labels text;
  v_activation jsonb;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('sale.update') then raise exception 'Missing permission sale.update'; end if;
  select * into v_order from public.sales_orders where id=p_order_id for update;
  if not found then raise exception 'Không tìm thấy đơn bán'; end if;
  if v_order.status<>'PAID' then raise exception 'Chỉ được bàn giao khi đơn đã PAID'; end if;

  v_ledger_paid:=private.sale_payment_ledger_total(p_order_id);
  if v_order.paid_amount<>v_order.total_amount or v_ledger_paid<>v_order.total_amount then
    raise exception 'PAYMENT_LEDGER_MISMATCH: Giá bán %, đã thu trên đơn %, sổ thanh toán %. Phải đối soát trước bàn giao.',v_order.total_amount,v_order.paid_amount,v_ledger_paid;
  end if;

  v_blockers:=private.sale_handover_blockers(p_order_id);
  if jsonb_array_length(v_blockers)>0 then
    select string_agg(value->>'label','; ' order by ord) into v_blocker_labels
    from jsonb_array_elements(v_blockers) with ordinality x(value,ord);
    raise exception 'HANDOVER_PREREQUISITES_INCOMPLETE: Chưa thể bàn giao. Cần hoàn thành: %',v_blocker_labels;
  end if;

  update public.sales_orders
  set status='DELIVERED',delivered_at=now(),updated_by=v_uid,updated_at=now()
  where id=p_order_id
  returning * into v_order;

  v_activation:=private.warranty_activate_sale_impl(p_order_id,v_uid);
  perform private.warranty_assert_sale_coverage(p_order_id);
  return to_jsonb(v_order)||jsonb_build_object('warranty_activation',v_activation);
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
  v_ledger_paid numeric(14,2);
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('sale.update') then raise exception 'Missing permission sale.update'; end if;
  select * into v_order from public.sales_orders where id=p_order_id for update;
  if not found then raise exception 'Không tìm thấy đơn bán'; end if;
  if v_order.status<>'DELIVERED' then raise exception 'Chỉ đơn DELIVERED mới được hoàn tất'; end if;

  v_ledger_paid:=private.sale_payment_ledger_total(p_order_id);
  if v_order.paid_amount<>v_order.total_amount or v_ledger_paid<>v_order.total_amount then
    raise exception 'PAYMENT_LEDGER_MISMATCH: Đơn chưa đối soát đủ tiền trước khi hoàn tất';
  end if;
  if not private.sale_checklist_complete(p_order_id) then
    raise exception 'HANDOVER_PREREQUISITES_INCOMPLETE: Checklist bàn giao bắt buộc chưa hoàn thành';
  end if;
  perform private.warranty_assert_sale_coverage(p_order_id);

  update public.sales_orders
  set status='COMPLETED',completed_at=now(),updated_by=v_uid,updated_at=now()
  where id=p_order_id
  returning * into v_order;
  return to_jsonb(v_order);
end;
$$;

-- ---------------------------------------------------------------------------
-- Internal staff scan: serial, asset tag, warranty code, sale code, public QR,
-- and HomeTechVN internal QR all resolve through one permission-checked RPC.
-- ---------------------------------------------------------------------------

create or replace function private.warranty_scan_product_impl(p_query text)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_query text:=btrim(coalesce(p_query,''));
  v_match text[];
  v_token text;
  v_lookup_type text:='REFERENCE';
  v_target_type text;
  v_target_id uuid;
  v_qr_id uuid;
  v_qr_permission text;
  v_matches jsonb:='[]'::jsonb;
  v_match_count integer:=0;
  v_eligible boolean:=false;
  v_result_status text;
  v_target jsonb;
begin
  perform private.fn_assert_active_or_privileged();
  if not private.has_permission('warranty.view') then raise exception 'Missing permission warranty.view'; end if;
  if v_query='' then raise exception 'SCAN_QUERY_REQUIRED: Nhập Serial, Asset Tag, mã đơn, mã bảo hành hoặc quét QR.'; end if;
  if length(v_query)>512 then raise exception 'SCAN_QUERY_TOO_LONG: Dữ liệu quét vượt quá 512 ký tự.'; end if;

  if lower(v_query) ~ '^[0-9a-f]{64}$' then
    v_token:=lower(v_query);
  else
    v_match:=regexp_match(v_query,'/w/([0-9a-f]{64})','i');
    if v_match is not null then v_token:=lower(v_match[1]); end if;
    if v_token is null then
      v_match:=regexp_match(v_query,'[?&]qr=([0-9a-f]{64})','i');
      if v_match is not null then v_token:=lower(v_match[1]); end if;
    end if;
  end if;

  if v_token is not null then
    select w.id into v_target_id from public.warranties w where w.lookup_token=v_token;
    if found then
      v_target_type:='WARRANTY';
      v_lookup_type:='PUBLIC_WARRANTY_QR';
    else
      select q.id,q.resource_type,q.resource_id
      into v_qr_id,v_target_type,v_target_id
      from private.qr_codes q
      where q.token_hash=extensions.digest(v_token,'sha256')
        and q.revoked_at is null and (q.expires_at is null or q.expires_at>now());

      if found then
        if v_target_type not in ('WARRANTY','INVENTORY_UNIT','SALES_ORDER') then
          return jsonb_build_object(
            'found',false,'has_warranty',false,'eligible_for_claim',false,
            'status','UNSUPPORTED_QR_TARGET','lookup_type','INTERNAL_QR','matches','[]'::jsonb
          );
        end if;
        v_qr_permission:=private.qr_required_permission(v_target_type,'VIEW');
        if v_qr_permission is null or not private.has_permission(v_qr_permission) then
          raise exception 'QR target is not permitted for current user';
        end if;
        v_lookup_type:='INTERNAL_QR_'||v_target_type;
        update private.qr_codes set use_count=use_count+1,last_used_at=now() where id=v_qr_id;
        insert into private.qr_action_events(qr_code_id,actor_user_id,event_type,resource_type,resource_id)
        values(v_qr_id,auth.uid(),'RESOLVED',v_target_type,v_target_id);
      end if;
    end if;
  end if;

  if v_target_type is null then
    select w.id into v_target_id from public.warranties w where upper(w.warranty_code)=upper(v_query) limit 1;
    if found then
      v_target_type:='WARRANTY';v_lookup_type:='WARRANTY_CODE';
    else
      select o.id into v_target_id from public.sales_orders o where upper(o.order_code)=upper(v_query) limit 1;
      if found then
        v_target_type:='SALES_ORDER';v_lookup_type:='SALES_ORDER_CODE';
      else
        select u.id into v_target_id
        from public.inventory_units u
        where lower(u.serial_number)=lower(v_query) or lower(coalesce(u.asset_tag,''))=lower(v_query)
        order by u.created_at desc limit 1;
        if found then
          v_target_type:='INVENTORY_UNIT';v_lookup_type:='SERIAL_OR_ASSET_TAG';
        else
          select d.id into v_target_id
          from public.customer_devices d
          where upper(d.device_code)=upper(v_query)
             or lower(coalesce(d.serial_number,''))=lower(v_query)
             or lower(coalesce(d.asset_tag,''))=lower(v_query)
          order by d.created_at desc limit 1;
          if found then v_target_type:='CUSTOMER_DEVICE';v_lookup_type:='CUSTOMER_DEVICE'; end if;
        end if;
      end if;
    end if;
  end if;

  with candidate as (
    select w.*,c.customer_code,c.full_name as customer_name,c.phone,
           coalesce(iu.serial_number,w.serial_snapshot,d.serial_number) as resolved_serial,
           iu.asset_tag,coalesce(p.sku,si.sku_snapshot) as sku,
           coalesce(p.name,w.product_name_snapshot,d.device_type) as product_name,
           so.order_code,ro.repair_code,
           case
             when w.status='VOID' then 'VOID'
             when current_date<w.start_date then 'PENDING'
             when w.status='EXPIRED' or current_date>w.end_date then 'EXPIRED'
             else 'ACTIVE'
           end as effective_status,
           exists(
             select 1 from public.warranty_claims oc
             where oc.warranty_id=w.id and oc.status not in ('CLOSED','REJECTED')
           ) as has_open_claim,
           lc.claim_code as latest_claim_code,lc.status as latest_claim_status
    from public.warranties w
    join public.customers c on c.id=w.customer_id
    left join public.inventory_units iu on iu.id=w.inventory_unit_id
    left join public.products p on p.id=w.product_id
    left join public.customer_devices d on d.id=w.customer_device_id
    left join public.sales_order_items si on si.id=w.source_item_id and w.source_type='SALE'
    left join public.sales_orders so on so.id=w.source_id and w.source_type='SALE'
    left join public.repair_orders ro on ro.id=w.source_id and w.source_type='REPAIR'
    left join lateral (
      select cl.claim_code,cl.status
      from public.warranty_claims cl
      where cl.warranty_id=w.id
      order by cl.created_at desc
      limit 1
    ) lc on true
    where (v_target_type='WARRANTY' and w.id=v_target_id)
       or (v_target_type='INVENTORY_UNIT' and w.inventory_unit_id=v_target_id)
       or (v_target_type='SALES_ORDER' and w.source_type='SALE' and w.source_id=v_target_id)
       or (v_target_type='CUSTOMER_DEVICE' and w.customer_device_id=v_target_id)
       or (v_target_type is null and (
            upper(w.warranty_code)=upper(v_query)
            or w.lookup_token=v_token
            or lower(coalesce(w.serial_snapshot,''))=lower(v_query)
            or lower(coalesce(iu.serial_number,''))=lower(v_query)
            or lower(coalesce(iu.asset_tag,''))=lower(v_query)
            or lower(coalesce(d.serial_number,''))=lower(v_query)
            or lower(coalesce(d.asset_tag,''))=lower(v_query)
            or upper(coalesce(d.device_code,''))=upper(v_query)
            or upper(coalesce(so.order_code,''))=upper(v_query)
          ))
  ), payload as (
    select jsonb_build_object(
      'warranty_id',id,'warranty_code',warranty_code,'effective_status',effective_status,
      'eligible_for_claim',(effective_status='ACTIVE' and not has_open_claim),
      'has_open_claim',has_open_claim,'start_date',start_date,'end_date',end_date,
      'days_remaining',case when effective_status='ACTIVE' then end_date-current_date else 0 end,
      'coverage',coverage,'source_type',source_type,'source_id',source_id,
      'source_code',coalesce(order_code,repair_code),'order_code',order_code,
      'product_id',product_id,'inventory_unit_id',inventory_unit_id,
      'sku',sku,'product_name',product_name,'serial_number',resolved_serial,'asset_tag',asset_tag,
      'customer_id',customer_id,'customer_code',customer_code,'customer_name',customer_name,'phone',phone,
      'latest_claim_code',latest_claim_code,'latest_claim_status',latest_claim_status
    ) as value,created_at,(effective_status='ACTIVE' and not has_open_claim) as can_claim
    from candidate
  )
  select coalesce(jsonb_agg(value order by created_at desc),'[]'::jsonb),
         count(*)::integer,coalesce(bool_or(can_claim),false)
  into v_matches,v_match_count,v_eligible
  from payload;

  if v_match_count>0 then
    v_result_status:=case when v_match_count=1 then v_matches->0->>'effective_status' else 'MULTIPLE' end;
    return jsonb_build_object(
      'found',true,'has_warranty',true,'eligible_for_claim',v_eligible,
      'status',v_result_status,'lookup_type',v_lookup_type,'query',v_query,
      'result_count',v_match_count,'matches',v_matches
    );
  end if;

  if v_target_type='INVENTORY_UNIT' then
    select jsonb_build_object(
      'target_type','INVENTORY_UNIT','inventory_unit_id',u.id,'serial_number',u.serial_number,
      'asset_tag',u.asset_tag,'inventory_status',u.status,'product_id',p.id,'sku',p.sku,
      'product_name',p.name,'order_id',sold.order_id,'order_code',sold.order_code,
      'order_status',sold.order_status,'customer_id',sold.customer_id,'customer_name',sold.customer_name,
      'warranty_months',sold.warranty_months,
      'status',case
        when sold.order_id is null then 'NOT_SOLD'
        when sold.order_status not in ('DELIVERED','COMPLETED') then 'SALE_NOT_DELIVERED'
        when coalesce(sold.warranty_months,0)<=0 then 'NO_WARRANTY_POLICY'
        else 'NOT_REGISTERED'
      end
    ) into v_target
    from public.inventory_units u
    join public.products p on p.id=u.product_id
    left join lateral (
      select o.id as order_id,o.order_code,o.status as order_status,o.customer_id,c.full_name as customer_name,
             i.warranty_months
      from public.sales_order_items i
      join public.sales_orders o on o.id=i.sales_order_id and o.status<>'CANCELLED'
      join public.customers c on c.id=o.customer_id
      where u.id=any(i.inventory_unit_ids)
      order by case o.status when 'COMPLETED' then 1 when 'DELIVERED' then 2 else 3 end,o.created_at desc
      limit 1
    ) sold on true
    where u.id=v_target_id;
  elsif v_target_type='SALES_ORDER' then
    select jsonb_build_object(
      'target_type','SALES_ORDER','order_id',o.id,'order_code',o.order_code,'order_status',o.status,
      'customer_id',o.customer_id,'customer_name',c.full_name,'eligible_item_count',x.eligible_count,
      'status',case
        when o.status not in ('DELIVERED','COMPLETED') then 'SALE_NOT_DELIVERED'
        when x.eligible_count=0 then 'NO_WARRANTY_POLICY'
        else 'NOT_REGISTERED'
      end
    ) into v_target
    from public.sales_orders o
    join public.customers c on c.id=o.customer_id
    cross join lateral (
      select count(*)::integer as eligible_count
      from public.sales_order_items i where i.sales_order_id=o.id and i.warranty_months>0
    ) x
    where o.id=v_target_id;
  elsif v_target_type='CUSTOMER_DEVICE' then
    select jsonb_build_object(
      'target_type','CUSTOMER_DEVICE','device_id',d.id,'device_code',d.device_code,
      'serial_number',d.serial_number,'asset_tag',d.asset_tag,'customer_id',d.customer_id,
      'customer_name',c.full_name,'status','NOT_REGISTERED'
    ) into v_target
    from public.customer_devices d join public.customers c on c.id=d.customer_id
    where d.id=v_target_id;
  end if;

  v_result_status:=coalesce(v_target->>'status','NOT_FOUND');
  return jsonb_build_object(
    'found',(v_target is not null),'has_warranty',false,'eligible_for_claim',false,
    'status',v_result_status,'lookup_type',v_lookup_type,'query',v_query,
    'result_count',0,'target',v_target,'matches','[]'::jsonb
  );
end;
$$;

create or replace function public.warranty_scan_product(p_query text)
returns jsonb
language sql
volatile
security definer
set search_path=''
as $$
  select private.warranty_scan_product_impl(p_query);
$$;

-- ---------------------------------------------------------------------------
-- Repair workflow prerequisites and a whole-system operational snapshot.
-- ---------------------------------------------------------------------------

create or replace function private.repair_transition_prerequisite_guard()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_pending_parts integer;
begin
  if new.status is not distinct from old.status then return new; end if;

  if new.status in ('REPAIRING','QC','READY','RETURNED','COMPLETED') then
    select count(*) into v_pending_parts
    from public.repair_parts p where p.repair_order_id=new.id and p.status='PLANNED';
    if v_pending_parts>0 then
      raise exception 'REPAIR_PREREQUISITES_INCOMPLETE: Còn % vật tư PLANNED chưa xuất kho. Bộ phận kho phải hoàn thành trước bước %.',v_pending_parts,new.status;
    end if;
  end if;

  if new.status in ('REPAIRING','QC','READY','RETURNED','COMPLETED')
     and (new.approved_quote_id is null or new.approved_amount is null) then
    raise exception 'REPAIR_PREREQUISITES_INCOMPLETE: Chưa có báo giá được khách duyệt trước bước %.',new.status;
  end if;
  if new.status in ('QC','READY','RETURNED','COMPLETED') and not exists(
    select 1 from public.repair_diagnostics d where d.repair_order_id=new.id and d.stage='DIAGNOSIS'
  ) then
    raise exception 'REPAIR_PREREQUISITES_INCOMPLETE: Kỹ thuật chưa hoàn thành chẩn đoán trước bước %.',new.status;
  end if;
  if new.status in ('READY','RETURNED','COMPLETED') and new.qc_passed is distinct from true then
    raise exception 'REPAIR_PREREQUISITES_INCOMPLETE: QC phải PASS trước bước %.',new.status;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_repair_transition_prerequisite_guard on public.repair_orders;
create trigger trg_repair_transition_prerequisite_guard
before update of status on public.repair_orders
for each row execute function private.repair_transition_prerequisite_guard();

create or replace function private.operational_integrity_snapshot_impl()
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_order_totals integer;
  v_payment_ledgers integer;
  v_payment_statuses integer;
  v_duplicate_refs integer;
  v_serial_assignments integer;
  v_inventory_states integer;
  v_warranty_gaps integer;
  v_repair_workflows integer;
  v_admin_permission_gaps integer;
begin
  perform private.fn_assert_active_or_privileged();
  if not private.has_permission('audit.view') then raise exception 'Missing permission audit.view'; end if;

  select count(*) into v_order_totals
  from public.sales_orders o
  where o.subtotal<>(select coalesce(sum(i.quantity*i.unit_price),0)::numeric(14,2) from public.sales_order_items i where i.sales_order_id=o.id)
     or o.total_amount<>greatest(
       (select coalesce(sum(i.quantity*i.unit_price-i.discount_amount),0)::numeric(14,2) from public.sales_order_items i where i.sales_order_id=o.id)-o.discount_amount,0
     );

  select count(*) into v_payment_ledgers
  from public.sales_orders o where o.paid_amount<>private.sale_payment_ledger_total(o.id);
  select count(*) into v_payment_statuses
  from public.sales_orders o
  where private.sale_payment_ledger_total(o.id)>o.total_amount
     or (o.status in ('DRAFT','CONFIRMED','CANCELLED') and private.sale_payment_ledger_total(o.id)<>0)
     or (o.status='PAYMENT_PENDING' and not (private.sale_payment_ledger_total(o.id)>0 and private.sale_payment_ledger_total(o.id)<o.total_amount))
     or (o.status in ('PAID','DELIVERED','COMPLETED') and private.sale_payment_ledger_total(o.id)<>o.total_amount);
  select count(*) into v_duplicate_refs from (
    select 1 from public.payments p where nullif(btrim(p.reference_no),'') is not null
    group by p.payment_method,upper(btrim(p.reference_no)) having count(*)>1
  ) x;
  select count(*) into v_serial_assignments
  from public.sales_order_items i
  join public.sales_orders o on o.id=i.sales_order_id and o.status not in ('DRAFT','CANCELLED')
  join public.products p on p.id=i.product_id and p.track_serial
  where trunc(i.quantity)<>i.quantity
     or cardinality(i.inventory_unit_ids)<>i.quantity::integer
     or exists(
       select 1 from unnest(i.inventory_unit_ids) u(unit_id)
       left join public.inventory_units iu on iu.id=u.unit_id and iu.product_id=i.product_id
       where iu.id is null
     );
  select count(*) into v_inventory_states
  from public.sales_order_items i
  join public.sales_orders o on o.id=i.sales_order_id and o.status in ('CONFIRMED','PAYMENT_PENDING','PAID','DELIVERED','COMPLETED')
  join public.products p on p.id=i.product_id and p.track_serial
  cross join lateral unnest(i.inventory_unit_ids) x(unit_id)
  join public.inventory_units u on u.id=x.unit_id
  where u.status<>'OUT';
  select coalesce(sum(private.warranty_sale_missing_count(o.id)),0)::integer into v_warranty_gaps
  from public.sales_orders o where o.status in ('DELIVERED','COMPLETED');
  select count(*) into v_repair_workflows
  from public.repair_orders r
  where (r.status in ('REPAIRING','QC','READY','RETURNED','COMPLETED') and (r.approved_quote_id is null or r.approved_amount is null))
     or (r.status in ('QC','READY','RETURNED','COMPLETED') and not exists(
       select 1 from public.repair_diagnostics d where d.repair_order_id=r.id and d.stage='DIAGNOSIS'
     ))
     or (r.status in ('READY','RETURNED','COMPLETED') and r.qc_passed is distinct from true)
     or (r.status in ('REPAIRING','QC','READY','RETURNED','COMPLETED') and exists(
       select 1 from public.repair_parts p where p.repair_order_id=r.id and p.status='PLANNED'
     ));
  select count(*) into v_admin_permission_gaps
  from public.permissions p
  where not exists(
    select 1 from public.role_permissions rp
    join public.roles r on r.id=rp.role_id
    where r.code='admin' and rp.permission_id=p.id
  );

  return jsonb_build_object(
    'ok',v_order_totals=0 and v_payment_ledgers=0 and v_payment_statuses=0
         and v_duplicate_refs=0 and v_serial_assignments=0 and v_inventory_states=0
         and v_warranty_gaps=0 and v_repair_workflows=0 and v_admin_permission_gaps=0,
    'checked_at',now(),
    'violations',jsonb_build_object(
      'order_totals',v_order_totals,'payment_ledgers',v_payment_ledgers,
      'payment_statuses',v_payment_statuses,'duplicate_payment_references',v_duplicate_refs,
      'serial_assignments',v_serial_assignments,'inventory_sale_states',v_inventory_states,
      'warranty_coverage',v_warranty_gaps,'repair_workflows',v_repair_workflows,
      'admin_permissions',v_admin_permission_gaps
    )
  );
end;
$$;

create or replace function public.operational_integrity_snapshot()
returns jsonb
language sql
volatile
security definer
set search_path=''
as $$
  select private.operational_integrity_snapshot_impl();
$$;

-- Demo Admin always receives every RBAC permission; this does not grant direct
-- table writes to anon/authenticated and does not bypass RLS/RPC checks.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where r.code='admin'
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Explicit execution surface.
-- ---------------------------------------------------------------------------

revoke execute on function private.sale_payment_ledger_total(uuid) from public,anon,authenticated;
revoke execute on function private.sale_assert_reference_available(text,text,uuid) from public,anon,authenticated;
revoke execute on function private.sale_assert_order_total_consistency(uuid) from public,anon,authenticated;
revoke execute on function private.sale_assert_payment_consistency(uuid) from public,anon,authenticated;
revoke execute on function private.sale_order_total_from_item_trigger() from public,anon,authenticated;
revoke execute on function private.sale_order_total_from_order_trigger() from public,anon,authenticated;
revoke execute on function private.sale_payment_consistency_from_payment_trigger() from public,anon,authenticated;
revoke execute on function private.sale_payment_consistency_from_order_trigger() from public,anon,authenticated;
revoke execute on function private.sale_record_partial_payment_impl(uuid,numeric,text,text,text) from public,anon,authenticated;
revoke execute on function private.warranty_activate_sale_impl(uuid,uuid) from public,anon,authenticated;
revoke execute on function private.warranty_sale_missing_count(uuid) from public,anon,authenticated;
revoke execute on function private.warranty_assert_sale_coverage(uuid) from public,anon,authenticated;
revoke execute on function private.warranty_sale_consistency_from_order_trigger() from public,anon,authenticated;
revoke execute on function private.warranty_sale_consistency_from_warranty_trigger() from public,anon,authenticated;
revoke execute on function private.warranty_activate_sale_manual_impl(uuid) from public,anon,authenticated;
revoke execute on function private.sale_handover_blockers(uuid) from public,anon,authenticated;
revoke execute on function private.warranty_scan_product_impl(text) from public,anon,authenticated;
revoke execute on function private.repair_transition_prerequisite_guard() from public,anon,authenticated;
revoke execute on function private.operational_integrity_snapshot_impl() from public,anon,authenticated;

revoke execute on function public.sale_record_partial_payment(uuid,numeric,text,text,text) from public,anon;
revoke execute on function public.warranty_activate_sale(uuid) from public,anon;
revoke execute on function public.warranty_scan_product(text) from public,anon;
revoke execute on function public.operational_integrity_snapshot() from public,anon;

grant execute on function public.sale_record_partial_payment(uuid,numeric,text,text,text) to authenticated;
grant execute on function public.warranty_activate_sale(uuid) to authenticated;
grant execute on function public.warranty_scan_product(text) to authenticated;
grant execute on function public.operational_integrity_snapshot() to authenticated;

commit;
