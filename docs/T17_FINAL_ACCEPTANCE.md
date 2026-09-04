# HomeTechVN — T17 FINAL ACCEPTANCE

Acceptance date: 2026-09-01
Stage: T17 — Demo Integration
Status: FINAL & LOCKED
Validated artifact baseline: T17 v1.14
Root package version: 0.17.14-t17.14
App version: 0.17.14

## Windows runtime acceptance

The user executed:

```powershell
cd D:\HOMETECHVN
npm run t17:verify
```

and reported all required final markers:

```text
T17 LOCAL REPRODUCIBILITY: PASS
T17 INHERITED REGRESSION CHECKS: PASS
T17 DEMO INTEGRATION CHECKS: PASS
T17 DEMO AUTH LOGIN CHECK: PASS
T17 DEMO ROLE JWT CHECK: PASS
T17 DEMO RESPONSIVE UI CHECK: PASS
T17 APP BUILD: PASS
T17 WORKER CHECK: PASS
T17 CLEAN BASELINE AFTER VERIFY: PASS
```

Runtime artifacts reported by the Windows verifier:

```text
Dependency lock bundle:
D:\HOMETECHVN\docs\snapshots\T16_DEPENDENCY_LOCKS_20260901_231228.zip

Demo snapshot:
D:\HOMETECHVN\docs\snapshots\T17_DEMO_LOAD_20260901_161555.json

Local verification snapshot:
D:\HOMETECHVN\docs\snapshots\T17_LOCAL_VERIFY_20260901_231708.txt
```

## Acceptance interpretation

T17 is accepted as a real Windows runtime checkpoint, not a source-only or
simulated result.

The accepted verifier covered:

- exact local reproducibility from migrations/seed;
- inherited T1–T16 regression checks;
- integrated CRM/Sales/Inventory/Repair/Warranty/Service/License/Reminder/
  Notification demo workflow;
- real local Supabase Auth password login;
- real JWT + role/RLS checks;
- responsive UI checks;
- application production build;
- worker syntax/runtime check;
- final cleanup back to an empty Auth/business operational baseline while
  preserving locked system foundation configuration.

## Database invariant

T17 intentionally adds zero database migrations.

```text
T1 → T16 migration chain: 36
T17 migrations: 0
Final locked chain after T17: 36
```

The T1–T16 migration files are immutable after T17 acceptance.

If T18 requires a database migration, the next migration is #37.

## T17 data policy

T17 demo data is LOCAL verification data only.

After successful verification:

- temporary demo Auth users are removed;
- customer/business demo data is removed;
- transactional reminders/notifications are removed;
- the 12 locked T9 system reminder rules remain as foundation configuration;
- normal first operational use starts with no real customer/business data.

## Baseline rule for T18

T18 must be built from this T17 FINAL checkpoint.

Do not modify T17 FINAL migrations or accepted T17 runtime behavior in place.
Any T18 database change must begin at migration #37.
