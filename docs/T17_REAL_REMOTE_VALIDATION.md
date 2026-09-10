# HomeTechVN - T17 REAL REMOTE VALIDATION

Date: 01/09/2026
Project: HomeTechVN (`puqvbenyenwemfbsqpfd`)

T17 was re-reviewed against the connected Supabase project before v1.5 packaging.
All mutation tests below ran inside explicit PostgreSQL transactions and ended with
`ROLLBACK`; no T17 test customer/order/repair/warranty data was retained.

## Verified against the real remote database

- Public RPC signatures used by T17 were queried from `pg_proc`: PASS.
- Role/permission mapping for Admin/Manager/Sales/Technician/Cashier: PASS.
- Sales -> Inventory -> Payment -> Checklist -> COMPLETED -> SALE Warranty: PASS, rollback.
- Repair -> part issue -> QC -> COMPLETED -> REPAIR Warranty: PASS, rollback.
- Service Schedule + Software License -> Reminder -> IN_APP Notification: PASS, rollback.
- Dashboard snapshot with real Admin context: PASS.
- Report snapshot with real Admin context: PASS.
- Security/Audit snapshot with real Admin context: PASS.
- Security Advisor: only Leaked Password Protection warning remains; this is the previously documented Free-plan limitation.
- Performance Advisor: unused-index INFO only; no blind deletion performed.

## What remote validation does not replace

The local T17 verifier must still prove the actual Windows-local chain:

`Supabase CLI -> local Auth signup -> password login -> JWT -> PostgREST/RLS -> demo dataset -> app build`.

That local runtime gate remains authoritative for T17 FINAL.
