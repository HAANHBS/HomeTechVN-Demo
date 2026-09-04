# HomeTechVN — T4 STATUS

## Current status

**T4 — SALES: COMPLETE / WINDOWS ACCEPTED**

Remote Supabase: PASS.
Windows local reproducibility + production build: PASS.

## Remote migration history T4

```text
20260830080141_t4_sales.sql
20260830080302_t4_rpc_execution_and_item_uniqueness.sql
20260830081007_t4_payment_checklist_guard.sql
```

T1/T2/T3 migrations remain locked and unchanged.

## Remote runtime evidence

Lifecycle transaction returned:

```text
lifecycle_status = COMPLETED
cancel_status = CANCELLED
refund_status = CANCELLED
bulk_stock = 18.000
sold_serial_status = OUT
cancelled_serial_status = IN_STOCK
checklist_count = 16
```

All runtime test data was rolled back.

## Issues caught before candidate

1. Public RPC wrapper could not execute private implementation (`42501`).
   - Fixed by migration `t4_rpc_execution_and_item_uniqueness`.
   - Only top-level impls that perform Auth/permission checks are executable by authenticated.
   - Internal helpers remain unexposed.

2. Test harness attempted to change `profiles.role_id` while running as authenticated.
   - Corrected by `RESET ROLE` before changing the temporary user's test role.
   - T1 privilege protection remains intact.

3. Verifier attempted to read private cost snapshots as authenticated.
   - Correct behavior is permission denied.
   - Final verifier explicitly tests this, then resets role for internal assertions.

4. `payment_confirmed` could be toggled manually through checklist RPC.
   - Fixed by migration `t4_payment_checklist_guard`.
   - Only payment workflow may control this item.

## Advisor status

Security Advisor only reports existing/deferred T1 items:
- `private.sequence_counters` RLS with no policy — intentional private/no client grants.
- Auth leaked-password protection disabled — deferred until pre-public hardening.

Performance Advisor only reports unused-index INFO because the database has no production workload yet.

## Acceptance command

```powershell
cd D:\HOMETECHVN
npm run t4:verify
```

Required final markers:

```text
T4 LOCAL REPRODUCIBILITY: PASS
T4 FINAL CORE CHECKS: PASS
T4 APP BUILD: PASS
```


# T4 FINAL ACCEPTANCE — 30/08/2026

## STATUS

**T4 — SALES: COMPLETE**

Runtime acceptance evidence from Windows machine:

```text
T4 LOCAL REPRODUCIBILITY: PASS
T4 FINAL CORE CHECKS: PASS
T4 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T4_LOCAL_VERIFY_20260830_152028.txt
```

## Accepted runtime checks

- Local migration replay: PASS
- T4 SQL verification: PASS
- React/TypeScript production build: PASS
- Sales order workflow: PASS
- Sales order items: PASS
- Payment workflow: PASS
- Partial/full payment transitions: PASS
- Refund workflow: PASS
- Inventory issue on confirm: PASS
- Stock reversal on cancellation: PASS
- Serialized item issue/reversal: PASS
- Sales checklist 16 items: PASS
- COMPLETED checklist gate: PASS
- payment_confirmed system guard: PASS
- Role matrix Sales/Cashier/Manager/Admin/Technician: PASS
- Private cost snapshot: PASS
- No direct frontend Sales/Payment mutation: PASS
- Audit integration: PASS

## Locked T4 migrations

```text
20260830080141_t4_sales.sql
20260830080302_t4_rpc_execution_and_item_uniqueness.sql
20260830081007_t4_payment_checklist_guard.sql
```

These migrations must not be rewritten or squashed.
T5 and later stages must add new migrations only.

## Checkpoint rule

Code -> Test -> Checklist -> Fix -> Acceptance -> Final backup

T4 is now locked as the baseline for T5.
