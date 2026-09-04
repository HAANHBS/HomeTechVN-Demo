create or replace function private.service_add_interval(p_date date,p_count integer,p_unit text)
returns date language plpgsql immutable set search_path='' as $$
begin
  if p_count is null or p_count<=0 then raise exception 'Interval count must be greater than zero'; end if;
  case p_unit
    when 'DAYS' then return (p_date + make_interval(days=>p_count))::date;
    when 'MONTHS' then return (p_date + make_interval(months=>p_count))::date;
    when 'YEARS' then return (p_date + make_interval(years=>p_count))::date;
    else raise exception 'Invalid interval unit';
  end case;
end; $$;
revoke execute on function private.service_add_interval(date,integer,text) from public,anon,authenticated;

create or replace function private.service_create_impl(
  p_name text,p_category text default 'MAINTENANCE',p_description text default null,
  p_interval_count integer default 1,p_interval_unit text default 'MONTHS',
  p_default_price numeric default 0,p_warranty_months integer default 0
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.services%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('service.manage') then raise exception 'Missing permission service.manage'; end if;
  if nullif(btrim(p_name),'') is null then raise exception 'Service name is required'; end if;
  if p_interval_count is null or p_interval_count<=0 then raise exception 'Interval count must be greater than zero'; end if;
  if p_interval_unit not in ('DAYS','MONTHS','YEARS') then raise exception 'Invalid interval unit'; end if;
  if p_default_price is null or p_default_price<0 then raise exception 'Default price cannot be negative'; end if;
  if p_warranty_months is null or p_warranty_months<0 then raise exception 'Warranty months cannot be negative'; end if;
  insert into public.services(name,category,description,default_interval_count,default_interval_unit,default_price,warranty_months,created_by,updated_by)
  values(btrim(p_name),p_category,nullif(btrim(p_description),''),p_interval_count,p_interval_unit,p_default_price,p_warranty_months,v_uid,v_uid)
  returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.service_update_impl(
  p_service_id uuid,p_name text,p_category text,p_description text,
  p_interval_count integer,p_interval_unit text,p_default_price numeric,
  p_warranty_months integer,p_is_active boolean
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.services%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('service.manage') then raise exception 'Missing permission service.manage'; end if;
  select * into v_row from public.services where id=p_service_id for update;
  if not found then raise exception 'Service not found'; end if;
  if nullif(btrim(p_name),'') is null then raise exception 'Service name is required'; end if;
  if p_interval_count is null or p_interval_count<=0 then raise exception 'Interval count must be greater than zero'; end if;
  if p_interval_unit not in ('DAYS','MONTHS','YEARS') then raise exception 'Invalid interval unit'; end if;
  if p_default_price is null or p_default_price<0 then raise exception 'Default price cannot be negative'; end if;
  if p_warranty_months is null or p_warranty_months<0 then raise exception 'Warranty months cannot be negative'; end if;
  update public.services set
    name=btrim(p_name),category=p_category,description=nullif(btrim(p_description),''),
    default_interval_count=p_interval_count,default_interval_unit=p_interval_unit,
    default_price=p_default_price,warranty_months=p_warranty_months,is_active=coalesce(p_is_active,true),
    updated_by=v_uid,updated_at=now()
  where id=p_service_id returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.service_schedule_create_impl(
  p_service_id uuid,p_customer_id uuid,p_customer_device_id uuid default null,
  p_start_date date default current_date,p_next_due_date date default null,
  p_interval_count integer default null,p_interval_unit text default null,
  p_price numeric default null,p_end_date date default null,p_note text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid(); v_service public.services%rowtype; v_row public.service_schedules%rowtype;
  v_count integer; v_unit text; v_due date; v_price numeric;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('service.manage') then raise exception 'Missing permission service.manage'; end if;
  select * into v_service from public.services where id=p_service_id and is_active=true;
  if not found then raise exception 'Active service not found'; end if;
  if not exists(select 1 from public.customers where id=p_customer_id and status='ACTIVE') then
    raise exception 'Customer not found or inactive';
  end if;
  if p_customer_device_id is not null
     and not exists(select 1 from public.customer_devices where id=p_customer_device_id and customer_id=p_customer_id)
  then raise exception 'Customer device does not belong to customer'; end if;
  if p_start_date is null then raise exception 'Start date is required'; end if;
  v_count:=coalesce(p_interval_count,v_service.default_interval_count);
  v_unit:=coalesce(p_interval_unit,v_service.default_interval_unit);
  v_price:=coalesce(p_price,v_service.default_price);
  if v_count<=0 or v_unit not in ('DAYS','MONTHS','YEARS') then raise exception 'Invalid service interval'; end if;
  if v_price<0 then raise exception 'Price cannot be negative'; end if;
  v_due:=coalesce(p_next_due_date,p_start_date);
  if v_due<p_start_date then raise exception 'Next due date cannot be before start date'; end if;
  if p_end_date is not null and p_end_date<p_start_date then raise exception 'End date cannot be before start date'; end if;
  insert into public.service_schedules(
    service_id,customer_id,customer_device_id,status,interval_count,interval_unit,
    start_date,next_due_date,end_date,price,note,created_by,updated_by
  )
  values(
    p_service_id,p_customer_id,p_customer_device_id,'ACTIVE',v_count,v_unit,
    p_start_date,v_due,p_end_date,v_price,nullif(btrim(p_note),''),v_uid,v_uid
  ) returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.service_schedule_update_impl(
  p_schedule_id uuid,p_next_due_date date,p_interval_count integer,p_interval_unit text,
  p_price numeric,p_end_date date default null,p_note text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.service_schedules%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('service.manage') then raise exception 'Missing permission service.manage'; end if;
  select * into v_row from public.service_schedules where id=p_schedule_id for update;
  if not found then raise exception 'Service schedule not found'; end if;
  if v_row.status in ('CANCELLED','COMPLETED') then raise exception 'Closed service schedule cannot be edited'; end if;
  if p_next_due_date is null or p_next_due_date<v_row.start_date then raise exception 'Invalid next due date'; end if;
  if p_interval_count is null or p_interval_count<=0 or p_interval_unit not in ('DAYS','MONTHS','YEARS') then
    raise exception 'Invalid service interval';
  end if;
  if p_price is null or p_price<0 then raise exception 'Price cannot be negative'; end if;
  if p_end_date is not null and p_end_date<v_row.start_date then raise exception 'Invalid end date'; end if;
  update public.service_schedules set
    next_due_date=p_next_due_date,interval_count=p_interval_count,interval_unit=p_interval_unit,
    price=p_price,end_date=p_end_date,note=nullif(btrim(p_note),''),
    updated_by=v_uid,updated_at=now()
  where id=p_schedule_id returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.service_schedule_set_status_impl(
  p_schedule_id uuid,p_status text,p_note text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.service_schedules%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('service.manage') then raise exception 'Missing permission service.manage'; end if;
  if p_status not in ('ACTIVE','PAUSED','CANCELLED') then raise exception 'Invalid service schedule status'; end if;
  select * into v_row from public.service_schedules where id=p_schedule_id for update;
  if not found then raise exception 'Service schedule not found'; end if;
  if v_row.status='COMPLETED' then raise exception 'Completed service schedule cannot change status'; end if;
  if v_row.status='CANCELLED' and p_status<>'CANCELLED' then raise exception 'Cancelled service schedule cannot be reopened'; end if;
  update public.service_schedules set
    status=p_status,note=coalesce(nullif(btrim(p_note),''),note),updated_by=v_uid,updated_at=now()
  where id=p_schedule_id returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.service_schedule_complete_impl(
  p_schedule_id uuid,p_note text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.service_schedules%rowtype; v_next date; v_status text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('service.manage') then raise exception 'Missing permission service.manage'; end if;
  select * into v_row from public.service_schedules where id=p_schedule_id for update;
  if not found then raise exception 'Service schedule not found'; end if;
  if v_row.status<>'ACTIVE' then raise exception 'Only ACTIVE service schedule can be completed'; end if;
  v_next:=private.service_add_interval(v_row.next_due_date,v_row.interval_count,v_row.interval_unit);
  v_status:=case when v_row.end_date is not null and v_next>v_row.end_date then 'COMPLETED' else 'ACTIVE' end;
  update public.service_schedules set
    completion_count=completion_count+1,last_completed_at=now(),last_completion_id=gen_random_uuid(),
    next_due_date=v_next,status=v_status,note=coalesce(nullif(btrim(p_note),''),note),
    updated_by=v_uid,updated_at=now()
  where id=p_schedule_id returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.software_product_create_impl(
  p_category text,p_vendor text,p_name text,p_edition text default null,
  p_billing_model text default 'SUBSCRIPTION',p_default_term_months integer default null,
  p_description text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.software_products%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('license.manage') then raise exception 'Missing permission license.manage'; end if;
  if nullif(btrim(p_name),'') is null then raise exception 'Software product name is required'; end if;
  if p_billing_model='SUBSCRIPTION' and (p_default_term_months is null or p_default_term_months<=0) then
    raise exception 'Subscription default term months must be greater than zero';
  end if;
  if p_default_term_months is not null and p_default_term_months<=0 then
    raise exception 'Default term months must be greater than zero';
  end if;
  insert into public.software_products(
    category,vendor,name,edition,billing_model,default_term_months,description,created_by,updated_by
  ) values(
    p_category,nullif(btrim(p_vendor),''),btrim(p_name),nullif(btrim(p_edition),''),
    p_billing_model,p_default_term_months,nullif(btrim(p_description),''),v_uid,v_uid
  ) returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.software_product_update_impl(
  p_product_id uuid,p_category text,p_vendor text,p_name text,p_edition text,
  p_billing_model text,p_default_term_months integer,p_description text,p_is_active boolean
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.software_products%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('license.manage') then raise exception 'Missing permission license.manage'; end if;
  select * into v_row from public.software_products where id=p_product_id for update;
  if not found then raise exception 'Software product not found'; end if;
  if nullif(btrim(p_name),'') is null then raise exception 'Software product name is required'; end if;
  if p_billing_model='SUBSCRIPTION' and (p_default_term_months is null or p_default_term_months<=0) then
    raise exception 'Subscription default term months must be greater than zero';
  end if;
  update public.software_products set
    category=p_category,vendor=nullif(btrim(p_vendor),''),name=btrim(p_name),
    edition=nullif(btrim(p_edition),''),billing_model=p_billing_model,
    default_term_months=p_default_term_months,description=nullif(btrim(p_description),''),
    is_active=coalesce(p_is_active,true),updated_by=v_uid,updated_at=now()
  where id=p_product_id returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.software_license_create_impl(
  p_software_product_id uuid,p_customer_id uuid,p_customer_device_id uuid default null,
  p_start_date date default current_date,p_end_date date default null,p_seats integer default 1,
  p_account_identifier text default null,p_secret_ref text default null,p_auto_renew boolean default false,
  p_renewal_cost numeric default 0,p_note text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid(); v_product public.software_products%rowtype;
  v_row public.software_licenses%rowtype; v_end date; v_code text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('license.manage') then raise exception 'Missing permission license.manage'; end if;
  select * into v_product from public.software_products where id=p_software_product_id and is_active=true;
  if not found then raise exception 'Active software product not found'; end if;
  if not exists(select 1 from public.customers where id=p_customer_id and status='ACTIVE') then
    raise exception 'Customer not found or inactive';
  end if;
  if p_customer_device_id is not null
     and not exists(select 1 from public.customer_devices where id=p_customer_device_id and customer_id=p_customer_id)
  then raise exception 'Customer device does not belong to customer'; end if;
  if p_start_date is null then raise exception 'Start date is required'; end if;
  if p_seats is null or p_seats<=0 then raise exception 'Seats must be greater than zero'; end if;
  if p_renewal_cost is null or p_renewal_cost<0 then raise exception 'Renewal cost cannot be negative'; end if;
  if nullif(btrim(p_secret_ref),'') is not null
     and btrim(p_secret_ref) !~ '^[A-Za-z][A-Za-z0-9+.-]*://.+'
  then raise exception 'secret_ref must be an external secret reference URI, never a plaintext license key'; end if;
  v_end:=p_end_date;
  if v_end is null and v_product.default_term_months is not null then
    v_end:=(p_start_date+make_interval(months=>v_product.default_term_months)-interval '1 day')::date;
  end if;
  if v_product.billing_model='SUBSCRIPTION' and v_end is null then
    raise exception 'Subscription license requires end date or default term';
  end if;
  if v_end is not null and v_end<p_start_date then raise exception 'End date cannot be before start date'; end if;
  v_code:=private.next_simple_code('SOFTWARE_LICENSE','LIC',6);
  insert into public.software_licenses(
    license_code,software_product_id,customer_id,customer_device_id,status,start_date,end_date,seats,
    account_identifier,secret_ref,auto_renew,renewal_cost,note,created_by,updated_by
  ) values(
    v_code,p_software_product_id,p_customer_id,p_customer_device_id,'ACTIVE',p_start_date,v_end,p_seats,
    nullif(btrim(p_account_identifier),''),nullif(btrim(p_secret_ref),''),coalesce(p_auto_renew,false),
    p_renewal_cost,nullif(btrim(p_note),''),v_uid,v_uid
  ) returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.software_license_update_impl(
  p_license_id uuid,p_seats integer,p_account_identifier text,p_secret_ref text,
  p_auto_renew boolean,p_renewal_cost numeric,p_note text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.software_licenses%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('license.manage') then raise exception 'Missing permission license.manage'; end if;
  select * into v_row from public.software_licenses where id=p_license_id for update;
  if not found then raise exception 'Software license not found'; end if;
  if v_row.status='CANCELLED' then raise exception 'Cancelled license cannot be edited'; end if;
  if p_seats is null or p_seats<=0 then raise exception 'Seats must be greater than zero'; end if;
  if p_renewal_cost is null or p_renewal_cost<0 then raise exception 'Renewal cost cannot be negative'; end if;
  if nullif(btrim(p_secret_ref),'') is not null
     and btrim(p_secret_ref) !~ '^[A-Za-z][A-Za-z0-9+.-]*://.+'
  then raise exception 'secret_ref must be an external secret reference URI, never a plaintext license key'; end if;
  update public.software_licenses set
    seats=p_seats,account_identifier=nullif(btrim(p_account_identifier),''),
    secret_ref=nullif(btrim(p_secret_ref),''),auto_renew=coalesce(p_auto_renew,false),
    renewal_cost=p_renewal_cost,note=nullif(btrim(p_note),''),updated_by=v_uid,updated_at=now()
  where id=p_license_id returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.software_license_renew_impl(
  p_license_id uuid,p_term_months integer,p_renewal_cost numeric default null,p_note text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.software_licenses%rowtype; v_base date;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('license.manage') then raise exception 'Missing permission license.manage'; end if;
  if p_term_months is null or p_term_months<=0 then raise exception 'Renewal term months must be greater than zero'; end if;
  select * into v_row from public.software_licenses where id=p_license_id for update;
  if not found then raise exception 'Software license not found'; end if;
  if v_row.status='CANCELLED' then raise exception 'Cancelled license cannot be renewed'; end if;
  v_base:=greatest(coalesce(v_row.end_date,current_date),current_date);
  update public.software_licenses set
    end_date=(v_base+make_interval(months=>p_term_months)-interval '1 day')::date,
    status='ACTIVE',renewal_cost=coalesce(p_renewal_cost,renewal_cost),
    note=coalesce(nullif(btrim(p_note),''),note),updated_by=v_uid,updated_at=now()
  where id=p_license_id returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.software_license_set_status_impl(
  p_license_id uuid,p_status text,p_reason text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.software_licenses%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('license.manage') then raise exception 'Missing permission license.manage'; end if;
  if p_status not in ('ACTIVE','EXPIRED','SUSPENDED','CANCELLED') then raise exception 'Invalid license status'; end if;
  select * into v_row from public.software_licenses where id=p_license_id for update;
  if not found then raise exception 'Software license not found'; end if;
  if v_row.status='CANCELLED' and p_status<>'CANCELLED' then raise exception 'Cancelled license cannot be reopened'; end if;
  if p_status='CANCELLED' and nullif(btrim(p_reason),'') is null then raise exception 'Cancellation reason is required'; end if;
  update public.software_licenses set
    status=p_status,
    cancelled_reason=case when p_status='CANCELLED' then btrim(p_reason) else null end,
    updated_by=v_uid,updated_at=now()
  where id=p_license_id returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function private.warranty_create_service_impl(
  p_schedule_id uuid,p_warranty_months integer default null,p_coverage text default null,p_note text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid(); v_schedule public.service_schedules%rowtype; v_service public.services%rowtype;
  v_device public.customer_devices%rowtype; v_months integer; v_start date; v_code text;
  v_row public.warranties%rowtype; v_name text; v_serial text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('warranty.manage') then raise exception 'Missing permission warranty.manage'; end if;
  if not private.has_permission('service.view') then raise exception 'Missing permission service.view'; end if;
  select * into v_schedule from public.service_schedules where id=p_schedule_id;
  if not found then raise exception 'Service schedule not found'; end if;
  if v_schedule.last_completion_id is null or v_schedule.last_completed_at is null then
    raise exception 'Service schedule has no completed occurrence';
  end if;
  select * into v_service from public.services where id=v_schedule.service_id;
  v_months:=coalesce(p_warranty_months,v_service.warranty_months);
  if v_months is null or v_months<=0 then raise exception 'Warranty months must be greater than zero'; end if;
  v_start:=timezone('Asia/Bangkok',v_schedule.last_completed_at)::date;
  if v_schedule.customer_device_id is not null then
    select * into v_device from public.customer_devices where id=v_schedule.customer_device_id;
    v_name:=nullif(btrim(concat_ws(' ',v_device.device_type,v_device.brand,v_device.model)),'');
    v_serial:=v_device.serial_number;
  end if;
  v_name:=coalesce(v_name,v_service.name);
  v_code:=private.next_daily_code('WARRANTY','WAR',null,4);
  insert into public.warranties(
    warranty_code,customer_id,customer_device_id,source_type,source_id,source_item_id,
    product_name_snapshot,serial_snapshot,coverage,start_date,end_date,status,note,created_by,updated_by
  ) values(
    v_code,v_schedule.customer_id,v_schedule.customer_device_id,'SERVICE',v_schedule.id,v_schedule.last_completion_id,
    v_name,v_serial,coalesce(nullif(btrim(p_coverage),''),'Bao hanh dich vu: '||v_service.name),
    v_start,(v_start+make_interval(months=>v_months)-interval '1 day')::date,
    'ACTIVE',nullif(btrim(p_note),''),v_uid,v_uid
  ) returning * into v_row;
  return to_jsonb(v_row);
end; $$;

create or replace function public.service_create(
  p_name text,p_category text default 'MAINTENANCE',p_description text default null,
  p_interval_count integer default 1,p_interval_unit text default 'MONTHS',
  p_default_price numeric default 0,p_warranty_months integer default 0
) returns jsonb language sql set search_path='' as $$
  select private.service_create_impl(p_name,p_category,p_description,p_interval_count,p_interval_unit,p_default_price,p_warranty_months);
$$;
create or replace function public.service_update(
  p_service_id uuid,p_name text,p_category text,p_description text,p_interval_count integer,
  p_interval_unit text,p_default_price numeric,p_warranty_months integer,p_is_active boolean
) returns jsonb language sql set search_path='' as $$
  select private.service_update_impl(p_service_id,p_name,p_category,p_description,p_interval_count,p_interval_unit,p_default_price,p_warranty_months,p_is_active);
$$;
create or replace function public.service_schedule_create(
  p_service_id uuid,p_customer_id uuid,p_customer_device_id uuid default null,
  p_start_date date default current_date,p_next_due_date date default null,
  p_interval_count integer default null,p_interval_unit text default null,
  p_price numeric default null,p_end_date date default null,p_note text default null
) returns jsonb language sql set search_path='' as $$
  select private.service_schedule_create_impl(p_service_id,p_customer_id,p_customer_device_id,p_start_date,p_next_due_date,p_interval_count,p_interval_unit,p_price,p_end_date,p_note);
$$;
create or replace function public.service_schedule_update(
  p_schedule_id uuid,p_next_due_date date,p_interval_count integer,p_interval_unit text,
  p_price numeric,p_end_date date default null,p_note text default null
) returns jsonb language sql set search_path='' as $$
  select private.service_schedule_update_impl(p_schedule_id,p_next_due_date,p_interval_count,p_interval_unit,p_price,p_end_date,p_note);
$$;
create or replace function public.service_schedule_set_status(
  p_schedule_id uuid,p_status text,p_note text default null
) returns jsonb language sql set search_path='' as $$
  select private.service_schedule_set_status_impl(p_schedule_id,p_status,p_note);
$$;
create or replace function public.service_schedule_complete(
  p_schedule_id uuid,p_note text default null
) returns jsonb language sql set search_path='' as $$
  select private.service_schedule_complete_impl(p_schedule_id,p_note);
$$;
create or replace function public.software_product_create(
  p_category text,p_vendor text,p_name text,p_edition text default null,
  p_billing_model text default 'SUBSCRIPTION',p_default_term_months integer default null,p_description text default null
) returns jsonb language sql set search_path='' as $$
  select private.software_product_create_impl(p_category,p_vendor,p_name,p_edition,p_billing_model,p_default_term_months,p_description);
$$;
create or replace function public.software_product_update(
  p_product_id uuid,p_category text,p_vendor text,p_name text,p_edition text,
  p_billing_model text,p_default_term_months integer,p_description text,p_is_active boolean
) returns jsonb language sql set search_path='' as $$
  select private.software_product_update_impl(p_product_id,p_category,p_vendor,p_name,p_edition,p_billing_model,p_default_term_months,p_description,p_is_active);
$$;
create or replace function public.software_license_create(
  p_software_product_id uuid,p_customer_id uuid,p_customer_device_id uuid default null,
  p_start_date date default current_date,p_end_date date default null,p_seats integer default 1,
  p_account_identifier text default null,p_secret_ref text default null,p_auto_renew boolean default false,
  p_renewal_cost numeric default 0,p_note text default null
) returns jsonb language sql set search_path='' as $$
  select private.software_license_create_impl(p_software_product_id,p_customer_id,p_customer_device_id,p_start_date,p_end_date,p_seats,p_account_identifier,p_secret_ref,p_auto_renew,p_renewal_cost,p_note);
$$;
create or replace function public.software_license_update(
  p_license_id uuid,p_seats integer,p_account_identifier text,p_secret_ref text,
  p_auto_renew boolean,p_renewal_cost numeric,p_note text default null
) returns jsonb language sql set search_path='' as $$
  select private.software_license_update_impl(p_license_id,p_seats,p_account_identifier,p_secret_ref,p_auto_renew,p_renewal_cost,p_note);
$$;
create or replace function public.software_license_renew(
  p_license_id uuid,p_term_months integer,p_renewal_cost numeric default null,p_note text default null
) returns jsonb language sql set search_path='' as $$
  select private.software_license_renew_impl(p_license_id,p_term_months,p_renewal_cost,p_note);
$$;
create or replace function public.software_license_set_status(
  p_license_id uuid,p_status text,p_reason text default null
) returns jsonb language sql set search_path='' as $$
  select private.software_license_set_status_impl(p_license_id,p_status,p_reason);
$$;
create or replace function public.warranty_create_service(
  p_schedule_id uuid,p_warranty_months integer default null,p_coverage text default null,p_note text default null
) returns jsonb language sql set search_path='' as $$
  select private.warranty_create_service_impl(p_schedule_id,p_warranty_months,p_coverage,p_note);
$$;

revoke execute on function private.service_create_impl(text,text,text,integer,text,numeric,integer) from public,anon,authenticated;
revoke execute on function private.service_update_impl(uuid,text,text,text,integer,text,numeric,integer,boolean) from public,anon,authenticated;
revoke execute on function private.service_schedule_create_impl(uuid,uuid,uuid,date,date,integer,text,numeric,date,text) from public,anon,authenticated;
revoke execute on function private.service_schedule_update_impl(uuid,date,integer,text,numeric,date,text) from public,anon,authenticated;
revoke execute on function private.service_schedule_set_status_impl(uuid,text,text) from public,anon,authenticated;
revoke execute on function private.service_schedule_complete_impl(uuid,text) from public,anon,authenticated;
revoke execute on function private.software_product_create_impl(text,text,text,text,text,integer,text) from public,anon,authenticated;
revoke execute on function private.software_product_update_impl(uuid,text,text,text,text,text,integer,text,boolean) from public,anon,authenticated;
revoke execute on function private.software_license_create_impl(uuid,uuid,uuid,date,date,integer,text,text,boolean,numeric,text) from public,anon,authenticated;
revoke execute on function private.software_license_update_impl(uuid,integer,text,text,boolean,numeric,text) from public,anon,authenticated;
revoke execute on function private.software_license_renew_impl(uuid,integer,numeric,text) from public,anon,authenticated;
revoke execute on function private.software_license_set_status_impl(uuid,text,text) from public,anon,authenticated;
revoke execute on function private.warranty_create_service_impl(uuid,integer,text,text) from public,anon,authenticated;

grant execute on function private.service_create_impl(text,text,text,integer,text,numeric,integer) to authenticated;
grant execute on function private.service_update_impl(uuid,text,text,text,integer,text,numeric,integer,boolean) to authenticated;
grant execute on function private.service_schedule_create_impl(uuid,uuid,uuid,date,date,integer,text,numeric,date,text) to authenticated;
grant execute on function private.service_schedule_update_impl(uuid,date,integer,text,numeric,date,text) to authenticated;
grant execute on function private.service_schedule_set_status_impl(uuid,text,text) to authenticated;
grant execute on function private.service_schedule_complete_impl(uuid,text) to authenticated;
grant execute on function private.software_product_create_impl(text,text,text,text,text,integer,text) to authenticated;
grant execute on function private.software_product_update_impl(uuid,text,text,text,text,text,integer,text,boolean) to authenticated;
grant execute on function private.software_license_create_impl(uuid,uuid,uuid,date,date,integer,text,text,boolean,numeric,text) to authenticated;
grant execute on function private.software_license_update_impl(uuid,integer,text,text,boolean,numeric,text) to authenticated;
grant execute on function private.software_license_renew_impl(uuid,integer,numeric,text) to authenticated;
grant execute on function private.software_license_set_status_impl(uuid,text,text) to authenticated;
grant execute on function private.warranty_create_service_impl(uuid,integer,text,text) to authenticated;

revoke execute on function public.service_create(text,text,text,integer,text,numeric,integer) from public,anon;
revoke execute on function public.service_update(uuid,text,text,text,integer,text,numeric,integer,boolean) from public,anon;
revoke execute on function public.service_schedule_create(uuid,uuid,uuid,date,date,integer,text,numeric,date,text) from public,anon;
revoke execute on function public.service_schedule_update(uuid,date,integer,text,numeric,date,text) from public,anon;
revoke execute on function public.service_schedule_set_status(uuid,text,text) from public,anon;
revoke execute on function public.service_schedule_complete(uuid,text) from public,anon;
revoke execute on function public.software_product_create(text,text,text,text,text,integer,text) from public,anon;
revoke execute on function public.software_product_update(uuid,text,text,text,text,text,integer,text,boolean) from public,anon;
revoke execute on function public.software_license_create(uuid,uuid,uuid,date,date,integer,text,text,boolean,numeric,text) from public,anon;
revoke execute on function public.software_license_update(uuid,integer,text,text,boolean,numeric,text) from public,anon;
revoke execute on function public.software_license_renew(uuid,integer,numeric,text) from public,anon;
revoke execute on function public.software_license_set_status(uuid,text,text) from public,anon;
revoke execute on function public.warranty_create_service(uuid,integer,text,text) from public,anon;

grant execute on function public.service_create(text,text,text,integer,text,numeric,integer) to authenticated;
grant execute on function public.service_update(uuid,text,text,text,integer,text,numeric,integer,boolean) to authenticated;
grant execute on function public.service_schedule_create(uuid,uuid,uuid,date,date,integer,text,numeric,date,text) to authenticated;
grant execute on function public.service_schedule_update(uuid,date,integer,text,numeric,date,text) to authenticated;
grant execute on function public.service_schedule_set_status(uuid,text,text) to authenticated;
grant execute on function public.service_schedule_complete(uuid,text) to authenticated;
grant execute on function public.software_product_create(text,text,text,text,text,integer,text) to authenticated;
grant execute on function public.software_product_update(uuid,text,text,text,text,text,integer,text,boolean) to authenticated;
grant execute on function public.software_license_create(uuid,uuid,uuid,date,date,integer,text,text,boolean,numeric,text) to authenticated;
grant execute on function public.software_license_update(uuid,integer,text,text,boolean,numeric,text) to authenticated;
grant execute on function public.software_license_renew(uuid,integer,numeric,text) to authenticated;
grant execute on function public.software_license_set_status(uuid,text,text) to authenticated;
grant execute on function public.warranty_create_service(uuid,integer,text,text) to authenticated;
