-- HomeTechVN T20 - defense-in-depth for private cost tables.
-- These tables remain RPC-only. RLS and explicit deny-all policies make the
-- intended closure visible to security posture checks.

begin;

alter table private.sales_order_item_costs enable row level security;
alter table private.repair_part_costs enable row level security;

create policy sales_order_item_costs_no_direct_access
on private.sales_order_item_costs
for all
to public
using (false)
with check (false);

create policy repair_part_costs_no_direct_access
on private.repair_part_costs
for all
to public
using (false)
with check (false);

revoke all on table
  private.sales_order_item_costs,
  private.repair_part_costs
from public, anon, authenticated;

grant all on table
  private.sales_order_item_costs,
  private.repair_part_costs
to service_role;

commit;
