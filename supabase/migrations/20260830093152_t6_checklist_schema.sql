create table public.checklist_templates (
  id uuid primary key default gen_random_uuid(),
  template_code text not null,
  version integer not null check (version > 0),
  name text not null check (length(btrim(name)) > 0),
  module text not null check (module in ('SALES','REPAIR','WARRANTY','SERVICE','GENERIC')),
  entity_type text not null check (entity_type in ('SALES_ORDER','REPAIR_ORDER','WARRANTY','SERVICE','GENERIC')),
  description text,
  is_active boolean not null default false,
  is_system boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint checklist_templates_code_version_unique unique(template_code,version)
);
create unique index ux_checklist_templates_active_code on public.checklist_templates(template_code) where is_active;
create index idx_checklist_templates_module_active on public.checklist_templates(module,is_active);
create index idx_checklist_templates_created_by on public.checklist_templates(created_by);
create index idx_checklist_templates_updated_by on public.checklist_templates(updated_by);

create table public.checklist_template_items (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.checklist_templates(id) on delete cascade,
  item_key text not null check (item_key ~ '^[a-z0-9_]+$'),
  label text not null check (length(btrim(label)) > 0),
  description text,
  sort_order integer not null check (sort_order > 0),
  requirement_rule text not null default 'OPTIONAL' check (requirement_rule in ('ALWAYS','OPTIONAL','SALES_HAS_SERIAL')),
  system_managed boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint checklist_template_items_key_unique unique(template_id,item_key),
  constraint checklist_template_items_sort_unique unique(template_id,sort_order)
);
create index idx_checklist_template_items_created_by on public.checklist_template_items(created_by);
create index idx_checklist_template_items_updated_by on public.checklist_template_items(updated_by);

create table public.checklist_runs (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.checklist_templates(id) on delete restrict,
  template_code_snapshot text not null,
  template_version integer not null,
  entity_type text not null,
  entity_id uuid not null,
  status text not null default 'OPEN' check (status in ('OPEN','COMPLETED','CANCELLED')),
  note text,
  started_by uuid references public.profiles(id) on delete set null,
  completed_by uuid references public.profiles(id) on delete set null,
  cancelled_by uuid references public.profiles(id) on delete set null,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint checklist_runs_template_entity_unique unique(template_id,entity_type,entity_id)
);
create index idx_checklist_runs_entity on public.checklist_runs(entity_type,entity_id,created_at desc);
create index idx_checklist_runs_status on public.checklist_runs(status,created_at desc);
create index idx_checklist_runs_started_by on public.checklist_runs(started_by);
create index idx_checklist_runs_completed_by on public.checklist_runs(completed_by);
create index idx_checklist_runs_cancelled_by on public.checklist_runs(cancelled_by);

create table public.checklist_run_items (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.checklist_runs(id) on delete cascade,
  template_item_id uuid references public.checklist_template_items(id) on delete set null,
  item_key text not null,
  label text not null,
  description text,
  sort_order integer not null,
  required boolean not null default false,
  system_managed boolean not null default false,
  checked boolean not null default false,
  note text,
  checked_by uuid references public.profiles(id) on delete set null,
  checked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint checklist_run_items_key_unique unique(run_id,item_key),
  constraint checklist_run_items_sort_unique unique(run_id,sort_order),
  constraint checklist_run_items_checked_fields check ((checked and checked_at is not null) or (not checked and checked_at is null))
);
create index idx_checklist_run_items_template_item on public.checklist_run_items(template_item_id);
create index idx_checklist_run_items_checked_by on public.checklist_run_items(checked_by);

create trigger trg_checklist_templates_updated_at before update on public.checklist_templates for each row execute function public.fn_set_updated_at();
create trigger trg_checklist_template_items_updated_at before update on public.checklist_template_items for each row execute function public.fn_set_updated_at();
create trigger trg_checklist_runs_updated_at before update on public.checklist_runs for each row execute function public.fn_set_updated_at();
create trigger trg_checklist_run_items_updated_at before update on public.checklist_run_items for each row execute function public.fn_set_updated_at();
create trigger trg_checklist_templates_audit after insert or update or delete on public.checklist_templates for each row execute function public.fn_audit_row();
create trigger trg_checklist_template_items_audit after insert or update or delete on public.checklist_template_items for each row execute function public.fn_audit_row();
create trigger trg_checklist_runs_audit after insert or update or delete on public.checklist_runs for each row execute function public.fn_audit_row();
create trigger trg_checklist_run_items_audit after insert or update or delete on public.checklist_run_items for each row execute function public.fn_audit_row();

create or replace function private.checklist_can_access_entity(p_entity_type text,p_entity_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not private.has_permission('checklist.run') then return false; end if;
  case p_entity_type
    when 'SALES_ORDER' then return private.has_permission('sale.view') and exists(select 1 from public.sales_orders where id=p_entity_id);
    when 'REPAIR_ORDER' then return private.has_permission('repair.view') and exists(select 1 from public.repair_orders where id=p_entity_id);
    when 'GENERIC' then return true;
    else return false;
  end case;
end; $$;
revoke execute on function private.checklist_can_access_entity(text,uuid) from public,anon,authenticated;

create or replace function private.checklist_can_access_run(p_run_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select coalesce((select private.checklist_can_access_entity(r.entity_type,r.entity_id) from public.checklist_runs r where r.id=p_run_id),false);
$$;
revoke execute on function private.checklist_can_access_run(uuid) from public,anon,authenticated;

alter table public.checklist_templates enable row level security;
alter table public.checklist_template_items enable row level security;
alter table public.checklist_runs enable row level security;
alter table public.checklist_run_items enable row level security;

create policy checklist_templates_select on public.checklist_templates for select to authenticated
using ((select private.has_permission('checklist.run')) or (select private.has_permission('checklist.manage')));
create policy checklist_template_items_select on public.checklist_template_items for select to authenticated
using ((select private.has_permission('checklist.run')) or (select private.has_permission('checklist.manage')));
create policy checklist_runs_select on public.checklist_runs for select to authenticated
using (private.checklist_can_access_entity(entity_type,entity_id));
create policy checklist_run_items_select on public.checklist_run_items for select to authenticated
using (private.checklist_can_access_run(run_id));

revoke all on public.checklist_templates,public.checklist_template_items,public.checklist_runs,public.checklist_run_items from anon,authenticated;
grant select on public.checklist_templates,public.checklist_template_items,public.checklist_runs,public.checklist_run_items to authenticated;
