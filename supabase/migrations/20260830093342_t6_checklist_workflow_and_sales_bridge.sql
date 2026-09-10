create or replace function private.checklist_requirement_required(p_rule text,p_entity_type text,p_entity_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
begin
  case p_rule
    when 'ALWAYS' then return true;
    when 'OPTIONAL' then return false;
    when 'SALES_HAS_SERIAL' then
      return p_entity_type='SALES_ORDER' and exists(
        select 1 from public.sales_order_items i join public.products p on p.id=i.product_id
        where i.sales_order_id=p_entity_id and p.track_serial=true
      );
    else return false;
  end case;
end; $$;
revoke execute on function private.checklist_requirement_required(text,text,uuid) from public,anon,authenticated;

create or replace function private.checklist_sync_sales_run(p_order_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare
  v_order public.sales_orders%rowtype;
  v_rec record;
  v_json jsonb;
  v_checked boolean;
  v_checked_at timestamptz;
  v_checked_by uuid;
begin
  select * into v_order from public.sales_orders where id=p_order_id;
  if not found then return; end if;

  for v_rec in
    select i.id,i.item_key,i.checked,i.checked_at,i.checked_by,ti.requirement_rule
    from public.checklist_run_items i
    join public.checklist_runs r on r.id=i.run_id
    left join public.checklist_template_items ti on ti.id=i.template_item_id
    where r.entity_type='SALES_ORDER' and r.entity_id=p_order_id and r.status<>'CANCELLED'
  loop
    select x into v_json from jsonb_array_elements(v_order.checklist) x where x->>'key'=v_rec.item_key limit 1;
    if v_json is null then continue; end if;
    v_checked:=coalesce((v_json->>'checked')::boolean,false);
    if v_checked then
      begin v_checked_at:=nullif(v_json->>'checked_at','')::timestamptz; exception when others then v_checked_at:=null; end;
      begin v_checked_by:=nullif(v_json->>'checked_by','')::uuid; exception when others then v_checked_by:=null; end;
      v_checked_at:=coalesce(v_checked_at,v_rec.checked_at,now());
      v_checked_by:=coalesce(v_checked_by,v_rec.checked_by);
    else
      v_checked_at:=null; v_checked_by:=null;
    end if;
    update public.checklist_run_items
    set required=private.checklist_requirement_required(coalesce(v_rec.requirement_rule,'OPTIONAL'),'SALES_ORDER',p_order_id),
        checked=v_checked,checked_at=v_checked_at,checked_by=v_checked_by,updated_at=now()
    where id=v_rec.id;
  end loop;

  update public.checklist_runs r
  set status='OPEN',completed_by=null,completed_at=null,updated_at=now()
  where r.entity_type='SALES_ORDER' and r.entity_id=p_order_id and r.status='COMPLETED'
    and exists(select 1 from public.checklist_run_items i where i.run_id=r.id and i.required and not i.checked);
end; $$;
revoke execute on function private.checklist_sync_sales_run(uuid) from public,anon,authenticated;

create or replace function private.trg_t6_sales_checklist_sync()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform private.checklist_sync_sales_run(new.id);
  return new;
end; $$;
revoke execute on function private.trg_t6_sales_checklist_sync() from public,anon,authenticated;
create trigger trg_t6_sales_checklist_sync
after update of checklist,paid_amount,total_amount on public.sales_orders
for each row execute function private.trg_t6_sales_checklist_sync();

create or replace function private.checklist_template_create_impl(
  p_template_code text,p_name text,p_module text,p_entity_type text,p_description text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_code text; v_version integer; v_row public.checklist_templates%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('checklist.manage') then raise exception 'Missing permission checklist.manage'; end if;
  v_code:=upper(btrim(p_template_code));
  if v_code !~ '^[A-Z0-9_]+$' then raise exception 'Invalid template_code'; end if;
  if nullif(btrim(p_name),'') is null then raise exception 'Template name is required'; end if;
  select coalesce(max(version),0)+1 into v_version from public.checklist_templates where template_code=v_code;
  insert into public.checklist_templates(template_code,version,name,module,entity_type,description,is_active,is_system,created_by,updated_by)
  values(v_code,v_version,btrim(p_name),p_module,p_entity_type,nullif(btrim(p_description),''),false,false,v_uid,v_uid)
  returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.checklist_template_add_item_impl(
  p_template_id uuid,p_item_key text,p_label text,p_sort_order integer,
  p_requirement_rule text default 'OPTIONAL',p_system_managed boolean default false,p_description text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_template public.checklist_templates%rowtype; v_row public.checklist_template_items%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('checklist.manage') then raise exception 'Missing permission checklist.manage'; end if;
  select * into v_template from public.checklist_templates where id=p_template_id for update;
  if not found then raise exception 'Checklist template not found'; end if;
  if v_template.is_active then raise exception 'Active template cannot be edited; create a new version'; end if;
  if p_item_key !~ '^[a-z0-9_]+$' then raise exception 'Invalid item_key'; end if;
  insert into public.checklist_template_items(template_id,item_key,label,description,sort_order,requirement_rule,system_managed,created_by,updated_by)
  values(p_template_id,p_item_key,btrim(p_label),nullif(btrim(p_description),''),p_sort_order,p_requirement_rule,coalesce(p_system_managed,false),v_uid,v_uid)
  returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.checklist_template_activate_impl(p_template_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_template public.checklist_templates%rowtype; v_count integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('checklist.manage') then raise exception 'Missing permission checklist.manage'; end if;
  select * into v_template from public.checklist_templates where id=p_template_id for update;
  if not found then raise exception 'Checklist template not found'; end if;
  select count(*) into v_count from public.checklist_template_items where template_id=p_template_id;
  if v_count=0 then raise exception 'Checklist template has no items'; end if;
  update public.checklist_templates set is_active=false,updated_by=v_uid,updated_at=now()
  where template_code=v_template.template_code and id<>p_template_id and is_active;
  update public.checklist_templates set is_active=true,updated_by=v_uid,updated_at=now()
  where id=p_template_id returning * into v_template;
  return to_jsonb(v_template);
end; $$;

create or replace function private.checklist_run_start_impl(
  p_template_id uuid,p_entity_type text,p_entity_id uuid,p_note text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_template public.checklist_templates%rowtype; v_run public.checklist_runs%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('checklist.run') then raise exception 'Missing permission checklist.run'; end if;
  if not private.checklist_can_access_entity(p_entity_type,p_entity_id) then raise exception 'Checklist entity access denied'; end if;
  select * into v_template from public.checklist_templates where id=p_template_id and is_active=true;
  if not found then raise exception 'Active checklist template not found'; end if;
  if v_template.entity_type<>p_entity_type then raise exception 'Template entity type mismatch'; end if;
  select * into v_run from public.checklist_runs
  where template_id=p_template_id and entity_type=p_entity_type and entity_id=p_entity_id;
  if found then
    if p_entity_type='SALES_ORDER' then perform private.checklist_sync_sales_run(p_entity_id); end if;
    select * into v_run from public.checklist_runs where id=v_run.id;
    return to_jsonb(v_run);
  end if;
  insert into public.checklist_runs(template_id,template_code_snapshot,template_version,entity_type,entity_id,status,note,started_by)
  values(v_template.id,v_template.template_code,v_template.version,p_entity_type,p_entity_id,'OPEN',nullif(btrim(p_note),''),v_uid)
  returning * into v_run;
  insert into public.checklist_run_items(
    run_id,template_item_id,item_key,label,description,sort_order,required,system_managed,checked,created_at,updated_at
  )
  select v_run.id,i.id,i.item_key,i.label,i.description,i.sort_order,
         private.checklist_requirement_required(i.requirement_rule,p_entity_type,p_entity_id),
         i.system_managed,false,now(),now()
  from public.checklist_template_items i where i.template_id=v_template.id order by i.sort_order;
  if p_entity_type='SALES_ORDER' then perform private.checklist_sync_sales_run(p_entity_id); end if;
  return to_jsonb(v_run);
end; $$;

create or replace function private.checklist_run_set_item_impl(
  p_run_item_id uuid,p_checked boolean,p_note text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_item public.checklist_run_items%rowtype; v_run public.checklist_runs%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('checklist.run') then raise exception 'Missing permission checklist.run'; end if;
  select * into v_item from public.checklist_run_items where id=p_run_item_id for update;
  if not found then raise exception 'Checklist run item not found'; end if;
  select * into v_run from public.checklist_runs where id=v_item.run_id for update;
  if not private.checklist_can_access_entity(v_run.entity_type,v_run.entity_id) then raise exception 'Checklist entity access denied'; end if;
  if v_run.status<>'OPEN' then raise exception 'Checklist run is not OPEN'; end if;
  if v_item.system_managed then raise exception 'Checklist item is system managed'; end if;
  if v_run.entity_type='SALES_ORDER' then
    perform private.sale_set_checklist_system(v_run.entity_id,v_item.item_key,p_checked,v_uid);
    update public.checklist_run_items set note=nullif(btrim(p_note),''),updated_at=now() where id=v_item.id;
    perform private.checklist_sync_sales_run(v_run.entity_id);
  else
    update public.checklist_run_items
    set checked=p_checked,
        checked_at=case when p_checked then now() else null end,
        checked_by=case when p_checked then v_uid else null end,
        note=nullif(btrim(p_note),''),
        updated_at=now()
    where id=v_item.id;
  end if;
  select * into v_item from public.checklist_run_items where id=v_item.id;
  return to_jsonb(v_item);
end; $$;

create or replace function private.checklist_run_refresh_impl(p_run_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_run public.checklist_runs%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('checklist.run') then raise exception 'Missing permission checklist.run'; end if;
  select * into v_run from public.checklist_runs where id=p_run_id;
  if not found then raise exception 'Checklist run not found'; end if;
  if not private.checklist_can_access_entity(v_run.entity_type,v_run.entity_id) then raise exception 'Checklist entity access denied'; end if;
  if v_run.entity_type='SALES_ORDER' then perform private.checklist_sync_sales_run(v_run.entity_id); end if;
  select * into v_run from public.checklist_runs where id=p_run_id;
  return to_jsonb(v_run);
end; $$;

create or replace function private.checklist_run_complete_impl(p_run_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_run public.checklist_runs%rowtype; v_missing integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('checklist.run') then raise exception 'Missing permission checklist.run'; end if;
  select * into v_run from public.checklist_runs where id=p_run_id for update;
  if not found then raise exception 'Checklist run not found'; end if;
  if not private.checklist_can_access_entity(v_run.entity_type,v_run.entity_id) then raise exception 'Checklist entity access denied'; end if;
  if v_run.status<>'OPEN' then raise exception 'Checklist run is not OPEN'; end if;
  if v_run.entity_type='SALES_ORDER' then perform private.checklist_sync_sales_run(v_run.entity_id); end if;
  select count(*) into v_missing from public.checklist_run_items where run_id=p_run_id and required and not checked;
  if v_missing>0 then raise exception 'Required checklist items incomplete: %',v_missing; end if;
  update public.checklist_runs set status='COMPLETED',completed_by=v_uid,completed_at=now(),updated_at=now()
  where id=p_run_id returning * into v_run;
  return to_jsonb(v_run);
end; $$;

create or replace function private.checklist_run_reopen_impl(p_run_id uuid,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_run public.checklist_runs%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('checklist.manage') then raise exception 'Missing permission checklist.manage'; end if;
  select * into v_run from public.checklist_runs where id=p_run_id for update;
  if not found then raise exception 'Checklist run not found'; end if;
  if v_run.status<>'COMPLETED' then raise exception 'Only COMPLETED run can be reopened'; end if;
  update public.checklist_runs
  set status='OPEN',completed_by=null,completed_at=null,note=coalesce(nullif(btrim(p_note),''),note),updated_at=now()
  where id=p_run_id returning * into v_run;
  return to_jsonb(v_run);
end; $$;

create or replace function private.checklist_run_cancel_impl(p_run_id uuid,p_note text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_run public.checklist_runs%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('checklist.manage') then raise exception 'Missing permission checklist.manage'; end if;
  if nullif(btrim(p_note),'') is null then raise exception 'Cancellation note is required'; end if;
  select * into v_run from public.checklist_runs where id=p_run_id for update;
  if not found then raise exception 'Checklist run not found'; end if;
  if v_run.status='CANCELLED' then raise exception 'Checklist run already cancelled'; end if;
  update public.checklist_runs
  set status='CANCELLED',cancelled_by=v_uid,cancelled_at=now(),note=btrim(p_note),updated_at=now()
  where id=p_run_id returning * into v_run;
  return to_jsonb(v_run);
end; $$;

create or replace function public.checklist_template_create(
  p_template_code text,p_name text,p_module text,p_entity_type text,p_description text default null
) returns jsonb language sql set search_path='' as $$
  select private.checklist_template_create_impl(p_template_code,p_name,p_module,p_entity_type,p_description);
$$;
create or replace function public.checklist_template_add_item(
  p_template_id uuid,p_item_key text,p_label text,p_sort_order integer,
  p_requirement_rule text default 'OPTIONAL',p_system_managed boolean default false,p_description text default null
) returns jsonb language sql set search_path='' as $$
  select private.checklist_template_add_item_impl(p_template_id,p_item_key,p_label,p_sort_order,p_requirement_rule,p_system_managed,p_description);
$$;
create or replace function public.checklist_template_activate(p_template_id uuid)
returns jsonb language sql set search_path='' as $$ select private.checklist_template_activate_impl(p_template_id); $$;
create or replace function public.checklist_run_start(p_template_id uuid,p_entity_type text,p_entity_id uuid,p_note text default null)
returns jsonb language sql set search_path='' as $$ select private.checklist_run_start_impl(p_template_id,p_entity_type,p_entity_id,p_note); $$;
create or replace function public.checklist_run_set_item(p_run_item_id uuid,p_checked boolean,p_note text default null)
returns jsonb language sql set search_path='' as $$ select private.checklist_run_set_item_impl(p_run_item_id,p_checked,p_note); $$;
create or replace function public.checklist_run_refresh(p_run_id uuid)
returns jsonb language sql set search_path='' as $$ select private.checklist_run_refresh_impl(p_run_id); $$;
create or replace function public.checklist_run_complete(p_run_id uuid)
returns jsonb language sql set search_path='' as $$ select private.checklist_run_complete_impl(p_run_id); $$;
create or replace function public.checklist_run_reopen(p_run_id uuid,p_note text default null)
returns jsonb language sql set search_path='' as $$ select private.checklist_run_reopen_impl(p_run_id,p_note); $$;
create or replace function public.checklist_run_cancel(p_run_id uuid,p_note text)
returns jsonb language sql set search_path='' as $$ select private.checklist_run_cancel_impl(p_run_id,p_note); $$;

revoke execute on function private.checklist_template_create_impl(text,text,text,text,text) from public,anon,authenticated;
revoke execute on function private.checklist_template_add_item_impl(uuid,text,text,integer,text,boolean,text) from public,anon,authenticated;
revoke execute on function private.checklist_template_activate_impl(uuid) from public,anon,authenticated;
revoke execute on function private.checklist_run_start_impl(uuid,text,uuid,text) from public,anon,authenticated;
revoke execute on function private.checklist_run_set_item_impl(uuid,boolean,text) from public,anon,authenticated;
revoke execute on function private.checklist_run_refresh_impl(uuid) from public,anon,authenticated;
revoke execute on function private.checklist_run_complete_impl(uuid) from public,anon,authenticated;
revoke execute on function private.checklist_run_reopen_impl(uuid,text) from public,anon,authenticated;
revoke execute on function private.checklist_run_cancel_impl(uuid,text) from public,anon,authenticated;

grant execute on function private.checklist_template_create_impl(text,text,text,text,text) to authenticated;
grant execute on function private.checklist_template_add_item_impl(uuid,text,text,integer,text,boolean,text) to authenticated;
grant execute on function private.checklist_template_activate_impl(uuid) to authenticated;
grant execute on function private.checklist_run_start_impl(uuid,text,uuid,text) to authenticated;
grant execute on function private.checklist_run_set_item_impl(uuid,boolean,text) to authenticated;
grant execute on function private.checklist_run_refresh_impl(uuid) to authenticated;
grant execute on function private.checklist_run_complete_impl(uuid) to authenticated;
grant execute on function private.checklist_run_reopen_impl(uuid,text) to authenticated;
grant execute on function private.checklist_run_cancel_impl(uuid,text) to authenticated;

revoke execute on function public.checklist_template_create(text,text,text,text,text) from public,anon;
revoke execute on function public.checklist_template_add_item(uuid,text,text,integer,text,boolean,text) from public,anon;
revoke execute on function public.checklist_template_activate(uuid) from public,anon;
revoke execute on function public.checklist_run_start(uuid,text,uuid,text) from public,anon;
revoke execute on function public.checklist_run_set_item(uuid,boolean,text) from public,anon;
revoke execute on function public.checklist_run_refresh(uuid) from public,anon;
revoke execute on function public.checklist_run_complete(uuid) from public,anon;
revoke execute on function public.checklist_run_reopen(uuid,text) from public,anon;
revoke execute on function public.checklist_run_cancel(uuid,text) from public,anon;
grant execute on function public.checklist_template_create(text,text,text,text,text) to authenticated;
grant execute on function public.checklist_template_add_item(uuid,text,text,integer,text,boolean,text) to authenticated;
grant execute on function public.checklist_template_activate(uuid) to authenticated;
grant execute on function public.checklist_run_start(uuid,text,uuid,text) to authenticated;
grant execute on function public.checklist_run_set_item(uuid,boolean,text) to authenticated;
grant execute on function public.checklist_run_refresh(uuid) to authenticated;
grant execute on function public.checklist_run_complete(uuid) to authenticated;
grant execute on function public.checklist_run_reopen(uuid,text) to authenticated;
grant execute on function public.checklist_run_cancel(uuid,text) to authenticated;

insert into public.checklist_templates(template_code,version,name,module,entity_type,description,is_active,is_system)
values('SALES_DELIVERY',1,'Bàn giao đơn bán','SALES','SALES_ORDER',
       'Checklist 16 mục bàn giao đơn bán đã khóa từ T0/T4',true,true);

insert into public.checklist_template_items(template_id,item_key,label,sort_order,requirement_rule,system_managed)
select t.id,x.item_key,x.label,x.sort_order,x.requirement_rule,x.system_managed
from public.checklist_templates t
cross join (values
 ('customer_identity','Đối chiếu thông tin khách hàng',1,'ALWAYS',false),
 ('contact_phone','Xác nhận số điện thoại liên hệ',2,'ALWAYS',false),
 ('product_quantity','Đối chiếu sản phẩm và số lượng',3,'ALWAYS',false),
 ('product_configuration','Đối chiếu model/cấu hình hàng giao',4,'ALWAYS',false),
 ('serial_numbers','Đối chiếu Serial/Asset Tag khi có',5,'SALES_HAS_SERIAL',false),
 ('accessories','Đối chiếu phụ kiện đi kèm',6,'OPTIONAL',false),
 ('physical_condition','Kiểm tra ngoại hình trước bàn giao',7,'ALWAYS',false),
 ('functionality_test','Kiểm tra hoạt động trước bàn giao',8,'ALWAYS',false),
 ('price_discount','Xác nhận giá bán và giảm giá',9,'ALWAYS',false),
 ('payment_confirmed','Xác nhận thanh toán',10,'ALWAYS',true),
 ('receipt_invoice','Giao phiếu/hoá đơn khi áp dụng',11,'OPTIONAL',false),
 ('warranty_terms','Thông báo điều kiện và thời hạn bảo hành',12,'ALWAYS',false),
 ('warranty_document','Giao thông tin/QR bảo hành khi áp dụng',13,'OPTIONAL',false),
 ('software_license','Bàn giao bản quyền/phần mềm khi áp dụng',14,'OPTIONAL',false),
 ('data_backup_handover','Xác nhận dữ liệu/backup khi áp dụng',15,'OPTIONAL',false),
 ('customer_delivery_confirmation','Khách xác nhận đã nhận đủ hàng',16,'ALWAYS',false)
) as x(item_key,label,sort_order,requirement_rule,system_managed)
where t.template_code='SALES_DELIVERY' and t.version=1;

create view public.checklist_run_summary with (security_invoker=true) as
select r.id,r.template_id,r.template_code_snapshot,r.template_version,t.name as template_name,t.module,
       r.entity_type,r.entity_id,r.status,r.note,r.started_by,r.completed_by,r.cancelled_by,
       r.started_at,r.completed_at,r.cancelled_at,r.created_at,r.updated_at,
       count(i.id) as item_count,
       count(i.id) filter(where i.required) as required_count,
       count(i.id) filter(where i.required and i.checked) as required_checked_count,
       count(i.id) filter(where i.checked) as checked_count
from public.checklist_runs r
join public.checklist_templates t on t.id=r.template_id
left join public.checklist_run_items i on i.run_id=r.id
group by r.id,t.id;
revoke all on public.checklist_run_summary from anon,authenticated;
grant select on public.checklist_run_summary to authenticated;
