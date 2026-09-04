# HomeTechVN — T16 FINAL ACCEPTANCE

Date: 31/08/2026

## Result

**T16 — Security / Audit Hardening: COMPLETE**

## Authoritative Windows evidence

```text
T16 LOCAL REPRODUCIBILITY: PASS
T16 T1-T15 DEBT CLEANUP CHECKS: PASS
T16 SECURITY CORE CHECKS: PASS
T16 CONCURRENCY CHECK: PASS
T16 AUDIT RESPONSIVE UI CHECK: PASS
T16 APP BUILD: PASS
T16 WORKER CHECK: PASS
Dependency lock bundle: D:\HOMETECHVN\docs\snapshots\T16_DEPENDENCY_LOCKS_20260831_182122.zip
Snapshot: D:\HOMETECHVN\docs\snapshots\T16_LOCAL_VERIFY_20260831_182440.txt
```

## Accepted T16 capabilities

- T1–T15 technical-debt reconciliation
- exact T1–T13 migration byte lock preserved
- explicit deny-all RLS policy for `private.sequence_counters`
- direct `service_role` sequence-table privileges removed
- `fn_audit_row()` hardened to `search_path=''`
- audit history append-only for UPDATE/DELETE/TRUNCATE
- audit actor UUID history independent of Auth-user lifecycle
- bounded permission-aware `audit_search` RPC
- `security_audit_snapshot` RPC
- Admin/Manager Audit UI
- responsive Audit UI
- no direct frontend read of audit tables
- no frontend secret material
- Security Advisor sequence warning resolved
- RLS application tables without policy = 0
- true parallel sequence-race test PASS
- true stock=1 concurrent inventory ISSUE test PASS
- T15 restore regression PASS on T16 schema
- T1→T13 database regression PASS on T16 schema
- PWA regression PASS
- application production build PASS
- Worker check PASS
- root/app/worker dependency-lock generation PASS on Windows
- root/app/worker `npm ci` dependency reproducibility PASS on Windows

## Dependency-lock evidence

Authoritative Windows verifier produced:

```text
D:\HOMETECHVN\docs\snapshots\T16_DEPENDENCY_LOCKS_20260831_182122.zip
```

The user supplied this bundle with the T16 acceptance evidence.

The artifact-generation runtime used to create this FINAL package was unable to
mount/read the uploaded ZIP bytes. Therefore this FINAL source ZIP does **not**
invent or reconstruct package-lock hashes and does not claim bit-identical
embedding of that external Windows lock bundle.

Operational rule:

- retain `T16_DEPENDENCY_LOCKS_20260831_182122.zip` beside the T16 FINAL checkpoint;
- the Windows project directory already contains the generated lockfiles from
  the accepted `npm run t16:verify` run;
- if reproducing the exact Windows dependency tree, use that accepted bundle,
  not a newly generated registry resolution.

## Migration baseline

```text
T1 → T13 = migrations #1–#33 LOCKED
T14 DB migrations = 0
T15 DB migrations = 0
T16 migrations = #34, #35, #36
Total = 36 migrations
```

T16 migration files:

```text
20260831104002_t16_security_audit_core_hardening.sql
20260831104029_t16_audit_search_and_security_snapshot.sql
20260831105049_t16_audit_actor_history_independence.sql
```

## Remaining explicitly classified limitations

These are not hidden and are not falsely marked as verified capabilities:

1. Supabase Leaked Password Protection
   - current project plan: Free
   - classified as plan limitation
   - mandatory pre-public gate if upgraded to Pro+

2. Telegram / Email / Zalo real-provider live-send
   - external credential limitation
   - T10 DB/outbox/Worker contract remains accepted
   - no fake live-send PASS without provider credentials

3. Performance Advisor unused-index INFO
   - no blind index deletion on low-workload DEV database
   - re-evaluate with representative production query statistics

## Inherited locked policies

T16 preserves:

- T11 PC/tablet/phone responsive UI standard
- T12 minimal-data public Warranty privacy contract
- T13 conservative auditable profit calculation
- T14 no offline transaction writes / no Background Sync
- T15 FULL-backup + disposable restore-target policy

## Next stage

T17 must start from **HOMETECHVN_T16_FINAL** and preserve migration #1–#36.

If T17 requires a new DB migration, its first migration is **#37**.
