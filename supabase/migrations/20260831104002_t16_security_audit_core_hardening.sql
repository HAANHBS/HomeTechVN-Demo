-- HomeTechVN T16 — Core security/audit hardening.

alter table private.sequence_counters enable row level security;

drop policy if exists sequence_counters_no_direct_access
on private.sequence_counters;

create policy sequence_counters_no_direct_access
on private.sequence_counters
for all
to public
using (false)
with check (false);

revoke all on table private.sequence_counters
from public, anon, authenticated, service_role;

create or replace function public.fn_audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_record_id text;
begin
  if tg_op = 'INSERT' then
    v_record_id := coalesce(to_jsonb(new) ->> 'id', to_jsonb(new) ->> 'key');
    insert into public.audit_logs(actor_user_id, table_name, record_id, action, new_data)
    values (auth.uid(), tg_table_name, v_record_id, 'INSERT', to_jsonb(new));
    return new;
  elsif tg_op = 'UPDATE' then
    v_record_id := coalesce(to_jsonb(new) ->> 'id', to_jsonb(new) ->> 'key');
    insert into public.audit_logs(actor_user_id, table_name, record_id, action, old_data, new_data)
    values (auth.uid(), tg_table_name, v_record_id, 'UPDATE', to_jsonb(old), to_jsonb(new));
    return new;
  elsif tg_op = 'DELETE' then
    v_record_id := coalesce(to_jsonb(old) ->> 'id', to_jsonb(old) ->> 'key');
    insert into public.audit_logs(actor_user_id, table_name, record_id, action, old_data)
    values (auth.uid(), tg_table_name, v_record_id, 'DELETE', to_jsonb(old));
    return old;
  end if;
  return null;
end;
$$;

revoke execute on function public.fn_audit_row()
from public, anon, authenticated, service_role;

create or replace function private.audit_logs_reject_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception 'audit_logs is append-only';
end;
$$;

revoke execute on function private.audit_logs_reject_mutation()
from public, anon, authenticated, service_role;

drop trigger if exists trg_audit_logs_no_update_delete on public.audit_logs;
create trigger trg_audit_logs_no_update_delete
before update or delete on public.audit_logs
for each row execute function private.audit_logs_reject_mutation();

drop trigger if exists trg_audit_logs_no_truncate on public.audit_logs;
create trigger trg_audit_logs_no_truncate
before truncate on public.audit_logs
for each statement execute function private.audit_logs_reject_mutation();

revoke insert, update, delete, truncate on table public.audit_logs
from public, anon, authenticated, service_role;

grant select on table public.audit_logs to authenticated, service_role;

create index if not exists idx_audit_logs_table_record_time
  on public.audit_logs(table_name, record_id, occurred_at desc, id desc);

create index if not exists idx_audit_logs_actor_time
  on public.audit_logs(actor_user_id, occurred_at desc, id desc)
  where actor_user_id is not null;
