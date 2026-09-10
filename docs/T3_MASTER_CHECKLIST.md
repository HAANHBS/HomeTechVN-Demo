# HomeTechVN — T3 MASTER CHECKLIST

## A. Migration baseline

- [x] T1 migration chain unchanged
- [x] T2 migration chain unchanged
- [x] 20260830051756_t3_product_inventory.sql
- [x] 20260830052012_t3_performance_indexes_and_settings_policy.sql
- [x] Remote migration history = 8 versions
- [ ] Local db reset replays all 8 migrations — Windows acceptance

## B. Product catalog

- [x] product_categories
- [x] products
- [x] SKU required + case-insensitive unique
- [x] SKU immutable after creation
- [x] Barcode partial unique
- [x] category / brand / model / unit / sale_price / min_stock
- [x] track_serial
- [x] warranty_months
- [x] no physical delete workflow
- [x] audit integration

## C. Inventory

- [x] inventory_units for serialized stock
- [x] inventory_transactions immutable ledger
- [x] bulk stock derived from ledger
- [x] serialized stock derived from IN_STOCK units
- [x] receive RPC
- [x] issue RPC
- [x] adjust RPC
- [x] product row lock used during mutation
- [x] negative stock blocked
- [x] duplicate serialized units blocked per product
- [x] direct Data API ledger/unit writes blocked
- [x] all remote mutation tests rolled back cleanly
- [ ] true parallel-session concurrency test — defer until dedicated load/concurrency test

## D. Cost security

- [x] no cost field in public.products
- [x] no cost field in public.inventory_transactions
- [x] private.inventory_transaction_costs
- [x] private cost RLS requires cost_price.view
- [x] security_invoker inventory views
- [x] Manager cost visible
- [x] Sales cost NULL
- [x] Technician cost NULL
- [x] Cashier cost NULL

## E. RLS / permissions

- [x] Product View matrix
- [x] Product Manage matrix
- [x] Inventory View matrix
- [x] Inventory Receive matrix
- [x] Inventory Issue matrix
- [x] Inventory Adjust matrix
- [x] Fake UID blocked
- [x] Anon direct access blocked

## F. Advisor

- [x] Security Advisor rerun
- [x] No new T3 security issue
- [x] Missing FK indexes fixed
- [x] Duplicate Settings SELECT policy warning fixed
- [x] Remaining unused-index INFO documented

## G. Frontend

- [x] Product & stock page
- [x] Category management
- [x] Serial list
- [x] Transaction history
- [x] Receive form
- [x] Issue form
- [x] Adjust form
- [x] Cost UI permission guard
- [x] CRM ↔ Inventory navigation
- [x] TS/TSX syntax static PASS
- [x] structural typecheck PASS
- [ ] Windows tsc + Vite production build PASS

## H. Final acceptance

Required output:

```text
T3 LOCAL REPRODUCIBILITY: PASS
T3 FINAL CORE CHECKS: PASS
T3 APP BUILD: PASS
```

Only after these three markers may T3 be marked COMPLETE and the T3 migrations locked.
