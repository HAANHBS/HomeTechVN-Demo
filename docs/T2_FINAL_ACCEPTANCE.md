# HomeTechVN — T2 FINAL ACCEPTANCE

Date: 30/08/2026

## Result

T2 — CRM + Customer Devices is officially COMPLETE.

## Runtime evidence

```text
T2 LOCAL REPRODUCIBILITY: PASS
T2 FINAL CORE CHECKS: PASS
T2 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T2_LOCAL_VERIFY_20260830_091410.txt
```

## Locked deliverables

- Customers CRM
- Customer devices
- Customer notes
- CUS automatic codes
- DEV automatic codes
- Phone normalization
- Search-oriented indexes
- CRM RLS policies
- Device RLS policies
- Notes RLS policies
- Audit integration
- Device type configuration access
- React + TypeScript CRM interface
- Supabase client integration
- Login/session shell
- Customer list/detail/forms
- Device list/forms
- Production app build verification
- Local DB reproducibility verification

## Baseline migration chain

### T1
```text
20260829143948_t1_core_foundation.sql
20260829144121_t1_security_hardening.sql
20260829150727_t1_private_security_and_rls_performance.sql
```

### T2
```text
20260829162450_t2_crm_customer_devices.sql
20260829162924_t2_client_insert_defaults.sql
20260829162949_t2_device_types_access.sql
```

## Rule from T3 onward

Do not edit or squash T1/T2 migrations.
Every schema change must be introduced in a new migration.
