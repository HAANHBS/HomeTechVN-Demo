begin;

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  customer_code text not null unique,
  full_name text not null,
  customer_type text not null default 'INDIVIDUAL'
    check (customer_type in ('INDIVIDUAL','BUSINESS')),
  phone text,
  phone_normalized text,
  email text,
  zalo text,
  address text,
  tax_code text,
  birthday date,
  status text not null default 'ACTIVE'
    check (status in ('ACTIVE','INACTIVE')),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customers_full_name_not_blank check (btrim(full_name) <> ''),
  constraint customers_customer_code_format check (customer_code ~ '^CUS-[0-9]{6,12}$'),
  constraint customers_phone_length check (phone is null or char_length(phone) <= 40),
  constraint customers_email_length check (email is null or char_length(email) <= 320)
);

create table public.customer_devices (
  id uuid primary key default gen_random_uuid(),
  device_code text not null unique,
  customer_id uuid not null references public.customers(id) on delete restrict,
  device_type text not null,
  brand text,
  model text,
  serial_number text,
  asset_tag text,
  color text,
  condition_notes text,
  purchase_date date,
  status text not null default 'ACTIVE'
    check (status in ('ACTIVE','INACTIVE')),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customer_devices_device_type_not_blank check (btrim(device_type) <> ''),
  constraint customer_devices_device_code_format check (device_code ~ '^DEV-[0-9]{6,12}$'),
  constraint customer_devices_serial_length check (serial_number is null or char_length(serial_number) <= 200)
);

create table public.customer_notes (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete restrict,
  note_type text not null default 'GENERAL'
    check (note_type in ('GENERAL','IMPORTANT','CONTACT','SERVICE')),
  content text not null,
  is_pinned boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customer_notes_content_not_blank check (btrim(content) <> '')
);

create index idx_customers_full_name_lower
  on public.customers (lower(full_name) text_pattern_ops);
create index idx_customers_phone_normalized
  on public.customers (phone_normalized);
create index idx_customers_phone
  on public.customers (phone);
create index idx_customers_email_lower
  on public.customers (lower(email));
create index idx_customers_status
  on public.customers (status);
create index idx_customers_created_by
  on public.customers (created_by);
create index idx_customers_updated_by
  on public.customers (updated_by);

create index idx_customer_devices_customer_id
  on public.customer_devices (customer_id);
create index idx_customer_devices_serial_lower
  on public.customer_devices (lower(serial_number));
create index idx_customer_devices_type
  on public.customer_devices (device_type);
create index idx_customer_devices_brand_model_lower
  on public.customer_devices (lower(brand), lower(model));
create index idx_customer_devices_status
  on public.customer_devices (status);
create index idx_customer_devices_created_by
  on public.customer_devices (created_by);
create index idx_customer_devices_updated_by
  on public.customer_devices (updated_by);

create index idx_customer_notes_customer_created
  on public.customer_notes (customer_id, created_at desc);
create index idx_customer_notes_pinned
  on public.customer_notes (customer_id, is_pinned, created_at desc);
create index idx_customer_notes_created_by
  on public.customer_notes (created_by);
create index idx_customer_notes_updated_by
  on public.customer_notes (updated_by);

create or replace function private.fn_t2_customer_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_digits text;
begin
  v_uid := auth.uid();

  if tg_op = 'INSERT' then
    if v_uid is not null or nullif(btrim(new.customer_code), '') is null then
      new.customer_code := private.next_simple_code('customer', 'CUS', 6);
    else
      new.customer_code := upper(btrim(new.customer_code));
    end if;

    if v_uid is not null then
      new.created_by := v_uid;
      new.updated_by := v_uid;
    end if;
  else
    if new.customer_code is distinct from old.customer_code then
      raise exception 'customer_code is immutable';
    end if;

    new.created_by := old.created_by;
    if v_uid is not null then
      new.updated_by := v_uid;
    end if;
  end if;

  new.full_name := btrim(new.full_name);
  new.phone := nullif(btrim(new.phone), '');
  new.email := nullif(lower(btrim(new.email)), '');
  new.zalo := nullif(btrim(new.zalo), '');
  new.address := nullif(btrim(new.address), '');
  new.tax_code := nullif(btrim(new.tax_code), '');

  v_digits := regexp_replace(coalesce(new.phone, ''), '[^0-9]', '', 'g');
  if v_digits like '0084%' and char_length(v_digits) > 4 then
    v_digits := '0' || substring(v_digits from 5);
  elsif v_digits like '84%' and char_length(v_digits) > 2 then
    v_digits := '0' || substring(v_digits from 3);
  end if;
  new.phone_normalized := nullif(v_digits, '');

  return new;
end;
$$;

create or replace function private.fn_t2_device_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
begin
  v_uid := auth.uid();

  if tg_op = 'INSERT' then
    if v_uid is not null or nullif(btrim(new.device_code), '') is null then
      new.device_code := private.next_simple_code('device', 'DEV', 6);
    else
      new.device_code := upper(btrim(new.device_code));
    end if;

    if v_uid is not null then
      new.created_by := v_uid;
      new.updated_by := v_uid;
    end if;
  else
    if new.device_code is distinct from old.device_code then
      raise exception 'device_code is immutable';
    end if;

    new.created_by := old.created_by;
    if v_uid is not null then
      new.updated_by := v_uid;
    end if;
  end if;

  new.device_type := btrim(new.device_type);
  new.brand := nullif(btrim(new.brand), '');
  new.model := nullif(btrim(new.model), '');
  new.serial_number := nullif(btrim(new.serial_number), '');
  new.asset_tag := nullif(btrim(new.asset_tag), '');
  new.color := nullif(btrim(new.color), '');
  new.condition_notes := nullif(btrim(new.condition_notes), '');

  return new;
end;
$$;

create or replace function private.fn_t2_note_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
begin
  v_uid := auth.uid();

  if tg_op = 'INSERT' then
    if v_uid is not null then
      new.created_by := v_uid;
      new.updated_by := v_uid;
    end if;
  else
    new.created_by := old.created_by;
    if v_uid is not null then
      new.updated_by := v_uid;
    end if;
  end if;

  new.content := btrim(new.content);
  return new;
end;
$$;

revoke all on function private.fn_t2_customer_before_write() from public, anon, authenticated;
revoke all on function private.fn_t2_device_before_write() from public, anon, authenticated;
revoke all on function private.fn_t2_note_before_write() from public, anon, authenticated;

create trigger trg_customers_before_write
before insert or update on public.customers
for each row execute function private.fn_t2_customer_before_write();

create trigger trg_customer_devices_before_write
before insert or update on public.customer_devices
for each row execute function private.fn_t2_device_before_write();

create trigger trg_customer_notes_before_write
before insert or update on public.customer_notes
for each row execute function private.fn_t2_note_before_write();

create trigger trg_customers_updated_at
before update on public.customers
for each row execute function public.fn_set_updated_at();

create trigger trg_customer_devices_updated_at
before update on public.customer_devices
for each row execute function public.fn_set_updated_at();

create trigger trg_customer_notes_updated_at
before update on public.customer_notes
for each row execute function public.fn_set_updated_at();

create trigger trg_customers_audit
after insert or update or delete on public.customers
for each row execute function public.fn_audit_row();

create trigger trg_customer_devices_audit
after insert or update or delete on public.customer_devices
for each row execute function public.fn_audit_row();

create trigger trg_customer_notes_audit
after insert or update or delete on public.customer_notes
for each row execute function public.fn_audit_row();

alter table public.customers enable row level security;
alter table public.customer_devices enable row level security;
alter table public.customer_notes enable row level security;

create policy customers_select
on public.customers for select
to authenticated
using ((select private.has_permission('customer.view')));

create policy customers_insert
on public.customers for insert
to authenticated
with check ((select private.has_permission('customer.create')));

create policy customers_update
on public.customers for update
to authenticated
using ((select private.has_permission('customer.update')))
with check ((select private.has_permission('customer.update')));

create policy customer_devices_select
on public.customer_devices for select
to authenticated
using ((select private.has_permission('device.view')));

create policy customer_devices_insert
on public.customer_devices for insert
to authenticated
with check ((select private.has_permission('device.create')));

create policy customer_devices_update
on public.customer_devices for update
to authenticated
using ((select private.has_permission('device.update')))
with check ((select private.has_permission('device.update')));

create policy customer_notes_select
on public.customer_notes for select
to authenticated
using ((select private.has_permission('customer.view')));

create policy customer_notes_insert
on public.customer_notes for insert
to authenticated
with check ((select private.has_permission('customer.update')));

create policy customer_notes_update
on public.customer_notes for update
to authenticated
using ((select private.has_permission('customer.update')))
with check ((select private.has_permission('customer.update')));

grant select, insert, update on public.customers to authenticated, service_role;
grant select, insert, update on public.customer_devices to authenticated, service_role;
grant select, insert, update on public.customer_notes to authenticated, service_role;
revoke delete on public.customers from public, anon, authenticated, service_role;
revoke delete on public.customer_devices from public, anon, authenticated, service_role;
revoke delete on public.customer_notes from public, anon, authenticated, service_role;
revoke all on public.customers from anon;
revoke all on public.customer_devices from anon;
revoke all on public.customer_notes from anon;

insert into public.settings(key, value, description, is_sensitive)
values (
  'crm.device_types',
  '["Laptop","PC","Monitor","Printer","Camera","NVR/DVR","Router","Switch","UPS","Disk","Phone","Other"]'::jsonb,
  'Configurable customer device types for CRM',
  false
)
on conflict (key) do nothing;

commit;
