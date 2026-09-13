-- T21.4 hardening: remove new SECURITY DEFINER RPC surface.

drop policy if exists settings_payment_qr_select on public.settings;
create policy settings_payment_qr_select
on public.settings
for select
to authenticated
using (
  key='payment.vietqr.config'
  and (select private.has_permission('payment.create'))
);

create or replace function public.payment_qr_config_get()
returns jsonb
language plpgsql
stable
security invoker
set search_path=''
as $$
declare
  v_config jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('payment.create')
     and not private.has_permission('settings.view')
  then
    raise exception 'Missing permission payment.create or settings.view';
  end if;

  select coalesce(s.value,'{}'::jsonb)
  into v_config
  from public.settings s
  where s.key='payment.vietqr.config'
    and s.is_sensitive=false;

  if not found then raise exception 'Payment QR configuration not found'; end if;
  return jsonb_build_object(
    'enabled',lower(coalesce(v_config->>'enabled','false'))='true',
    'bank_id',upper(btrim(coalesce(v_config->>'bank_id',''))),
    'account_no',upper(btrim(coalesce(v_config->>'account_no',''))),
    'account_name',btrim(coalesce(v_config->>'account_name','')),
    'template','compact2',
    'provider','VIETQR'
  );
end;
$$;

create or replace function public.payment_qr_configure(
  p_enabled boolean,
  p_bank_id text,
  p_account_no text,
  p_account_name text
)
returns jsonb
language plpgsql
security invoker
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_bank_id text:=upper(btrim(coalesce(p_bank_id,'')));
  v_account_no text:=upper(btrim(coalesce(p_account_no,'')));
  v_account_name text:=btrim(coalesce(p_account_name,''));
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('settings.manage') then
    raise exception 'Missing permission settings.manage';
  end if;

  if coalesce(p_enabled,false) then
    if v_bank_id !~ '^[A-Z0-9]{2,12}$' then
      raise exception 'Mã ngân hàng phải gồm 2-12 chữ hoặc số';
    end if;
    if v_account_no !~ '^[A-Z0-9]{4,24}$' then
      raise exception 'Số tài khoản phải gồm 4-24 chữ hoặc số';
    end if;
    if char_length(v_account_name)<2 or char_length(v_account_name)>100 then
      raise exception 'Tên người nhận phải gồm 2-100 ký tự';
    end if;
  end if;

  insert into public.settings(key,value,description,is_sensitive,secret_ref,updated_by)
  values (
    'payment.vietqr.config',
    jsonb_build_object(
      'enabled',coalesce(p_enabled,false),
      'bank_id',v_bank_id,
      'account_no',v_account_no,
      'account_name',v_account_name,
      'template','compact2'
    ),
    'VietQR receiving account used to prepare exact-balance payment QR codes',
    false,null,v_uid
  )
  on conflict (key) do update
  set value=excluded.value,
      description=excluded.description,
      is_sensitive=false,
      secret_ref=null,
      updated_by=v_uid,
      updated_at=now();

  return public.payment_qr_config_get();
end;
$$;

drop function if exists private.payment_qr_configure_impl(boolean,text,text,text);
drop function if exists private.payment_qr_config_get_impl();

revoke all on function public.payment_qr_config_get()
from public,anon,authenticated;
revoke all on function public.payment_qr_configure(boolean,text,text,text)
from public,anon,authenticated;
grant execute on function public.payment_qr_config_get() to authenticated;
grant execute on function public.payment_qr_configure(boolean,text,text,text) to authenticated;

