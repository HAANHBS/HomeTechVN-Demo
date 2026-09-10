# HomeTechVN — T13 STATUS

Status: **CANDIDATE — waiting for Windows acceptance**

## Migration

```text
20260830171108_t13_reports_snapshot.sql
```

Live Supabase migration ledger and local filename are aligned.

Total candidate migration chain:

```text
T1 → T13 = 33 migrations
```

T1–T12 remain locked and unchanged.

## Remote result

`report_snapshot()` functional test: **PASS**.

Deterministic test result includes:

```text
Sales revenue                         1,500
Gross collected                       1,500
Refunds                                 500
Net cash flow                         1,000

Sales cost-covered revenue            1,000
Sales excluded missing-cost revenue     500
Sales known product cost                600
Sales known gross profit                400
Sales coverage                        66.67%

Repair revenue                        1,200
Repair cost-covered revenue             800
Repair excluded missing-cost revenue    400
Repair recorded parts cost              200
Repair known gross profit               600

Combined known gross profit           1,000
Combined coverage                     66.67%
```

A RETURNED repair part with captured cost was explicitly tested and excluded.

## Role test

- Admin: full report + profit
- Sales: report allowed, profit/cost values absent
- Cashier: Service/License report data absent
- Technician: denied (`report.view` missing)
- anon: denied

## Advisor

No new T13 security issue.

Existing notices only:

1. `private.sequence_counters` has RLS enabled with no policy intentionally.
   Remediation reference:
   https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
2. Leaked-password protection remains a pre-public Auth hardening item.
   Remediation reference:
   https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

Performance Advisor currently reports `unused_index` INFO because the DEV
database has little/no production workload. These indexes are not removed merely
because they are unused before real workload.

## Historical pre-Windows note

The artifact environment timed out downloading npm packages, so the real
React/Vite production build: PASS — T13 Windows acceptance completed.

Run on Windows:

```powershell
npm run t13:verify
```

Required final markers:

```text
T13 LOCAL REPRODUCIBILITY: PASS
T13 FINAL CORE CHECKS: PASS
T13 RESPONSIVE UI CHECK: PASS
T13 APP BUILD: PASS
```


# T13 FINAL STATUS — 31/08/2026

Status: **COMPLETE**

Windows acceptance:

```text
T13 LOCAL REPRODUCIBILITY: PASS
T13 FINAL CORE CHECKS: PASS
T13 RESPONSIVE UI CHECK: PASS
T13 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T13_LOCAL_VERIFY_20260831_004615.txt
```

The T13 migration chain is now LOCKED.
Do not edit, squash, rename or reorder T1–T13 migrations.
