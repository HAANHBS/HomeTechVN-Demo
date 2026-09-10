begin;

create schema if not exists private;
revoke all on schema private from public, anon;

-- Internal sequence storage must not be part of the exposed public API schema.
alter table public.sequence_counters set schema private;
revoke all on table private.sequence_counters from public, anon, authenticated;

-- Foreign-key indexes flagged by Performance Advisor.
create index if not exists idx_role_permissions_permission_id
  on public.role_permissions(permission_id);

create index if not exists idx_settings_updated_by
  on public.settings(updated_by);

-- Private authorization helpers.
create or replace function private.current_role_code()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select r.code
  from public.profiles p
  join public.roles r on r.id = p.role_id
  where p.id = (select auth.uid())
    and p.is_active = true
    and r.is_active = true
  limit 1;
$$;

create or replace function private.has_permission(p_permission_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(exists (
    select 1
    from public.profiles p
    join public.roles r
      on r.id = p.role_id
     and r.is_active = true
    join public.role_permissions rp
      on rp.role_id = r.id
    join public.permissions perm
      on perm.id = rp.permission_id
    where p.id = (select auth.uid())
      and p.is_active = true
      and perm.code = p_permission_code
  ), false);
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(private.current_role_code() = 'admin', false);
$$;

create or replace function private.fn_assert_active_or_privileged()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if current_user in ('postgres', 'service_role') then
    return;
  end if;

  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and is_active = true
  ) then
    raise exception 'User is not active';
  end if;
end;
$$;

create or replace function private.next_counter(
  p_entity_type text,
  p_scope_key text default 'GLOBAL'
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_next bigint;
begin
  perform private.fn_assert_active_or_privileged();

  if nullif(trim(p_entity_type), '') is null then
    raise exception 'entity_type is required';
  end if;

  insert into private.sequence_counters(entity_type, scope_key, current_value)
  values (
    lower(trim(p_entity_type)),
    coalesce(nullif(trim(p_scope_key), ''), 'GLOBAL'),
    1
  )
  on conflict (entity_type, scope_key)
  do update
     set current_value = private.sequence_counters.current_value + 1,
         updated_at = now()
  returning current_value into v_next;

  return v_next;
end;
$$;

create or replace function private.next_simple_code(
  p_entity_type text,
  p_prefix text,
  p_pad integer default 6
)
returns text
language plpgsql
security definer
set search_path = ''
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

  v_next := private.next_counter(p_entity_type, 'GLOBAL');

  return upper(trim(p_prefix))
         || '-'
         || lpad(v_next::text, p_pad, '0');
end;
$$;

create or replace function private.next_daily_code(
  p_entity_type text,
  p_prefix text,
  p_business_date date default null,
  p_pad integer default 4
)
returns text
language plpgsql
security definer
set search_path = ''
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
  v_next := private.next_counter(p_entity_type, v_scope);

  return upper(trim(p_prefix))
         || '-'
         || v_scope
         || '-'
         || lpad(v_next::text, p_pad, '0');
end;
$$;

-- No direct API access to internal private helpers.
revoke all on all functions in schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.has_permission(text) to authenticated;

-- IMPORTANT FIX:
-- This trigger must be SECURITY INVOKER. If it were SECURITY DEFINER,
-- current_user would be postgres and the privilege-change check could be skipped.
create or replace function public.fn_protect_profile_privilege_fields()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_user not in ('postgres', 'service_role') then
    if (
      new.role_id is distinct from old.role_id
      or new.is_active is distinct from old.is_active
      or new.email is distinct from old.email
    ) and not private.has_permission('user.manage') then
      raise exception 'Not allowed to change protected profile fields';
    end if;
  end if;

  return new;
end;
$$;

revoke execute on function public.fn_protect_profile_privilege_fields()
  from public, anon, authenticated;

-- RLS: fixed per-row auth/function re-evaluation.
drop policy if exists roles_select_authenticated on public.roles;
create policy roles_select_authenticated
on public.roles for select
to authenticated
using (true);

drop policy if exists permissions_select_authenticated on public.permissions;
create policy permissions_select_authenticated
on public.permissions for select
to authenticated
using (true);

drop policy if exists role_permissions_select_authenticated on public.role_permissions;
create policy role_permissions_select_authenticated
on public.role_permissions for select
to authenticated
using (true);

drop policy if exists roles_admin_insert on public.roles;
create policy roles_admin_insert
on public.roles for insert
to authenticated
with check ((select private.has_permission('role.manage')));

drop policy if exists roles_admin_update on public.roles;
create policy roles_admin_update
on public.roles for update
to authenticated
using ((select private.has_permission('role.manage')))
with check ((select private.has_permission('role.manage')));

drop policy if exists roles_admin_delete on public.roles;
create policy roles_admin_delete
on public.roles for delete
to authenticated
using ((select private.has_permission('role.manage')));

drop policy if exists permissions_admin_insert on public.permissions;
create policy permissions_admin_insert
on public.permissions for insert
to authenticated
with check ((select private.has_permission('role.manage')));

drop policy if exists permissions_admin_update on public.permissions;
create policy permissions_admin_update
on public.permissions for update
to authenticated
using ((select private.has_permission('role.manage')))
with check ((select private.has_permission('role.manage')));

drop policy if exists permissions_admin_delete on public.permissions;
create policy permissions_admin_delete
on public.permissions for delete
to authenticated
using ((select private.has_permission('role.manage')));

drop policy if exists role_permissions_admin_insert on public.role_permissions;
create policy role_permissions_admin_insert
on public.role_permissions for insert
to authenticated
with check ((select private.has_permission('role.manage')));

drop policy if exists role_permissions_admin_update on public.role_permissions;
create policy role_permissions_admin_update
on public.role_permissions for update
to authenticated
using ((select private.has_permission('role.manage')))
with check ((select private.has_permission('role.manage')));

drop policy if exists role_permissions_admin_delete on public.role_permissions;
create policy role_permissions_admin_delete
on public.role_permissions for delete
to authenticated
using ((select private.has_permission('role.manage')));

drop policy if exists profiles_select on public.profiles;
create policy profiles_select
on public.profiles for select
to authenticated
using (
  id = (select auth.uid())
  or (select private.has_permission('user.view'))
);

drop policy if exists profiles_update on public.profiles;
create policy profiles_update
on public.profiles for update
to authenticated
using (
  id = (select auth.uid())
  or (select private.has_permission('user.manage'))
)
with check (
  id = (select auth.uid())
  or (select private.has_permission('user.manage'))
);

drop policy if exists settings_select on public.settings;
create policy settings_select
on public.settings for select
to authenticated
using ((select private.has_permission('settings.view')));

drop policy if exists settings_admin_insert on public.settings;
create policy settings_admin_insert
on public.settings for insert
to authenticated
with check ((select private.has_permission('settings.manage')));

drop policy if exists settings_admin_update on public.settings;
create policy settings_admin_update
on public.settings for update
to authenticated
using ((select private.has_permission('settings.manage')))
with check ((select private.has_permission('settings.manage')));

drop policy if exists settings_admin_delete on public.settings;
create policy settings_admin_delete
on public.settings for delete
to authenticated
using ((select private.has_permission('settings.manage')));

drop policy if exists audit_select on public.audit_logs;
create policy audit_select
on public.audit_logs for select
to authenticated
using ((select private.has_permission('audit.view')));

-- Remove obsolete SECURITY DEFINER RPCs from exposed public schema.
drop function if exists public.is_admin();
drop function if exists public.current_role_code();
drop function if exists public.next_daily_code(text,text,date,integer);
drop function if exists public.next_simple_code(text,text,integer);
drop function if exists public.next_counter(text,text);
drop function if exists public.fn_assert_active_or_privileged();
drop function if exists public.has_permission(text);

-- New public objects are private by default until a migration explicitly grants access.
alter default privileges for role postgres in schema public
  revoke select, insert, update, delete on tables
  from anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  revoke execute on functions
  from anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  revoke usage, select on sequences
  from anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  revoke execute on functions from public;

commit;
