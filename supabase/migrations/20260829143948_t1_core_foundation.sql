-- ============================================================
-- HomeTechVN Management
-- T1 v1.0 — Database + Auth Foundation
-- ============================================================

begin;

create extension if not exists pgcrypto with schema extensions;

-- ------------------------------------------------------------
-- Utility: updated_at
-- ------------------------------------------------------------
create or replace function public.fn_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ------------------------------------------------------------
-- Roles
-- ------------------------------------------------------------
create table if not exists public.roles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  is_system boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint roles_code_format check (code ~ '^[a-z][a-z0-9_]*$')
);

create trigger trg_roles_updated_at
before update on public.roles
for each row execute function public.fn_set_updated_at();

-- ------------------------------------------------------------
-- Permissions
-- ------------------------------------------------------------
create table if not exists public.permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  module text not null,
  description text,
  created_at timestamptz not null default now(),
  constraint permissions_code_format check (code ~ '^[a-z][a-z0-9_.]*$')
);

create table if not exists public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (role_id, permission_id)
);

-- ------------------------------------------------------------
-- Profiles
-- ------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  phone text,
  avatar_url text,
  role_id uuid references public.roles(id) on delete set null,
  is_active boolean not null default false,
  last_login_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_profiles_role_id on public.profiles(role_id);
create index if not exists idx_profiles_email_lower on public.profiles(lower(email));

create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.fn_set_updated_at();

-- Auto-create inactive profile for each Auth user.
create or replace function public.fn_handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  insert into public.profiles (id, email, full_name, is_active)
  values (
    new.id,
    new.email,
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), ''),
    false
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.fn_handle_new_auth_user();

-- Keep profile email synchronized with Auth.
create or replace function public.fn_handle_auth_user_updated()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if new.email is distinct from old.email then
    update public.profiles
      set email = new.email,
          updated_at = now()
    where id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
after update on auth.users
for each row execute function public.fn_handle_auth_user_updated();

-- ------------------------------------------------------------
-- Permission helpers
-- ------------------------------------------------------------
create or replace function public.current_role_code()
returns text
language sql
stable
security definer
set search_path = public, auth
as $$
  select r.code
  from public.profiles p
  join public.roles r on r.id = p.role_id
  where p.id = auth.uid()
    and p.is_active = true
    and r.is_active = true
  limit 1;
$$;

create or replace function public.has_permission(p_permission_code text)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.profiles p
    join public.roles r on r.id = p.role_id and r.is_active = true
    join public.role_permissions rp on rp.role_id = r.id
    join public.permissions perm on perm.id = rp.permission_id
    where p.id = auth.uid()
      and p.is_active = true
      and perm.code = p_permission_code
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(public.current_role_code() = 'admin', false);
$$;

-- Prevent self privilege escalation.
create or replace function public.fn_protect_profile_privilege_fields()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if current_user not in ('postgres', 'service_role') then
    if (
      new.role_id is distinct from old.role_id
      or new.is_active is distinct from old.is_active
      or new.email is distinct from old.email
    ) and not public.has_permission('user.manage') then
      raise exception 'Not allowed to change protected profile fields';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_profiles_protect_privileges on public.profiles;
create trigger trg_profiles_protect_privileges
before update on public.profiles
for each row execute function public.fn_protect_profile_privilege_fields();

-- ------------------------------------------------------------
-- Settings
-- Sensitive values are not stored here. Store only secret_ref.
-- ------------------------------------------------------------
create table if not exists public.settings (
  key text primary key,
  value jsonb,
  description text,
  is_sensitive boolean not null default false,
  secret_ref text,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint settings_no_sensitive_value
    check (not (is_sensitive = true and value is not null))
);

create trigger trg_settings_updated_at
before update on public.settings
for each row execute function public.fn_set_updated_at();

-- ------------------------------------------------------------
-- Audit Log
-- ------------------------------------------------------------
create table if not exists public.audit_logs (
  id bigint generated by default as identity primary key,
  actor_user_id uuid references auth.users(id) on delete set null,
  table_name text not null,
  record_id text,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  old_data jsonb,
  new_data jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists idx_audit_logs_table_record
  on public.audit_logs(table_name, record_id);
create index if not exists idx_audit_logs_actor
  on public.audit_logs(actor_user_id);
create index if not exists idx_audit_logs_occurred_at
  on public.audit_logs(occurred_at desc);

create or replace function public.fn_audit_row()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_record_id text;
begin
  if tg_op = 'INSERT' then
    v_record_id := coalesce(to_jsonb(new) ->> 'id', to_jsonb(new) ->> 'key');
    insert into public.audit_logs(actor_user_id, table_name, record_id, action, new_data)
    values (auth.uid(), tg_table_name, v_record_id, 'INSERT', to_jsonb(new));
    return new;
  elsif tg_op = 'UPDATE' then
    v_record_id := coalesce(to_jsonb(new) ->> 'id', to_jsonb(new) ->> 'key');
    insert into public.audit_logs(actor_user_id, table_name, record_id, action, old_data, new_data)
    values (auth.uid(), tg_table_name, v_record_id, 'UPDATE', to_jsonb(old), to_jsonb(new));
    return new;
  elsif tg_op = 'DELETE' then
    v_record_id := coalesce(to_jsonb(old) ->> 'id', to_jsonb(old) ->> 'key');
    insert into public.audit_logs(actor_user_id, table_name, record_id, action, old_data)
    values (auth.uid(), tg_table_name, v_record_id, 'DELETE', to_jsonb(old));
    return old;
  end if;
  return null;
end;
$$;

create trigger trg_roles_audit
after insert or update or delete on public.roles
for each row execute function public.fn_audit_row();

create trigger trg_role_permissions_audit
after insert or update or delete on public.role_permissions
for each row execute function public.fn_audit_row();

create trigger trg_profiles_audit
after insert or update or delete on public.profiles
for each row execute function public.fn_audit_row();

create trigger trg_settings_audit
after insert or update or delete on public.settings
for each row execute function public.fn_audit_row();

-- ------------------------------------------------------------
-- Code Counters
-- ------------------------------------------------------------
create table if not exists public.sequence_counters (
  entity_type text not null,
  scope_key text not null default 'GLOBAL',
  current_value bigint not null default 0 check (current_value >= 0),
  updated_at timestamptz not null default now(),
  primary key (entity_type, scope_key)
);

create or replace function public.fn_assert_active_or_privileged()
returns void
language plpgsql
stable
security definer
set search_path = public, auth
as $$
begin
  if current_user in ('postgres', 'service_role') then
    return;
  end if;

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and is_active = true
  ) then
    raise exception 'User is not active';
  end if;
end;
$$;

create or replace function public.next_counter(
  p_entity_type text,
  p_scope_key text default 'GLOBAL'
)
returns bigint
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_next bigint;
begin
  perform public.fn_assert_active_or_privileged();

  if nullif(trim(p_entity_type), '') is null then
    raise exception 'entity_type is required';
  end if;

  insert into public.sequence_counters(entity_type, scope_key, current_value)
  values (lower(trim(p_entity_type)), coalesce(nullif(trim(p_scope_key), ''), 'GLOBAL'), 1)
  on conflict (entity_type, scope_key)
  do update
     set current_value = public.sequence_counters.current_value + 1,
         updated_at = now()
  returning current_value into v_next;

  return v_next;
end;
$$;

create or replace function public.next_simple_code(
  p_entity_type text,
  p_prefix text,
  p_pad integer default 6
)
returns text
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_next bigint;
begin
  if p_pad < 1 or p_pad > 12 then
    raise exception 'pad must be between 1 and 12';
  end if;

  if nullif(trim(p_prefix), '') is null then
    raise exception 'prefix is required';
  end if;

  v_next := public.next_counter(p_entity_type, 'GLOBAL');
  return upper(trim(p_prefix)) || '-' || lpad(v_next::text, p_pad, '0');
end;
$$;

create or replace function public.next_daily_code(
  p_entity_type text,
  p_prefix text,
  p_business_date date default null,
  p_pad integer default 4
)
returns text
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_date date;
  v_scope text;
  v_next bigint;
begin
  if p_pad < 1 or p_pad > 12 then
    raise exception 'pad must be between 1 and 12';
  end if;

  if nullif(trim(p_prefix), '') is null then
    raise exception 'prefix is required';
  end if;

  v_date := coalesce(
    p_business_date,
    timezone('Asia/Bangkok', now())::date
  );

  v_scope := to_char(v_date, 'YYMMDD');
  v_next := public.next_counter(p_entity_type, v_scope);

  return upper(trim(p_prefix))
         || '-'
         || v_scope
         || '-'
         || lpad(v_next::text, p_pad, '0');
end;
$$;

-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.profiles enable row level security;
alter table public.settings enable row level security;
alter table public.audit_logs enable row level security;
alter table public.sequence_counters enable row level security;

-- Clean grants first.
revoke all on table public.roles from anon, authenticated;
revoke all on table public.permissions from anon, authenticated;
revoke all on table public.role_permissions from anon, authenticated;
revoke all on table public.profiles from anon, authenticated;
revoke all on table public.settings from anon, authenticated;
revoke all on table public.audit_logs from anon, authenticated;
revoke all on table public.sequence_counters from anon, authenticated;

-- Authenticated grants; RLS still controls rows.
grant select, insert, update, delete on public.roles to authenticated;
grant select, insert, update, delete on public.permissions to authenticated;
grant select, insert, update, delete on public.role_permissions to authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.settings to authenticated;
grant select on public.audit_logs to authenticated;

-- Metadata readable only after login.
create policy roles_select_authenticated
on public.roles for select
to authenticated
using (auth.uid() is not null);

create policy permissions_select_authenticated
on public.permissions for select
to authenticated
using (auth.uid() is not null);

create policy role_permissions_select_authenticated
on public.role_permissions for select
to authenticated
using (auth.uid() is not null);

-- Admin-only management.
create policy roles_admin_insert
on public.roles for insert
to authenticated
with check (public.has_permission('role.manage'));

create policy roles_admin_update
on public.roles for update
to authenticated
using (public.has_permission('role.manage'))
with check (public.has_permission('role.manage'));

create policy roles_admin_delete
on public.roles for delete
to authenticated
using (public.has_permission('role.manage'));

create policy permissions_admin_insert
on public.permissions for insert
to authenticated
with check (public.has_permission('role.manage'));

create policy permissions_admin_update
on public.permissions for update
to authenticated
using (public.has_permission('role.manage'))
with check (public.has_permission('role.manage'));

create policy permissions_admin_delete
on public.permissions for delete
to authenticated
using (public.has_permission('role.manage'));

create policy role_permissions_admin_insert
on public.role_permissions for insert
to authenticated
with check (public.has_permission('role.manage'));

create policy role_permissions_admin_update
on public.role_permissions for update
to authenticated
using (public.has_permission('role.manage'))
with check (public.has_permission('role.manage'));

create policy role_permissions_admin_delete
on public.role_permissions for delete
to authenticated
using (public.has_permission('role.manage'));

-- Profile: self or staff with user.view.
create policy profiles_select
on public.profiles for select
to authenticated
using (
  id = auth.uid()
  or public.has_permission('user.view')
);

create policy profiles_update
on public.profiles for update
to authenticated
using (
  id = auth.uid()
  or public.has_permission('user.manage')
)
with check (
  id = auth.uid()
  or public.has_permission('user.manage')
);

-- Settings.
create policy settings_select
on public.settings for select
to authenticated
using (public.has_permission('settings.view'));

create policy settings_admin_insert
on public.settings for insert
to authenticated
with check (public.has_permission('settings.manage'));

create policy settings_admin_update
on public.settings for update
to authenticated
using (public.has_permission('settings.manage'))
with check (public.has_permission('settings.manage'));

create policy settings_admin_delete
on public.settings for delete
to authenticated
using (public.has_permission('settings.manage'));

-- Audit is read-only for permitted users from client.
create policy audit_select
on public.audit_logs for select
to authenticated
using (public.has_permission('audit.view'));

-- sequence_counters intentionally has no direct client policies.
-- Use SECURITY DEFINER functions to generate codes.

grant execute on function public.current_role_code() to authenticated;
grant execute on function public.has_permission(text) to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.next_simple_code(text, text, integer) to authenticated;
grant execute on function public.next_daily_code(text, text, date, integer) to authenticated;

commit;
