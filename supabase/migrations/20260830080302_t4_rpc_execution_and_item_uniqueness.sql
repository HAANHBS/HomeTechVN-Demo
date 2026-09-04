create unique index ux_sales_order_items_order_product
  on public.sales_order_items(sales_order_id,product_id);

grant execute on function private.sale_create_impl(uuid,text) to authenticated;
grant execute on function private.sale_update_draft_impl(uuid,uuid,numeric,text) to authenticated;
grant execute on function private.sale_add_item_impl(uuid,uuid,numeric,numeric,numeric,uuid[]) to authenticated;
grant execute on function private.sale_update_item_impl(uuid,numeric,numeric,numeric,uuid[]) to authenticated;
grant execute on function private.sale_remove_item_impl(uuid) to authenticated;
grant execute on function private.sale_set_checklist_item_impl(uuid,text,boolean) to authenticated;
grant execute on function private.sale_confirm_impl(uuid) to authenticated;
grant execute on function private.sale_record_payment_impl(uuid,numeric,text,text,text) to authenticated;
grant execute on function private.sale_refund_payment_impl(uuid,text) to authenticated;
grant execute on function private.sale_deliver_impl(uuid) to authenticated;
grant execute on function private.sale_complete_impl(uuid) to authenticated;
grant execute on function private.sale_cancel_impl(uuid,text) to authenticated;
