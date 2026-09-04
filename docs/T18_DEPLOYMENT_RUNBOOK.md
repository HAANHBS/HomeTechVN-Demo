# HomeTechVN T18 — Deployment Runbook

T18 is a release gate, not authorization to publish. Complete the Windows gate
first, review the generated ZIP, then configure the chosen hosting platforms.

## 1. Verify the candidate

If `app/.env.local` does not exist, configure the hosted browser connection
first:

```powershell
cd D:\HOMETECHVN
npm run t18:configure
```

Enter the Supabase **Project URL** and **Publishable key** from the project's
Connect dialog or Settings > API Keys. A legacy `anon` key is accepted. Never
enter an `sb_secret_` or `service_role` key. The helper validates the values,
writes only the local working-copy file, and the release packager excludes it.

Then run:

```powershell
cd D:\HOMETECHVN
npm run t18:verify
```

The command runs the full T17 regression/cleanup, validates production browser
configuration, builds the app, tests Worker safe-off behavior, and creates a
release ZIP under `docs\snapshots`.

## 2. Configure the frontend host

Set these in the hosting platform, not in the uploaded package:

```text
VITE_SUPABASE_URL=https://<project>.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=<publishable key or legacy anon key>
```

Do not upload `app/.env.local`, `.env.production`, or `.env.production.local`.
Build output must not contain demo accounts, demo passwords, source maps, a
service-role key, or a Supabase secret key.

## 3. Configure the Worker

Start with:

```text
WORKER_CRON_ENABLED=false
DRY_RUN=true
```

Add `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `WORKER_TRIGGER_KEY`, and only
the channel credentials actually used. Test `/health`, confirm unauthorized
`POST /run` returns 401, then perform a controlled dry run.

Only after provider credentials and dry-run evidence are accepted may the
operator set `DRY_RUN=false`. Enable `WORKER_CRON_ENABLED=true` as a separate,
last activation step. Record the operator, date, deployment URL, version, secret
location, and test result in `docs/T18_ACCOUNT_CONFIG_REGISTER.md`.

## 4. Database release rule

T18 applies no SQL. The hosted chain remains #1–#36. Any later schema change must
start with migration #37 and pass a new migration review before deployment.
