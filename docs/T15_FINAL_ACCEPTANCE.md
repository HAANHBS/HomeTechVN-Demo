# HomeTechVN — T15 FINAL ACCEPTANCE

Date: 31/08/2026

## Result

**T15 — Backup & Restore: COMPLETE**

## Windows runtime evidence

```text
T15 LOCAL REPRODUCIBILITY: PASS
T15 BACKUP CORE CHECKS: PASS
T15 RESTORE DRILL: PASS
T15 RESPONSIVE UI CHECK: PASS
T15 APP BUILD: PASS
Production backup: D:\HOMETECHVN_BACKUPS\HomeTechVN_20260831_171756
Snapshot: D:\HOMETECHVN\docs\snapshots\T15_LOCAL_VERIFY_20260831_172248.txt
```

## Accepted T15 capabilities

- Real remote Supabase logical backup
- roles.sql
- schema.sql
- data.sql
- Supabase migration-history schema/data backup
- Storage metadata backup
- source.zip without secrets
- SHA-256 payload checksums
- manifest.json with FULL/PARTIAL/FAILED status
- production backup completeness gate
- Storage object completeness gate
- DPAPI-protected local backup credentials
- Session Pooler password-template workflow
- optional S3/rclone Storage backup when objects exist
- automatic refusal of FULL status when Storage objects exist but S3 backup is absent
- retention policy
- LATEST.txt pointer
- Windows Scheduled Task support
- actual local full restore drill
- independent scratch database from template0
- local superuser detection
- marker restoration verification
- critical row-count signature verification
- archive structure verification
- scratch database cleanup
- T11 responsive UI regression preserved
- T12 public Warranty/privacy regression preserved
- T13 Reports regression preserved
- T14 PWA regression preserved
- Windows production build PASS

## Production backup accepted

```text
D:\HOMETECHVN_BACKUPS\HomeTechVN_20260831_171756
```

## Backup/restore safety policy

- Never test restore by overwriting production.
- Always restore to a disposable local/new target first.
- Database backup does not imply Storage object backup.
- Storage object backup becomes mandatory once Storage contains files.
- No plaintext secrets in source/checkpoints/backups.
- Failed/PARTIAL backup is never treated as FULL.

## Database

T15 adds **zero database migrations**.

Locked baseline remains:

```text
T1 → T13 = 33 migrations
T14 DB migrations = 0
T15 DB migrations = 0
```

All 33 T1–T13 migrations remain LOCKED and unchanged.

## Next stage

T16 and later stages must preserve:

- T11 responsive UI/UX standard
- T14 offline-write prohibition
- T15 backup/restore safety policy
- no modification/rename/reorder/squash of T1–T13 migrations
