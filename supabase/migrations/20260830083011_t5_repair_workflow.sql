create or replace function private.repair_log_transition(p_order_id uuid,p_to_status text,p_note text,p_uid uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_from text; v_allowed boolean:=false;
begin
  select status into v_from from public.repair_orders where id=p_order_id for update;
  if not found then raise exception 'Repair order not found'; end if;
  if v_from=p_to_status then return; end if;
  v_allowed := case
    when v_from='RECEIVED' and p_to_status in ('DIAGNOSING','CANCELLED') then true
    when v_from='DIAGNOSING' and p_to_status in ('QUOTED','NO_FIX','WARRANTY_TRANSFER','CANCELLED') then true
    when v_from='QUOTED' and p_to_status in ('AWAITING_CUSTOMER','CANCELLED') then true
    when v_from='AWAITING_CUSTOMER' and p_to_status in ('APPROVED','CUSTOMER_REJECTED','CANCELLED') then true
    when v_from='APPROVED' and p_to_status in ('REPAIRING','WAITING_PART','WARRANTY_TRANSFER','CANCELLED') then true
    when v_from='WAITING_PART' and p_to_status in ('REPAIRING','NO_FIX','WARRANTY_TRANSFER','CANCELLED') then true
    when v_from='REPAIRING' and p_to_status in ('QC','WAITING_PART','NO_FIX','WARRANTY_TRANSFER','CANCELLED') then true
    when v_from='QC' and p_to_status in ('READY','REPAIRING','WARRANTY_TRANSFER') then true
    when v_from='READY' and p_to_status='RETURNED' then true
    when v_from='RETURNED' and p_to_status='COMPLETED' then true
    when v_from='WARRANTY_TRANSFER' and p_to_status='DIAGNOSING' then true
    else false end;
  if not v_allowed then raise exception 'Invalid repair transition % -> %',v_from,p_to_status; end if;
  update public.repair_orders set
    status=p_to_status,updated_by=p_uid,updated_at=now(),
    diagnosed_at=case when p_to_status='DIAGNOSING' then coalesce(diagnosed_at,now()) else diagnosed_at end,
    quoted_at=case when p_to_status='QUOTED' then coalesce(quoted_at,now()) else quoted_at end,
    awaiting_customer_at=case when p_to_status='AWAITING_CUSTOMER' then coalesce(awaiting_customer_at,now()) else awaiting_customer_at end,
    approved_at=case when p_to_status='APPROVED' then coalesce(approved_at,now()) else approved_at end,
    repairing_at=case when p_to_status='REPAIRING' then coalesce(repairing_at,now()) else repairing_at end,
    qc_at=case when p_to_status='QC' then now() else qc_at end,
    ready_at=case when p_to_status='READY' then now() else ready_at end,
    returned_at=case when p_to_status='RETURNED' then now() else returned_at end,
    completed_at=case when p_to_status='COMPLETED' then now() else completed_at end,
    cancelled_at=case when p_to_status='CANCELLED' then now() else cancelled_at end,
    warranty_transfer_at=case when p_to_status='WARRANTY_TRANSFER' then now() else warranty_transfer_at end
  where id=p_order_id;
  insert into public.repair_status_history(repair_order_id,from_status,to_status,note,changed_by)
  values(p_order_id,v_from,p_to_status,nullif(btrim(p_note),''),p_uid);
end $$;

create or replace function private.repair_latest_unit_cost(p_product_id uuid)
returns numeric language sql stable security definer set search_path='' as $$
  select c.unit_cost from public.inventory_transactions t
  join private.inventory_transaction_costs c on c.transaction_id=t.id
  where t.product_id=p_product_id and t.transaction_type in ('RECEIVE','ADJUST_IN','RETURN_IN')
  order by t.occurred_at desc,t.created_at desc limit 1;
$$;

create or replace function private.repair_restore_part(p_part_id uuid,p_uid uuid,p_note text)
returns void language plpgsql security definer set search_path='' as $$
declare v_part public.repair_parts%rowtype; v_product public.products%rowtype; v_unit_id uuid; v_affected integer;
begin
  select * into v_part from public.repair_parts where id=p_part_id for update;
  if not found then raise exception 'Repair part not found'; end if;
  if v_part.status<>'ISSUED' then return; end if;
  select * into v_product from public.products where id=v_part.product_id for update;
  if v_product.track_serial then
    foreach v_unit_id in array v_part.inventory_unit_ids loop
      update public.inventory_units set status='IN_STOCK',issued_at=null,updated_by=p_uid,updated_at=now()
      where id=v_unit_id and product_id=v_part.product_id and status='OUT';
      get diagnostics v_affected=row_count;
      if v_affected<>1 then raise exception 'Cannot restore inventory unit %',v_unit_id; end if;
      insert into public.inventory_transactions(product_id,inventory_unit_id,transaction_type,quantity,reference_type,reference_id,note,occurred_at,created_by)
      values(v_part.product_id,v_unit_id,'RETURN_IN',1,'REPAIR_RETURN',v_part.repair_order_id,nullif(btrim(p_note),''),now(),p_uid);
    end loop;
  else
    insert into public.inventory_transactions(product_id,transaction_type,quantity,reference_type,reference_id,note,occurred_at,created_by)
    values(v_part.product_id,'RETURN_IN',v_part.quantity,'REPAIR_RETURN',v_part.repair_order_id,nullif(btrim(p_note),''),now(),p_uid);
  end if;
  update public.repair_parts set status='RETURNED',returned_at=now(),updated_by=p_uid,updated_at=now() where id=p_part_id;
end $$;

create or replace function private.repair_restore_all_parts(p_order_id uuid,p_uid uuid,p_note text)
returns void language plpgsql security definer set search_path='' as $$
declare r record;
begin
  for r in select id from public.repair_parts where repair_order_id=p_order_id and status='ISSUED' order by created_at,id loop
    perform private.repair_restore_part(r.id,p_uid,p_note);
  end loop;
end $$;

create or replace function private.repair_create_impl(
  p_customer_id uuid,p_customer_device_id uuid,p_reported_issue text,p_intake_condition text default null,
  p_accessories_received text[] default '{}'::text[],p_customer_request text default null,
  p_priority text default 'NORMAL',p_intake_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_id uuid; v_code text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.create') then raise exception 'Missing permission repair.create'; end if;
  if nullif(btrim(p_reported_issue),'') is null then raise exception 'reported_issue is required'; end if;
  if p_priority not in ('NORMAL','HIGH','URGENT') then raise exception 'Invalid priority'; end if;
  if not exists(select 1 from public.customers where id=p_customer_id and status='ACTIVE') then raise exception 'Customer not found or inactive'; end if;
  if not exists(select 1 from public.customer_devices where id=p_customer_device_id and customer_id=p_customer_id and status='ACTIVE') then raise exception 'Device does not belong to active customer'; end if;
  v_code:=private.next_daily_code('REPAIR_ORDER','SRV',null,4);
  insert into public.repair_orders(repair_code,customer_id,customer_device_id,reported_issue,intake_condition,accessories_received,customer_request,priority,intake_note,created_by,updated_by)
  values(v_code,p_customer_id,p_customer_device_id,btrim(p_reported_issue),nullif(btrim(p_intake_condition),''),coalesce(p_accessories_received,'{}'::text[]),nullif(btrim(p_customer_request),''),p_priority,nullif(btrim(p_intake_note),''),v_uid,v_uid)
  returning id into v_id;
  insert into public.repair_status_history(repair_order_id,from_status,to_status,note,changed_by)
  values(v_id,null,'RECEIVED','Tiếp nhận thiết bị',v_uid);
  return jsonb_build_object('id',v_id,'repair_code',v_code,'status','RECEIVED');
end $$;

create or replace function private.repair_start_diagnosis_impl(p_order_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_order public.repair_orders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.diagnose') then raise exception 'Missing permission repair.diagnose'; end if;
  perform private.repair_log_transition(p_order_id,'DIAGNOSING','Bắt đầu chẩn đoán',v_uid);
  update public.repair_orders set assigned_technician_id=coalesce(assigned_technician_id,v_uid) where id=p_order_id;
  select * into v_order from public.repair_orders where id=p_order_id;
  return to_jsonb(v_order);
end $$;

create or replace function private.repair_add_diagnostic_impl(p_order_id uuid,p_symptom text,p_findings text,p_conclusion text default null,p_recommendation text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_status text; v_row public.repair_diagnostics%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.diagnose') then raise exception 'Missing permission repair.diagnose'; end if;
  if nullif(btrim(p_findings),'') is null then raise exception 'findings is required'; end if;
  select status into v_status from public.repair_orders where id=p_order_id for update;
  if not found then raise exception 'Repair order not found'; end if;
  if v_status<>'DIAGNOSING' then raise exception 'Diagnosis can only be added in DIAGNOSING'; end if;
  insert into public.repair_diagnostics(repair_order_id,stage,symptom,findings,conclusion,recommendation,passed,created_by)
  values(p_order_id,'DIAGNOSIS',nullif(btrim(p_symptom),''),btrim(p_findings),nullif(btrim(p_conclusion),''),nullif(btrim(p_recommendation),''),null,v_uid)
  returning * into v_row;
  return to_jsonb(v_row);
end $$;

create or replace function private.repair_create_quote_impl(p_order_id uuid,p_labor_amount numeric,p_parts_amount numeric,p_discount_amount numeric default 0,p_valid_until date default null,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_status text; v_version integer; v_row public.repair_quotes%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.quote') then raise exception 'Missing permission repair.quote'; end if;
  if p_labor_amount<0 or p_parts_amount<0 or p_discount_amount<0 or p_discount_amount>p_labor_amount+p_parts_amount then raise exception 'Invalid quote amounts'; end if;
  select status into v_status from public.repair_orders where id=p_order_id for update;
  if not found then raise exception 'Repair order not found'; end if;
  if v_status not in ('DIAGNOSING','QUOTED') then raise exception 'Quote can only be created from DIAGNOSING/QUOTED'; end if;
  if not exists(select 1 from public.repair_diagnostics where repair_order_id=p_order_id and stage='DIAGNOSIS') then raise exception 'Diagnosis is required before quote'; end if;
  update public.repair_quotes set status='SUPERSEDED' where repair_order_id=p_order_id and status in ('DRAFT','SENT');
  select coalesce(max(version),0)+1 into v_version from public.repair_quotes where repair_order_id=p_order_id;
  insert into public.repair_quotes(repair_order_id,version,labor_amount,parts_amount,discount_amount,valid_until,note,created_by)
  values(p_order_id,v_version,p_labor_amount,p_parts_amount,p_discount_amount,p_valid_until,nullif(btrim(p_note),''),v_uid)
  returning * into v_row;
  if v_status='DIAGNOSING' then perform private.repair_log_transition(p_order_id,'QUOTED','Đã lập báo giá',v_uid); end if;
  return to_jsonb(v_row);
end $$;

create or replace function private.repair_submit_quote_impl(p_quote_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_quote public.repair_quotes%rowtype; v_status text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.quote') then raise exception 'Missing permission repair.quote'; end if;
  select * into v_quote from public.repair_quotes where id=p_quote_id for update;
  if not found then raise exception 'Repair quote not found'; end if;
  if v_quote.status<>'DRAFT' then raise exception 'Only DRAFT quote can be submitted'; end if;
  select status into v_status from public.repair_orders where id=v_quote.repair_order_id for update;
  if v_status<>'QUOTED' then raise exception 'Repair order is not QUOTED'; end if;
  update public.repair_quotes set status='SENT',sent_at=now() where id=p_quote_id returning * into v_quote;
  perform private.repair_log_transition(v_quote.repair_order_id,'AWAITING_CUSTOMER','Đã gửi báo giá, chờ khách phản hồi',v_uid);
  return to_jsonb(v_quote);
end $$;

create or replace function private.repair_customer_decision_impl(p_order_id uuid,p_approved boolean,p_response_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_status text; v_quote public.repair_quotes%rowtype; v_order public.repair_orders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.update') then raise exception 'Missing permission repair.update'; end if;
  select status into v_status from public.repair_orders where id=p_order_id for update;
  if not found then raise exception 'Repair order not found'; end if;
  if v_status<>'AWAITING_CUSTOMER' then raise exception 'Customer decision requires AWAITING_CUSTOMER'; end if;
  select * into v_quote from public.repair_quotes where repair_order_id=p_order_id and status='SENT' order by version desc limit 1 for update;
  if not found then raise exception 'No SENT quote found'; end if;
  if p_approved then
    update public.repair_quotes set status='APPROVED',approved_at=now(),customer_response_note=nullif(btrim(p_response_note),'') where id=v_quote.id;
    update public.repair_orders set approved_quote_id=v_quote.id,approved_amount=v_quote.total_amount,customer_rejected_reason=null where id=p_order_id;
    perform private.repair_log_transition(p_order_id,'APPROVED',coalesce(nullif(btrim(p_response_note),''),'Khách đồng ý báo giá'),v_uid);
  else
    update public.repair_quotes set status='REJECTED',rejected_at=now(),customer_response_note=nullif(btrim(p_response_note),'') where id=v_quote.id;
    update public.repair_orders set customer_rejected_reason=coalesce(nullif(btrim(p_response_note),''),'Khách từ chối báo giá') where id=p_order_id;
    perform private.repair_log_transition(p_order_id,'CUSTOMER_REJECTED',coalesce(nullif(btrim(p_response_note),''),'Khách từ chối báo giá'),v_uid);
  end if;
  select * into v_order from public.repair_orders where id=p_order_id;
  return to_jsonb(v_order);
end $$;

create or replace function private.repair_plan_part_impl(p_order_id uuid,p_product_id uuid,p_quantity numeric,p_unit_price numeric default null,p_inventory_unit_ids uuid[] default '{}'::uuid[],p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_status text; v_product public.products%rowtype; v_price numeric(14,2); v_count integer:=coalesce(array_length(p_inventory_unit_ids,1),0); v_distinct integer; v_part public.repair_parts%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.update') then raise exception 'Missing permission repair.update'; end if;
  if p_quantity is null or p_quantity<=0 then raise exception 'quantity must be greater than zero'; end if;
  select status into v_status from public.repair_orders where id=p_order_id for update;
  if not found then raise exception 'Repair order not found'; end if;
  if v_status not in ('APPROVED','WAITING_PART','REPAIRING') then raise exception 'Parts can only be planned after approval'; end if;
  select * into v_product from public.products where id=p_product_id and is_active=true;
  if not found then raise exception 'Product not found or inactive'; end if;
  v_price:=coalesce(p_unit_price,v_product.sale_price);
  if v_price<0 then raise exception 'unit_price cannot be negative'; end if;
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
    set quantity=excluded.quantity,unit_price=excluded.unit_price,inventory_unit_ids=excluded.inventory_unit_ids,note=excluded.note,updated_by=v_uid,updated_at=now()
  where public.repair_parts.status='PLANNED'
  returning * into v_part;
  if not found then raise exception 'Issued/returned repair part cannot be replanned'; end if;
  return to_jsonb(v_part);
end $$;

create or replace function private.repair_issue_part_impl(p_part_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_part public.repair_parts%rowtype; v_order public.repair_orders%rowtype; v_product public.products%rowtype; v_unit_id uuid; v_count integer; v_distinct integer; v_stock numeric(14,3); v_affected integer; v_cost numeric(14,2); v_tx_id uuid;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.update') then raise exception 'Missing permission repair.update'; end if;
  if not private.has_permission('inventory.issue') then raise exception 'Missing permission inventory.issue'; end if;
  select * into v_part from public.repair_parts where id=p_part_id for update;
  if not found then raise exception 'Repair part not found'; end if;
  if v_part.status<>'PLANNED' then raise exception 'Only PLANNED part can be issued'; end if;
  select * into v_order from public.repair_orders where id=v_part.repair_order_id for update;
  if v_order.status not in ('APPROVED','WAITING_PART','REPAIRING') then raise exception 'Repair order is not ready to issue parts'; end if;
  select * into v_product from public.products where id=v_part.product_id for update;
  if not found then raise exception 'Product not found'; end if;
  v_cost:=private.repair_latest_unit_cost(v_part.product_id);
  if v_product.track_serial then
    if trunc(v_part.quantity)<>v_part.quantity then raise exception 'Serialized quantity must be integer'; end if;
    v_count:=coalesce(array_length(v_part.inventory_unit_ids,1),0);
    if v_count<>v_part.quantity::integer then raise exception 'Select exactly % serial unit(s)',v_part.quantity; end if;
    select count(distinct x) into v_distinct from unnest(v_part.inventory_unit_ids) u(x) where x is not null;
    if v_distinct<>v_count then raise exception 'Duplicate/null inventory unit selection'; end if;
    foreach v_unit_id in array v_part.inventory_unit_ids loop
      update public.inventory_units set status='OUT',issued_at=now(),updated_by=v_uid,updated_at=now()
      where id=v_unit_id and product_id=v_part.product_id and status='IN_STOCK';
      get diagnostics v_affected=row_count;
      if v_affected<>1 then raise exception 'Inventory unit % unavailable',v_unit_id; end if;
      insert into public.inventory_transactions(product_id,inventory_unit_id,transaction_type,quantity,reference_type,reference_id,note,occurred_at,created_by)
      values(v_part.product_id,v_unit_id,'ISSUE',1,'REPAIR',v_part.repair_order_id,'Repair '||v_order.repair_code,now(),v_uid)
      returning id into v_tx_id;
    end loop;
  else
    select coalesce(sum(case when transaction_type in ('RECEIVE','ADJUST_IN','RETURN_IN') then quantity else -quantity end),0)
    into v_stock from public.inventory_transactions where product_id=v_part.product_id;
    if v_stock<v_part.quantity then raise exception 'Insufficient stock: available %, requested %',v_stock,v_part.quantity; end if;
    insert into public.inventory_transactions(product_id,transaction_type,quantity,reference_type,reference_id,note,occurred_at,created_by)
    values(v_part.product_id,'ISSUE',v_part.quantity,'REPAIR',v_part.repair_order_id,'Repair '||v_order.repair_code,now(),v_uid)
    returning id into v_tx_id;
  end if;
  insert into private.repair_part_costs(repair_part_id,unit_cost,total_cost)
  values(p_part_id,v_cost,case when v_cost is null then null else v_cost*v_part.quantity end)
  on conflict(repair_part_id) do update set unit_cost=excluded.unit_cost,total_cost=excluded.total_cost,captured_at=now();
  update public.repair_parts set status='ISSUED',issued_at=now(),returned_at=null,updated_by=v_uid,updated_at=now()
  where id=p_part_id returning * into v_part;
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
  select status into v_status from public.repair_orders where id=v_part.repair_order_id for update;
  if v_status in ('RETURNED','COMPLETED','CANCELLED','CUSTOMER_REJECTED') then raise exception 'Repair order is locked'; end if;
  perform private.repair_restore_part(p_part_id,v_uid,coalesce(nullif(btrim(p_note),''),'Trả vật tư sửa chữa'));
  select * into v_part from public.repair_parts where id=p_part_id;
  return to_jsonb(v_part);
end $$;

create or replace function private.repair_start_repair_impl(p_order_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_order public.repair_orders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.update') then raise exception 'Missing permission repair.update'; end if;
  perform private.repair_log_transition(p_order_id,'REPAIRING','Bắt đầu sửa chữa',v_uid);
  update public.repair_orders set waiting_part_note=null where id=p_order_id;
  select * into v_order from public.repair_orders where id=p_order_id;
  return to_jsonb(v_order);
end $$;

create or replace function private.repair_waiting_part_impl(p_order_id uuid,p_note text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_order public.repair_orders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.update') then raise exception 'Missing permission repair.update'; end if;
  if nullif(btrim(p_note),'') is null then raise exception 'Waiting-part note is required'; end if;
  update public.repair_orders set waiting_part_note=btrim(p_note) where id=p_order_id;
  perform private.repair_log_transition(p_order_id,'WAITING_PART',p_note,v_uid);
  select * into v_order from public.repair_orders where id=p_order_id;
  return to_jsonb(v_order);
end $$;

create or replace function private.repair_start_qc_impl(p_order_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_order public.repair_orders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.qc') then raise exception 'Missing permission repair.qc'; end if;
  perform private.repair_log_transition(p_order_id,'QC','Bắt đầu QC',v_uid);
  select * into v_order from public.repair_orders where id=p_order_id;
  return to_jsonb(v_order);
end $$;

create or replace function private.repair_record_qc_impl(p_order_id uuid,p_passed boolean,p_findings text,p_conclusion text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_status text; v_order public.repair_orders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.qc') then raise exception 'Missing permission repair.qc'; end if;
  if nullif(btrim(p_findings),'') is null then raise exception 'QC findings are required'; end if;
  select status into v_status from public.repair_orders where id=p_order_id for update;
  if not found then raise exception 'Repair order not found'; end if;
  if v_status<>'QC' then raise exception 'QC result requires QC status'; end if;
  insert into public.repair_diagnostics(repair_order_id,stage,findings,conclusion,passed,created_by)
  values(p_order_id,'QC',btrim(p_findings),nullif(btrim(p_conclusion),''),p_passed,v_uid);
  update public.repair_orders set qc_passed=p_passed,qc_note=btrim(p_findings),final_amount=case when p_passed then approved_amount else final_amount end where id=p_order_id;
  if p_passed then
    perform private.repair_log_transition(p_order_id,'READY','QC đạt',v_uid);
  else
    perform private.repair_log_transition(p_order_id,'REPAIRING','QC chưa đạt, quay lại sửa chữa',v_uid);
  end if;
  select * into v_order from public.repair_orders where id=p_order_id;
  return to_jsonb(v_order);
end $$;

create or replace function private.repair_mark_returned_impl(p_order_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_order public.repair_orders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.update') then raise exception 'Missing permission repair.update'; end if;
  perform private.repair_log_transition(p_order_id,'RETURNED','Đã trả thiết bị cho khách',v_uid);
  select * into v_order from public.repair_orders where id=p_order_id;
  return to_jsonb(v_order);
end $$;

create or replace function private.repair_complete_impl(p_order_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_order public.repair_orders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.update') then raise exception 'Missing permission repair.update'; end if;
  select * into v_order from public.repair_orders where id=p_order_id for update;
  if not found then raise exception 'Repair order not found'; end if;
  if v_order.status<>'RETURNED' then raise exception 'Only RETURNED repair can be completed'; end if;
  if v_order.qc_passed is distinct from true then raise exception 'QC must pass before completion'; end if;
  perform private.repair_log_transition(p_order_id,'COMPLETED','Hoàn tất sửa chữa',v_uid);
  select * into v_order from public.repair_orders where id=p_order_id;
  return to_jsonb(v_order);
end $$;

create or replace function private.repair_no_fix_impl(p_order_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_status text; v_order public.repair_orders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.update') then raise exception 'Missing permission repair.update'; end if;
  if nullif(btrim(p_reason),'') is null then raise exception 'NO_FIX reason is required'; end if;
  select status into v_status from public.repair_orders where id=p_order_id for update;
  if v_status not in ('DIAGNOSING','WAITING_PART','REPAIRING') then raise exception 'NO_FIX not allowed from %',v_status; end if;
  perform private.repair_restore_all_parts(p_order_id,v_uid,'NO_FIX: '||btrim(p_reason));
  update public.repair_orders set no_fix_reason=btrim(p_reason) where id=p_order_id;
  perform private.repair_log_transition(p_order_id,'NO_FIX',p_reason,v_uid);
  select * into v_order from public.repair_orders where id=p_order_id;
  return to_jsonb(v_order);
end $$;

create or replace function private.repair_warranty_transfer_impl(p_order_id uuid,p_note text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_status text; v_order public.repair_orders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.update') then raise exception 'Missing permission repair.update'; end if;
  if nullif(btrim(p_note),'') is null then raise exception 'Warranty transfer note is required'; end if;
  select status into v_status from public.repair_orders where id=p_order_id for update;
  if v_status not in ('DIAGNOSING','APPROVED','WAITING_PART','REPAIRING','QC') then raise exception 'WARRANTY_TRANSFER not allowed from %',v_status; end if;
  perform private.repair_restore_all_parts(p_order_id,v_uid,'WARRANTY_TRANSFER: '||btrim(p_note));
  update public.repair_orders set warranty_transfer_note=btrim(p_note) where id=p_order_id;
  perform private.repair_log_transition(p_order_id,'WARRANTY_TRANSFER',p_note,v_uid);
  select * into v_order from public.repair_orders where id=p_order_id;
  return to_jsonb(v_order);
end $$;

create or replace function private.repair_resume_warranty_impl(p_order_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_order public.repair_orders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.diagnose') then raise exception 'Missing permission repair.diagnose'; end if;
  perform private.repair_log_transition(p_order_id,'DIAGNOSING','Nhận lại từ luồng bảo hành, tiếp tục chẩn đoán',v_uid);
  select * into v_order from public.repair_orders where id=p_order_id;
  return to_jsonb(v_order);
end $$;

create or replace function private.repair_cancel_impl(p_order_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_status text; v_order public.repair_orders%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('repair.cancel') then raise exception 'Missing permission repair.cancel'; end if;
  if nullif(btrim(p_reason),'') is null then raise exception 'Cancellation reason is required'; end if;
  select status into v_status from public.repair_orders where id=p_order_id for update;
  if not found then raise exception 'Repair order not found'; end if;
  if v_status not in ('RECEIVED','DIAGNOSING','QUOTED','AWAITING_CUSTOMER','APPROVED','WAITING_PART','REPAIRING') then raise exception 'Repair cannot be cancelled from %',v_status; end if;
  perform private.repair_restore_all_parts(p_order_id,v_uid,'CANCELLED: '||btrim(p_reason));
  update public.repair_orders set intake_note=concat_ws(E'\n',intake_note,'Hủy: '||btrim(p_reason)) where id=p_order_id;
  perform private.repair_log_transition(p_order_id,'CANCELLED',p_reason,v_uid);
  select * into v_order from public.repair_orders where id=p_order_id;
  return to_jsonb(v_order);
end $$;

create or replace function public.repair_create(p_customer_id uuid,p_customer_device_id uuid,p_reported_issue text,p_intake_condition text default null,p_accessories_received text[] default '{}'::text[],p_customer_request text default null,p_priority text default 'NORMAL',p_intake_note text default null)
returns jsonb language sql set search_path='' as $$ select private.repair_create_impl(p_customer_id,p_customer_device_id,p_reported_issue,p_intake_condition,p_accessories_received,p_customer_request,p_priority,p_intake_note); $$;
create or replace function public.repair_start_diagnosis(p_order_id uuid) returns jsonb language sql set search_path='' as $$ select private.repair_start_diagnosis_impl(p_order_id); $$;
create or replace function public.repair_add_diagnostic(p_order_id uuid,p_symptom text,p_findings text,p_conclusion text default null,p_recommendation text default null) returns jsonb language sql set search_path='' as $$ select private.repair_add_diagnostic_impl(p_order_id,p_symptom,p_findings,p_conclusion,p_recommendation); $$;
create or replace function public.repair_create_quote(p_order_id uuid,p_labor_amount numeric,p_parts_amount numeric,p_discount_amount numeric default 0,p_valid_until date default null,p_note text default null) returns jsonb language sql set search_path='' as $$ select private.repair_create_quote_impl(p_order_id,p_labor_amount,p_parts_amount,p_discount_amount,p_valid_until,p_note); $$;
create or replace function public.repair_submit_quote(p_quote_id uuid) returns jsonb language sql set search_path='' as $$ select private.repair_submit_quote_impl(p_quote_id); $$;
create or replace function public.repair_customer_decision(p_order_id uuid,p_approved boolean,p_response_note text default null) returns jsonb language sql set search_path='' as $$ select private.repair_customer_decision_impl(p_order_id,p_approved,p_response_note); $$;
create or replace function public.repair_plan_part(p_order_id uuid,p_product_id uuid,p_quantity numeric,p_unit_price numeric default null,p_inventory_unit_ids uuid[] default '{}'::uuid[],p_note text default null) returns jsonb language sql set search_path='' as $$ select private.repair_plan_part_impl(p_order_id,p_product_id,p_quantity,p_unit_price,p_inventory_unit_ids,p_note); $$;
create or replace function public.repair_issue_part(p_part_id uuid) returns jsonb language sql set search_path='' as $$ select private.repair_issue_part_impl(p_part_id); $$;
create or replace function public.repair_return_part(p_part_id uuid,p_note text default null) returns jsonb language sql set search_path='' as $$ select private.repair_return_part_impl(p_part_id,p_note); $$;
create or replace function public.repair_start_repair(p_order_id uuid) returns jsonb language sql set search_path='' as $$ select private.repair_start_repair_impl(p_order_id); $$;
create or replace function public.repair_waiting_part(p_order_id uuid,p_note text) returns jsonb language sql set search_path='' as $$ select private.repair_waiting_part_impl(p_order_id,p_note); $$;
create or replace function public.repair_start_qc(p_order_id uuid) returns jsonb language sql set search_path='' as $$ select private.repair_start_qc_impl(p_order_id); $$;
create or replace function public.repair_record_qc(p_order_id uuid,p_passed boolean,p_findings text,p_conclusion text default null) returns jsonb language sql set search_path='' as $$ select private.repair_record_qc_impl(p_order_id,p_passed,p_findings,p_conclusion); $$;
create or replace function public.repair_mark_returned(p_order_id uuid) returns jsonb language sql set search_path='' as $$ select private.repair_mark_returned_impl(p_order_id); $$;
create or replace function public.repair_complete(p_order_id uuid) returns jsonb language sql set search_path='' as $$ select private.repair_complete_impl(p_order_id); $$;
create or replace function public.repair_no_fix(p_order_id uuid,p_reason text) returns jsonb language sql set search_path='' as $$ select private.repair_no_fix_impl(p_order_id,p_reason); $$;
create or replace function public.repair_warranty_transfer(p_order_id uuid,p_note text) returns jsonb language sql set search_path='' as $$ select private.repair_warranty_transfer_impl(p_order_id,p_note); $$;
create or replace function public.repair_resume_warranty(p_order_id uuid) returns jsonb language sql set search_path='' as $$ select private.repair_resume_warranty_impl(p_order_id); $$;
create or replace function public.repair_cancel(p_order_id uuid,p_reason text) returns jsonb language sql set search_path='' as $$ select private.repair_cancel_impl(p_order_id,p_reason); $$;

revoke execute on function
  private.repair_log_transition(uuid,text,text,uuid),
  private.repair_latest_unit_cost(uuid),
  private.repair_restore_part(uuid,uuid,text),
  private.repair_restore_all_parts(uuid,uuid,text)
from public,anon,authenticated;

revoke execute on function
  private.repair_create_impl(uuid,uuid,text,text,text[],text,text,text),
  private.repair_start_diagnosis_impl(uuid),
  private.repair_add_diagnostic_impl(uuid,text,text,text,text),
  private.repair_create_quote_impl(uuid,numeric,numeric,numeric,date,text),
  private.repair_submit_quote_impl(uuid),
  private.repair_customer_decision_impl(uuid,boolean,text),
  private.repair_plan_part_impl(uuid,uuid,numeric,numeric,uuid[],text),
  private.repair_issue_part_impl(uuid),
  private.repair_return_part_impl(uuid,text),
  private.repair_start_repair_impl(uuid),
  private.repair_waiting_part_impl(uuid,text),
  private.repair_start_qc_impl(uuid),
  private.repair_record_qc_impl(uuid,boolean,text,text),
  private.repair_mark_returned_impl(uuid),
  private.repair_complete_impl(uuid),
  private.repair_no_fix_impl(uuid,text),
  private.repair_warranty_transfer_impl(uuid,text),
  private.repair_resume_warranty_impl(uuid),
  private.repair_cancel_impl(uuid,text)
from public,anon,authenticated;

grant execute on function
  private.repair_create_impl(uuid,uuid,text,text,text[],text,text,text),
  private.repair_start_diagnosis_impl(uuid),
  private.repair_add_diagnostic_impl(uuid,text,text,text,text),
  private.repair_create_quote_impl(uuid,numeric,numeric,numeric,date,text),
  private.repair_submit_quote_impl(uuid),
  private.repair_customer_decision_impl(uuid,boolean,text),
  private.repair_plan_part_impl(uuid,uuid,numeric,numeric,uuid[],text),
  private.repair_issue_part_impl(uuid),
  private.repair_return_part_impl(uuid,text),
  private.repair_start_repair_impl(uuid),
  private.repair_waiting_part_impl(uuid,text),
  private.repair_start_qc_impl(uuid),
  private.repair_record_qc_impl(uuid,boolean,text,text),
  private.repair_mark_returned_impl(uuid),
  private.repair_complete_impl(uuid),
  private.repair_no_fix_impl(uuid,text),
  private.repair_warranty_transfer_impl(uuid,text),
  private.repair_resume_warranty_impl(uuid),
  private.repair_cancel_impl(uuid,text)
to authenticated;

revoke execute on function
  public.repair_create(uuid,uuid,text,text,text[],text,text,text),
  public.repair_start_diagnosis(uuid),
  public.repair_add_diagnostic(uuid,text,text,text,text),
  public.repair_create_quote(uuid,numeric,numeric,numeric,date,text),
  public.repair_submit_quote(uuid),
  public.repair_customer_decision(uuid,boolean,text),
  public.repair_plan_part(uuid,uuid,numeric,numeric,uuid[],text),
  public.repair_issue_part(uuid),
  public.repair_return_part(uuid,text),
  public.repair_start_repair(uuid),
  public.repair_waiting_part(uuid,text),
  public.repair_start_qc(uuid),
  public.repair_record_qc(uuid,boolean,text,text),
  public.repair_mark_returned(uuid),
  public.repair_complete(uuid),
  public.repair_no_fix(uuid,text),
  public.repair_warranty_transfer(uuid,text),
  public.repair_resume_warranty(uuid),
  public.repair_cancel(uuid,text)
from public,anon;

grant execute on function
  public.repair_create(uuid,uuid,text,text,text[],text,text,text),
  public.repair_start_diagnosis(uuid),
  public.repair_add_diagnostic(uuid,text,text,text,text),
  public.repair_create_quote(uuid,numeric,numeric,numeric,date,text),
  public.repair_submit_quote(uuid),
  public.repair_customer_decision(uuid,boolean,text),
  public.repair_plan_part(uuid,uuid,numeric,numeric,uuid[],text),
  public.repair_issue_part(uuid),
  public.repair_return_part(uuid,text),
  public.repair_start_repair(uuid),
  public.repair_waiting_part(uuid,text),
  public.repair_start_qc(uuid),
  public.repair_record_qc(uuid,boolean,text,text),
  public.repair_mark_returned(uuid),
  public.repair_complete(uuid),
  public.repair_no_fix(uuid,text),
  public.repair_warranty_transfer(uuid,text),
  public.repair_resume_warranty(uuid),
  public.repair_cancel(uuid,text)
to authenticated;
