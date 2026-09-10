-- T20 automated hosted/demo acceptance.
-- Uses only the fictional T20 dataset and rolls every test mutation back.

begin;

do $$
begin
  if not exists(
    select 1 from public.settings
    where key='demo.t20.hosted'
      and value->>'mode'='HOSTED_DEMO'
      and coalesce((value->>'contains_real_customer_data')::boolean,true)=false
  ) then
    raise exception 'T20_DEMO_SAFETY_GATE: Hosted fake-data marker is missing.';
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
  v_granted integer;
  v_total integer;
begin
  if auth.uid() is null then raise exception 'T20 demo Admin auth context is missing'; end if;
  select count(distinct rp.permission_id) into v_granted
  from public.role_permissions rp join public.roles r on r.id=rp.role_id
  where r.code='admin';
  select count(*) into v_total from public.permissions;
  if v_granted<>v_total then raise exception 'T20 demo Admin is missing permissions: %/%',v_granted,v_total; end if;
end;
$$;

select public.sale_create(
  (select id from public.customers where full_name='Khach Demo 101'),
  'T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY'
);

select public.sale_add_item(
  (select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY'),
  (select id from public.products where sku='DEMO-LAP-T20'),
  1,12500000,0,
  array[(select id from public.inventory_units where serial_number='DEMO-T20-SN-002')]
);

select public.sale_confirm(
  (select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY')
);

do $$
declare
  v_order_id uuid;
  v_balance numeric;
begin
  select id,balance_due into v_order_id,v_balance
  from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY';

  begin
    perform public.sale_record_payment(v_order_id,v_balance-1,'BANK_TRANSFER','T20-AUTO-WRONG-UNDER','must fail');
    raise exception 'T20 underpayment unexpectedly succeeded';
  exception when others then
    if sqlerrm='T20 underpayment unexpectedly succeeded' then raise; end if;
    if position('PAYMENT_AMOUNT_MUST_MATCH_BALANCE' in sqlerrm)=0 then raise; end if;
  end;

  begin
    perform public.sale_record_payment(v_order_id,v_balance+1,'BANK_TRANSFER','T20-AUTO-WRONG-OVER','must fail');
    raise exception 'T20 overpayment unexpectedly succeeded';
  exception when others then
    if sqlerrm='T20 overpayment unexpectedly succeeded' then raise; end if;
    if position('PAYMENT_AMOUNT_MUST_MATCH_BALANCE' in sqlerrm)=0 then raise; end if;
  end;
end;
$$;

select public.sale_record_payment(
  (select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY'),
  (select balance_due from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY'),
  'BANK_TRANSFER','T20-AUTO-PAY-UNIQUE','T20 exact-balance payment'
);

do $$
begin
  begin
    perform public.sale_deliver(
      (select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY')
    );
    raise exception 'T20 handover without prerequisites unexpectedly succeeded';
  exception when others then
    if sqlerrm='T20 handover without prerequisites unexpectedly succeeded' then raise; end if;
    if position('HANDOVER_PREREQUISITES_INCOMPLETE' in sqlerrm)=0 then raise; end if;
  end;
end;
$$;

select public.sale_set_checklist_item((select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY'),'customer_identity',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY'),'contact_phone',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY'),'product_quantity',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY'),'product_configuration',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY'),'serial_numbers',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY'),'physical_condition',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY'),'functionality_test',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY'),'price_discount',true);
select public.sale_set_checklist_item((select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY'),'warranty_terms',true);

select public.sale_deliver(
  (select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY')
);

do $$
declare
  v_order_id uuid;
  v_item_id uuid;
  v_unit_id uuid;
  v_warranty public.warranties%rowtype;
  v_scan jsonb;
  v_qr jsonb;
begin
  select id into v_order_id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY';
  select i.id,i.inventory_unit_ids[1] into v_item_id,v_unit_id
  from public.sales_order_items i where i.sales_order_id=v_order_id;

  select * into v_warranty
  from public.warranties
  where source_type='SALE' and source_id=v_order_id and source_item_id=v_item_id and inventory_unit_id=v_unit_id;
  if not found then raise exception 'T20 automatic warranty was not created at handover'; end if;
  if v_warranty.status<>'ACTIVE' or v_warranty.serial_snapshot<>'DEMO-T20-SN-002' then
    raise exception 'T20 automatic warranty has wrong status/serial';
  end if;

  v_scan:=public.warranty_scan_product('DEMO-T20-SN-002');
  if coalesce((v_scan->>'found')::boolean,false)=false
     or coalesce((v_scan->>'has_warranty')::boolean,false)=false
     or v_scan->>'status'<>'ACTIVE'
  then raise exception 'T20 serial scan did not return ACTIVE warranty: %',v_scan; end if;

  v_scan:=public.warranty_scan_product(v_warranty.warranty_code);
  if v_scan->>'status'<>'ACTIVE' then raise exception 'T20 warranty-code scan failed: %',v_scan; end if;
  v_scan:=public.warranty_scan_product('https://demo.invalid/w/'||v_warranty.lookup_token);
  if v_scan->>'status'<>'ACTIVE' then raise exception 'T20 public QR scan failed: %',v_scan; end if;
  v_scan:=public.warranty_scan_product((select order_code from public.sales_orders where id=v_order_id));
  if v_scan->>'status'<>'ACTIVE' then raise exception 'T20 sale-code scan failed: %',v_scan; end if;

  v_qr:=public.qr_issue('INVENTORY_UNIT','DEMO-T20-SN-002','VIEW',null);
  v_scan:=public.warranty_scan_product(v_qr->>'token');
  if v_scan->>'status'<>'ACTIVE' or v_scan->>'lookup_type'<>'INTERNAL_QR_INVENTORY_UNIT' then
    raise exception 'T20 internal inventory QR scan failed: %',v_scan;
  end if;

  perform public.warranty_create_sale(
    v_item_id,v_unit_id,null,current_date-400,12,'T20 expired simulation','T20 AUTOMATED EXPIRED'
  );
  v_scan:=public.warranty_scan_product('DEMO-T20-SN-002');
  if v_scan->>'status'<>'EXPIRED' then raise exception 'T20 expired scan simulation failed: %',v_scan; end if;

  perform public.warranty_create_sale(
    v_item_id,v_unit_id,null,current_date,12,'Bảo hành tự động theo đơn','T20 AUTOMATED ACTIVE'
  );
  if (select count(*) from public.warranties where source_type='SALE' and source_id=v_order_id and inventory_unit_id=v_unit_id)<>1 then
    raise exception 'T20 idempotent warranty activation created a duplicate';
  end if;
end;
$$;

select public.sale_set_checklist_item(
  (select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY'),
  'customer_delivery_confirmation',true
);
select public.sale_complete(
  (select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY')
);

-- Duplicate external payment reference must fail on a separate sale.
select public.sale_create(
  (select id from public.customers where full_name='Cong ty Demo 103'),
  'T20 AUTOMATED ACCEPTANCE PARTIAL PAYMENT'
);
select public.sale_add_item(
  (select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE PARTIAL PAYMENT'),
  (select id from public.products where sku='DEMO-MOUSE-T20'),
  1,220000,0,'{}'::uuid[]
);
select public.sale_confirm(
  (select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE PARTIAL PAYMENT')
);

do $$
begin
  begin
    perform public.sale_record_partial_payment(
      (select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE PARTIAL PAYMENT'),
      100000,'BANK_TRANSFER','T20-AUTO-PAY-UNIQUE','duplicate reference must fail'
    );
    raise exception 'T20 duplicate payment reference unexpectedly succeeded';
  exception when others then
    if sqlerrm='T20 duplicate payment reference unexpectedly succeeded' then raise; end if;
    if position('PAYMENT_REFERENCE_DUPLICATE' in sqlerrm)=0 then raise; end if;
  end;
end;
$$;

select public.sale_record_partial_payment(
  (select id from public.sales_orders where note='T20 AUTOMATED ACCEPTANCE PARTIAL PAYMENT'),
  100000,'BANK_TRANSFER','T20-AUTO-PARTIAL-UNIQUE','Công nợ demo có lý do rõ ràng'
);

set constraints all immediate;

reset role;

do $$
declare
  v_snapshot jsonb;
begin
  v_snapshot:=private.operational_integrity_snapshot_impl();
  if coalesce((v_snapshot->>'ok')::boolean,false)=false then
    raise exception 'T20 operational integrity snapshot failed: %',v_snapshot;
  end if;
end;
$$;

do $$
begin

  begin
    update public.sales_orders
    set paid_amount=paid_amount-1
    where note='T20 AUTOMATED ACCEPTANCE SERIAL WARRANTY';
    raise exception 'T20 payment-ledger drift unexpectedly succeeded';
  exception when others then
    if sqlerrm='T20 payment-ledger drift unexpectedly succeeded' then raise; end if;
    if position('PAYMENT_LEDGER_MISMATCH' in sqlerrm)=0 then raise; end if;
  end;

  begin
    update public.sales_orders
    set total_amount=total_amount+1
    where note='T20 AUTOMATED ACCEPTANCE PARTIAL PAYMENT';
    raise exception 'T20 sale-total drift unexpectedly succeeded';
  exception when others then
    if sqlerrm='T20 sale-total drift unexpectedly succeeded' then raise; end if;
    if position('SALE_TOTAL_MISMATCH' in sqlerrm)=0 then raise; end if;
  end;

  begin
    update public.repair_orders set status='READY'
    where intake_note='T20 HOSTED DEMO REPAIR';
    raise exception 'T20 repair prerequisite bypass unexpectedly succeeded';
  exception when others then
    if sqlerrm='T20 repair prerequisite bypass unexpectedly succeeded' then raise; end if;
    if position('REPAIR_PREREQUISITES_INCOMPLETE' in sqlerrm)=0 then raise; end if;
  end;
end;
$$;

do $$
begin
  if has_function_privilege('anon','public.warranty_scan_product(text)','EXECUTE') then
    raise exception 'anon must not execute internal warranty scanner';
  end if;
  if to_regprocedure('public.operational_integrity_snapshot()') is not null then
    raise exception 'operational integrity snapshot must not be public';
  end if;
  if to_regprocedure('public.warranty_activate_sale(uuid)') is not null then
    raise exception 'manual warranty activation must not be public';
  end if;
  if not has_function_privilege('authenticated','public.warranty_scan_product(text)','EXECUTE') then
    raise exception 'authenticated warranty scanner grant missing';
  end if;
  if has_function_privilege('authenticated','private.warranty_activate_sale_impl(uuid,uuid)','EXECUTE') then
    raise exception 'private automatic warranty implementation is directly executable';
  end if;
  if has_function_privilege('authenticated','private.operational_integrity_snapshot_impl()','EXECUTE') then
    raise exception 'private integrity implementation is directly executable';
  end if;
end;
$$;

rollback;

select 'T20 DEMO PAYMENT AMOUNT/REFERENCE ACCEPTANCE: PASS' as result;
select 'T20 DEMO AUTO WARRANTY/SCAN ACCEPTANCE: PASS' as result;
select 'T20 DEMO WORKFLOW/INTEGRITY ACCEPTANCE: PASS' as result;
select 'T20 DEMO ADMIN FULL RBAC ACCEPTANCE: PASS' as result;
select 'T20 AUTOMATED FAKE-DATA ACCEPTANCE: PASS' as result;
