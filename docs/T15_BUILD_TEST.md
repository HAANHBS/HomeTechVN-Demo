# T15 Build / Test

## Remote preflight — PASS

Remote project inspection:

```text
PostgreSQL 17.6
DB approximately 18 MB
Storage buckets = 0
Storage objects = 0
```

No T15 DDL was applied.

## Static backup/security — PASS

```text
T15 BACKUP SOURCE CHECK: PASS
```

Verified:

- DPAPI encrypted secrets
- no project-local plaintext DB password
- password-placeholder connection URL flow
- official logical-dump component contract
- migration-history backup
- Storage metadata audit
- S3/rclone future-object path
- source archive exclusions
- SHA-256 manifest/checksum contract
- retention rules
- restore-drill implementation
- daily Task Scheduler implementation
- unchanged 33 migration baseline

## Historical pre-Windows runtime note

Artifact environment does not have Docker/Windows PowerShell, so it cannot
truthfully run the Supabase local restore drill or Windows DPAPI.

The authoritative Windows verifier performs:

- real remote logical backup
- checksum verification
- official local Supabase dump generation
- actual pg_dump/pg_restore drill
- T11–T14 regression
- PWA production build

This note predates the final Windows acceptance below; T15 runtime acceptance is PASS.


## Windows v1.0 runtime finding

Remote dump phase reached PASS for all six database artifacts.

Failure occurred afterward during local backup packaging because one checksum
path still called `.NET Path.GetRelativePath`.

v1.1 replaces that call with the existing PowerShell 5.1 compatibility helper.

The observed `repair_orders` / `repair_quotes` circular-FK dump warning is
non-fatal. The local restore drill now restores with disabled triggers on the
disposable scratch database.


## Windows final acceptance — PASS

```text
T15 LOCAL REPRODUCIBILITY: PASS
T15 BACKUP CORE CHECKS: PASS
T15 RESTORE DRILL: PASS
T15 RESPONSIVE UI CHECK: PASS
T15 APP BUILD: PASS
Production backup: D:\HOMETECHVN_BACKUPS\HomeTechVN_20260831_171756
Snapshot: D:\HOMETECHVN\docs\snapshots\T15_LOCAL_VERIFY_20260831_172248.txt
```
