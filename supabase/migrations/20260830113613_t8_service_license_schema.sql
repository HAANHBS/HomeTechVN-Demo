create table public.services (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name))>0),
  category text not null default 'MAINTENANCE' check (category in ('MAINTENANCE','SUBSCRIPTION','MANAGED_SERVICE','OTHER')),
  description text,
  default_interval_count integer not null default 1 check (default_interval_count>0),
  default_interval_unit text not null default 'MONTHS' check (default_interval_unit in ('DAYS','MONTHS','YEARS')),
  default_price numeric(14,2) not null default 0 check (default_price>=0),
  warranty_months integer not null default 0 check (warranty_months>=0),
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index ux_services_name_ci on public.services(lower(name));
create index idx_services_category_active on public.services(category,is_active);
create index idx_services_created_by on public.services(created_by);
create index idx_services_updated_by on public.services(updated_by);

create table public.service_schedules (
  id uuid primary key default gen_random_uuid(),
  service_id uuid not null references public.services(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  customer_device_id uuid references public.customer_devices(id) on delete restrict,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','PAUSED','CANCELLED','COMPLETED')),
  interval_count integer not null check (interval_count>0),
  interval_unit text not null check (interval_unit in ('DAYS','MONTHS','YEARS')),
  start_date date not null,
  next_due_date date not null,
  end_date date,
  price numeric(14,2) not null default 0 check (price>=0),
  completion_count integer not null default 0 check (completion_count>=0),
  last_completed_at timestamptz,
  last_completion_id uuid,
  note text,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint service_schedules_dates check (end_date is null or end_date>=start_date),
  constraint service_schedules_completion_fields check (
    (completion_count=0 and last_completed_at is null and last_completion_id is null)
    or
    (completion_count>0 and last_completed_at is not null and last_completion_id is not null)
  )
);
create index idx_service_schedules_service on public.service_schedules(service_id);
create index idx_service_schedules_customer_due on public.service_schedules(customer_id,status,next_due_date);
create index idx_service_schedules_device on public.service_schedules(customer_device_id) where customer_device_id is not null;
create index idx_service_schedules_due on public.service_schedules(status,next_due_date);
create index idx_service_schedules_created_by on public.service_schedules(created_by);
create index idx_service_schedules_updated_by on public.service_schedules(updated_by);

create table public.software_products (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('WINDOWS','OFFICE','M365','ANTIVIRUS','CAMERA_CLOUD','HOSTING','DOMAIN','BACKUP','ACCOUNTING','OTHER')),
  vendor text,
  name text not null check (length(btrim(name))>0),
  edition text,
  billing_model text not null default 'SUBSCRIPTION' check (billing_model in ('ONE_TIME','SUBSCRIPTION')),
  default_term_months integer check (default_term_months is null or default_term_months>0),
  description text,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index ux_software_products_identity_ci
  on public.software_products(category,lower(coalesce(vendor,'')),lower(name),lower(coalesce(edition,'')));
create index idx_software_products_category_active on public.software_products(category,is_active);
create index idx_software_products_created_by on public.software_products(created_by);
create index idx_software_products_updated_by on public.software_products(updated_by);

create table public.software_licenses (
  id uuid primary key default gen_random_uuid(),
  license_code text not null default '',
  software_product_id uuid not null references public.software_products(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  customer_device_id uuid references public.customer_devices(id) on delete restrict,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','EXPIRED','SUSPENDED','CANCELLED')),
  start_date date not null,
  end_date date,
  seats integer not null default 1 check (seats>0),
  account_identifier text,
  secret_ref text,
  auto_renew boolean not null default false,
  renewal_cost numeric(14,2) not null default 0 check (renewal_cost>=0),
  note text,
  cancelled_reason text,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint software_licenses_code_unique unique(license_code),
  constraint software_licenses_dates check (end_date is null or end_date>=start_date),
  constraint software_licenses_cancel_fields check (
    (status='CANCELLED' and cancelled_reason is not null) or status<>'CANCELLED'
  )
);
create index idx_software_licenses_product on public.software_licenses(software_product_id);
create index idx_software_licenses_customer_end on public.software_licenses(customer_id,status,end_date);
create index idx_software_licenses_device on public.software_licenses(customer_device_id) where customer_device_id is not null;
create index idx_software_licenses_end on public.software_licenses(status,end_date) where end_date is not null;
create index idx_software_licenses_created_by on public.software_licenses(created_by);
create index idx_software_licenses_updated_by on public.software_licenses(updated_by);

create trigger trg_services_updated_at before update on public.services for each row execute function public.fn_set_updated_at();
create trigger trg_service_schedules_updated_at before update on public.service_schedules for each row execute function public.fn_set_updated_at();
create trigger trg_software_products_updated_at before update on public.software_products for each row execute function public.fn_set_updated_at();
create trigger trg_software_licenses_updated_at before update on public.software_licenses for each row execute function public.fn_set_updated_at();

create trigger trg_services_audit after insert or update or delete on public.services for each row execute function public.fn_audit_row();
create trigger trg_service_schedules_audit after insert or update or delete on public.service_schedules for each row execute function public.fn_audit_row();
create trigger trg_software_products_audit after insert or update or delete on public.software_products for each row execute function public.fn_audit_row();
create trigger trg_software_licenses_audit after insert or update or delete on public.software_licenses for each row execute function public.fn_audit_row();

alter table public.services enable row level security;
alter table public.service_schedules enable row level security;
alter table public.software_products enable row level security;
alter table public.software_licenses enable row level security;

create policy services_select on public.services for select to authenticated
using ((select private.has_permission('service.view')));
create policy service_schedules_select on public.service_schedules for select to authenticated
using ((select private.has_permission('service.view')));
create policy software_products_select on public.software_products for select to authenticated
using ((select private.has_permission('license.view')));
create policy software_licenses_select on public.software_licenses for select to authenticated
using ((select private.has_permission('license.view')));

revoke all on public.services,public.service_schedules,public.software_products,public.software_licenses from anon,authenticated;
grant select on public.services,public.service_schedules to authenticated;
grant select on public.software_products,public.software_licenses to authenticated;

create view public.service_schedule_summary with (security_invoker=true) as
select
  ss.id,ss.service_id,s.name as service_name,s.category,
  ss.customer_id,c.customer_code,c.full_name as customer_name,c.phone,
  ss.customer_device_id,d.device_code,d.device_type,d.brand as device_brand,d.model as device_model,
  ss.status,ss.interval_count,ss.interval_unit,ss.start_date,ss.next_due_date,ss.end_date,ss.price,
  ss.completion_count,ss.last_completed_at,ss.last_completion_id,ss.note,ss.created_at,ss.updated_at
from public.service_schedules ss
join public.services s on s.id=ss.service_id
join public.customers c on c.id=ss.customer_id
left join public.customer_devices d on d.id=ss.customer_device_id;
revoke all on public.service_schedule_summary from anon,authenticated;
grant select on public.service_schedule_summary to authenticated;

create view public.software_license_summary with (security_invoker=true) as
select
  l.id,l.license_code,l.software_product_id,p.category,p.vendor,p.name as product_name,p.edition,p.billing_model,
  l.customer_id,c.customer_code,c.full_name as customer_name,c.phone,
  l.customer_device_id,d.device_code,d.device_type,d.brand as device_brand,d.model as device_model,
  l.status,l.start_date,l.end_date,l.seats,l.account_identifier,l.secret_ref,l.auto_renew,l.renewal_cost,
  l.note,l.cancelled_reason,l.created_at,l.updated_at
from public.software_licenses l
join public.software_products p on p.id=l.software_product_id
join public.customers c on c.id=l.customer_id
left join public.customer_devices d on d.id=l.customer_device_id;
revoke all on public.software_license_summary from anon,authenticated;
grant select on public.software_license_summary to authenticated;
