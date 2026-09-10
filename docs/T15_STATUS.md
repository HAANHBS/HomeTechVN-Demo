# HomeTechVN — T15 STATUS

Status: **CANDIDATE — waiting for Windows real-backup + restore acceptance**

## Database

T15 intentionally adds no database migration.

```text
T1 → T13 = 33 locked migrations
T14 DB migrations = 0
T15 DB migrations = 0
```

## Remote preflight

31/08/2026:

```text
PostgreSQL version    17.6
Database size         approximately 18 MB
Storage buckets       0
Storage objects       0
```

Because Storage is currently empty, the initial FULL backup does not require S3
credentials.

If Storage contains objects later, `t15-backup.ps1` refuses FULL status until S3
backup is configured and object count/byte count match.

## Security Advisor

No new T15 database change exists.

Existing notices remain:

- `private.sequence_counters`: RLS enabled with no policy, intentional private
  defense in depth.
- leaked-password protection disabled: retained for pre-public Auth hardening.

## Performance Advisor

Only existing `unused_index` INFO notices on the low-workload DEV database.
T15 does not remove indexes based on pre-production inactivity.

## Static result

```text
T15 DPAPI secret-storage contract: PASS
T15 DB/source/storage backup contract: PASS
T15 restore-drill source contract: PASS
T15 retention/schedule contract: PASS
T15 migration baseline unchanged: PASS (33/33)
T15 BACKUP SOURCE CHECK: PASS
```

## Windows acceptance

First execution of:

```powershell
npm run t15:verify
```

will securely launch T15 configuration if backup credentials have not yet been
configured.

It then requires a real remote backup with `status=FULL`, validates checksums,
performs the local restore drill, reruns T11–T14 regression checks and builds
the PWA.

Expected markers:

```text
T15 LOCAL REPRODUCIBILITY: PASS
T15 BACKUP CORE CHECKS: PASS
T15 RESTORE DRILL: PASS
T15 RESPONSIVE UI CHECK: PASS
T15 APP BUILD: PASS
```


## Candidate v1.1 compatibility correction

Windows v1.0 successfully completed the real remote Supabase dump files and
failed only while building the local source/checksum payload because Windows
PowerShell 5.1 lacks `System.IO.Path.GetRelativePath`.

v1.1 removes that remaining API call and adds a regression guard.

The existing DPAPI backup configuration and database password are valid and are
reused automatically.

The data-only dump warning about circular foreign keys between `repair_orders`
and `repair_quotes` is addressed proactively in the disposable local restore
drill with `pg_restore --disable-triggers`.


## Candidate v1.2 restore-drill redesign

v1.2 removes source-session termination and active-database cloning. The scratch database is created from `template0`, then a full local database dump is restored using an accessible local SUPERUSER. Cleanup uses `DROP DATABASE ... WITH (FORCE)` and cannot mask the primary failure. Existing DPAPI configuration is reused.


## Candidate v1.3 Windows/docker JSON correction

v1.2 confirmed that the independent `template0` scratch database design works
through scratch creation. The next failure was limited to JSON quote handling
through Windows PowerShell → docker.exe → psql `-c`.

v1.3 replaces command-line JSON text with PostgreSQL
`jsonb_build_object('stage','T15','restore','required')`.

Existing DPAPI backup configuration remains valid.


# T15 FINAL STATUS — 31/08/2026

Status: **COMPLETE**

Windows acceptance:

```text
T15 LOCAL REPRODUCIBILITY: PASS
T15 BACKUP CORE CHECKS: PASS
T15 RESTORE DRILL: PASS
T15 RESPONSIVE UI CHECK: PASS
T15 APP BUILD: PASS
Production backup: D:\HOMETECHVN_BACKUPS\HomeTechVN_20260831_171756
Snapshot: D:\HOMETECHVN\docs\snapshots\T15_LOCAL_VERIFY_20260831_172248.txt
```

The accepted production backup is recorded above.

T15 introduced no database migration.
The locked database chain remains T1–T13 = 33 migrations.
