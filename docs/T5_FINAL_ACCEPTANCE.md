# HomeTechVN — T5 FINAL ACCEPTANCE

Date: 30/08/2026

## Result

T5 — Repair is officially COMPLETE.

## Runtime evidence

```text
T5 LOCAL REPRODUCIBILITY: PASS
T5 FINAL CORE CHECKS: PASS
T5 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T5_LOCAL_VERIFY_20260830_162633.txt
```

## Locked deliverables

- Repair orders
- Repair diagnostics
- Repair quotes
- Repair parts
- Repair status history
- Repair code `SRV-YYMMDD-0001`
- Full repair state machine
- Diagnosis workflow
- Quote versioning and customer decision
- Bulk/serial repair parts
- Atomic inventory issue/reversal
- QC fail/pass loop
- WAITING_PART
- CUSTOMER_REJECTED
- NO_FIX
- WARRANTY_TRANSFER / resume
- Cancellation with stock reversal
- Private cost snapshots
- Role-specific repair access
- Repair UI
- Production app build verification
- Local database reproducibility verification

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

### T3
```text
20260830051756_t3_product_inventory.sql
20260830052012_t3_performance_indexes_and_settings_policy.sql
```

### T4
```text
20260830080141_t4_sales.sql
20260830080302_t4_rpc_execution_and_item_uniqueness.sql
20260830081007_t4_payment_checklist_guard.sql
```

### T5
```text
20260830082723_t5_repair_schema.sql
20260830083011_t5_repair_workflow.sql
20260830083317_t5_repair_part_replan_guard.sql
```

## Rule from T6 onward

Do not edit or squash T1/T2/T3/T4/T5 migrations.
Every schema change must be introduced in a new migration.
