create or replace function private.notification_assert_safe_config(
  p_value jsonb,
  p_path text default '$'
)
returns void language plpgsql immutable set search_path='' as $$
declare
  v_key text;
  v_child jsonb;
  v_index integer:=0;
begin
  if p_value is null then return; end if;

  if jsonb_typeof(p_value)='object' then
    for v_key,v_child in
      select key,value from jsonb_each(p_value)
    loop
      if lower(v_key) ~ '(token|secret|password|passphrase|api[_-]?key|apikey|authorization|bearer)' then
        raise exception
          'Sensitive key is not allowed in notification config: %',
          p_path||'.'||v_key;
      end if;
      perform private.notification_assert_safe_config(
        v_child,
        p_path||'.'||v_key
      );
    end loop;
  elsif jsonb_typeof(p_value)='array' then
    for v_child in
      select value from jsonb_array_elements(p_value)
    loop
      perform private.notification_assert_safe_config(
        v_child,
        p_path||'['||v_index||']'
      );
      v_index:=v_index+1;
    end loop;
  end if;
end; $$;

revoke execute on function private.notification_assert_safe_config(jsonb,text)
from public,anon,authenticated;

create or replace function private.notification_channel_configure_impl(
  p_channel text,
  p_enabled boolean,
  p_config jsonb,
  p_secret_ref text default null
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid();
  v_key text;
  v_secret_key text;
  v_cfg jsonb:=coalesce(p_config,'{}'::jsonb);
begin
  if v_uid is null then raise exception 'Authentication required'; end if;

  if not private.has_permission('notification.manage')
     or not private.has_permission('settings.manage')
  then
    raise exception 'Missing permission settings.manage';
  end if;

  if jsonb_typeof(v_cfg)<>'object' then
    raise exception 'Channel config must be a JSON object';
  end if;

  perform private.notification_assert_safe_config(v_cfg,'$');

  case p_channel
    when 'IN_APP' then
      v_key:='notification.in_app';
      v_secret_key:=null;
    when 'TELEGRAM' then
      v_key:='notification.telegram.config';
      v_secret_key:='notification.telegram.token';
    when 'EMAIL' then
      v_key:='notification.email.config';
      v_secret_key:='notification.email.token';
    when 'ZALO' then
      v_key:='notification.zalo.config';
      v_secret_key:='notification.zalo.token';
    else
      raise exception 'Unsupported notification channel';
  end case;

  if p_channel='TELEGRAM'
     and coalesce(jsonb_typeof(v_cfg->'recipients'),'array')<>'array'
  then
    raise exception 'Telegram recipients must be an array';
  end if;

  if p_channel='ZALO'
     and coalesce(v_cfg->>'mode','ZBS_PHONE') not in ('ZBS_PHONE','OA_UID')
  then
    raise exception 'Invalid Zalo mode';
  end if;

  if p_channel='ZALO'
     and coalesce(jsonb_typeof(v_cfg->'template_map'),'object')<>'object'
  then
    raise exception 'Zalo template_map must be an object';
  end if;

  if p_secret_ref is not null
     and btrim(p_secret_ref)<>''
     and btrim(p_secret_ref) !~ '^[A-Za-z][A-Za-z0-9+.-]*://.+'
  then
    raise exception
      'secret_ref must be an external secret reference URI';
  end if;

  update public.settings
  set value=v_cfg||jsonb_build_object(
        'enabled',
        coalesce(p_enabled,false)
      ),
      updated_by=v_uid,
      updated_at=now()
  where key=v_key;

  if not found then
    raise exception 'Notification setting not found: %',v_key;
  end if;

  if v_secret_key is not null
     and p_secret_ref is not null
     and btrim(p_secret_ref)<>''
  then
    update public.settings
    set secret_ref=btrim(p_secret_ref),
        updated_by=v_uid,
        updated_at=now()
    where key=v_secret_key;
  end if;

  return jsonb_build_object(
    'channel',p_channel,
    'enabled',coalesce(p_enabled,false),
    'config_key',v_key,
    'secret_key',v_secret_key
  );
end; $$;
