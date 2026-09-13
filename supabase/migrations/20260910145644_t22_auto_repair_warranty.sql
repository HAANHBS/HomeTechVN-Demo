-- HomeTechVN T22 — automatic repair warranties and integrity enforcement.
-- Migrations #1-#40 are locked. This migration is intentionally additive.

begin;

insert into public.settings(key,value,description,is_sensitive)
values(
  'warranty.repair.labor_policy',
  '{"months":3}'::jsonb,
  'Default labor warranty created automatically when a repair is completed.',
  false
)
on conflict (key) do nothing;

create or replace function private.warranty_repair_labor_months()
returns integer
language sql
stable
security definer
set search_path=''
as $$
  select case
    when value->>'months' ~ '^[0-9]+$'
      and (value->>'months')::integer between 1 and 120
      then (value->>'months')::integer
    else 3
  end
  from public.settings
  where key='warranty.repair.labor_policy'
  union all
  select 3
  where not exists(
    select 1 from public.settings where key='warranty.repair.labor_policy'
  )
  limit 1;
$$;

create or replace function private.warranty_activate_repair_impl(p_order_id uuid,p_actor uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_repair public.repair_orders%rowtype;
  v_device public.customer_devices%rowtype;
  v_part record;
  v_unit public.inventory_units%rowtype;
  v_unit_id uuid;
  v_start date;
  v_end date;
  v_code text;
  v_device_name text;
  v_labor_months integer;
  v_created integer:=0;
  v_existing integer:=0;
begin
  select * into v_repair
  from public.repair_orders
  where id=p_order_id
  for update;
  if not found then raise exception 'Không tìm thấy phiếu sửa chữa'; end if;
  if v_repair.status<>'COMPLETED' then
    raise exception 'WARRANTY_ACTIVATION_REQUIRES_REPAIR_COMPLETION: Phiếu % chưa hoàn tất.',v_repair.repair_code;
  end if;

  select * into v_device
  from public.customer_devices
  where id=v_repair.customer_device_id;
  if not found then raise exception 'Không tìm thấy thiết bị của phiếu sửa chữa'; end if;

  v_start:=coalesce(v_repair.completed_at,now())::date;
  v_labor_months:=private.warranty_repair_labor_months();
  v_end:=(v_start+make_interval(months=>v_labor_months)-interval '1 day')::date;
  v_device_name:=nullif(btrim(concat_ws(' ',v_device.device_type,v_device.brand,v_device.model)),'');

  if exists(
    select 1 from public.warranties w
    where w.source_type='REPAIR' and w.source_id=p_order_id
      and w.source_item_id is null and w.inventory_unit_id is null
  ) then
    v_existing:=v_existing+1;
  else
    v_code:=private.next_daily_code('WARRANTY','WAR',null,4);
    insert into public.warranties(
      warranty_code,customer_id,customer_device_id,source_type,source_id,
      product_name_snapshot,serial_snapshot,coverage,start_date,end_date,status,
      note,created_by,updated_by
    ) values(
      v_code,v_repair.customer_id,v_repair.customer_device_id,'REPAIR',p_order_id,
      v_device_name,v_device.serial_number,
      'Bảo hành công sửa chữa theo phiếu '||v_repair.repair_code,
      v_start,v_end,case when v_end<current_date then 'EXPIRED' else 'ACTIVE' end,
      'AUTO_REPAIR_COMPLETION_LABOR',p_actor,p_actor
    );
    v_created:=v_created+1;
  end if;

  for v_part in
    select rp.*,p.track_serial,p.warranty_months,p.name as product_name
    from public.repair_parts rp
    join public.products p on p.id=rp.product_id
    where rp.repair_order_id=p_order_id
      and rp.status='ISSUED'
      and p.warranty_months>0
    order by rp.created_at,rp.id
  loop
    v_end:=(v_start+make_interval(months=>v_part.warranty_months)-interval '1 day')::date;
    if v_part.track_serial then
      if trunc(v_part.quantity)<>v_part.quantity
         or cardinality(v_part.inventory_unit_ids)<>v_part.quantity::integer then
        raise exception 'WARRANTY_REPAIR_SERIAL_ASSIGNMENT_MISMATCH: Linh kiện % chưa đủ Serial đã xuất.',v_part.product_name;
      end if;

      foreach v_unit_id in array v_part.inventory_unit_ids loop
        select * into strict v_unit
        from public.inventory_units
        where id=v_unit_id and product_id=v_part.product_id;

        if exists(
          select 1 from public.warranties w
          where w.source_type='REPAIR' and w.source_id=p_order_id
            and w.source_item_id=v_part.id and w.inventory_unit_id=v_unit_id
        ) then
          v_existing:=v_existing+1;
          continue;
        end if;

        v_code:=private.next_daily_code('WARRANTY','WAR',null,4);
        insert into public.warranties(
          warranty_code,customer_id,customer_device_id,source_type,source_id,source_item_id,
          product_id,inventory_unit_id,product_name_snapshot,serial_snapshot,coverage,
          start_date,end_date,status,note,created_by,updated_by
        ) values(
          v_code,v_repair.customer_id,v_repair.customer_device_id,'REPAIR',p_order_id,v_part.id,
          v_part.product_id,v_unit_id,v_part.product_name,v_unit.serial_number,
          'Bảo hành linh kiện thay thế theo phiếu '||v_repair.repair_code,
          v_start,v_end,case when v_end<current_date then 'EXPIRED' else 'ACTIVE' end,
          'AUTO_REPAIR_COMPLETION_PART',p_actor,p_actor
        );
        v_created:=v_created+1;
      end loop;
    else
      if exists(
        select 1 from public.warranties w
        where w.source_type='REPAIR' and w.source_id=p_order_id
          and w.source_item_id=v_part.id and w.inventory_unit_id is null
      ) then
        v_existing:=v_existing+1;
      else
        v_code:=private.next_daily_code('WARRANTY','WAR',null,4);
        insert into public.warranties(
          warranty_code,customer_id,customer_device_id,source_type,source_id,source_item_id,
          product_id,product_name_snapshot,coverage,start_date,end_date,status,
          note,created_by,updated_by
        ) values(
          v_code,v_repair.customer_id,v_repair.customer_device_id,'REPAIR',p_order_id,v_part.id,
          v_part.product_id,v_part.product_name,
          'Bảo hành linh kiện thay thế theo phiếu '||v_repair.repair_code,
          v_start,v_end,case when v_end<current_date then 'EXPIRED' else 'ACTIVE' end,
          'AUTO_REPAIR_COMPLETION_PART',p_actor,p_actor
        );
        v_created:=v_created+1;
      end if;
    end if;
  end loop;

  return jsonb_build_object(
    'repair_order_id',p_order_id,
    'created',v_created,
    'existing',v_existing,
    'labor_months',v_labor_months
  );
end;
$$;

create or replace function private.warranty_repair_missing_count(p_order_id uuid)
returns integer
language sql
volatile
security definer
set search_path=''
as $$
  with root_expected as (
    select 1 as expected
    from public.repair_orders r
    where r.id=p_order_id and r.status='COMPLETED'
  ), serial_expected as (
    select rp.id as part_id,u.unit_id
    from public.repair_parts rp
    join public.products p on p.id=rp.product_id and p.track_serial and p.warranty_months>0
    cross join lateral unnest(rp.inventory_unit_ids) u(unit_id)
    where rp.repair_order_id=p_order_id and rp.status='ISSUED'
  ), nonserial_expected as (
    select rp.id as part_id
    from public.repair_parts rp
    join public.products p on p.id=rp.product_id and not p.track_serial and p.warranty_months>0
    where rp.repair_order_id=p_order_id and rp.status='ISSUED'
  ), missing as (
    select 1
    from root_expected
    where not exists(
      select 1 from public.warranties w
      where w.source_type='REPAIR' and w.source_id=p_order_id
        and w.source_item_id is null and w.inventory_unit_id is null
    )
    union all
    select 1
    from serial_expected e
    where not exists(
      select 1 from public.warranties w
      where w.source_type='REPAIR' and w.source_id=p_order_id
        and w.source_item_id=e.part_id and w.inventory_unit_id=e.unit_id
    )
    union all
    select 1
    from nonserial_expected e
    where not exists(
      select 1 from public.warranties w
      where w.source_type='REPAIR' and w.source_id=p_order_id
        and w.source_item_id=e.part_id and w.inventory_unit_id is null
    )
  )
  select count(*)::integer from missing;
$$;

create or replace function private.warranty_assert_repair_coverage(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  v_repair public.repair_orders%rowtype;
  v_missing integer;
begin
  select * into v_repair from public.repair_orders where id=p_order_id;
  if not found or v_repair.status<>'COMPLETED' then return; end if;
  v_missing:=private.warranty_repair_missing_count(p_order_id);
  if v_missing<>0 then
    raise exception using
      errcode='23514',
      message=format(
        'WARRANTY_REPAIR_COVERAGE_MISSING: Phiếu %s còn %s quyền lợi công/linh kiện chưa có hồ sơ bảo hành.',
        v_repair.repair_code,v_missing
      );
  end if;
end;
$$;

create or replace function private.warranty_repair_auto_from_order_trigger()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if new.status='COMPLETED' and new.status is distinct from old.status then
    perform private.warranty_activate_repair_impl(
      new.id,
      coalesce(new.updated_by,new.created_by,auth.uid())
    );
    perform private.warranty_assert_repair_coverage(new.id);
  end if;
  return new;
end;
$$;

create or replace function private.warranty_repair_consistency_from_order_trigger()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  perform private.warranty_assert_repair_coverage(new.id);
  return null;
end;
$$;

create or replace function private.warranty_repair_consistency_from_warranty_trigger()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if tg_op<>'INSERT' and old.source_type='REPAIR' then
    perform private.warranty_assert_repair_coverage(old.source_id);
  end if;
  if tg_op<>'DELETE' and new.source_type='REPAIR'
     and (tg_op='INSERT' or new.source_id is distinct from old.source_id) then
    perform private.warranty_assert_repair_coverage(new.source_id);
  end if;
  return null;
end;
$$;

drop trigger if exists trg_repair_orders_auto_warranty on public.repair_orders;
create trigger trg_repair_orders_auto_warranty
after update of status on public.repair_orders
for each row execute function private.warranty_repair_auto_from_order_trigger();

drop trigger if exists trg_repair_orders_deferred_warranty_coverage on public.repair_orders;
create constraint trigger trg_repair_orders_deferred_warranty_coverage
after update of status on public.repair_orders
deferrable initially deferred
for each row execute function private.warranty_repair_consistency_from_order_trigger();

drop trigger if exists trg_warranties_deferred_repair_coverage on public.warranties;
create constraint trigger trg_warranties_deferred_repair_coverage
after insert or update or delete on public.warranties
deferrable initially deferred
for each row execute function private.warranty_repair_consistency_from_warranty_trigger();

-- Backfill completed repairs once. The function is idempotent, so an existing
-- manually-created labor warranty is retained and only missing coverage is added.
do $$
declare
  v_repair record;
begin
  for v_repair in
    select id,coalesce(updated_by,created_by) as actor
    from public.repair_orders
    where status='COMPLETED'
    order by created_at,id
  loop
    perform private.warranty_activate_repair_impl(v_repair.id,v_repair.actor);
  end loop;
end;
$$;

-- The legacy admin RPC becomes an adjustment of the automatically-created
-- labor entitlement, never a second warranty for the same repair.
create or replace function private.warranty_create_repair_impl(
  p_repair_order_id uuid,
  p_start_date date default current_date,
  p_warranty_months integer default 3,
  p_coverage text default 'Bao hanh dich vu sua chua',
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_repair public.repair_orders%rowtype;
  v_row public.warranties%rowtype;
  v_end date;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if;
  select * into v_repair from public.repair_orders where id=p_repair_order_id;
  if not found then raise exception 'Repair order not found'; end if;
  if v_repair.status<>'COMPLETED' then raise exception 'Repair must be COMPLETED before warranty creation'; end if;
  if p_warranty_months is null or p_warranty_months<=0 or p_warranty_months>120 then
    raise exception 'Warranty months must be between 1 and 120';
  end if;
  if p_start_date is null then raise exception 'Warranty start_date is required'; end if;
  if nullif(btrim(p_coverage),'') is null then raise exception 'Warranty coverage is required'; end if;

  perform private.warranty_activate_repair_impl(p_repair_order_id,v_uid);
  v_end:=(p_start_date+make_interval(months=>p_warranty_months)-interval '1 day')::date;
  update public.warranties
  set coverage=btrim(p_coverage),start_date=p_start_date,end_date=v_end,
      status=case when v_end<current_date then 'EXPIRED' else 'ACTIVE' end,
      note=coalesce(nullif(btrim(p_note),''),note),updated_by=v_uid,updated_at=now()
  where source_type='REPAIR' and source_id=p_repair_order_id
    and source_item_id is null and inventory_unit_id is null
  returning * into v_row;
  if not found then raise exception 'Automatic repair warranty was not created'; end if;
  return to_jsonb(v_row);
end;
$$;

create or replace function public.warranty_create_repair(
  p_repair_order_id uuid,
  p_start_date date default current_date,
  p_warranty_months integer default 3,
  p_coverage text default 'Bao hanh dich vu sua chua',
  p_note text default null
) returns jsonb
language sql
security definer
set search_path=''
as $$
  select private.warranty_create_repair_impl(
    p_repair_order_id,p_start_date,p_warranty_months,p_coverage,p_note
  );
$$;

-- Preserve T20's verified integrity checks and extend their result with repair
-- warranty coverage, without duplicating or weakening the existing assertions.
alter function private.operational_integrity_snapshot_impl()
rename to operational_integrity_t20_snapshot_impl;

create or replace function private.operational_integrity_snapshot_impl()
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_snapshot jsonb;
  v_repair_warranty_gaps integer;
begin
  v_snapshot:=private.operational_integrity_t20_snapshot_impl();
  select coalesce(sum(private.warranty_repair_missing_count(r.id)),0)::integer
  into v_repair_warranty_gaps
  from public.repair_orders r
  where r.status='COMPLETED';

  v_snapshot:=jsonb_set(
    v_snapshot,
    '{violations,repair_warranty_coverage}',
    to_jsonb(v_repair_warranty_gaps),
    true
  );
  v_snapshot:=jsonb_set(
    v_snapshot,
    '{ok}',
    to_jsonb(coalesce((v_snapshot->>'ok')::boolean,false) and v_repair_warranty_gaps=0),
    true
  );
  return v_snapshot;
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

revoke execute on function private.warranty_repair_labor_months() from public,anon,authenticated;
revoke execute on function private.warranty_activate_repair_impl(uuid,uuid) from public,anon,authenticated;
revoke execute on function private.warranty_repair_missing_count(uuid) from public,anon,authenticated;
revoke execute on function private.warranty_assert_repair_coverage(uuid) from public,anon,authenticated;
revoke execute on function private.warranty_repair_auto_from_order_trigger() from public,anon,authenticated;
revoke execute on function private.warranty_repair_consistency_from_order_trigger() from public,anon,authenticated;
revoke execute on function private.warranty_repair_consistency_from_warranty_trigger() from public,anon,authenticated;
revoke execute on function private.warranty_create_repair_impl(uuid,date,integer,text,text) from public,anon,authenticated;
revoke execute on function private.operational_integrity_t20_snapshot_impl() from public,anon,authenticated;
revoke execute on function private.operational_integrity_snapshot_impl() from public,anon,authenticated;

revoke execute on function public.warranty_create_repair(uuid,date,integer,text,text) from public,anon;
revoke execute on function public.operational_integrity_snapshot() from public,anon;
grant execute on function public.warranty_create_repair(uuid,date,integer,text,text) to authenticated;
grant execute on function public.operational_integrity_snapshot() to authenticated;

commit;

