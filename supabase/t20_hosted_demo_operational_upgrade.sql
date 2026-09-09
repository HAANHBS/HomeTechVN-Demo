-- T20 hosted fake-data operational upgrade.
-- Adds one completed serialized sale with an ACTIVE auto-created warranty.
-- Safe to rerun; refuses databases without the explicit fictional-data marker.

begin;

do $$
begin
  if not exists(
    select 1 from public.settings
    where key='demo.t20.hosted'
      and value->>'mode'='HOSTED_DEMO'
      and coalesce((value->>'contains_real_customer_data')::boolean,true)=false
  ) then
    raise exception 'T20_DEMO_SAFETY_GATE: Refusing database without fictional hosted-demo marker.';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  (select p.id::text
   from public.profiles p join public.roles r on r.id=p.role_id
   where p.is_active and r.code='admin'
   order by p.created_at limit 1),
  true
);
set local role authenticated;

do $$
declare
  v_order_id uuid;
  v_item_id uuid;
  v_unit_id uuid;
  v_device_id uuid;
  v_total numeric;
begin
  if auth.uid() is null then raise exception 'T20 hosted demo Admin auth context is missing'; end if;

  select id into v_order_id
  from public.sales_orders
  where note='T20 HOSTED DEMO COMPLETED SERIAL WARRANTY';

  if v_order_id is null then
    select id into v_unit_id
    from public.inventory_units
    where serial_number='DEMO-T20-SN-001' and status='IN_STOCK';
    if v_unit_id is null then
      raise exception 'T20 hosted demo serial DEMO-T20-SN-001 is not available';
    end if;

    perform public.sale_create(
      (select id from public.customers where full_name='Khach Demo 101'),
      'T20 HOSTED DEMO COMPLETED SERIAL WARRANTY'
    );
    select id into strict v_order_id
    from public.sales_orders where note='T20 HOSTED DEMO COMPLETED SERIAL WARRANTY';

    perform public.sale_add_item(
      v_order_id,(select id from public.products where sku='DEMO-LAP-T20'),
      1,12500000,0,array[v_unit_id]
    );
    perform public.sale_confirm(v_order_id);
    select total_amount into v_total from public.sales_orders where id=v_order_id;
    perform public.sale_record_payment(
      v_order_id,v_total,'BANK_TRANSFER','DEMO-T20-SERIAL-PAY-001','Thanh toán đủ đơn serial giả lập'
    );

    perform public.sale_set_checklist_item(v_order_id,'customer_identity',true);
    perform public.sale_set_checklist_item(v_order_id,'contact_phone',true);
    perform public.sale_set_checklist_item(v_order_id,'product_quantity',true);
    perform public.sale_set_checklist_item(v_order_id,'product_configuration',true);
    perform public.sale_set_checklist_item(v_order_id,'serial_numbers',true);
    perform public.sale_set_checklist_item(v_order_id,'physical_condition',true);
    perform public.sale_set_checklist_item(v_order_id,'functionality_test',true);
    perform public.sale_set_checklist_item(v_order_id,'price_discount',true);
    perform public.sale_set_checklist_item(v_order_id,'warranty_terms',true);
    perform public.sale_deliver(v_order_id);

    select i.id,i.inventory_unit_ids[1] into strict v_item_id,v_unit_id
    from public.sales_order_items i where i.sales_order_id=v_order_id;
    select d.id into v_device_id
    from public.customer_devices d
    where d.customer_id=(select customer_id from public.sales_orders where id=v_order_id)
      and lower(coalesce(d.serial_number,''))='demo-t20-sn-001'
    limit 1;

    perform public.warranty_create_sale(
      v_item_id,v_unit_id,v_device_id,current_date-30,12,
      'Bảo hành phần cứng 12 tháng · dữ liệu demo',
      'T20 HOSTED DEMO ACTIVE SERIAL WARRANTY'
    );
    perform public.sale_set_checklist_item(v_order_id,'warranty_document',true);
    perform public.sale_set_checklist_item(v_order_id,'customer_delivery_confirmation',true);
    perform public.sale_complete(v_order_id);
  end if;

  if not exists(
    select 1
    from public.sales_orders o
    join public.sales_order_items i on i.sales_order_id=o.id
    join public.warranties w on w.source_type='SALE' and w.source_id=o.id
      and w.source_item_id=i.id and w.inventory_unit_id=i.inventory_unit_ids[1]
    where o.note='T20 HOSTED DEMO COMPLETED SERIAL WARRANTY'
      and o.status='COMPLETED' and o.paid_amount=o.total_amount and o.balance_due=0
      and w.status='ACTIVE' and w.end_date>=current_date
      and w.serial_snapshot='DEMO-T20-SN-001'
  ) then
    raise exception 'T20 hosted completed-sale/warranty fixture is inconsistent';
  end if;

end;
$$;

update public.settings
set value=value||jsonb_build_object(
      'operational_acceptance','AUTOMATED_FAKE_DATA',
      'warranty_scan_serial','DEMO-T20-SN-001',
      'logic_hardening','T20.2',
      'logic_loaded_at',now()
    ),
    updated_at=now()
where key='demo.t20.hosted';

reset role;

do $$
begin
  if coalesce((private.operational_integrity_snapshot_impl()->>'ok')::boolean,false)=false then
    raise exception 'T20 hosted operational integrity snapshot is not clean';
  end if;
end;
$$;

commit;

select 'T20 HOSTED COMPLETED SERIAL/WARRANTY DEMO: PASS' as result;
