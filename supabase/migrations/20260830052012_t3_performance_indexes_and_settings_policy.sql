-- HomeTechVN T3 — performance indexes + consolidate Settings SELECT policy

create index idx_product_categories_created_by on public.product_categories(created_by);
create index idx_product_categories_updated_by on public.product_categories(updated_by);
create index idx_products_created_by on public.products(created_by);
create index idx_products_updated_by on public.products(updated_by);
create index idx_inventory_units_created_by on public.inventory_units(created_by);
create index idx_inventory_units_updated_by on public.inventory_units(updated_by);
create index idx_inventory_transactions_created_by on public.inventory_transactions(created_by);

drop policy settings_crm_device_types_select on public.settings;
drop policy settings_select on public.settings;
create policy settings_select
on public.settings for select
to authenticated
using (
  (select private.has_permission('settings.view'))
  or (
    key = 'crm.device_types'
    and (select private.has_permission('device.view'))
  )
);
