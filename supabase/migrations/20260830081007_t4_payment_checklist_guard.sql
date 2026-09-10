create or replace function private.sale_set_checklist_item_impl(
  p_order_id uuid,
  p_key text,
  p_checked boolean
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_status text;
  v_checklist jsonb;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('sale.update') then raise exception 'Missing permission sale.update'; end if;
  if p_key='payment_confirmed' then raise exception 'payment_confirmed is managed by payment workflow'; end if;

  select status into v_status from public.sales_orders where id=p_order_id for update;
  if not found then raise exception 'Sales order not found'; end if;
  if v_status in ('COMPLETED','CANCELLED') then raise exception 'Checklist is locked for completed/cancelled order'; end if;

  perform private.sale_set_checklist_system(p_order_id,p_key,p_checked,v_uid);
  select checklist into v_checklist from public.sales_orders where id=p_order_id;
  return v_checklist;
end;
$$;

grant execute on function private.sale_set_checklist_item_impl(uuid,text,boolean) to authenticated;
