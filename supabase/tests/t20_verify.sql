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
