# HomeTechVN — T8 STATUS

Status: **CANDIDATE — waiting for Windows acceptance**

Remote Supabase T8 runtime: PASS.

## T8 migrations
```text
20260830113613_t8_service_license_schema.sql
20260830113900_t8_service_license_workflow.sql
```

T1–T7 migrations remain locked and unchanged. Total candidate chain: 23 migrations.

## Remote evidence
- recurring service completion count: 2
- SERVICE warranties from same schedule: 2 with distinct completion IDs
- license code: `LIC-000001`
- final test license status: `CANCELLED`
- plaintext license-key-like value: rejected
- Technician: read-only
- Cashier: no access
- rollback cleanup: PASS

T8 becomes COMPLETE only after Windows returns:

```text
T8 LOCAL REPRODUCIBILITY: PASS
T8 FINAL CORE CHECKS: PASS
T8 APP BUILD: PASS
```


# T8 FINAL STATUS — 30/08/2026

Status: **COMPLETE**

Windows acceptance:

```text
T8 LOCAL REPRODUCIBILITY: PASS
T8 FINAL CORE CHECKS: PASS
T8 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T8_LOCAL_VERIFY_20260830_190457.txt
```

The T8 migration pair is now LOCKED.
Do not edit, squash, rename or reorder T1–T8 migrations.
