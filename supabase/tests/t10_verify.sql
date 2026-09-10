\set ON_ERROR_STOP on
begin;

-- ------------------------------------------------------------------
-- T10 schema / security contract
-- ------------------------------------------------------------------
do $$
declare
  v_tables integer;
  v_settings integer;
  v_direct boolean;
begin
  select count(*) into v_tables
  from information_schema.tables
  where table_schema='public'
    and table_name in ('notifications','notification_logs');
  if v_tables<>2 then
    raise exception 'T10 notification table count expected 2, got %',v_tables;
  end if;

  if not exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='reminder_rules'
      and column_name='staff_channels' and data_type='ARRAY'
  ) then raise exception 'reminder_rules.staff_channels missing'; end if;

  if not exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='reminder_rules'
      and column_name='customer_channels' and data_type='ARRAY'
  ) then raise exception 'reminder_rules.customer_channels missing'; end if;

  select count(*) into v_settings
  from public.settings
  where key in (
    'notification.in_app',
    'notification.telegram.config','notification.telegram.token',
    'notification.email.config','notification.email.token',
    'notification.zalo.config','notification.zalo.token'
  );
  if v_settings<>7 then
    raise exception 'Expected 7 notification settings, got %',v_settings;
  end if;

  if exists(
    select 1 from public.settings
    where key in (
      'notification.telegram.token',
      'notification.email.token',
      'notification.zalo.token'
    ) and value is not null
  ) then raise exception 'Sensitive notification token setting contains plaintext value'; end if;

  if exists(
    select 1 from public.settings
    where key in (
      'notification.telegram.token',
      'notification.email.token',
      'notification.zalo.token'
    ) and (secret_ref is null or secret_ref !~ '^[A-Za-z][A-Za-z0-9+.-]*://.+')
  ) then raise exception 'Notification token setting missing external secret_ref'; end if;

  select has_table_privilege('authenticated','public.notifications','INSERT') into v_direct;
  if v_direct then raise exception 'authenticated must not INSERT notifications directly'; end if;
  select has_table_privilege('authenticated','public.notifications','UPDATE') into v_direct;
  if v_direct then raise exception 'authenticated must not UPDATE notifications directly'; end if;
  select has_table_privilege('authenticated','public.notification_logs','INSERT') into v_direct;
  if v_direct then raise exception 'authenticated must not INSERT notification_logs directly'; end if;
  select has_table_privilege('authenticated','public.notification_logs','UPDATE') into v_direct;
  if v_direct then raise exception 'authenticated must not UPDATE notification_logs directly'; end if;

  -- Worker must use RPC outbox, not arbitrary direct table reads.
  if has_table_privilege('service_role','public.notifications','SELECT') then
    raise exception 'service_role unexpectedly has direct notifications SELECT';
  end if;

  if not has_function_privilege(
    'service_role',
    'public.notification_claim_batch(text,integer,timestamptz)',
    'EXECUTE'
  ) then raise exception 'service_role missing notification_claim_batch EXECUTE'; end if;

  if has_function_privilege(
    'authenticated',
    'public.notification_claim_batch(text,integer,timestamptz)',
    'EXECUTE'
  ) then raise exception 'authenticated unexpectedly can claim dispatch batch'; end if;
end $$;

-- ------------------------------------------------------------------
-- Deterministic test identities/data.
-- Everything rolls back at the end.
-- ------------------------------------------------------------------
update public.profiles set is_active=false;

insert into auth.users(id,email,raw_user_meta_data) values
('a0101010-1010-4010-8010-101010101010','t10-admin@example.invalid','{}'::jsonb),
('a0202020-2020-4020-8020-202020202020','t10-sales@example.invalid','{}'::jsonb);

update public.profiles
set role_id=(select id from public.roles where code='admin'),
    is_active=true,full_name='T10 Admin'
where id='a0101010-1010-4010-8010-101010101010';

update public.profiles
set role_id=(select id from public.roles where code='sales'),
    is_active=true,full_name='T10 Sales'
where id='a0202020-2020-4020-8020-202020202020';

insert into public.customers(
  id,customer_code,full_name,phone,phone_normalized,email,zalo,status
) values(
  'a0303030-3030-4030-8030-303030303030',
  'CUS-101010','T10 Customer',
  '0912345678','0912345678',
  't10.customer@example.invalid',
  'zalo_uid_t10','ACTIVE'
);

insert into public.reminder_rules(
  id,rule_code,name,event_type,offset_minutes,priority,is_active,is_system,
  staff_channels,customer_channels
) values(
  'a0404040-4040-4040-8040-404040404040',
  'T10_TEST','T10 test notification','WARRANTY_END',
  0,'HIGH',true,false,
  array['IN_APP','TELEGRAM']::text[],
  array['EMAIL','ZALO']::text[]
);

insert into public.reminders(
  id,reminder_code,rule_id,rule_code_snapshot,event_type,
  source_type,source_id,source_label,customer_id,due_at,
  priority,status,title,message,dedupe_key
) values(
  'a0505050-5050-4050-8050-505050505050',
  'REM-101010',
  'a0404040-4040-4040-8040-404040404040',
  'T10_TEST','WARRANTY_END',
  'WARRANTY','a0606060-6060-4060-8060-606060606060','WAR-T10',
  'a0303030-3030-4030-8030-303030303030',
  now()-interval '1 minute',
  'HIGH','DUE','T10 Due','T10 body','T10:one'
);

-- ------------------------------------------------------------------
-- Admin config: all four channels + secret references only.
-- ------------------------------------------------------------------
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a0101010-1010-4010-8010-101010101010',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"a0101010-1010-4010-8010-101010101010","role":"authenticated"}',
  true
);

select public.notification_channel_configure(
  'IN_APP',true,'{}'::jsonb,null
);

select public.notification_channel_configure(
  'TELEGRAM',true,
  jsonb_build_object(
    'recipients',
      jsonb_build_array(
        jsonb_build_object(
          'profile_id','a0101010-1010-4010-8010-101010101010',
          'chat_id','100001'
        )
      ),
    'parse_mode','HTML'
  ),
  'env://TELEGRAM_BOT_TOKEN'
);

select public.notification_channel_configure(
  'EMAIL',true,
  jsonb_build_object(
    'provider','HTTP',
    'from','support@hometechvn.invalid'
  ),
  'env://EMAIL_API_KEY'
);

select public.notification_channel_configure(
  'ZALO',true,
  jsonb_build_object(
    'mode','ZBS_PHONE',
    'template_map',jsonb_build_object('T10_TEST','tpl_t10')
  ),
  'env://ZALO_ACCESS_TOKEN'
);

do $$
begin
  begin
    perform public.notification_channel_configure(
      'ZALO',
      true,
      jsonb_build_object(
        'mode','ZBS_PHONE',
        'access_token','plaintext-must-be-rejected'
      ),
      'env://ZALO_ACCESS_TOKEN'
    );
    raise exception 'Sensitive config key unexpectedly accepted';
  exception when others then
    if sqlerrm='Sensitive config key unexpectedly accepted' then raise; end if;
    if position('Sensitive key is not allowed' in sqlerrm)=0 then raise; end if;
  end;
end $$;

select public.notification_prepare(now());

do $$
begin
  -- Admin + Sales IN_APP, plus Telegram + Email + Zalo = 5.
  if (
    select count(*) from public.notifications
    where reminder_id='a0505050-5050-4050-8050-505050505050'
  )<>5 then raise exception 'Expected 5 prepared notifications'; end if;

  if (
    select count(*) from public.notifications
    where reminder_id='a0505050-5050-4050-8050-505050505050'
      and channel='IN_APP'
  )<>2 then raise exception 'Expected two IN_APP recipients'; end if;

  if (
    select recipient_address from public.notifications
    where reminder_id='a0505050-5050-4050-8050-505050505050'
      and channel='ZALO'
  )<>'0912345678' then
    raise exception 'ZBS phone destination mismatch';
  end if;

  if (
    select provider from public.notifications
    where reminder_id='a0505050-5050-4050-8050-505050505050'
      and channel='ZALO'
  )<>'ZALO_ZBS_PHONE' then
    raise exception 'ZBS provider mismatch';
  end if;

  if exists(
    select 1 from public.notifications
    where notification_code !~ '^NTF-[0-9]{6}$'
  ) then raise exception 'Invalid NTF code'; end if;

  if (
    select count(*) from public.notifications
  ) <> (
    select count(distinct delivery_key) from public.notifications
  ) then raise exception 'delivery_key dedupe failure'; end if;
end $$;

-- Prepare rerun is idempotent.
select public.notification_prepare(now());

do $$
begin
  if (
    select count(*) from public.notifications
    where reminder_id='a0505050-5050-4050-8050-505050505050'
  )<>5 then raise exception 'Prepare duplicated notifications'; end if;
end $$;

-- ------------------------------------------------------------------
-- Sales RLS: only own IN_APP; logs hidden; mark read allowed.
-- ------------------------------------------------------------------
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a0202020-2020-4020-8020-202020202020',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"a0202020-2020-4020-8020-202020202020","role":"authenticated"}',
  true
);

do $$
begin
  if (select count(*) from public.notifications)<>1 then
    raise exception 'Sales RLS should expose exactly one own IN_APP notification';
  end if;
  if (select count(*) from public.notification_logs)<>0 then
    raise exception 'Sales should not see notification logs';
  end if;
end $$;

select public.notification_mark_read(
  (select id from public.notifications limit 1)
);

do $$
begin
  if not (select read_at is not null from public.notifications limit 1) then
    raise exception 'IN_APP mark_read failed';
  end if;

  begin
    perform public.notification_channel_configure(
      'EMAIL',false,'{}'::jsonb,null
    );
    raise exception 'Sales unexpectedly configured channels';
  exception when others then
    if sqlerrm='Sales unexpectedly configured channels' then raise; end if;
    if position('settings.manage' in sqlerrm)=0 then raise; end if;
  end;
end $$;

-- ------------------------------------------------------------------
-- Worker path:
-- Telegram sent.
-- Zalo ZBS sent.
-- Email fails once then retries and sends on attempt 2.
-- ------------------------------------------------------------------
reset role;
set local role service_role;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{"role":"service_role"}',true);

with claimed as (
  select * from public.notification_claim_batch(
    'TELEGRAM',10,now()+interval '1 minute'
  )
)
select public.notification_mark_sent(
  id,'tg-msg-1',jsonb_build_object('ok',true)
)
from claimed;

with claimed as (
  select * from public.notification_claim_batch(
    'ZALO',10,now()+interval '1 minute'
  )
)
select public.notification_mark_sent(
  id,'zalo-zbs-msg-1',jsonb_build_object('ok',true)
)
from claimed;

with claimed as (
  select * from public.notification_claim_batch(
    'EMAIL',10,now()+interval '1 minute'
  )
)
select public.notification_mark_failed(
  id,'HTTP_503','temporary',
  jsonb_build_object('status',503),
  1
)
from claimed;

with claimed as (
  select * from public.notification_claim_batch(
    'EMAIL',10,now()+interval '2 minute'
  )
)
select public.notification_mark_sent(
  id,'email-msg-1',jsonb_build_object('status',200)
)
from claimed;

-- ------------------------------------------------------------------
-- Switch Zalo to OA UID and verify second reminder route.
-- ------------------------------------------------------------------
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a0101010-1010-4010-8010-101010101010',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"a0101010-1010-4010-8010-101010101010","role":"authenticated"}',
  true
);

select public.notification_rule_configure(
  'a0404040-4040-4040-8040-404040404040',
  array[]::text[],
  array['ZALO']::text[]
);

select public.notification_channel_configure(
  'ZALO',true,
  jsonb_build_object(
    'mode','OA_UID',
    'template_map','{}'::jsonb
  ),
  'env://ZALO_ACCESS_TOKEN'
);

reset role;

insert into public.reminders(
  id,reminder_code,rule_id,rule_code_snapshot,event_type,
  source_type,source_id,source_label,customer_id,due_at,
  priority,status,title,message,dedupe_key
) values(
  'a0707070-7070-4070-8070-707070707070',
  'REM-101011',
  'a0404040-4040-4040-8040-404040404040',
  'T10_TEST','WARRANTY_END',
  'WARRANTY','a0808080-8080-4080-8080-808080808080','WAR-T10-2',
  'a0303030-3030-4030-8030-303030303030',
  now()-interval '1 minute',
  'HIGH','DUE','T10 OA','T10 OA body','T10:two'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a0101010-1010-4010-8010-101010101010',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"a0101010-1010-4010-8010-101010101010","role":"authenticated"}',
  true
);

select public.notification_prepare(now());

do $$
begin
  if (
    select count(*) from public.notifications
    where reminder_id='a0707070-7070-4070-8070-707070707070'
  )<>1 then raise exception 'OA_UID expected one Zalo notification'; end if;

  if (
    select recipient_address from public.notifications
    where reminder_id='a0707070-7070-4070-8070-707070707070'
  )<>'zalo_uid_t10' then raise exception 'OA UID destination mismatch'; end if;

  if (
    select provider from public.notifications
    where reminder_id='a0707070-7070-4070-8070-707070707070'
  )<>'ZALO_OA_UID' then raise exception 'OA UID provider mismatch'; end if;
end $$;

reset role;
set local role service_role;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{"role":"service_role"}',true);

with claimed as (
  select * from public.notification_claim_batch(
    'ZALO',10,now()+interval '1 minute'
  )
)
select public.notification_mark_sent(
  id,'zalo-oa-msg-1',jsonb_build_object('ok',true)
)
from claimed;

-- ------------------------------------------------------------------
-- Final assertions as postgres.
-- ------------------------------------------------------------------
reset role;

do $$
begin
  if (
    select status from public.notifications
    where channel='TELEGRAM'
      and reminder_id='a0505050-5050-4050-8050-505050505050'
  )<>'SENT' then raise exception 'Telegram did not reach SENT'; end if;

  if (
    select status from public.notifications
    where channel='EMAIL'
      and reminder_id='a0505050-5050-4050-8050-505050505050'
  )<>'SENT' then raise exception 'Email did not reach SENT after retry'; end if;

  if (
    select attempt_count from public.notifications
    where channel='EMAIL'
      and reminder_id='a0505050-5050-4050-8050-505050505050'
  )<>2 then raise exception 'Email attempt_count expected 2'; end if;

  if (
    select count(*)
    from public.notification_logs l
    join public.notifications n on n.id=l.notification_id
    where n.channel='EMAIL'
      and n.reminder_id='a0505050-5050-4050-8050-505050505050'
  )<>2 then raise exception 'Email logs expected two attempts'; end if;

  if (
    select count(*)
    from public.notification_logs l
    join public.notifications n on n.id=l.notification_id
    where n.channel='EMAIL'
      and n.reminder_id='a0505050-5050-4050-8050-505050505050'
      and l.status='SENT'
  )<>1 then raise exception 'Email final SENT log missing'; end if;

  if (
    select status from public.notifications
    where reminder_id='a0707070-7070-4070-8070-707070707070'
  )<>'SENT' then raise exception 'Zalo OA UID did not reach SENT'; end if;

  if exists(
    select 1 from public.settings
    where key like 'notification.%.token'
      and value is not null
  ) then raise exception 'Sensitive notification setting contains plaintext value'; end if;

  if exists(
    select 1 from public.settings
    where key like 'notification.%.token'
      and secret_ref not like 'env://%'
  ) then raise exception 'Notification token secret_ref is not env://'; end if;
end $$;

select
  (select count(*) from public.notifications) as notifications,
  (select count(*) from public.notifications where channel='IN_APP') as in_app,
  (select count(*) from public.notifications where channel='TELEGRAM') as telegram,
  (select count(*) from public.notifications where channel='EMAIL') as email,
  (select count(*) from public.notifications where channel='ZALO') as zalo,
  (select count(*) from public.notification_logs) as attempt_logs,
  (select attempt_count from public.notifications
   where channel='EMAIL'
     and reminder_id='a0505050-5050-4050-8050-505050505050') as email_attempts;

do $$ begin
  raise notice 'T10 FINAL CORE CHECKS: PASS';
end $$;

rollback;
