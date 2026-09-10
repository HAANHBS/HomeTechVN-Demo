create table public.repair_orders (
  id uuid primary key default gen_random_uuid(),
  repair_code text not null default '',
  customer_id uuid not null references public.customers(id) on delete restrict,
  customer_device_id uuid not null references public.customer_devices(id) on delete restrict,
  status text not null default 'RECEIVED' check (status in ('RECEIVED','DIAGNOSING','QUOTED','AWAITING_CUSTOMER','APPROVED','REPAIRING','QC','READY','RETURNED','COMPLETED','CUSTOMER_REJECTED','NO_FIX','WAITING_PART','CANCELLED','WARRANTY_TRANSFER')),
  priority text not null default 'NORMAL' check (priority in ('NORMAL','HIGH','URGENT')),
  reported_issue text not null check (length(btrim(reported_issue)) > 0),
  intake_condition text,
  accessories_received text[] not null default '{}'::text[],
  customer_request text,
  intake_note text,
  assigned_technician_id uuid references public.profiles(id) on delete set null,
  approved_quote_id uuid,
  approved_amount numeric(14,2) not null default 0 check (approved_amount >= 0),
  final_amount numeric(14,2) not null default 0 check (final_amount >= 0),
  estimated_completion_at timestamptz,
  waiting_part_note text,
  customer_rejected_reason text,
  no_fix_reason text,
  warranty_transfer_note text,
  qc_passed boolean,
  qc_note text,
  diagnosed_at timestamptz,
  quoted_at timestamptz,
  awaiting_customer_at timestamptz,
  approved_at timestamptz,
  repairing_at timestamptz,
  qc_at timestamptz,
  ready_at timestamptz,
  returned_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  warranty_transfer_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint repair_orders_code_unique unique(repair_code)
);

create table public.repair_diagnostics (
  id uuid primary key default gen_random_uuid(),
  repair_order_id uuid not null references public.repair_orders(id) on delete cascade,
  stage text not null check (stage in ('DIAGNOSIS','QC')),
  symptom text,
  findings text not null check (length(btrim(findings)) > 0),
  conclusion text,
  recommendation text,
  passed boolean,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint repair_diagnostics_qc_pass_check check ((stage='DIAGNOSIS' and passed is null) or (stage='QC' and passed is not null))
);

create table public.repair_quotes (
  id uuid primary key default gen_random_uuid(),
  repair_order_id uuid not null references public.repair_orders(id) on delete cascade,
  version integer not null check (version > 0),
  status text not null default 'DRAFT' check (status in ('DRAFT','SENT','APPROVED','REJECTED','SUPERSEDED')),
  labor_amount numeric(14,2) not null default 0 check (labor_amount >= 0),
  parts_amount numeric(14,2) not null default 0 check (parts_amount >= 0),
  discount_amount numeric(14,2) not null default 0 check (discount_amount >= 0),
  total_amount numeric(14,2) generated always as (greatest(labor_amount + parts_amount - discount_amount, 0)) stored,
  valid_until date,
  note text,
  customer_response_note text,
  sent_at timestamptz,
  approved_at timestamptz,
  rejected_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint repair_quotes_version_unique unique(repair_order_id,version),
  constraint repair_quotes_discount_check check (discount_amount <= labor_amount + parts_amount)
);

alter table public.repair_orders
  add constraint repair_orders_approved_quote_fkey
  foreign key (approved_quote_id) references public.repair_quotes(id) on delete set null;

create table public.repair_parts (
  id uuid primary key default gen_random_uuid(),
  repair_order_id uuid not null references public.repair_orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity numeric(12,3) not null check (quantity > 0),
  unit_price numeric(14,2) not null default 0 check (unit_price >= 0),
  line_total numeric(14,2) generated always as (quantity * unit_price) stored,
  inventory_unit_ids uuid[] not null default '{}'::uuid[],
  status text not null default 'PLANNED' check (status in ('PLANNED','ISSUED','RETURNED')),
  note text,
  issued_at timestamptz,
  returned_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint repair_parts_order_product_unique unique(repair_order_id,product_id)
);

create table public.repair_status_history (
  id bigint generated always as identity primary key,
  repair_order_id uuid not null references public.repair_orders(id) on delete cascade,
  from_status text,
  to_status text not null,
  note text,
  changed_by uuid references public.profiles(id) on delete set null,
  changed_at timestamptz not null default now()
);

create table private.repair_part_costs (
  repair_part_id uuid primary key references public.repair_parts(id) on delete cascade,
  unit_cost numeric(14,2),
  total_cost numeric(14,2),
  captured_at timestamptz not null default now(),
  check (unit_cost is null or unit_cost >= 0),
  check (total_cost is null or total_cost >= 0)
);
revoke all on table private.repair_part_costs from public,anon,authenticated;
grant all on table private.repair_part_costs to service_role;

create index idx_repair_orders_customer_created on public.repair_orders(customer_id,created_at desc);
create index idx_repair_orders_device_created on public.repair_orders(customer_device_id,created_at desc);
create index idx_repair_orders_status_created on public.repair_orders(status,created_at desc);
create index idx_repair_orders_assigned_technician on public.repair_orders(assigned_technician_id);
create index idx_repair_orders_approved_quote on public.repair_orders(approved_quote_id);
create index idx_repair_orders_created_by on public.repair_orders(created_by);
create index idx_repair_orders_updated_by on public.repair_orders(updated_by);
create index idx_repair_diagnostics_order_created on public.repair_diagnostics(repair_order_id,created_at desc);
create index idx_repair_diagnostics_created_by on public.repair_diagnostics(created_by);
create index idx_repair_quotes_order_created on public.repair_quotes(repair_order_id,created_at desc);
create index idx_repair_quotes_created_by on public.repair_quotes(created_by);
create index idx_repair_parts_order on public.repair_parts(repair_order_id);
create index idx_repair_parts_product on public.repair_parts(product_id);
create index idx_repair_parts_created_by on public.repair_parts(created_by);
create index idx_repair_parts_updated_by on public.repair_parts(updated_by);
create index idx_repair_status_history_order_changed on public.repair_status_history(repair_order_id,changed_at desc);
create index idx_repair_status_history_changed_by on public.repair_status_history(changed_by);

create trigger trg_repair_orders_updated_at before update on public.repair_orders for each row execute function public.fn_set_updated_at();
create trigger trg_repair_parts_updated_at before update on public.repair_parts for each row execute function public.fn_set_updated_at();
create trigger trg_repair_orders_audit after insert or update or delete on public.repair_orders for each row execute function public.fn_audit_row();
create trigger trg_repair_diagnostics_audit after insert or update or delete on public.repair_diagnostics for each row execute function public.fn_audit_row();
create trigger trg_repair_quotes_audit after insert or update or delete on public.repair_quotes for each row execute function public.fn_audit_row();
create trigger trg_repair_parts_audit after insert or update or delete on public.repair_parts for each row execute function public.fn_audit_row();
create trigger trg_repair_status_history_audit after insert or update or delete on public.repair_status_history for each row execute function public.fn_audit_row();

alter table public.repair_orders enable row level security;
alter table public.repair_diagnostics enable row level security;
alter table public.repair_quotes enable row level security;
alter table public.repair_parts enable row level security;
alter table public.repair_status_history enable row level security;

create policy repair_orders_select on public.repair_orders for select to authenticated using ((select private.has_permission('repair.view')));
create policy repair_diagnostics_select on public.repair_diagnostics for select to authenticated using ((select private.has_permission('repair.view')));
create policy repair_quotes_select on public.repair_quotes for select to authenticated using ((select private.has_permission('repair.view')));
create policy repair_parts_select on public.repair_parts for select to authenticated using ((select private.has_permission('repair.view')));
create policy repair_status_history_select on public.repair_status_history for select to authenticated using ((select private.has_permission('repair.view')));

revoke all on public.repair_orders,public.repair_diagnostics,public.repair_quotes,public.repair_parts,public.repair_status_history from anon,authenticated;
grant select on public.repair_orders,public.repair_diagnostics,public.repair_quotes,public.repair_parts,public.repair_status_history to authenticated;

create view public.repair_order_summary with (security_invoker=true) as
select o.id,o.repair_code,o.customer_id,c.customer_code,c.full_name as customer_name,c.phone,
       o.customer_device_id,d.device_code,d.device_type,d.brand,d.model,d.serial_number,
       o.status,o.priority,o.reported_issue,o.assigned_technician_id,o.approved_amount,o.final_amount,
       o.estimated_completion_at,o.created_at,o.updated_at,o.ready_at,o.completed_at,
       (select count(*) from public.repair_diagnostics x where x.repair_order_id=o.id and x.stage='DIAGNOSIS') as diagnosis_count,
       (select count(*) from public.repair_parts p where p.repair_order_id=o.id and p.status='ISSUED') as issued_part_count,
       (select q.status from public.repair_quotes q where q.repair_order_id=o.id order by q.version desc limit 1) as latest_quote_status,
       (select q.total_amount from public.repair_quotes q where q.repair_order_id=o.id order by q.version desc limit 1) as latest_quote_total
from public.repair_orders o
join public.customers c on c.id=o.customer_id
join public.customer_devices d on d.id=o.customer_device_id;
revoke all on public.repair_order_summary from anon,authenticated;
grant select on public.repair_order_summary to authenticated;
