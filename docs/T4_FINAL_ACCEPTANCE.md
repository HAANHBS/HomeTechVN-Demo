# HomeTechVN — T4 FINAL ACCEPTANCE

Date: 30/08/2026

## Result

T4 — Sales is officially COMPLETE.

## Runtime evidence

```text
T4 LOCAL REPRODUCIBILITY: PASS
T4 FINAL CORE CHECKS: PASS
T4 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T4_LOCAL_VERIFY_20260830_152028.txt
```

## Locked deliverables

- Sales orders
- Sales order items
- Payments
- Order code `SO-YYMMDD-0001`
- Payment code `PAY-YYMMDD-0001`
- DRAFT → CONFIRMED → PAYMENT_PENDING → PAID → DELIVERED → COMPLETED
- Cancellation flow
- Inventory issue on order confirmation
- Inventory reversal on cancellation
- Serialized-unit sale flow
- Payment/refund flow
- 16-item sales checklist
- Required-checklist completion gate
- payment_confirmed system protection
- Private cost snapshots
- Role-specific Sales/Payment access
- Sales UI
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

## Rule from T5 onward

Do not edit or squash T1/T2/T3/T4 migrations.
Every schema change must be introduced in a new migration.
