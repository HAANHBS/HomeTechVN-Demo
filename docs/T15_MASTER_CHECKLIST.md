# HomeTechVN — T15 MASTER CHECKLIST

## Baseline / database
- [x] T15 adds zero DB migrations
- [x] T1–T13 migration chain remains 33/33
- [x] T1–T13 byte hashes unchanged
- [x] remote PostgreSQL 17.6 recorded
- [x] remote DB size approximately 18 MB recorded
- [x] remote Storage bucket count = 0
- [x] remote Storage object count = 0
- [x] Security Advisor reviewed
- [x] Performance Advisor reviewed

## Backup content
- [x] roles.sql
- [x] schema.sql
- [x] data.sql
- [x] migration history schema
- [x] migration history data
- [x] Storage metadata dump
- [x] source.zip
- [x] manifest.json
- [x] checksums.sha256
- [x] source secret exclusions
- [x] failed/partial backup cannot report FULL
- [x] Storage objects force S3 backup once present

## Secret handling
- [x] DB password never written to project source
- [x] Session pooler URL template uses password placeholder
- [x] password entered as SecureString
- [x] password URL-encoded in memory
- [x] backup DB URL stored DPAPI-encrypted
- [x] optional S3 credentials DPAPI-encrypted
- [x] local config stored outside project
- [x] ACL hardening attempted
- [x] source backup explicitly records secretsIncluded=false

## Storage
- [x] empty Storage accepted as NOT_REQUIRED_EMPTY
- [x] rclone/S3 support for future objects
- [x] remote/local object-count comparison
- [x] remote/local byte-count comparison
- [x] no plaintext rclone config written
- [x] rclone credentials passed through process environment
- [x] Storage files kept separate from DB metadata

## Restore
- [x] disposable scratch DB only
- [x] post-clone marker
- [x] actual pg_dump
- [x] truncate scratch app data
- [x] actual pg_restore
- [x] restored marker check
- [x] critical row-count signature check
- [x] pg_restore archive list check
- [x] scratch DB cleanup
- [x] production never used as restore-drill target

## Operations
- [x] default 30-day retention
- [x] retention only deletes verified old FULL backups
- [x] LATEST.txt pointer
- [x] daily Windows Scheduled Task installer
- [x] Task Scheduler avoids storing Windows password
- [x] restore runbook
- [x] install/config register

## Static validation
- [x] T15 BACKUP SOURCE CHECK: PASS
- [x] PowerShell structural checks performed
- [x] T11 responsive regression retained
- [x] T12 public Warranty regression retained
- [x] T13 Reports regression retained
- [x] T14 PWA regression retained

## Windows / real backup acceptance
- [x] real remote production backup = FULL
- [x] production checksum validation PASS
- [x] official local logical dump components PASS
- [x] actual app-data restore drill PASS
- [x] T15 LOCAL REPRODUCIBILITY: PASS
- [x] T15 BACKUP CORE CHECKS: PASS
- [x] T15 RESTORE DRILL: PASS
- [x] T15 RESPONSIVE UI CHECK: PASS
- [x] T15 APP BUILD: PASS
