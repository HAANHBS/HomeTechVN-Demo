create or replace function private.repair_plan_part_impl(p_order_id uuid,p_product_id uuid,p_quantity numeric,p_unit_price numeric default null,p_inventory_unit_ids uuid[] default '{}'::uuid[],p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_status text; v_product public.products%rowtype; v_price numeric(14,2); v_count integer:=coalesce(array_length(p_inventory_unit_ids,1),0); v_distinct integer; v_part public.repair_parts%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.update') then raise exception 'Missing permission repair.update'; end if;
  if p_quantity is null or p_quantity<=0 then raise exception 'quantity must be greater than zero'; end if;
  select status into v_status from public.repair_orders where id=p_order_id for update; if not found then raise exception 'Repair order not found'; end if;
  if v_status not in ('APPROVED','WAITING_PART','REPAIRING') then raise exception 'Parts can only be planned after approval'; end if;
  select * into v_product from public.products where id=p_product_id and is_active=true; if not found then raise exception 'Product not found or inactive'; end if;
  v_price:=coalesce(p_unit_price,v_product.sale_price); if v_price<0 then raise exception 'unit_price cannot be negative'; end if;
  if v_product.track_serial then
    if trunc(p_quantity)<>p_quantity then raise exception 'Serialized quantity must be integer'; end if;
    if v_count not in (0,p_quantity::integer) then raise exception 'inventory_unit_ids must be empty or match quantity'; end if;
    if v_count>0 then
      select count(distinct x) into v_distinct from unnest(p_inventory_unit_ids) u(x) where x is not null;
      if v_distinct<>v_count then raise exception 'inventory_unit_ids contain null/duplicate'; end if;
      if (select count(*) from public.inventory_units u where u.id=any(p_inventory_unit_ids) and u.product_id=p_product_id and u.status='IN_STOCK')<>v_count then raise exception 'One or more serialized units unavailable'; end if;
    end if;
  elsif v_count>0 then raise exception 'Non-serialized part cannot use inventory_unit_ids'; end if;
  insert into public.repair_parts(repair_order_id,product_id,quantity,unit_price,inventory_unit_ids,note,created_by,updated_by)
  values(p_order_id,p_product_id,p_quantity,v_price,coalesce(p_inventory_unit_ids,'{}'::uuid[]),nullif(btrim(p_note),''),v_uid,v_uid)
  on conflict(repair_order_id,product_id) do update
    set quantity=excluded.quantity,unit_price=excluded.unit_price,inventory_unit_ids=excluded.inventory_unit_ids,note=excluded.note,
        status='PLANNED',issued_at=null,returned_at=null,updated_by=v_uid,updated_at=now()
  where public.repair_parts.status in ('PLANNED','RETURNED')
  returning * into v_part;
  if not found then raise exception 'ISSUED repair part must be returned before replanning'; end if;
  return to_jsonb(v_part);
end $$;

create or replace function private.repair_return_part_impl(p_part_id uuid,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_part public.repair_parts%rowtype; v_status text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.update') then raise exception 'Missing permission repair.update'; end if;
  select * into v_part from public.repair_parts where id=p_part_id for update;
  if not found then raise exception 'Repair part not found'; end if;
  if v_part.status<>'ISSUED' then raise exception 'Only ISSUED repair part can be returned'; end if;
  select status into v_status from public.repair_orders where id=v_part.repair_order_id for update;
  if v_status in ('RETURNED','COMPLETED','CANCELLED','CUSTOMER_REJECTED') then raise exception 'Repair order is locked'; end if;
  perform private.repair_restore_part(p_part_id,v_uid,coalesce(nullif(btrim(p_note),''),'Trả vật tư sửa chữa'));
  select * into v_part from public.repair_parts where id=p_part_id;
  return to_jsonb(v_part);
end $$;
