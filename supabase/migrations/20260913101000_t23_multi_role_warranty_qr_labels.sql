-- T23: multi-role staff, operator-selected warranty duration and QR-label lookup context.
-- T1-T22/T21.4 migrations remain immutable; this migration is additive.

begin;

-- ---------------------------------------------------------------------------
-- One staff account may hold multiple active roles. profiles.role_id remains
-- the primary/legacy role so older reports and integrations keep working.
-- ---------------------------------------------------------------------------

create table public.profile_roles (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete restrict,
  assigned_by uuid references public.profiles(id) on delete set null,
  assigned_at timestamptz not null default now(),
  primary key (profile_id,role_id)
);

create index idx_profile_roles_role_profile
on public.profile_roles(role_id,profile_id);

insert into public.profile_roles(profile_id,role_id,assigned_by)
select p.id,p.role_id,null
from public.profiles p
where p.role_id is not null
on conflict do nothing;

alter table public.profile_roles enable row level security;

revoke all on table public.profile_roles from public,anon,authenticated;
grant select,insert,delete on table public.profile_roles to authenticated;

create policy profile_roles_select
on public.profile_roles
for select
to authenticated
using (
  profile_id=(select auth.uid())
  or (select private.has_permission('user.view'))
);

create policy profile_roles_insert
on public.profile_roles
for insert
to authenticated
with check (
  profile_id<>(select auth.uid())
  and (select private.has_permission('user.manage'))
);

create policy profile_roles_delete
on public.profile_roles
for delete
to authenticated
using (
  profile_id<>(select auth.uid())
  and (select private.has_permission('user.manage'))
);

create or replace function private.has_permission(p_permission_code text)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists (
    select 1
    from public.profile_roles pr
    join public.roles r on r.id=pr.role_id and r.is_active=true
    join public.role_permissions rp on rp.role_id=r.id
    join public.permissions pm on pm.id=rp.permission_id
    join public.profiles p on p.id=pr.profile_id and p.is_active=true
    where pr.profile_id=auth.uid()
      and pm.code=p_permission_code
  ) or exists (
    -- Compatibility for a newly-created profile before its assignment row is made.
    select 1
    from public.profiles p
    join public.roles r on r.id=p.role_id and r.is_active=true
    join public.role_permissions rp on rp.role_id=r.id
    join public.permissions pm on pm.id=rp.permission_id
    where p.id=auth.uid()
      and p.is_active=true
      and pm.code=p_permission_code
  );
$$;

revoke all on function private.has_permission(text) from public,anon,authenticated;
grant execute on function private.has_permission(text) to authenticated;

create or replace function private.profile_primary_role_sync()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if new.role_id is not null then
    insert into public.profile_roles(profile_id,role_id,assigned_by)
    values(new.id,new.role_id,auth.uid())
    on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_primary_role_sync on public.profiles;
create trigger trg_profiles_primary_role_sync
after insert or update of role_id on public.profiles
for each row execute function private.profile_primary_role_sync();

create or replace function public.staff_set_roles(
  p_profile_id uuid,
  p_role_ids uuid[]
)
returns jsonb
language plpgsql
security invoker
set search_path=''
as $$
declare
  v_ids uuid[];
  v_valid integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('user.manage') then raise exception 'Missing permission user.manage'; end if;
  if p_profile_id is null or p_profile_id=auth.uid() then
    raise exception 'Không thể tự thay đổi chức vụ của tài khoản đang đăng nhập';
  end if;

  select coalesce(array_agg(x order by first_position),'{}'::uuid[])
  into v_ids
  from (
    select x,min(position) as first_position
    from unnest(coalesce(p_role_ids,'{}'::uuid[])) with ordinality u(x,position)
    group by x
  ) unique_roles;

  if cardinality(v_ids)<1 or cardinality(v_ids)>5 then
    raise exception 'Mỗi nhân viên phải có từ 1 đến 5 chức vụ';
  end if;

  select count(*) into v_valid
  from public.roles r
  where r.id=any(v_ids) and r.is_active=true;
  if v_valid<>cardinality(v_ids) then raise exception 'Danh sách chức vụ không hợp lệ hoặc đã bị khóa'; end if;

  update public.profiles
  set role_id=v_ids[1],updated_at=now()
  where id=p_profile_id;
  if not found then raise exception 'Không tìm thấy nhân viên'; end if;

  delete from public.profile_roles where profile_id=p_profile_id;
  insert into public.profile_roles(profile_id,role_id,assigned_by)
  select p_profile_id,x,auth.uid() from unnest(v_ids) x;

  return jsonb_build_object('profile_id',p_profile_id,'role_ids',to_jsonb(v_ids));
end;
$$;

create or replace function private.profile_has_role(p_profile_id uuid,p_role_code text)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists (
    select 1
    from public.profile_roles pr
    join public.roles r on r.id=pr.role_id and r.is_active=true
    join public.profiles p on p.id=pr.profile_id and p.is_active=true
    where pr.profile_id=p_profile_id and r.code=p_role_code
  ) or exists (
    select 1
    from public.profiles p
    join public.roles r on r.id=p.role_id and r.is_active=true
    where p.id=p_profile_id and p.is_active=true and r.code=p_role_code
  );
$$;

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
  if p_assigned_technician_id is not null and not private.profile_has_role(p_assigned_technician_id,'technician') then raise exception 'Assigned technician is invalid'; end if;
  if exists(select 1 from public.warranty_claims where warranty_id=p_warranty_id and status not in ('CLOSED','REJECTED')) then raise exception 'Warranty already has an active claim'; end if;
  v_code:=private.next_daily_code('WARRANTY_CLAIM','WCL',null,4);
  insert into public.warranty_claims(claim_code,warranty_id,status,issue_description,intake_condition,customer_request,assigned_technician_id,created_by,updated_by)
  values(v_code,p_warranty_id,'RECEIVED',btrim(p_issue_description),nullif(btrim(p_intake_condition),''),nullif(btrim(p_customer_request),''),p_assigned_technician_id,v_uid,v_uid)
  returning * into v_row;
  insert into public.warranty_status_history(warranty_claim_id,from_status,to_status,note,changed_by)
  values(v_row.id,null,'RECEIVED','Tiếp nhận yêu cầu bảo hành',v_uid);
  return to_jsonb(v_row);
end;
$$;

create or replace function private.warranty_claim_start_checking_impl(p_claim_id uuid,p_assigned_technician_id uuid default null,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v public.warranty_claims%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if;
  if p_assigned_technician_id is not null and not private.profile_has_role(p_assigned_technician_id,'technician') then raise exception 'Assigned technician is invalid'; end if;
  if p_assigned_technician_id is not null then update public.warranty_claims set assigned_technician_id=p_assigned_technician_id,updated_by=v_uid where id=p_claim_id; end if;
  v:=private.warranty_claim_transition(p_claim_id,'CHECKING',p_note,v_uid);
  return to_jsonb(v);
end;
$$;

revoke all on function private.profile_primary_role_sync() from public,anon,authenticated;
revoke all on function private.profile_has_role(uuid,text) from public,anon,authenticated;
revoke all on function public.staff_set_roles(uuid,uuid[]) from public,anon,authenticated;
grant execute on function public.staff_set_roles(uuid,uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- Warranty duration is selected where the actual transaction is created.
-- Existing RPCs stay available; the UI uses the additive v2 functions.
-- ---------------------------------------------------------------------------

alter table public.repair_quotes
add column warranty_months integer not null default 3
check (warranty_months between 1 and 120);

create or replace function private.sale_add_item_v2_impl(
  p_order_id uuid,
  p_product_id uuid,
  p_quantity numeric,
  p_unit_price numeric default null,
  p_discount_amount numeric default 0,
  p_inventory_unit_ids uuid[] default '{}'::uuid[],
  p_warranty_months integer default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_item jsonb;
  v_id uuid;
  v_row public.sales_order_items%rowtype;
begin
  if p_warranty_months is not null and (p_warranty_months<0 or p_warranty_months>120) then
    raise exception 'Thời hạn bảo hành phải từ 0 đến 120 tháng';
  end if;
  v_item:=private.sale_add_item_impl(
    p_order_id,p_product_id,p_quantity,p_unit_price,p_discount_amount,p_inventory_unit_ids
  );
  v_id:=(v_item->>'id')::uuid;
  if p_warranty_months is not null then
    update public.sales_order_items
    set warranty_months=p_warranty_months,updated_by=auth.uid(),updated_at=now()
    where id=v_id;
  end if;
  select * into strict v_row from public.sales_order_items where id=v_id;
  return to_jsonb(v_row);
end;
$$;

create or replace function private.sale_update_item_v2_impl(
  p_item_id uuid,
  p_quantity numeric,
  p_unit_price numeric,
  p_discount_amount numeric default 0,
  p_inventory_unit_ids uuid[] default '{}'::uuid[],
  p_warranty_months integer default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_item jsonb;
  v_row public.sales_order_items%rowtype;
begin
  if p_warranty_months is not null and (p_warranty_months<0 or p_warranty_months>120) then
    raise exception 'Thời hạn bảo hành phải từ 0 đến 120 tháng';
  end if;
  v_item:=private.sale_update_item_impl(
    p_item_id,p_quantity,p_unit_price,p_discount_amount,p_inventory_unit_ids
  );
  if p_warranty_months is not null then
    update public.sales_order_items
    set warranty_months=p_warranty_months,updated_by=auth.uid(),updated_at=now()
    where id=p_item_id;
  end if;
  select * into strict v_row from public.sales_order_items where id=p_item_id;
  return to_jsonb(v_row);
end;
$$;

create or replace function public.sale_add_item_v2(
  p_order_id uuid,
  p_product_id uuid,
  p_quantity numeric,
  p_unit_price numeric default null,
  p_discount_amount numeric default 0,
  p_inventory_unit_ids uuid[] default '{}'::uuid[],
  p_warranty_months integer default null
)
returns jsonb
language sql
security definer
set search_path=''
as $$
  select private.sale_add_item_v2_impl(
    p_order_id,p_product_id,p_quantity,p_unit_price,p_discount_amount,p_inventory_unit_ids,p_warranty_months
  );
$$;

create or replace function public.sale_update_item_v2(
  p_item_id uuid,
  p_quantity numeric,
  p_unit_price numeric,
  p_discount_amount numeric default 0,
  p_inventory_unit_ids uuid[] default '{}'::uuid[],
  p_warranty_months integer default null
)
returns jsonb
language sql
security definer
set search_path=''
as $$
  select private.sale_update_item_v2_impl(
    p_item_id,p_quantity,p_unit_price,p_discount_amount,p_inventory_unit_ids,p_warranty_months
  );
$$;

create or replace function private.repair_create_quote_v2_impl(
  p_order_id uuid,
  p_labor_amount numeric,
  p_parts_amount numeric,
  p_discount_amount numeric default 0,
  p_valid_until date default null,
  p_note text default null,
  p_warranty_months integer default 3
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_quote jsonb;
  v_id uuid;
  v_row public.repair_quotes%rowtype;
begin
  if p_warranty_months is null or p_warranty_months<1 or p_warranty_months>120 then
    raise exception 'Thời hạn bảo hành sửa chữa phải từ 1 đến 120 tháng';
  end if;
  v_quote:=private.repair_create_quote_impl(
    p_order_id,p_labor_amount,p_parts_amount,p_discount_amount,p_valid_until,p_note
  );
  v_id:=(v_quote->>'id')::uuid;
  update public.repair_quotes set warranty_months=p_warranty_months where id=v_id;
  select * into strict v_row from public.repair_quotes where id=v_id;
  return to_jsonb(v_row);
end;
$$;

create or replace function public.repair_create_quote_v2(
  p_order_id uuid,
  p_labor_amount numeric,
  p_parts_amount numeric,
  p_discount_amount numeric default 0,
  p_valid_until date default null,
  p_note text default null,
  p_warranty_months integer default 3
)
returns jsonb
language sql
security definer
set search_path=''
as $$
  select private.repair_create_quote_v2_impl(
    p_order_id,p_labor_amount,p_parts_amount,p_discount_amount,p_valid_until,p_note,p_warranty_months
  );
$$;

create or replace function private.repair_apply_selected_warranty_duration()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_months integer;
  v_start date;
begin
  if new.status='COMPLETED' and new.status is distinct from old.status then
    select q.warranty_months into v_months
    from public.repair_quotes q
    where q.id=new.approved_quote_id;
    v_months:=coalesce(v_months,3);
    v_start:=coalesce(new.completed_at,now())::date;
    update public.warranties
    set end_date=(v_start+make_interval(months=>v_months)-interval '1 day')::date,
        updated_by=coalesce(new.updated_by,new.created_by),updated_at=now()
    where source_type='REPAIR' and source_id=new.id
      and source_item_id is null and inventory_unit_id is null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_zz_repair_selected_warranty_duration on public.repair_orders;
create trigger trg_zz_repair_selected_warranty_duration
after update of status on public.repair_orders
for each row execute function private.repair_apply_selected_warranty_duration();

revoke all on function private.sale_add_item_v2_impl(uuid,uuid,numeric,numeric,numeric,uuid[],integer) from public,anon,authenticated;
revoke all on function private.sale_update_item_v2_impl(uuid,numeric,numeric,numeric,uuid[],integer) from public,anon,authenticated;
revoke all on function private.repair_create_quote_v2_impl(uuid,numeric,numeric,numeric,date,text,integer) from public,anon,authenticated;
revoke all on function private.repair_apply_selected_warranty_duration() from public,anon,authenticated;
revoke all on function public.sale_add_item_v2(uuid,uuid,numeric,numeric,numeric,uuid[],integer) from public,anon,authenticated;
revoke all on function public.sale_update_item_v2(uuid,numeric,numeric,numeric,uuid[],integer) from public,anon,authenticated;
revoke all on function public.repair_create_quote_v2(uuid,numeric,numeric,numeric,date,text,integer) from public,anon,authenticated;
grant execute on function public.sale_add_item_v2(uuid,uuid,numeric,numeric,numeric,uuid[],integer) to authenticated;
grant execute on function public.sale_update_item_v2(uuid,numeric,numeric,numeric,uuid[],integer) to authenticated;
grant execute on function public.repair_create_quote_v2(uuid,numeric,numeric,numeric,date,text,integer) to authenticated;

-- ---------------------------------------------------------------------------
-- A public warranty label identifies the buyer in masked form. Staff scans keep
-- using warranty_scan_product and receive the full customer details permitted
-- by their role.
-- ---------------------------------------------------------------------------

create or replace function private.warranty_mask_customer_name(p_value text)
returns text
language plpgsql
immutable
security invoker
set search_path=''
as $$
declare
  v_parts text[]:=regexp_split_to_array(btrim(coalesce(p_value,'')),'\s+');
  v_count integer;
begin
  v_count:=cardinality(v_parts);
  if v_count is null or v_count=0 or v_parts[1]='' then return null; end if;
  if v_count=1 then return left(v_parts[1],1)||'***'; end if;
  return left(v_parts[1],1)||'*** '||left(v_parts[v_count],1)||'***';
end;
$$;

create or replace function public_lookup_private.warranty_public_lookup_impl(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v jsonb;
begin
  if p_token is null or length(p_token)<>64 or p_token !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('found',false);
  end if;

  select jsonb_build_object(
    'found',true,
    'warranty_code',w.warranty_code,
    'status',case when w.status='VOID' then 'VOID' when current_date>w.end_date then 'EXPIRED' else 'ACTIVE' end,
    'start_date',w.start_date,
    'end_date',w.end_date,
    'days_remaining',case when w.status='VOID' then null when current_date>w.end_date then 0 else w.end_date-current_date end,
    'coverage',w.coverage,
    'product',coalesce(w.product_name_snapshot,nullif(concat_ws(' ',d.device_type,d.brand,d.model),'')),
    'serial_masked',private.warranty_mask_serial(coalesce(w.serial_snapshot,d.serial_number)),
    'customer_name_masked',private.warranty_mask_customer_name(c.full_name),
    'phone_masked',private.warranty_mask_phone(c.phone),
    'latest_claim',(
      select jsonb_build_object(
        'status',cl.status,'received_at',cl.received_at,'ready_at',cl.ready_at,
        'returned_at',cl.returned_at,'closed_at',cl.closed_at
      )
      from public.warranty_claims cl
      where cl.warranty_id=w.id
      order by cl.created_at desc
      limit 1
    )
  ) into v
  from public.warranties w
  join public.customers c on c.id=w.customer_id
  left join public.customer_devices d on d.id=w.customer_device_id
  where w.lookup_token=p_token;

  return coalesce(v,jsonb_build_object('found',false));
end;
$$;

revoke all on function private.warranty_mask_customer_name(text) from public,anon,authenticated;
revoke all on function public_lookup_private.warranty_public_lookup_impl(text) from public,anon,authenticated;
grant execute on function public_lookup_private.warranty_public_lookup_impl(text) to anon,authenticated,service_role;

commit;
