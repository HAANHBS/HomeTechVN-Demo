\set ON_ERROR_STOP on

do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from information_schema.tables
  where table_schema='private' and table_name in ('qr_codes','qr_action_events');
  if v_count<>2 then raise exception 'T20 QR private tables missing'; end if;

  select count(*) into v_count
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='private' and c.relname in ('qr_codes','qr_action_events') and c.relrowsecurity;
  if v_count<>2 then raise exception 'T20 QR private RLS missing'; end if;

  select count(*) into v_count from pg_policies
  where schemaname='private'
    and (
      (tablename='qr_codes' and policyname='qr_codes_no_direct_access') or
      (tablename='qr_action_events' and policyname='qr_action_events_no_direct_access')
    )
    and cmd='ALL'
    and roles='{public}'
    and qual='false'
    and with_check='false';
  if v_count<>2 then raise exception 'T20 private QR deny-all policies missing or unsafe'; end if;

  select count(*) into v_count
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where c.relkind in ('r','p')
    and c.relrowsecurity
    and n.nspname in ('public','private','public_lookup_private')
    and not exists(select 1 from pg_policy p where p.polrelid=c.oid);
  if v_count<>0 then raise exception 'T20 security snapshot RLS gap: % table(s) without policy',v_count; end if;

  if has_table_privilege('authenticated','private.qr_codes','SELECT') then
    raise exception 'authenticated must not read private QR tokens';
  end if;
  if has_function_privilege('anon','public.qr_resolve(text)','EXECUTE') then
    raise exception 'anon must not resolve internal QR';
  end if;
  if not has_function_privilege('authenticated','public.qr_resolve(text)','EXECUTE') then
    raise exception 'authenticated QR resolver grant missing';
  end if;
  if has_function_privilege('authenticated','private.qr_issue_impl(text,text,text,timestamp with time zone)','EXECUTE') then
    raise exception 'authenticated must not execute private QR implementation';
  end if;

  select count(*) into v_count from public.permissions where code in ('qr.issue','qr.revoke');
  if v_count<>2 then raise exception 'T20 QR permissions missing'; end if;

  select count(*) into v_count
  from information_schema.columns
  where table_schema='private' and table_name='qr_codes' and column_name in ('token','raw_token','plaintext_token');
  if v_count<>0 then raise exception 'T20 QR table contains a plaintext token column'; end if;

  select count(*) into v_count
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('private','public')
    and p.proname in ('qr_issue_impl','qr_resolve_impl','qr_revoke_impl','qr_issue','qr_resolve','qr_revoke')
    and p.prosecdef
    and coalesce(array_to_string(p.proconfig,','),'') like '%search_path=%';
  if v_count<>6 then raise exception 'T20 QR SECURITY DEFINER/search_path contract incomplete: %',v_count; end if;
end $$;

select 'T20 QR DATABASE SECURITY CHECK: PASS' as result;

do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='private'
    and c.relname in ('sales_order_item_costs','repair_part_costs')
    and c.relrowsecurity;
  if v_count<>2 then raise exception 'T20 private cost RLS missing'; end if;

  select count(*) into v_count
  from pg_policies
  where schemaname='private'
    and policyname in (
      'sales_order_item_costs_no_direct_access',
      'repair_part_costs_no_direct_access'
    )
    and cmd='ALL'
    and roles='{public}'
    and qual='false'
    and with_check='false';
  if v_count<>2 then raise exception 'T20 private cost deny-all policies missing or unsafe'; end if;

  if has_table_privilege('anon','private.sales_order_item_costs','SELECT')
     or has_table_privilege('authenticated','private.sales_order_item_costs','SELECT')
     or has_table_privilege('anon','private.repair_part_costs','SELECT')
     or has_table_privilege('authenticated','private.repair_part_costs','SELECT')
  then raise exception 'T20 private cost direct privilege regression'; end if;
end $$;

select 'T20 PRIVATE COST RLS CHECK: PASS' as result;

-- ------------------------------------------------------------------
-- T20.1 payment ledger and workflow prerequisite regression.
-- T17 demo data exists when this file is executed by t20:verify.
-- Every mutation below is rolled back.
-- ------------------------------------------------------------------
begin;

select set_config(
  'request.jwt.claim.sub',
  (select id::text from auth.users where email='demo.cashier@hometechvn.example'),
  true
);
set local role authenticated;

do $$
declare
  v_order_id uuid;
begin
  select id into v_order_id
  from public.sales_orders
  where note='T17 DEMO RECEIVABLE';

  begin
    perform public.sale_record_payment(v_order_id,1,'CASH',null,'T20 mismatch must fail');
    raise exception 'T20 mismatched payment unexpectedly succeeded';
  exception when others then
    if sqlerrm='T20 mismatched payment unexpectedly succeeded' then raise; end if;
    if position('PAYMENT_AMOUNT_MUST_MATCH_BALANCE' in sqlerrm)=0 then raise; end if;
  end;
end $$;

select public.sale_record_payment(
  (select id from public.sales_orders where note='T17 DEMO RECEIVABLE'),
  (select balance_due from public.sales_orders where note='T17 DEMO RECEIVABLE'),
  'CASH',null,'T20 exact-balance regression'
);

set constraints all immediate;

do $$
declare
  v_order public.sales_orders%rowtype;
  v_ledger numeric;
begin
  select * into v_order from public.sales_orders where note='T17 DEMO RECEIVABLE';
  select coalesce(sum(amount),0) into v_ledger
  from public.payments where sales_order_id=v_order.id and status='COMPLETED';
  if v_order.status<>'PAID'
     or v_order.paid_amount<>v_order.total_amount
     or v_ledger<>v_order.total_amount
     or v_order.balance_due<>0
  then raise exception 'T20 exact payment did not reconcile order and ledger'; end if;
end $$;

reset role;
update public.profiles
set role_id=(select id from public.roles where code='sales')
where id=(select id from auth.users where email='demo.cashier@hometechvn.example');
set local role authenticated;

do $$
begin
  perform public.sale_deliver(
    (select id from public.sales_orders where note='T17 DEMO RECEIVABLE')
  );
  raise exception 'T20 handover unexpectedly ignored checklist prerequisites';
exception when others then
  if sqlerrm='T20 handover unexpectedly ignored checklist prerequisites' then raise; end if;
  if position('HANDOVER_PREREQUISITES_INCOMPLETE' in sqlerrm)=0 then raise; end if;
end $$;

reset role;
set constraints all immediate;
do $$
begin
  begin
    update public.sales_orders
    set paid_amount=paid_amount-1
    where note='T17 DEMO RECEIVABLE';
    raise exception 'T20 payment-ledger drift unexpectedly succeeded';
  exception when check_violation then
    if position('PAYMENT_LEDGER_MISMATCH' in sqlerrm)=0 then raise; end if;
  end;
end $$;

rollback;

do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from pg_trigger t
  join pg_class c on c.oid=t.tgrelid
  join pg_namespace n on n.oid=c.relnamespace
  where not t.tgisinternal
    and n.nspname='public'
    and t.tgname in (
      'trg_sales_items_deferred_total_consistency',
      'trg_sales_orders_deferred_total_consistency',
      'trg_payments_deferred_consistency',
      'trg_sales_orders_deferred_payment_consistency',
      'trg_sales_orders_deferred_warranty_coverage',
      'trg_warranties_deferred_sale_coverage',
      'trg_repair_transition_prerequisite_guard'
    );
  if v_count<>7 then raise exception 'T20 logic-integrity trigger count expected 7, got %',v_count; end if;

  if has_function_privilege('anon','public.sale_record_partial_payment(uuid,numeric,text,text,text)','EXECUTE') then
    raise exception 'anon must not execute explicit partial payment RPC';
  end if;
  if not has_function_privilege('authenticated','public.sale_record_partial_payment(uuid,numeric,text,text,text)','EXECUTE') then
    raise exception 'authenticated explicit partial payment grant missing';
  end if;
  if has_function_privilege('authenticated','private.sale_record_partial_payment_impl(uuid,numeric,text,text,text)','EXECUTE') then
    raise exception 'authenticated must not directly execute private partial payment implementation';
  end if;
  if has_function_privilege('anon','public.warranty_scan_product(text)','EXECUTE') then
    raise exception 'anon must not execute internal warranty scan';
  end if;
  if not has_function_privilege('authenticated','public.warranty_scan_product(text)','EXECUTE') then
    raise exception 'authenticated warranty scan grant missing';
  end if;
  if has_function_privilege('authenticated','private.warranty_activate_sale_impl(uuid,uuid)','EXECUTE') then
    raise exception 'authenticated must not directly execute automatic warranty activation';
  end if;
end $$;

select 'T20 PAYMENT LEDGER INTEGRITY CHECK: PASS' as result;
select 'T20 WORKFLOW PREREQUISITE CHECK: PASS' as result;
select 'T20 AUTO WARRANTY/SCAN SECURITY CHECK: PASS' as result;
