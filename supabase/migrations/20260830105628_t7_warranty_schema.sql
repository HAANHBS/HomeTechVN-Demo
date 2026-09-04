create table public.warranties (
  id uuid primary key default gen_random_uuid(),
  warranty_code text not null default '',
  lookup_token text not null default (replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','')),
  customer_id uuid not null references public.customers(id) on delete restrict,
  customer_device_id uuid references public.customer_devices(id) on delete restrict,
  source_type text not null check (source_type in ('SALE','REPAIR','SERVICE')),
  source_id uuid not null,
  source_item_id uuid,
  product_id uuid references public.products(id) on delete restrict,
  inventory_unit_id uuid references public.inventory_units(id) on delete restrict,
  product_name_snapshot text,
  serial_snapshot text,
  coverage text not null default 'Bao hanh tieu chuan' check (length(btrim(coverage))>0),
  start_date date not null,
  end_date date not null,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','EXPIRED','VOID')),
  void_reason text,
  note text,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint warranties_code_unique unique(warranty_code),
  constraint warranties_lookup_token_unique unique(lookup_token),
  constraint warranties_dates_valid check (end_date>=start_date),
  constraint warranties_void_fields check ((status='VOID' and void_reason is not null) or status<>'VOID')
);
create unique index ux_warranties_source_serial on public.warranties(source_type,source_id,source_item_id,inventory_unit_id) where inventory_unit_id is not null;
create unique index ux_warranties_source_item_nonserial on public.warranties(source_type,source_id,source_item_id) where source_item_id is not null and inventory_unit_id is null;
create unique index ux_warranties_source_root on public.warranties(source_type,source_id) where source_item_id is null and inventory_unit_id is null;
create index idx_warranties_customer on public.warranties(customer_id,created_at desc);
create index idx_warranties_device on public.warranties(customer_device_id) where customer_device_id is not null;
create index idx_warranties_product on public.warranties(product_id) where product_id is not null;
create index idx_warranties_status_dates on public.warranties(status,end_date);
create index idx_warranties_created_by on public.warranties(created_by);
create index idx_warranties_updated_by on public.warranties(updated_by);

create table public.warranty_claims (
  id uuid primary key default gen_random_uuid(),
  claim_code text not null default '',
  warranty_id uuid not null references public.warranties(id) on delete restrict,
  status text not null default 'RECEIVED' check (status in ('RECEIVED','CHECKING','APPROVED','REJECTED','IN_SERVICE','QC','READY','RETURNED','CLOSED')),
  issue_description text not null check (length(btrim(issue_description))>0),
  intake_condition text,
  customer_request text,
  assigned_technician_id uuid references public.profiles(id) on delete set null,
  decision_note text,
  service_note text,
  resolution text,
  qc_passed boolean,
  qc_note text,
  received_at timestamptz not null default now(),
  checking_at timestamptz,
  approved_at timestamptz,
  rejected_at timestamptz,
  in_service_at timestamptz,
  qc_at timestamptz,
  ready_at timestamptz,
  returned_at timestamptz,
  closed_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint warranty_claims_code_unique unique(claim_code)
);
create unique index ux_warranty_claims_one_open on public.warranty_claims(warranty_id) where status not in ('CLOSED','REJECTED');
create index idx_warranty_claims_warranty_created on public.warranty_claims(warranty_id,created_at desc);
create index idx_warranty_claims_status_created on public.warranty_claims(status,created_at desc);
create index idx_warranty_claims_assignee on public.warranty_claims(assigned_technician_id) where assigned_technician_id is not null;
create index idx_warranty_claims_created_by on public.warranty_claims(created_by);
create index idx_warranty_claims_updated_by on public.warranty_claims(updated_by);

create table public.warranty_status_history (
  id bigint generated always as identity primary key,
  warranty_claim_id uuid not null references public.warranty_claims(id) on delete cascade,
  from_status text,
  to_status text not null,
  note text,
  changed_by uuid references public.profiles(id) on delete set null,
  changed_at timestamptz not null default now()
);
create index idx_warranty_status_history_claim on public.warranty_status_history(warranty_claim_id,changed_at desc);
create index idx_warranty_status_history_changed_by on public.warranty_status_history(changed_by) where changed_by is not null;

create trigger trg_warranties_updated_at before update on public.warranties for each row execute function public.fn_set_updated_at();
create trigger trg_warranty_claims_updated_at before update on public.warranty_claims for each row execute function public.fn_set_updated_at();
create trigger trg_warranties_audit after insert or update or delete on public.warranties for each row execute function public.fn_audit_row();
create trigger trg_warranty_claims_audit after insert or update or delete on public.warranty_claims for each row execute function public.fn_audit_row();
create trigger trg_warranty_status_history_audit after insert or update or delete on public.warranty_status_history for each row execute function public.fn_audit_row();

alter table public.warranties enable row level security;
alter table public.warranty_claims enable row level security;
alter table public.warranty_status_history enable row level security;
create policy warranties_select on public.warranties for select to authenticated using ((select private.has_permission('warranty.view')));
create policy warranty_claims_select on public.warranty_claims for select to authenticated using ((select private.has_permission('warranty.view')));
create policy warranty_status_history_select on public.warranty_status_history for select to authenticated using ((select private.has_permission('warranty.view')));
revoke all on public.warranties,public.warranty_claims,public.warranty_status_history from anon,authenticated;
grant select on public.warranties,public.warranty_claims,public.warranty_status_history to authenticated;

create view public.warranty_summary with (security_invoker=true) as
select w.id,w.warranty_code,w.lookup_token,w.customer_id,c.customer_code,c.full_name as customer_name,c.phone,
       w.customer_device_id,d.device_code,d.device_type,d.brand,d.model,d.serial_number as device_serial,
       w.source_type,w.source_id,w.source_item_id,w.product_id,w.inventory_unit_id,w.product_name_snapshot,w.serial_snapshot,
       w.coverage,w.start_date,w.end_date,w.status,
       case when w.status='VOID' then 'VOID' when current_date>w.end_date then 'EXPIRED' else 'ACTIVE' end as effective_status,
       w.void_reason,w.note,w.created_at,w.updated_at,
       (select count(*) from public.warranty_claims cl where cl.warranty_id=w.id) as claim_count,
       (select cl.status from public.warranty_claims cl where cl.warranty_id=w.id order by cl.created_at desc limit 1) as latest_claim_status
from public.warranties w
join public.customers c on c.id=w.customer_id
left join public.customer_devices d on d.id=w.customer_device_id;
revoke all on public.warranty_summary from anon,authenticated;
grant select on public.warranty_summary to authenticated;

create view public.warranty_claim_summary with (security_invoker=true) as
select cl.id,cl.claim_code,cl.warranty_id,w.warranty_code,w.customer_id,c.customer_code,c.full_name as customer_name,c.phone,
       w.customer_device_id,d.device_code,d.device_type,d.brand,d.model,
       cl.status,cl.issue_description,cl.assigned_technician_id,cl.qc_passed,cl.received_at,cl.ready_at,cl.returned_at,cl.closed_at,cl.created_at,cl.updated_at
from public.warranty_claims cl
join public.warranties w on w.id=cl.warranty_id
join public.customers c on c.id=w.customer_id
left join public.customer_devices d on d.id=w.customer_device_id;
revoke all on public.warranty_claim_summary from anon,authenticated;
grant select on public.warranty_claim_summary to authenticated;
