create index idx_warranties_inventory_unit on public.warranties(inventory_unit_id) where inventory_unit_id is not null;
