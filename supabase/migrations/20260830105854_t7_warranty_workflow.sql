create or replace function private.warranty_mask_phone(p_phone text)
returns text language sql immutable security invoker set search_path='' as $$
  select case when nullif(regexp_replace(coalesce(p_phone,''),'\D','','g'),'') is null then null when length(regexp_replace(p_phone,'\D','','g'))<7 then '***' else left(regexp_replace(p_phone,'\D','','g'),3)||'***'||right(regexp_replace(p_phone,'\D','','g'),3) end;
$$;
create or replace function private.warranty_mask_serial(p_serial text)
returns text language sql immutable security invoker set search_path='' as $$
  select case when nullif(btrim(coalesce(p_serial,'')),'') is null then null when length(btrim(p_serial))<=6 then '***' else left(btrim(p_serial),3)||'****'||right(btrim(p_serial),3) end;
$$;
create or replace function private.warranty_public_payload_impl(p_token text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v jsonb;
begin
  if p_token is null or length(p_token)<>64 or p_token !~ '^[0-9a-f]{64}$' then return jsonb_build_object('found',false); end if;
  select jsonb_build_object('found',true,'warranty_code',w.warranty_code,'status',case when w.status='VOID' then 'VOID' when current_date>w.end_date then 'EXPIRED' else 'ACTIVE' end,'start_date',w.start_date,'end_date',w.end_date,'coverage',w.coverage,'product',coalesce(w.product_name_snapshot,nullif(concat_ws(' ',d.device_type,d.brand,d.model),'')),'serial_masked',private.warranty_mask_serial(coalesce(w.serial_snapshot,d.serial_number)),'phone_masked',private.warranty_mask_phone(c.phone),'latest_claim_status',(select cl.status from public.warranty_claims cl where cl.warranty_id=w.id order by cl.created_at desc limit 1)) into v
  from public.warranties w join public.customers c on c.id=w.customer_id left join public.customer_devices d on d.id=w.customer_device_id where w.lookup_token=p_token;
  return coalesce(v,jsonb_build_object('found',false));
end; $$;
revoke execute on function private.warranty_public_payload_impl(text) from public,anon,authenticated;
grant execute on function private.warranty_public_payload_impl(text) to service_role;

create or replace function private.warranty_create_sale_impl(
  p_sales_order_item_id uuid,p_inventory_unit_id uuid default null,p_customer_device_id uuid default null,
  p_start_date date default current_date,p_warranty_months integer default null,
  p_coverage text default 'Bao hanh tieu chuan',p_note text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid(); v_item public.sales_order_items%rowtype; v_order public.sales_orders%rowtype;
  v_product public.products%rowtype; v_unit public.inventory_units%rowtype; v_months integer; v_code text; v_row public.warranties%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if;
  select * into v_item from public.sales_order_items where id=p_sales_order_item_id;
  if not found then raise exception 'Sales order item not found'; end if;
  select * into v_order from public.sales_orders where id=v_item.sales_order_id;
  if v_order.status not in ('DELIVERED','COMPLETED') then raise exception 'Sale must be DELIVERED or COMPLETED before warranty creation'; end if;
  select * into v_product from public.products where id=v_item.product_id;
  if p_customer_device_id is not null and not exists(select 1 from public.customer_devices d where d.id=p_customer_device_id and d.customer_id=v_order.customer_id) then raise exception 'Customer device does not belong to sale customer'; end if;
  if v_product.track_serial then
    if p_inventory_unit_id is null then raise exception 'Serialized sale warranty requires inventory_unit_id'; end if;
    if not (p_inventory_unit_id=any(v_item.inventory_unit_ids)) then raise exception 'Inventory unit is not part of this sales item'; end if;
    select * into v_unit from public.inventory_units where id=p_inventory_unit_id and product_id=v_item.product_id;
    if not found then raise exception 'Inventory unit not found'; end if;
  elsif p_inventory_unit_id is not null then raise exception 'Non-serialized product must not use inventory_unit_id'; end if;
  v_months:=coalesce(p_warranty_months,v_item.warranty_months);
  if v_months is null or v_months<=0 then raise exception 'Warranty months must be greater than zero'; end if;
  if p_start_date is null then raise exception 'Warranty start_date is required'; end if;
  if nullif(btrim(p_coverage),'') is null then raise exception 'Warranty coverage is required'; end if;
  v_code:=private.next_daily_code('WARRANTY','WAR',null,4);
  insert into public.warranties(warranty_code,customer_id,customer_device_id,source_type,source_id,source_item_id,product_id,inventory_unit_id,product_name_snapshot,serial_snapshot,coverage,start_date,end_date,status,note,created_by,updated_by)
  values(v_code,v_order.customer_id,p_customer_device_id,'SALE',v_order.id,v_item.id,v_item.product_id,p_inventory_unit_id,v_item.product_name_snapshot,case when p_inventory_unit_id is null then null else v_unit.serial_number end,btrim(p_coverage),p_start_date,(p_start_date+make_interval(months=>v_months)-interval '1 day')::date,'ACTIVE',nullif(btrim(p_note),''),v_uid,v_uid)
  returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.warranty_create_repair_impl(
  p_repair_order_id uuid,p_start_date date default current_date,p_warranty_months integer default 3,
  p_coverage text default 'Bao hanh dich vu sua chua',p_note text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_repair public.repair_orders%rowtype; v_device public.customer_devices%rowtype; v_code text; v_row public.warranties%rowtype; v_name text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if;
  select * into v_repair from public.repair_orders where id=p_repair_order_id;
  if not found then raise exception 'Repair order not found'; end if;
  if v_repair.status<>'COMPLETED' then raise exception 'Repair must be COMPLETED before warranty creation'; end if;
  if p_warranty_months is null or p_warranty_months<=0 then raise exception 'Warranty months must be greater than zero'; end if;
  if p_start_date is null then raise exception 'Warranty start_date is required'; end if;
  if nullif(btrim(p_coverage),'') is null then raise exception 'Warranty coverage is required'; end if;
  select * into v_device from public.customer_devices where id=v_repair.customer_device_id;
  v_name:=nullif(btrim(concat_ws(' ',v_device.device_type,v_device.brand,v_device.model)),'');
  v_code:=private.next_daily_code('WARRANTY','WAR',null,4);
  insert into public.warranties(warranty_code,customer_id,customer_device_id,source_type,source_id,product_name_snapshot,serial_snapshot,coverage,start_date,end_date,status,note,created_by,updated_by)
  values(v_code,v_repair.customer_id,v_repair.customer_device_id,'REPAIR',v_repair.id,v_name,v_device.serial_number,btrim(p_coverage),p_start_date,(p_start_date+make_interval(months=>p_warranty_months)-interval '1 day')::date,'ACTIVE',nullif(btrim(p_note),''),v_uid,v_uid)
  returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.warranty_void_impl(p_warranty_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.warranties%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if;
  if nullif(btrim(p_reason),'') is null then raise exception 'Void reason is required'; end if;
  select * into v_row from public.warranties where id=p_warranty_id for update;
  if not found then raise exception 'Warranty not found'; end if;
  if v_row.status='VOID' then raise exception 'Warranty already VOID'; end if;
  if exists(select 1 from public.warranty_claims where warranty_id=p_warranty_id and status not in ('CLOSED','REJECTED')) then raise exception 'Cannot void warranty with active claim'; end if;
  update public.warranties set status='VOID',void_reason=btrim(p_reason),updated_by=v_uid,updated_at=now() where id=p_warranty_id returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.warranty_claim_transition(p_claim_id uuid,p_to_status text,p_note text,p_actor uuid)
returns public.warranty_claims language plpgsql security definer set search_path='' as $$
declare v public.warranty_claims%rowtype; v_from text;
begin
  select * into v from public.warranty_claims where id=p_claim_id for update;
  if not found then raise exception 'Warranty claim not found'; end if;
  v_from:=v.status;
  if not ((v_from='RECEIVED' and p_to_status='CHECKING') or
          (v_from='CHECKING' and p_to_status in ('APPROVED','REJECTED')) or
          (v_from='APPROVED' and p_to_status='IN_SERVICE') or
          (v_from='IN_SERVICE' and p_to_status='QC') or
          (v_from='QC' and p_to_status in ('IN_SERVICE','READY')) or
          (v_from='READY' and p_to_status='RETURNED') or
          (v_from='RETURNED' and p_to_status='CLOSED') or
          (v_from='REJECTED' and p_to_status='CLOSED')) then
    raise exception 'Invalid warranty claim transition % -> %',v_from,p_to_status;
  end if;
  update public.warranty_claims set
    status=p_to_status,
    checking_at=case when p_to_status='CHECKING' then now() else checking_at end,
    approved_at=case when p_to_status='APPROVED' then now() else approved_at end,
    rejected_at=case when p_to_status='REJECTED' then now() else rejected_at end,
    in_service_at=case when p_to_status='IN_SERVICE' then now() else in_service_at end,
    qc_at=case when p_to_status='QC' then now() else qc_at end,
    ready_at=case when p_to_status='READY' then now() else ready_at end,
    returned_at=case when p_to_status='RETURNED' then now() else returned_at end,
    closed_at=case when p_to_status='CLOSED' then now() else closed_at end,
    updated_by=p_actor,updated_at=now()
  where id=p_claim_id returning * into v;
  insert into public.warranty_status_history(warranty_claim_id,from_status,to_status,note,changed_by)
  values(p_claim_id,v_from,p_to_status,nullif(btrim(p_note),''),p_actor);
  return v;
end; $$;

create or replace function private.warranty_claim_create_impl(p_warranty_id uuid,p_issue_description text,p_intake_condition text default null,p_customer_request text default null,p_assigned_technician_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_w public.warranties%rowtype; v_code text; v_row public.warranty_claims%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if;
  if nullif(btrim(p_issue_description),'') is null then raise exception 'Issue description is required'; end if;
  select * into v_w from public.warranties where id=p_warranty_id for update;
  if not found then raise exception 'Warranty not found'; end if;
  if v_w.status='VOID' then raise exception 'Warranty is VOID'; end if;
  if current_date<v_w.start_date then raise exception 'Warranty has not started'; end if;
  if current_date>v_w.end_date or v_w.status='EXPIRED' then raise exception 'Warranty is EXPIRED'; end if;
  if p_assigned_technician_id is not null and not exists(select 1 from public.profiles p join public.roles r on r.id=p.role_id where p.id=p_assigned_technician_id and p.is_active and r.code='technician') then raise exception 'Assigned technician is invalid'; end if;
  if exists(select 1 from public.warranty_claims where warranty_id=p_warranty_id and status not in ('CLOSED','REJECTED')) then raise exception 'Warranty already has an active claim'; end if;
  v_code:=private.next_daily_code('WARRANTY_CLAIM','WCL',null,4);
  insert into public.warranty_claims(claim_code,warranty_id,status,issue_description,intake_condition,customer_request,assigned_technician_id,created_by,updated_by)
  values(v_code,p_warranty_id,'RECEIVED',btrim(p_issue_description),nullif(btrim(p_intake_condition),''),nullif(btrim(p_customer_request),''),p_assigned_technician_id,v_uid,v_uid)
  returning * into v_row;
  insert into public.warranty_status_history(warranty_claim_id,from_status,to_status,note,changed_by)
  values(v_row.id,null,'RECEIVED','Tiep nhan yeu cau bao hanh',v_uid);
  return to_jsonb(v_row);
end; $$;

create or replace function private.warranty_claim_start_checking_impl(p_claim_id uuid,p_assigned_technician_id uuid default null,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v public.warranty_claims%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if;
  if p_assigned_technician_id is not null and not exists(select 1 from public.profiles p join public.roles r on r.id=p.role_id where p.id=p_assigned_technician_id and p.is_active and r.code='technician') then raise exception 'Assigned technician is invalid'; end if;
  if p_assigned_technician_id is not null then update public.warranty_claims set assigned_technician_id=p_assigned_technician_id,updated_by=v_uid where id=p_claim_id; end if;
  v:=private.warranty_claim_transition(p_claim_id,'CHECKING',p_note,v_uid);
  return to_jsonb(v);
end; $$;

create or replace function private.warranty_claim_decide_impl(p_claim_id uuid,p_approved boolean,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v public.warranty_claims%rowtype; v_to text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if;
  if p_approved is null then raise exception 'Decision is required'; end if;
  v_to:=case when p_approved then 'APPROVED' else 'REJECTED' end;
  update public.warranty_claims set decision_note=nullif(btrim(p_note),''),updated_by=v_uid where id=p_claim_id;
  v:=private.warranty_claim_transition(p_claim_id,v_to,p_note,v_uid);
  return to_jsonb(v);
end; $$;

create or replace function private.warranty_claim_start_service_impl(p_claim_id uuid,p_service_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v public.warranty_claims%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if;
  update public.warranty_claims set service_note=nullif(btrim(p_service_note),''),updated_by=v_uid where id=p_claim_id;
  v:=private.warranty_claim_transition(p_claim_id,'IN_SERVICE',p_service_note,v_uid);
  return to_jsonb(v);
end; $$;

create or replace function private.warranty_claim_update_service_impl(p_claim_id uuid,p_service_note text,p_resolution text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v public.warranty_claims%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if;
  if nullif(btrim(p_service_note),'') is null then raise exception 'Service note is required'; end if;
  select * into v from public.warranty_claims where id=p_claim_id for update;
  if not found then raise exception 'Warranty claim not found'; end if;
  if v.status<>'IN_SERVICE' then raise exception 'Service note can only be updated in IN_SERVICE'; end if;
  update public.warranty_claims set service_note=btrim(p_service_note),resolution=nullif(btrim(p_resolution),''),updated_by=v_uid,updated_at=now() where id=p_claim_id returning * into v;
  return to_jsonb(v);
end; $$;

create or replace function private.warranty_claim_start_qc_impl(p_claim_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v public.warranty_claims%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if;
  v:=private.warranty_claim_transition(p_claim_id,'QC',null,v_uid);
  return to_jsonb(v);
end; $$;

create or replace function private.warranty_claim_record_qc_impl(p_claim_id uuid,p_passed boolean,p_note text,p_resolution text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v public.warranty_claims%rowtype; v_to text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if;
  if p_passed is null then raise exception 'QC result is required'; end if;
  if nullif(btrim(p_note),'') is null then raise exception 'QC note is required'; end if;
  select * into v from public.warranty_claims where id=p_claim_id for update;
  if not found then raise exception 'Warranty claim not found'; end if;
  if v.status<>'QC' then raise exception 'Claim is not in QC'; end if;
  update public.warranty_claims set qc_passed=p_passed,qc_note=btrim(p_note),resolution=coalesce(nullif(btrim(p_resolution),''),resolution),updated_by=v_uid,updated_at=now() where id=p_claim_id;
  v_to:=case when p_passed then 'READY' else 'IN_SERVICE' end;
  v:=private.warranty_claim_transition(p_claim_id,v_to,p_note,v_uid);
  return to_jsonb(v);
end; $$;

create or replace function private.warranty_claim_mark_returned_impl(p_claim_id uuid,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v public.warranty_claims%rowtype;
begin if v_uid is null then raise exception 'Authentication required'; end if; if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if; v:=private.warranty_claim_transition(p_claim_id,'RETURNED',p_note,v_uid); return to_jsonb(v); end; $$;
create or replace function private.warranty_claim_close_impl(p_claim_id uuid,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v public.warranty_claims%rowtype;
begin if v_uid is null then raise exception 'Authentication required'; end if; if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if; v:=private.warranty_claim_transition(p_claim_id,'CLOSED',p_note,v_uid); return to_jsonb(v); end; $$;

create or replace function public.warranty_create_sale(p_sales_order_item_id uuid,p_inventory_unit_id uuid default null,p_customer_device_id uuid default null,p_start_date date default current_date,p_warranty_months integer default null,p_coverage text default 'Bao hanh tieu chuan',p_note text default null) returns jsonb language sql set search_path='' as $$ select private.warranty_create_sale_impl(p_sales_order_item_id,p_inventory_unit_id,p_customer_device_id,p_start_date,p_warranty_months,p_coverage,p_note); $$;
create or replace function public.warranty_create_repair(p_repair_order_id uuid,p_start_date date default current_date,p_warranty_months integer default 3,p_coverage text default 'Bao hanh dich vu sua chua',p_note text default null) returns jsonb language sql set search_path='' as $$ select private.warranty_create_repair_impl(p_repair_order_id,p_start_date,p_warranty_months,p_coverage,p_note); $$;
create or replace function public.warranty_void(p_warranty_id uuid,p_reason text) returns jsonb language sql set search_path='' as $$ select private.warranty_void_impl(p_warranty_id,p_reason); $$;
create or replace function public.warranty_claim_create(p_warranty_id uuid,p_issue_description text,p_intake_condition text default null,p_customer_request text default null,p_assigned_technician_id uuid default null) returns jsonb language sql set search_path='' as $$ select private.warranty_claim_create_impl(p_warranty_id,p_issue_description,p_intake_condition,p_customer_request,p_assigned_technician_id); $$;
create or replace function public.warranty_claim_start_checking(p_claim_id uuid,p_assigned_technician_id uuid default null,p_note text default null) returns jsonb language sql set search_path='' as $$ select private.warranty_claim_start_checking_impl(p_claim_id,p_assigned_technician_id,p_note); $$;
create or replace function public.warranty_claim_decide(p_claim_id uuid,p_approved boolean,p_note text default null) returns jsonb language sql set search_path='' as $$ select private.warranty_claim_decide_impl(p_claim_id,p_approved,p_note); $$;
create or replace function public.warranty_claim_start_service(p_claim_id uuid,p_service_note text default null) returns jsonb language sql set search_path='' as $$ select private.warranty_claim_start_service_impl(p_claim_id,p_service_note); $$;
create or replace function public.warranty_claim_update_service(p_claim_id uuid,p_service_note text,p_resolution text default null) returns jsonb language sql set search_path='' as $$ select private.warranty_claim_update_service_impl(p_claim_id,p_service_note,p_resolution); $$;
create or replace function public.warranty_claim_start_qc(p_claim_id uuid) returns jsonb language sql set search_path='' as $$ select private.warranty_claim_start_qc_impl(p_claim_id); $$;
create or replace function public.warranty_claim_record_qc(p_claim_id uuid,p_passed boolean,p_note text,p_resolution text default null) returns jsonb language sql set search_path='' as $$ select private.warranty_claim_record_qc_impl(p_claim_id,p_passed,p_note,p_resolution); $$;
create or replace function public.warranty_claim_mark_returned(p_claim_id uuid,p_note text default null) returns jsonb language sql set search_path='' as $$ select private.warranty_claim_mark_returned_impl(p_claim_id,p_note); $$;
create or replace function public.warranty_claim_close(p_claim_id uuid,p_note text default null) returns jsonb language sql set search_path='' as $$ select private.warranty_claim_close_impl(p_claim_id,p_note); $$;

revoke execute on all functions in schema private from anon;
revoke execute on function public.warranty_create_sale(uuid,uuid,uuid,date,integer,text,text) from public,anon;
revoke execute on function public.warranty_create_repair(uuid,date,integer,text,text) from public,anon;
revoke execute on function public.warranty_void(uuid,text) from public,anon;
revoke execute on function public.warranty_claim_create(uuid,text,text,text,uuid) from public,anon;
revoke execute on function public.warranty_claim_start_checking(uuid,uuid,text) from public,anon;
revoke execute on function public.warranty_claim_decide(uuid,boolean,text) from public,anon;
revoke execute on function public.warranty_claim_start_service(uuid,text) from public,anon;
revoke execute on function public.warranty_claim_update_service(uuid,text,text) from public,anon;
revoke execute on function public.warranty_claim_start_qc(uuid) from public,anon;
revoke execute on function public.warranty_claim_record_qc(uuid,boolean,text,text) from public,anon;
revoke execute on function public.warranty_claim_mark_returned(uuid,text) from public,anon;
revoke execute on function public.warranty_claim_close(uuid,text) from public,anon;

grant execute on function public.warranty_create_sale(uuid,uuid,uuid,date,integer,text,text),public.warranty_create_repair(uuid,date,integer,text,text),public.warranty_void(uuid,text),public.warranty_claim_create(uuid,text,text,text,uuid),public.warranty_claim_start_checking(uuid,uuid,text),public.warranty_claim_decide(uuid,boolean,text),public.warranty_claim_start_service(uuid,text),public.warranty_claim_update_service(uuid,text,text),public.warranty_claim_start_qc(uuid),public.warranty_claim_record_qc(uuid,boolean,text,text),public.warranty_claim_mark_returned(uuid,text),public.warranty_claim_close(uuid,text) to authenticated;

grant execute on function private.warranty_create_sale_impl(uuid,uuid,uuid,date,integer,text,text),private.warranty_create_repair_impl(uuid,date,integer,text,text),private.warranty_void_impl(uuid,text),private.warranty_claim_create_impl(uuid,text,text,text,uuid),private.warranty_claim_start_checking_impl(uuid,uuid,text),private.warranty_claim_decide_impl(uuid,boolean,text),private.warranty_claim_start_service_impl(uuid,text),private.warranty_claim_update_service_impl(uuid,text,text),private.warranty_claim_start_qc_impl(uuid),private.warranty_claim_record_qc_impl(uuid,boolean,text,text),private.warranty_claim_mark_returned_impl(uuid,text),private.warranty_claim_close_impl(uuid,text) to authenticated;
revoke execute on function private.warranty_claim_transition(uuid,text,text,uuid),private.warranty_mask_phone(text),private.warranty_mask_serial(text) from public,anon,authenticated;

create or replace function private.checklist_can_access_entity(p_entity_type text,p_entity_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not private.has_permission('checklist.run') then return false; end if;
  case p_entity_type
    when 'SALES_ORDER' then return private.has_permission('sale.view') and exists(select 1 from public.sales_orders where id=p_entity_id);
    when 'REPAIR_ORDER' then return private.has_permission('repair.view') and exists(select 1 from public.repair_orders where id=p_entity_id);
    when 'WARRANTY' then return private.has_permission('warranty.view') and exists(select 1 from public.warranties where id=p_entity_id);
    when 'GENERIC' then return true;
    else return false;
  end case;
end; $$;
revoke execute on function private.checklist_can_access_entity(text,uuid) from public,anon;
grant execute on function private.checklist_can_access_entity(text,uuid) to authenticated;
