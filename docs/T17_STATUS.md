# HomeTechVN — T17 STATUS

Status: **FINAL & LOCKED — Windows runtime accepted 2026-09-01**

## Database

T17 intentionally adds no migration.

```text
T1 → T16 = 36 migrations
T17 DB migration = 0
```

Remote production data was not seeded or modified for T17.

## Demo architecture

T17 provides:

```text
supabase/t17_demo_data.sql
supabase/tests/t17_demo_assert.sql
scripts/t17-demo-load.ps1
scripts/t17-source-check.mjs
scripts/t17-verify.ps1
```

## Local login accounts

Created dynamically through the local Auth signup API during demo load.

The local publishable/anon key is read from `supabase status -o env` into memory and
is not written to the source tree.

## Integrated scope

```text
Auth / Roles
CRM / Devices
Products / Inventory
Sales / Payment / Checklist
Warranty / Claims
Repair / Parts / Repair Warranty
Recurring Service
Software License
Reminder Engine
Notification Outbox / IN_APP
Dashboard
Reports
Security / Audit
Public Warranty
PWA / responsive UI
Worker regression
```

## Windows acceptance

Run:

```powershell
npm run t17:verify
```

Expected final markers:

```text
T17 LOCAL REPRODUCIBILITY: PASS
T17 INHERITED REGRESSION CHECKS: PASS
T17 DEMO INTEGRATION CHECKS: PASS
T17 DEMO AUTH LOGIN CHECK: PASS
T17 DEMO ROLE JWT CHECK: PASS
T17 DEMO RESPONSIVE UI CHECK: PASS
T17 APP BUILD: PASS
T17 WORKER CHECK: PASS
Dependency lock bundle: ...
Demo snapshot: ...
Snapshot: ...
```


## v1.1 correction

The first Windows run proved the 36-migration local reset succeeds.

The subsequent loader failure was API-key-name compatibility only.
v1.1 accepts new publishable-key names, falls back to legacy anon-key names,
and removes the secret/service-role dependency.


## v1.3 PowerShell/.NET regex correction

The v1.2 Windows run exposed a double-escaping bug in the `config.toml` API
section regex. v1.3 uses native .NET regex escaping inside PowerShell
single-quoted strings and adds a regression guard.


### T17 v1.5 full reliability pass

See `docs/T17_V1_5_FULL_REVIEW.md` and `docs/T17_REAL_REMOTE_VALIDATION.md`. PowerShell source is globally normalized for Windows PowerShell 5.1 and `npm run t17:verify` now performs an independent Node static gate before entering PowerShell.


## v1.5 full review

After repeated Windows loader failures, T17 was reviewed globally rather than patched line-by-line. Local API/key discovery now runs in Node, every PowerShell file is ASCII + UTF-8 BOM, a Node lexical/encoding gate scans all PowerShell before invocation, and connected Supabase rollback integration tests passed for Sales/Warranty and Repair/Service/Reminder/Notification. Remote test residue was verified as zero.


## v1.6 PowerShell ownership scope

The checker now validates exactly the 30 PowerShell files shipped by the current checkpoint manifest. npm-generated shims and legacy/untracked leftovers are not treated as HomeTechVN source.


## v1.7

The accumulated PowerShell demo-loader implementation was removed from the runtime path. `t17-demo-load.mjs` is authoritative; the `.ps1` file is compatibility-only. Duplicate PowerShell function definitions are now a static failure.


## v1.8 full-stack/Auth readiness correction

Windows v1.7 proved T15 restore and T16 concurrency PASS. T17 failed because
the verifier started the DB-only local path and then attempted to resolve an
Auth client key.

v1.8 starts the full Supabase stack, retries structured status until Auth is
ready, and avoids a second reset immediately before demo login tests.


## v1.9 Windows service-scope correction

v1.8 replayed the database successfully but `supabase start` failed on local
Storage and Studio health checks. T17 does not use those services.

v1.9 starts a minimal Auth/API integration stack using the official CLI
`-x/--exclude` mechanism and keeps real health checks for required services.

## First-run data decision

T17 demo fixtures are verification-only. After all integration/build checks
PASS, the verifier resets the local DB to the normal foundation seed and
asserts Auth/business data is empty before final acceptance.


## v1.10 JWT/RLS role-context fix

The v1.9 Windows run proved local API/Auth/key/container discovery works.

The first dataset write failed because the SQL switched to `authenticated`
before querying the RLS-protected `profiles` table for the JWT subject. v1.10
sets the subject first, then switches role, and asserts the expected
auth.uid/role/permission at every authenticated phase.


## v1.11 security-contract correction

T17 no longer calls `private.current_role_code()` from authenticated SQL. Role mapping is checked before role switch; authenticated phases use `auth.uid()` and the supported `private.has_permission(...)` helper.


## v1.12 receivable-state correction

The v1.11 Windows dataset completed successfully. The assertion failure proved
that the receivable fixture was still `CONFIRMED`, because `sale_confirm()` is
not the transition to `PAYMENT_PENDING`.

v1.12 records a real partial Cashier payment, verifies the payment row and
`payment_pending_at`, and requires the corresponding `RECEIVABLE_DUE` reminder.
SQL query-result noise is suppressed so phase/error output stays readable.


## v1.13 source/permission-boundary audit

The v1.12 dataset itself completed. The public-warranty assertion then violated
the intended T12 security boundary by selecting `public.warranties` after
switching to `anon`.

v1.13 captures the fixture token before the role switch, makes the anon
assertion RPC-only, adds static role-block security checks, and makes the
temporary T17 SQL fixture/assertion ASCII-only for Windows transport.


## v1.14 clean-baseline correction

The v1.13 Windows run reached the final cleanup/reset. The only final-baseline
failure was the expected set of 12 T9 system reminder rules.

v1.14 distinguishes system foundation configuration from transactional data:
the exact 12 system reminder rules must remain, while non-system rules and all
business/Auth transaction data must be zero. The app env cleanup is also
idempotent to prevent duplicate-restore warnings.


## FINAL acceptance — 2026-09-01

Windows `npm run t17:verify` returned every required PASS marker, including
local reproducibility, inherited regressions, integrated demo workflow,
real Auth login/JWT role validation, responsive UI, app build, worker check,
and clean-baseline cleanup.

T17 is now FINAL & LOCKED. T18 must use this checkpoint as its immutable
baseline. T17 adds zero migrations; the locked chain remains #1–#36.
