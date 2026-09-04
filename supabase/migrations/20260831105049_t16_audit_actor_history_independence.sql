-- HomeTechVN T16 — Keep append-only audit actor history independent of Auth-user lifecycle.

alter table public.audit_logs
  drop constraint if exists audit_logs_actor_user_id_fkey;

comment on column public.audit_logs.actor_user_id is
  'Immutable historical Auth user UUID. Intentionally no FK so deleting an Auth user never rewrites or blocks append-only audit history.';
