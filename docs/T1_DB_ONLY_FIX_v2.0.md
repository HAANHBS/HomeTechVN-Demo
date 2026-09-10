# HomeTechVN T1 — DB-only local verification v2.0

## Root cause

T1 v1.9 assumed an `[inbucket]` section existed in `supabase/config.toml`.
On the user's Supabase CLI 2.116.0 generated config, that section is omitted,
while the full `supabase start` still starts the email-testing container with defaults.

That made a non-essential Mailpit/Inbucket port conflict block database verification.

## Correct T1 approach

T1 only needs PostgreSQL to verify:
- migration replay
- seed
- RLS
- functions/triggers
- roles/permissions
- code generators

Supabase CLI provides:

```powershell
npx supabase db start
```

to start only the local Postgres database.

v2.0 therefore uses:

```text
supabase stop --no-backup
supabase db start
supabase db reset --local
docker exec ... psql < t1_verify.sql
docker inspect supabase_db_<project_id>
```

No Studio, Auth container, Mailpit/Inbucket, Storage, Realtime, Analytics or Edge
Runtime port is required for the T1 local reproducibility test.

## Run

```powershell
cd D:\HOMETECHVN
npm run t1:repair
```

## Acceptance

The last lines must contain:

```text
T1 LOCAL REPRODUCIBILITY: PASS
T1 FINAL CORE CHECKS: PASS
```
