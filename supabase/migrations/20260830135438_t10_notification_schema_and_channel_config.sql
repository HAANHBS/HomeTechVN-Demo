alter table public.reminder_rules
  add column staff_channels text[] not null default array['IN_APP']::text[],
  add column customer_channels text[] not null default array[]::text[],
  add constraint reminder_rules_staff_channels_check check (staff_channels <@ array['IN_APP','TELEGRAM']::text[]),
  add constraint reminder_rules_customer_channels_check check (customer_channels <@ array['EMAIL','ZALO']::text[]);

update public.reminder_rules
set staff_channels=array['IN_APP','TELEGRAM']::text[],
    customer_channels=case
      when rule_code in ('WARRANTY_30D','WARRANTY_7D','LICENSE_30D','LICENSE_7D','MAINTENANCE_7D','REPAIR_READY','REPAIR_UNCOLLECTED_3D','REPAIR_UNCOLLECTED_7D')
        then array['EMAIL','ZALO']::text[]
      else array[]::text[]
    end
where is_system=true;

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  notification_code text not null default '',
  reminder_id uuid not null references public.reminders(id) on delete cascade,
  channel text not null check (channel in ('IN_APP','TELEGRAM','EMAIL','ZALO')),
  provider text not null,
  audience text not null check (audience in ('STAFF','CUSTOMER')),
  recipient_profile_id uuid references public.profiles(id) on delete set null,
  recipient_customer_id uuid references public.customers(id) on delete set null,
  recipient_address text,
  template_key text,
  subject text,
  body text not null check (length(btrim(body))>0),
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload)='object'),
  status text not null default 'PENDING' check (status in ('PENDING','PROCESSING','RETRYING','SENT','FAILED','CANCELLED')),
  scheduled_at timestamptz not null default now(),
  next_attempt_at timestamptz not null default now(),
  attempt_count integer not null default 0 check (attempt_count>=0),
  max_attempts integer not null default 5 check (max_attempts between 1 and 20),
  last_attempt_at timestamptz,
  sent_at timestamptz,
  read_at timestamptz,
  external_message_id text,
  last_error_code text,
  last_error_message text,
  delivery_key text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notifications_recipient_check check (
    (audience='STAFF' and recipient_profile_id is not null)
    or
    (audience='CUSTOMER' and recipient_customer_id is not null)
  ),
  constraint notifications_in_app_address_check check (
    channel<>'IN_APP' or (audience='STAFF' and recipient_profile_id is not null)
  ),
  constraint notifications_sent_fields check ((status='SENT' and sent_at is not null) or status<>'SENT')
);
create unique index ux_notifications_code on public.notifications(notification_code);
create index idx_notifications_reminder on public.notifications(reminder_id,channel,status);
create index idx_notifications_delivery on public.notifications(status,next_attempt_at,channel);
create index idx_notifications_profile on public.notifications(recipient_profile_id,status,created_at desc) where recipient_profile_id is not null;
create index idx_notifications_customer on public.notifications(recipient_customer_id,status,created_at desc) where recipient_customer_id is not null;

create table public.notification_logs (
  id bigint generated always as identity primary key,
  notification_id uuid not null references public.notifications(id) on delete cascade,
  attempt_no integer not null check (attempt_no>0),
  channel text not null check (channel in ('TELEGRAM','EMAIL','ZALO')),
  provider text not null,
  status text not null check (status in ('PROCESSING','SENT','FAILED','RETRYING')),
  request_meta jsonb not null default '{}'::jsonb check (jsonb_typeof(request_meta)='object'),
  response_meta jsonb not null default '{}'::jsonb check (jsonb_typeof(response_meta)='object'),
  external_message_id text,
  error_code text,
  error_message text,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  constraint notification_logs_attempt_unique unique(notification_id,attempt_no)
);
create index idx_notification_logs_notification on public.notification_logs(notification_id,id desc);
create index idx_notification_logs_status on public.notification_logs(status,started_at desc);

create trigger trg_notifications_updated_at before update on public.notifications for each row execute function public.fn_set_updated_at();
create trigger trg_notifications_audit after insert or update or delete on public.notifications for each row execute function public.fn_audit_row();
create trigger trg_notification_logs_audit after insert or update or delete on public.notification_logs for each row execute function public.fn_audit_row();

alter table public.notifications enable row level security;
alter table public.notification_logs enable row level security;

create policy notifications_select on public.notifications for select to authenticated
using (
  (select private.has_permission('notification.manage'))
  or (
    (select private.has_permission('notification.view'))
    and channel='IN_APP'
    and recipient_profile_id=(select auth.uid())
  )
);
create policy notification_logs_select on public.notification_logs for select to authenticated
using ((select private.has_permission('notification.manage')));

revoke all on public.notifications,public.notification_logs from anon,authenticated;
grant select on public.notifications,public.notification_logs to authenticated;

create view public.notification_summary with (security_invoker=true) as
select n.id,n.notification_code,n.reminder_id,r.reminder_code,r.rule_code_snapshot,r.event_type,
       n.channel,n.provider,n.audience,n.recipient_profile_id,p.full_name as recipient_profile_name,
       n.recipient_customer_id,c.customer_code,c.full_name as customer_name,
       case when private.has_permission('notification.manage') then n.recipient_address else null end as recipient_address,
       n.template_key,n.subject,n.body,n.payload,n.status,n.scheduled_at,n.next_attempt_at,n.attempt_count,n.max_attempts,
       n.last_attempt_at,n.sent_at,n.read_at,n.external_message_id,n.last_error_code,n.last_error_message,n.created_at,n.updated_at
from public.notifications n
join public.reminders r on r.id=n.reminder_id
left join public.profiles p on p.id=n.recipient_profile_id
left join public.customers c on c.id=n.recipient_customer_id;
revoke all on public.notification_summary from anon,authenticated;
grant select on public.notification_summary to authenticated;

insert into public.settings(key,value,description,is_sensitive,secret_ref) values
('notification.in_app', jsonb_build_object('enabled',true), 'In-app notification channel', false, null),
('notification.telegram.config', jsonb_build_object('enabled',false,'recipients','[]'::jsonb,'parse_mode','HTML'), 'Telegram Bot staff notification config', false, null),
('notification.telegram.token', null, 'Telegram Bot token reference', true, 'env://TELEGRAM_BOT_TOKEN'),
('notification.email.config', jsonb_build_object('enabled',false,'provider','HTTP','from',null), 'Customer email notification config', false, null),
('notification.email.token', null, 'Email provider API key reference', true, 'env://EMAIL_API_KEY'),
('notification.zalo.config', jsonb_build_object('enabled',false,'mode','ZBS_PHONE','template_map','{}'::jsonb), 'Zalo OA/ZBS customer notification config', false, null),
('notification.zalo.token', null, 'Zalo access token reference', true, 'env://ZALO_ACCESS_TOKEN')
on conflict(key) do nothing;
