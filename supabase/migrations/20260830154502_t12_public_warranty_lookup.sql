create schema if not exists public_lookup_private;
revoke all on schema public_lookup_private from public;
grant usage on schema public_lookup_private to anon,authenticated,service_role;

create or replace function public_lookup_private.warranty_public_lookup_impl(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v jsonb;
begin
  if p_token is null or length(p_token)<>64 or p_token !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('found',false);
  end if;

  select jsonb_build_object(
    'found',true,
    'warranty_code',w.warranty_code,
    'status',case when w.status='VOID' then 'VOID' when current_date>w.end_date then 'EXPIRED' else 'ACTIVE' end,
    'start_date',w.start_date,
    'end_date',w.end_date,
    'days_remaining',case when w.status='VOID' then null when current_date>w.end_date then 0 else w.end_date-current_date end,
    'coverage',w.coverage,
    'product',coalesce(w.product_name_snapshot,nullif(concat_ws(' ',d.device_type,d.brand,d.model),'')),
    'serial_masked',private.warranty_mask_serial(coalesce(w.serial_snapshot,d.serial_number)),
    'phone_masked',private.warranty_mask_phone(c.phone),
    'latest_claim',(
      select jsonb_build_object(
        'status',cl.status,
        'received_at',cl.received_at,
        'ready_at',cl.ready_at,
        'returned_at',cl.returned_at,
        'closed_at',cl.closed_at
      )
      from public.warranty_claims cl
      where cl.warranty_id=w.id
      order by cl.created_at desc
      limit 1
    )
  ) into v
  from public.warranties w
  join public.customers c on c.id=w.customer_id
  left join public.customer_devices d on d.id=w.customer_device_id
  where w.lookup_token=p_token;

  return coalesce(v,jsonb_build_object('found',false));
end;
$$;

revoke execute on function public_lookup_private.warranty_public_lookup_impl(text) from public;
grant execute on function public_lookup_private.warranty_public_lookup_impl(text) to anon,authenticated,service_role;

create or replace function public.warranty_public_lookup(p_token text)
returns jsonb
language sql
security invoker
set search_path=''
as $$
  select public_lookup_private.warranty_public_lookup_impl(p_token);
$$;

revoke execute on function public.warranty_public_lookup(text) from public;
grant execute on function public.warranty_public_lookup(text) to anon,authenticated,service_role;
