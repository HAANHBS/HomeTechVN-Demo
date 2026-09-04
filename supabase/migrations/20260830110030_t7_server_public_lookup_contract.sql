revoke execute on function private.warranty_public_payload_impl(text) from service_role;
grant select on public.warranties,public.warranty_claims,public.customers,public.customer_devices to service_role;
create or replace function public.warranty_public_lookup_server(p_token text)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v jsonb;
begin
  if p_token is null or length(p_token)<>64 or p_token !~ '^[0-9a-f]{64}$' then return jsonb_build_object('found',false); end if;
  select jsonb_build_object(
    'found',true,'warranty_code',w.warranty_code,
    'status',case when w.status='VOID' then 'VOID' when current_date>w.end_date then 'EXPIRED' else 'ACTIVE' end,
    'start_date',w.start_date,'end_date',w.end_date,'coverage',w.coverage,
    'product',coalesce(w.product_name_snapshot,nullif(concat_ws(' ',d.device_type,d.brand,d.model),'')),
    'serial_masked',case when nullif(btrim(coalesce(w.serial_snapshot,d.serial_number,'')),'') is null then null when length(btrim(coalesce(w.serial_snapshot,d.serial_number)))<=6 then '***' else left(btrim(coalesce(w.serial_snapshot,d.serial_number)),3)||'****'||right(btrim(coalesce(w.serial_snapshot,d.serial_number)),3) end,
    'phone_masked',case when nullif(regexp_replace(coalesce(c.phone,''),'\D','','g'),'') is null then null when length(regexp_replace(c.phone,'\D','','g'))<7 then '***' else left(regexp_replace(c.phone,'\D','','g'),3)||'***'||right(regexp_replace(c.phone,'\D','','g'),3) end,
    'latest_claim_status',(select cl.status from public.warranty_claims cl where cl.warranty_id=w.id order by cl.created_at desc limit 1)
  ) into v
  from public.warranties w join public.customers c on c.id=w.customer_id left join public.customer_devices d on d.id=w.customer_device_id
  where w.lookup_token=p_token;
  return coalesce(v,jsonb_build_object('found',false));
end; $$;
revoke execute on function public.warranty_public_lookup_server(text) from public,anon,authenticated;
grant execute on function public.warranty_public_lookup_server(text) to service_role;
