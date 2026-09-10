create table public.reminder_rules (
  id uuid primary key default gen_random_uuid(),
  rule_code text not null unique check (rule_code ~ '^[A-Z0-9_]+$'),
  name text not null check (length(btrim(name))>0),
  event_type text not null check (event_type in (
    'WARRANTY_END','LICENSE_END','SERVICE_DUE','REPAIR_READY','REPAIR_AWAITING_CUSTOMER',
    'REPAIR_ESTIMATED_COMPLETION','SALES_PAYMENT_PENDING','PRODUCT_LOW_STOCK'
  )),
  offset_minutes integer not null default 0,
  priority text not null default 'NORMAL' check (priority in ('LOW','NORMAL','HIGH','URGENT')),
  is_active boolean not null default true,
  is_system boolean not null default false,
  description text,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_reminder_rules_event_active on public.reminder_rules(event_type,is_active);
create index idx_reminder_rules_created_by on public.reminder_rules(created_by);
create index idx_reminder_rules_updated_by on public.reminder_rules(updated_by);

create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  reminder_code text not null default '',
  rule_id uuid not null references public.reminder_rules(id) on delete restrict,
  rule_code_snapshot text not null,
  event_type text not null,
  source_type text not null check (source_type in ('WARRANTY','SOFTWARE_LICENSE','SERVICE_SCHEDULE','REPAIR_ORDER','SALES_ORDER','PRODUCT')),
  source_id uuid not null,
  source_label text,
  customer_id uuid references public.customers(id) on delete set null,
  anchor_at timestamptz,
  due_at timestamptz not null,
  priority text not null check (priority in ('LOW','NORMAL','HIGH','URGENT')),
  status text not null default 'PENDING' check (status in ('PENDING','DUE','SNOOZED','ACKNOWLEDGED','RESOLVED','CANCELLED')),
  title text not null check (length(btrim(title))>0),
  message text not null check (length(btrim(message))>0),
  dedupe_key text not null unique,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  generated_by text not null default 'SYSTEM' check (generated_by in ('SYSTEM','MANUAL')),
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  last_seen_run_id uuid,
  snoozed_until timestamptz,
  acknowledged_by uuid references public.profiles(id) on delete set null,
  acknowledged_at timestamptz,
  resolved_at timestamptz,
  resolution_reason text,
  operator_note text,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reminders_code_unique unique(reminder_code),
  constraint reminders_ack_fields check (
    (status='ACKNOWLEDGED' and acknowledged_at is not null) or status<>'ACKNOWLEDGED'
  ),
  constraint reminders_snooze_fields check (
    (status='SNOOZED' and snoozed_until is not null) or status<>'SNOOZED'
  ),
  constraint reminders_resolve_fields check (
    (status in ('RESOLVED','CANCELLED') and resolved_at is not null) or status not in ('RESOLVED','CANCELLED')
  )
);
create index idx_reminders_status_due on public.reminders(status,due_at);
create index idx_reminders_rule on public.reminders(rule_id,status);
create index idx_reminders_source on public.reminders(source_type,source_id);
create index idx_reminders_customer on public.reminders(customer_id) where customer_id is not null;
create index idx_reminders_last_seen_run on public.reminders(last_seen_run_id) where last_seen_run_id is not null;
create index idx_reminders_snoozed on public.reminders(snoozed_until) where status='SNOOZED';
create index idx_reminders_acknowledged_by on public.reminders(acknowledged_by) where acknowledged_by is not null;
create index idx_reminders_created_by on public.reminders(created_by) where created_by is not null;
create index idx_reminders_updated_by on public.reminders(updated_by) where updated_by is not null;

create trigger trg_reminder_rules_updated_at before update on public.reminder_rules for each row execute function public.fn_set_updated_at();
create trigger trg_reminders_updated_at before update on public.reminders for each row execute function public.fn_set_updated_at();
create trigger trg_reminder_rules_audit after insert or update or delete on public.reminder_rules for each row execute function public.fn_audit_row();
create trigger trg_reminders_audit after insert or update or delete on public.reminders for each row execute function public.fn_audit_row();

alter table public.reminder_rules enable row level security;
alter table public.reminders enable row level security;

create policy reminder_rules_select on public.reminder_rules for select to authenticated
using ((select private.has_permission('notification.view')) or (select private.has_permission('notification.manage')));
create policy reminders_select on public.reminders for select to authenticated
using ((select private.has_permission('notification.view')) or (select private.has_permission('notification.manage')));

revoke all on public.reminder_rules, public.reminders from anon, authenticated;
grant select on public.reminder_rules, public.reminders to authenticated;

create view public.reminder_summary with (security_invoker=true) as
select
  r.id,r.reminder_code,r.rule_id,r.rule_code_snapshot,r.event_type,r.source_type,r.source_id,r.source_label,
  r.customer_id,c.customer_code,c.full_name as customer_name,c.phone,
  r.anchor_at,r.due_at,r.priority,r.status,r.title,r.message,r.metadata,r.generated_by,
  r.first_seen_at,r.last_seen_at,r.snoozed_until,r.acknowledged_by,r.acknowledged_at,
  r.resolved_at,r.resolution_reason,r.operator_note,r.created_at,r.updated_at
from public.reminders r
left join public.customers c on c.id=r.customer_id;
revoke all on public.reminder_summary from anon,authenticated;
grant select on public.reminder_summary to authenticated;
