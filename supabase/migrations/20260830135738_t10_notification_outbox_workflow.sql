create or replace function private.notification_setting_value(p_key text)
returns jsonb language sql stable security definer set search_path='' as $$
  select s.value from public.settings s where s.key=p_key;
$$;
revoke execute on function private.notification_setting_value(text) from public,anon,authenticated;

create or replace function private.notification_rule_configure_impl(p_rule_id uuid,p_staff_channels text[],p_customer_channels text[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.reminder_rules%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('notification.manage') then raise exception 'Missing permission notification.manage'; end if;
  if not (coalesce(p_staff_channels,array[]::text[]) <@ array['IN_APP','TELEGRAM']::text[]) then raise exception 'Invalid staff channel'; end if;
  if not (coalesce(p_customer_channels,array[]::text[]) <@ array['EMAIL','ZALO']::text[]) then raise exception 'Invalid customer channel'; end if;
  update public.reminder_rules set staff_channels=coalesce(p_staff_channels,array[]::text[]),customer_channels=coalesce(p_customer_channels,array[]::text[]),updated_by=v_uid,updated_at=now()
  where id=p_rule_id returning * into v_row;
  if not found then raise exception 'Reminder rule not found'; end if;
  return to_jsonb(v_row);
end; $$;

create or replace function private.notification_channel_configure_impl(p_channel text,p_enabled boolean,p_config jsonb,p_secret_ref text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_key text; v_secret_key text; v_cfg jsonb:=coalesce(p_config,'{}'::jsonb);
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('notification.manage') or not private.has_permission('settings.manage') then raise exception 'Missing permission settings.manage'; end if;
  if jsonb_typeof(v_cfg)<>'object' then raise exception 'Channel config must be a JSON object'; end if;
  case p_channel
    when 'IN_APP' then v_key:='notification.in_app'; v_secret_key:=null;
    when 'TELEGRAM' then v_key:='notification.telegram.config'; v_secret_key:='notification.telegram.token';
    when 'EMAIL' then v_key:='notification.email.config'; v_secret_key:='notification.email.token';
    when 'ZALO' then v_key:='notification.zalo.config'; v_secret_key:='notification.zalo.token';
    else raise exception 'Unsupported notification channel';
  end case;
  if p_channel='TELEGRAM' and coalesce(jsonb_typeof(v_cfg->'recipients'),'array')<>'array' then raise exception 'Telegram recipients must be an array'; end if;
  if p_channel='ZALO' and coalesce(v_cfg->>'mode','ZBS_PHONE') not in ('ZBS_PHONE','OA_UID') then raise exception 'Invalid Zalo mode'; end if;
  if p_channel='ZALO' and coalesce(jsonb_typeof(v_cfg->'template_map'),'object')<>'object' then raise exception 'Zalo template_map must be an object'; end if;
  if p_secret_ref is not null and btrim(p_secret_ref)<>'' and btrim(p_secret_ref) !~ '^[A-Za-z][A-Za-z0-9+.-]*://.+' then raise exception 'secret_ref must be an external secret reference URI'; end if;
  update public.settings set value=v_cfg||jsonb_build_object('enabled',coalesce(p_enabled,false)),updated_by=v_uid,updated_at=now() where key=v_key;
  if not found then raise exception 'Notification setting not found: %',v_key; end if;
  if v_secret_key is not null and p_secret_ref is not null and btrim(p_secret_ref)<>'' then
    update public.settings set secret_ref=btrim(p_secret_ref),updated_by=v_uid,updated_at=now() where key=v_secret_key;
  end if;
  return jsonb_build_object('channel',p_channel,'enabled',coalesce(p_enabled,false),'config_key',v_key,'secret_key',v_secret_key);
end; $$;

create or replace function private.notification_prepare_impl(p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid(); v_role text:=coalesce(auth.jwt()->>'role','');
  v_inapp jsonb:=coalesce(private.notification_setting_value('notification.in_app'),'{}'::jsonb);
  v_tg jsonb:=coalesce(private.notification_setting_value('notification.telegram.config'),'{}'::jsonb);
  v_email jsonb:=coalesce(private.notification_setting_value('notification.email.config'),'{}'::jsonb);
  v_zalo jsonb:=coalesce(private.notification_setting_value('notification.zalo.config'),'{}'::jsonb);
  v_rem record; v_prof record; v_dest record; v_customer public.customers%rowtype;
  v_template text; v_mode text; v_address text; v_prepared integer:=0; v_cancelled integer:=0;
begin
  if v_role<>'service_role' then
    if v_uid is null then raise exception 'Authentication required'; end if;
    if not private.has_permission('notification.manage') then raise exception 'Missing permission notification.manage'; end if;
  end if;
  if p_now is null then p_now:=now(); end if;
  if not pg_try_advisory_xact_lock(hashtext('hometechvn.notification_prepare')) then raise exception 'Notification preparation already running'; end if;
  update public.notifications n set status='CANCELLED',last_error_code='REMINDER_CLOSED',last_error_message='Reminder is no longer DUE',updated_at=now()
  from public.reminders r where r.id=n.reminder_id and r.status<>'DUE' and n.status in ('PENDING','RETRYING');
  get diagnostics v_cancelled=row_count;
  for v_rem in select r.*,rr.staff_channels,rr.customer_channels from public.reminders r join public.reminder_rules rr on rr.id=r.rule_id where r.status='DUE' and rr.is_active
  loop
    if 'IN_APP'=any(v_rem.staff_channels) and coalesce((v_inapp->>'enabled')::boolean,false) then
      for v_prof in
        select distinct p.id from public.profiles p join public.roles ro on ro.id=p.role_id join public.role_permissions rp on rp.role_id=ro.id join public.permissions pm on pm.id=rp.permission_id and pm.code='notification.view' where p.is_active=true
      loop
        insert into public.notifications(notification_code,reminder_id,channel,provider,audience,recipient_profile_id,subject,body,payload,status,scheduled_at,next_attempt_at,sent_at,delivery_key)
        values(private.next_simple_code('NOTIFICATION','NTF',6),v_rem.id,'IN_APP','IN_APP','STAFF',v_prof.id,v_rem.title,v_rem.message,jsonb_build_object('reminder_code',v_rem.reminder_code,'rule_code',v_rem.rule_code_snapshot,'event_type',v_rem.event_type,'metadata',v_rem.metadata),'SENT',p_now,p_now,p_now,format('%s:IN_APP:%s',v_rem.id,v_prof.id))
        on conflict(delivery_key) do nothing;
        if found then v_prepared:=v_prepared+1; end if;
      end loop;
    end if;
    if 'TELEGRAM'=any(v_rem.staff_channels) and coalesce((v_tg->>'enabled')::boolean,false) then
      for v_dest in
        select p.id as profile_id,x->>'chat_id' as chat_id
        from jsonb_array_elements(coalesce(v_tg->'recipients','[]'::jsonb)) x
        join public.profiles p on (x->>'profile_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' and p.id=(x->>'profile_id')::uuid and p.is_active=true
        join public.roles ro on ro.id=p.role_id join public.role_permissions rp on rp.role_id=ro.id join public.permissions pm on pm.id=rp.permission_id and pm.code='notification.view'
        where nullif(btrim(x->>'chat_id'),'') is not null
      loop
        insert into public.notifications(notification_code,reminder_id,channel,provider,audience,recipient_profile_id,recipient_address,subject,body,payload,status,scheduled_at,next_attempt_at,delivery_key)
        values(private.next_simple_code('NOTIFICATION','NTF',6),v_rem.id,'TELEGRAM','TELEGRAM_BOT','STAFF',v_dest.profile_id,v_dest.chat_id,v_rem.title,v_rem.message,jsonb_build_object('reminder_code',v_rem.reminder_code,'rule_code',v_rem.rule_code_snapshot,'event_type',v_rem.event_type,'parse_mode',coalesce(v_tg->>'parse_mode','HTML'),'metadata',v_rem.metadata),'PENDING',p_now,p_now,format('%s:TELEGRAM:%s',v_rem.id,v_dest.profile_id))
        on conflict(delivery_key) do nothing;
        if found then v_prepared:=v_prepared+1; end if;
      end loop;
    end if;
    if v_rem.customer_id is not null then
      select * into v_customer from public.customers where id=v_rem.customer_id;
      if found then
        if 'EMAIL'=any(v_rem.customer_channels) and coalesce((v_email->>'enabled')::boolean,false) and nullif(btrim(v_customer.email),'') is not null then
          insert into public.notifications(notification_code,reminder_id,channel,provider,audience,recipient_customer_id,recipient_address,template_key,subject,body,payload,status,scheduled_at,next_attempt_at,delivery_key)
          values(private.next_simple_code('NOTIFICATION','NTF',6),v_rem.id,'EMAIL',coalesce(v_email->>'provider','HTTP'),'CUSTOMER',v_customer.id,btrim(v_customer.email),v_rem.rule_code_snapshot,v_rem.title,v_rem.message,jsonb_build_object('reminder_code',v_rem.reminder_code,'rule_code',v_rem.rule_code_snapshot,'event_type',v_rem.event_type,'customer_name',v_customer.full_name,'metadata',v_rem.metadata),'PENDING',p_now,p_now,format('%s:EMAIL:%s',v_rem.id,v_customer.id))
          on conflict(delivery_key) do nothing;
          if found then v_prepared:=v_prepared+1; end if;
        end if;
        if 'ZALO'=any(v_rem.customer_channels) and coalesce((v_zalo->>'enabled')::boolean,false) then
          v_mode:=coalesce(v_zalo->>'mode','ZBS_PHONE');
          v_template:=coalesce(v_zalo->'template_map'->>v_rem.rule_code_snapshot,v_zalo->'template_map'->>v_rem.event_type);
          v_address:=case when v_mode='OA_UID' then nullif(btrim(v_customer.zalo),'') else coalesce(nullif(btrim(v_customer.phone_normalized),''),nullif(btrim(v_customer.phone),'')) end;
          if v_address is not null and (v_mode='OA_UID' or v_template is not null) then
            insert into public.notifications(notification_code,reminder_id,channel,provider,audience,recipient_customer_id,recipient_address,template_key,subject,body,payload,status,scheduled_at,next_attempt_at,delivery_key)
            values(private.next_simple_code('NOTIFICATION','NTF',6),v_rem.id,'ZALO',case when v_mode='OA_UID' then 'ZALO_OA_UID' else 'ZALO_ZBS_PHONE' end,'CUSTOMER',v_customer.id,v_address,v_template,v_rem.title,v_rem.message,jsonb_build_object('mode',v_mode,'reminder_code',v_rem.reminder_code,'rule_code',v_rem.rule_code_snapshot,'event_type',v_rem.event_type,'customer_name',v_customer.full_name,'template_data',v_rem.metadata),'PENDING',p_now,p_now,format('%s:ZALO:%s',v_rem.id,v_customer.id))
            on conflict(delivery_key) do nothing;
            if found then v_prepared:=v_prepared+1; end if;
          end if;
        end if;
      end if;
    end if;
  end loop;
  return jsonb_build_object('prepared',v_prepared,'cancelled',v_cancelled,'evaluated_at',p_now);
end; $$;

create or replace function private.notification_claim_batch_impl(p_channel text,p_limit integer default 20,p_now timestamptz default now())
returns setof public.notifications language plpgsql security definer set search_path='' as $$
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'service_role required'; end if;
  if p_channel not in ('TELEGRAM','EMAIL','ZALO') then raise exception 'Unsupported dispatch channel'; end if;
  if p_limit is null or p_limit<1 or p_limit>100 then raise exception 'Invalid batch limit'; end if;
  if p_now is null then p_now:=now(); end if;
  return query with picked as (
    select n.id from public.notifications n where n.channel=p_channel and n.status in ('PENDING','RETRYING') and n.next_attempt_at<=p_now order by n.next_attempt_at,n.created_at for update skip locked limit p_limit
  ), upd as (
    update public.notifications n set status='PROCESSING',attempt_count=n.attempt_count+1,last_attempt_at=p_now,updated_at=now() from picked p where n.id=p.id returning n.*
  ), logs as (
    insert into public.notification_logs(notification_id,attempt_no,channel,provider,status,request_meta,started_at)
    select u.id,u.attempt_count,u.channel,u.provider,'PROCESSING',jsonb_build_object('delivery_key',u.delivery_key,'template_key',u.template_key),p_now from upd u
    on conflict(notification_id,attempt_no) do update set status='PROCESSING',started_at=excluded.started_at,error_code=null,error_message=null,response_meta='{}'::jsonb,finished_at=null returning notification_id
  ) select u.* from upd u join logs l on l.notification_id=u.id;
end; $$;

create or replace function private.notification_mark_sent_impl(p_notification_id uuid,p_external_message_id text default null,p_response_meta jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_row public.notifications%rowtype;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'service_role required'; end if;
  if jsonb_typeof(coalesce(p_response_meta,'{}'::jsonb))<>'object' then raise exception 'response_meta must be object'; end if;
  select * into v_row from public.notifications where id=p_notification_id for update;
  if not found then raise exception 'Notification not found'; end if;
  if v_row.status<>'PROCESSING' then raise exception 'Notification is not PROCESSING'; end if;
  update public.notifications set status='SENT',sent_at=now(),external_message_id=nullif(btrim(p_external_message_id),''),last_error_code=null,last_error_message=null,updated_at=now() where id=p_notification_id returning * into v_row;
  update public.notification_logs set status='SENT',response_meta=coalesce(p_response_meta,'{}'::jsonb),external_message_id=v_row.external_message_id,error_code=null,error_message=null,finished_at=now() where notification_id=v_row.id and attempt_no=v_row.attempt_count;
  return to_jsonb(v_row);
end; $$;

create or replace function private.notification_mark_failed_impl(p_notification_id uuid,p_error_code text,p_error_message text,p_response_meta jsonb default '{}'::jsonb,p_retry_after_seconds integer default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_row public.notifications%rowtype; v_retry boolean; v_delay integer;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'service_role required'; end if;
  if jsonb_typeof(coalesce(p_response_meta,'{}'::jsonb))<>'object' then raise exception 'response_meta must be object'; end if;
  select * into v_row from public.notifications where id=p_notification_id for update;
  if not found then raise exception 'Notification not found'; end if;
  if v_row.status<>'PROCESSING' then raise exception 'Notification is not PROCESSING'; end if;
  v_retry:=v_row.attempt_count<v_row.max_attempts;
  v_delay:=coalesce(p_retry_after_seconds,least(3600,30*(2^greatest(v_row.attempt_count-1,0))::integer));
  update public.notifications set status=case when v_retry then 'RETRYING' else 'FAILED' end,next_attempt_at=case when v_retry then now()+make_interval(secs=>greatest(v_delay,1)) else next_attempt_at end,last_error_code=nullif(btrim(p_error_code),''),last_error_message=left(coalesce(p_error_message,''),2000),updated_at=now() where id=p_notification_id returning * into v_row;
  update public.notification_logs set status=case when v_retry then 'RETRYING' else 'FAILED' end,response_meta=coalesce(p_response_meta,'{}'::jsonb),error_code=v_row.last_error_code,error_message=v_row.last_error_message,finished_at=now() where notification_id=v_row.id and attempt_no=v_row.attempt_count;
  return to_jsonb(v_row);
end; $$;

create or replace function private.notification_requeue_stale_impl(p_older_than_minutes integer default 10)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text:=coalesce(auth.jwt()->>'role',''); v_uid uuid:=auth.uid(); v_count integer;
begin
  if v_role<>'service_role' then if v_uid is null then raise exception 'Authentication required'; end if; if not private.has_permission('notification.manage') then raise exception 'Missing permission notification.manage'; end if; end if;
  if p_older_than_minutes is null or p_older_than_minutes<1 or p_older_than_minutes>1440 then raise exception 'Invalid stale threshold'; end if;
  with stale as (
    update public.notifications n set status=case when n.attempt_count<n.max_attempts then 'RETRYING' else 'FAILED' end,next_attempt_at=case when n.attempt_count<n.max_attempts then now() else n.next_attempt_at end,last_error_code='WORKER_TIMEOUT',last_error_message='Dispatch claim became stale',updated_at=now()
    where n.status='PROCESSING' and n.last_attempt_at<now()-make_interval(mins=>p_older_than_minutes) returning n.id,n.attempt_count,n.status,n.last_error_code,n.last_error_message
  ) update public.notification_logs l set status=case when s.status='RETRYING' then 'RETRYING' else 'FAILED' end,error_code=s.last_error_code,error_message=s.last_error_message,finished_at=now() from stale s where l.notification_id=s.id and l.attempt_no=s.attempt_count;
  get diagnostics v_count=row_count;
  return jsonb_build_object('requeued_or_failed',v_count);
end; $$;

create or replace function private.notification_mark_read_impl(p_notification_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.notifications%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('notification.view') and not private.has_permission('notification.manage') then raise exception 'Missing permission notification.view'; end if;
  update public.notifications set read_at=coalesce(read_at,now()),updated_at=now() where id=p_notification_id and channel='IN_APP' and recipient_profile_id=v_uid returning * into v_row;
  if not found then raise exception 'In-app notification not found for current user'; end if;
  return to_jsonb(v_row);
end; $$;

create or replace function private.notification_mark_all_read_impl()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_count integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('notification.view') and not private.has_permission('notification.manage') then raise exception 'Missing permission notification.view'; end if;
  update public.notifications set read_at=now(),updated_at=now() where channel='IN_APP' and recipient_profile_id=v_uid and read_at is null;
  get diagnostics v_count=row_count;
  return jsonb_build_object('marked_read',v_count);
end; $$;

create or replace function private.notification_retry_impl(p_notification_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.notifications%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('notification.manage') then raise exception 'Missing permission notification.manage'; end if;
  update public.notifications set status='RETRYING',next_attempt_at=now(),last_error_code=null,last_error_message=null,updated_at=now() where id=p_notification_id and channel<>'IN_APP' and status='FAILED' returning * into v_row;
  if not found then raise exception 'FAILED external notification not found'; end if;
  return to_jsonb(v_row);
end; $$;

create or replace function private.notification_cancel_impl(p_notification_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.notifications%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('notification.manage') then raise exception 'Missing permission notification.manage'; end if;
  if nullif(btrim(p_reason),'') is null then raise exception 'Cancellation reason is required'; end if;
  update public.notifications set status='CANCELLED',last_error_code='MANUAL_CANCEL',last_error_message=left(btrim(p_reason),2000),updated_at=now() where id=p_notification_id and status not in ('SENT','CANCELLED') returning * into v_row;
  if not found then raise exception 'Notification cannot be cancelled'; end if;
  return to_jsonb(v_row);
end; $$;

create or replace function public.notification_rule_configure(p_rule_id uuid,p_staff_channels text[],p_customer_channels text[]) returns jsonb language sql set search_path='' as $$ select private.notification_rule_configure_impl(p_rule_id,p_staff_channels,p_customer_channels); $$;
create or replace function public.notification_channel_configure(p_channel text,p_enabled boolean,p_config jsonb,p_secret_ref text default null) returns jsonb language sql set search_path='' as $$ select private.notification_channel_configure_impl(p_channel,p_enabled,p_config,p_secret_ref); $$;
create or replace function public.notification_prepare(p_now timestamptz default now()) returns jsonb language sql set search_path='' as $$ select private.notification_prepare_impl(p_now); $$;
create or replace function public.notification_claim_batch(p_channel text,p_limit integer default 20,p_now timestamptz default now()) returns setof public.notifications language sql set search_path='' as $$ select * from private.notification_claim_batch_impl(p_channel,p_limit,p_now); $$;
create or replace function public.notification_mark_sent(p_notification_id uuid,p_external_message_id text default null,p_response_meta jsonb default '{}'::jsonb) returns jsonb language sql set search_path='' as $$ select private.notification_mark_sent_impl(p_notification_id,p_external_message_id,p_response_meta); $$;
create or replace function public.notification_mark_failed(p_notification_id uuid,p_error_code text,p_error_message text,p_response_meta jsonb default '{}'::jsonb,p_retry_after_seconds integer default null) returns jsonb language sql set search_path='' as $$ select private.notification_mark_failed_impl(p_notification_id,p_error_code,p_error_message,p_response_meta,p_retry_after_seconds); $$;
create or replace function public.notification_requeue_stale(p_older_than_minutes integer default 10) returns jsonb language sql set search_path='' as $$ select private.notification_requeue_stale_impl(p_older_than_minutes); $$;
create or replace function public.notification_mark_read(p_notification_id uuid) returns jsonb language sql set search_path='' as $$ select private.notification_mark_read_impl(p_notification_id); $$;
create or replace function public.notification_mark_all_read() returns jsonb language sql set search_path='' as $$ select private.notification_mark_all_read_impl(); $$;
create or replace function public.notification_retry(p_notification_id uuid) returns jsonb language sql set search_path='' as $$ select private.notification_retry_impl(p_notification_id); $$;
create or replace function public.notification_cancel(p_notification_id uuid,p_reason text) returns jsonb language sql set search_path='' as $$ select private.notification_cancel_impl(p_notification_id,p_reason); $$;

revoke execute on function private.notification_rule_configure_impl(uuid,text[],text[]) from public,anon,authenticated;
revoke execute on function private.notification_channel_configure_impl(text,boolean,jsonb,text) from public,anon,authenticated;
revoke execute on function private.notification_prepare_impl(timestamptz) from public,anon,authenticated;
revoke execute on function private.notification_claim_batch_impl(text,integer,timestamptz) from public,anon,authenticated;
revoke execute on function private.notification_mark_sent_impl(uuid,text,jsonb) from public,anon,authenticated;
revoke execute on function private.notification_mark_failed_impl(uuid,text,text,jsonb,integer) from public,anon,authenticated;
revoke execute on function private.notification_requeue_stale_impl(integer) from public,anon,authenticated;
revoke execute on function private.notification_mark_read_impl(uuid) from public,anon,authenticated;
revoke execute on function private.notification_mark_all_read_impl() from public,anon,authenticated;
revoke execute on function private.notification_retry_impl(uuid) from public,anon,authenticated;
revoke execute on function private.notification_cancel_impl(uuid,text) from public,anon,authenticated;

grant execute on function private.notification_rule_configure_impl(uuid,text[],text[]) to authenticated;
grant execute on function private.notification_channel_configure_impl(text,boolean,jsonb,text) to authenticated;
grant execute on function private.notification_prepare_impl(timestamptz) to authenticated,service_role;
grant execute on function private.notification_claim_batch_impl(text,integer,timestamptz) to service_role;
grant execute on function private.notification_mark_sent_impl(uuid,text,jsonb) to service_role;
grant execute on function private.notification_mark_failed_impl(uuid,text,text,jsonb,integer) to service_role;
grant execute on function private.notification_requeue_stale_impl(integer) to authenticated,service_role;
grant execute on function private.notification_mark_read_impl(uuid) to authenticated;
grant execute on function private.notification_mark_all_read_impl() to authenticated;
grant execute on function private.notification_retry_impl(uuid) to authenticated;
grant execute on function private.notification_cancel_impl(uuid,text) to authenticated;

revoke execute on function public.notification_rule_configure(uuid,text[],text[]) from public,anon;
revoke execute on function public.notification_channel_configure(text,boolean,jsonb,text) from public,anon;
revoke execute on function public.notification_prepare(timestamptz) from public,anon;
revoke execute on function public.notification_claim_batch(text,integer,timestamptz) from public,anon,authenticated;
revoke execute on function public.notification_mark_sent(uuid,text,jsonb) from public,anon,authenticated;
revoke execute on function public.notification_mark_failed(uuid,text,text,jsonb,integer) from public,anon,authenticated;
revoke execute on function public.notification_requeue_stale(integer) from public,anon;
revoke execute on function public.notification_mark_read(uuid) from public,anon;
revoke execute on function public.notification_mark_all_read() from public,anon;
revoke execute on function public.notification_retry(uuid) from public,anon;
revoke execute on function public.notification_cancel(uuid,text) from public,anon;

grant execute on function public.notification_rule_configure(uuid,text[],text[]) to authenticated;
grant execute on function public.notification_channel_configure(text,boolean,jsonb,text) to authenticated;
grant execute on function public.notification_prepare(timestamptz) to authenticated,service_role;
grant execute on function public.notification_claim_batch(text,integer,timestamptz) to service_role;
grant execute on function public.notification_mark_sent(uuid,text,jsonb) to service_role;
grant execute on function public.notification_mark_failed(uuid,text,text,jsonb,integer) to service_role;
grant execute on function public.notification_requeue_stale(integer) to authenticated,service_role;
grant execute on function public.notification_mark_read(uuid) to authenticated;
grant execute on function public.notification_mark_all_read() to authenticated;
grant execute on function public.notification_retry(uuid) to authenticated;
grant execute on function public.notification_cancel(uuid,text) to authenticated;
