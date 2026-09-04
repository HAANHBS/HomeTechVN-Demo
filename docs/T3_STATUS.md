# HomeTechVN — T3 STATUS

Date: 30/08/2026
Stage: T3 — Product + Inventory

## Current status

**T3 REMOTE DATABASE: PASS**

**T3 LOCAL WINDOWS ACCEPTANCE: CLOSED BY WINDOWS ACCEPTANCE**

Do not mark T3 COMPLETE until the Windows verifier prints all three markers:

```text
T3 LOCAL REPRODUCIBILITY: PASS
T3 FINAL CORE CHECKS: PASS
T3 APP BUILD: PASS
```

## Remote migrations applied

```text
20260830051756_t3_product_inventory.sql
20260830052012_t3_performance_indexes_and_settings_policy.sql
```

T1/T2 migrations remain locked and unchanged.

## Remote database verification — PASS

- 4 public T3 tables created: product_categories, products, inventory_units, inventory_transactions.
- Private cost storage: private.inventory_transaction_costs.
- RLS enabled.
- Public inventory RPC wrappers are SECURITY INVOKER.
- Private implementations validate auth.uid() and permission before mutation.
- Direct authenticated writes to inventory_units / inventory_transactions blocked.
- Bulk stock flow PASS: receive 10 → issue 2 → adjust -1 = 7.
- Serialized flow PASS: receive 2 serials → issue 1 → 1 IN_STOCK, 1 OUT.
- Negative-stock protection PASS.
- SKU immutable PASS.
- track_serial cannot change after inventory exists PASS.
- Audit product INSERT PASS.
- DB-level cost masking PASS.
- Fake/no-profile UID sees no Product/Inventory rows PASS.
- Sales receive RPC blocked PASS.
- Sales direct ledger write blocked PASS.
- T2 crm.device_types access preserved after Settings policy consolidation PASS.
- Remote verifier logic returns `T3 FINAL CORE CHECKS: PASS` and rolls back test data.
- Remote cleanup verified: zero T3 test rows and real Admin role restored.

## Role matrix verified remotely

| Role | Product View | Inventory View | Receive | Issue | Adjust | Cost |
|---|---:|---:|---:|---:|---:|---:|
| Admin | Yes | Yes | Yes | Yes | Yes | Yes |
| Manager | Yes | Yes | Yes | Yes | Yes | Yes |
| Sales | Yes | Yes | No | No | No | No |
| Technician | Yes | Yes | No | Yes | No | No |
| Cashier | Yes | Yes | No | No | No | No |

For Sales / Technician / Cashier the database returns cost as NULL, not merely hidden by UI.

## Advisors

Security Advisor has no new T3 finding. Remaining existing DEV items:
- private.sequence_counters RLS enabled with no policy: intentional private inaccessible table.
- leaked password protection disabled: deferred to PRE_PUBLIC_AUTH_SECURITY.

Performance Advisor after T3 fix:
- missing-FK-index findings: FIXED.
- duplicate permissive Settings SELECT policies: FIXED by one new migration.
- remaining unused-index notices: informational because the database has almost no workload yet.

## Frontend candidate

Implemented:
- Product list + inventory summary.
- Product/category create/update.
- Receive / Issue / Adjust via RPC only.
- Serialized inventory list.
- Inventory transaction history.
- Low-stock indicator.
- Cost visibility by permission.
- CRM ↔ Inventory navigation.

Static checks in artifact environment:
- TS/TSX syntax parse: PASS 12/12.
- Structural TypeScript check with dependency stubs: PASS.
- Real npm install/build in artifact environment: NOT VERIFIED because registry access timed out.

Final production build must be accepted on Windows via `npm run t3:verify`.


# T3 FINAL ACCEPTANCE — 30/08/2026

## STATUS

**T3 — PRODUCT + INVENTORY: COMPLETE**

Runtime acceptance evidence from Windows machine:

```text
T3 LOCAL REPRODUCIBILITY: PASS
T3 FINAL CORE CHECKS: PASS
T3 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T3_LOCAL_VERIFY_20260830_144440.txt
```

## Locked T3 migrations

```text
20260830051756_t3_product_inventory.sql
20260830052012_t3_performance_indexes_and_settings_policy.sql
```

T1, T2 and T3 migration chains are now LOCKED.
T4 and later stages must add new migrations only.
