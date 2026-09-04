# HomeTechVN T5 — Master Checklist

## Database
- [x] `repair_orders`
- [x] `repair_diagnostics`
- [x] `repair_quotes`
- [x] `repair_parts`
- [x] `repair_status_history`
- [x] private repair part cost snapshot
- [x] RLS + explicit grants
- [x] `repair_order_summary` security_invoker
- [x] FK/query indexes
- [x] audit triggers

## Workflow/RPC
- [x] SRV daily code
- [x] RECEIVE → diagnosis → quote → customer decision
- [x] APPROVED / WAITING_PART / REPAIRING
- [x] QC fail → REPAIRING
- [x] QC pass → READY → RETURNED → COMPLETED
- [x] CUSTOMER_REJECTED
- [x] NO_FIX
- [x] CANCELLED with stock reversal
- [x] WARRANTY_TRANSFER + resume
- [x] bulk + serialized repair parts
- [x] private cost capture
- [x] returned repair part can be replanned

## Security / roles
- [x] Sales create/view only
- [x] Technician diagnose/quote/update/qc, no cancel
- [x] Cashier view only
- [x] Manager/Admin full repair permissions
- [x] no direct authenticated writes to repair tables
- [x] no authenticated read of private repair cost

## App
- [x] repair list/search/status filter
- [x] intake form
- [x] detail/timeline
- [x] diagnosis
- [x] quote/customer decision
- [x] parts issue/return
- [x] waiting part / repair / QC
- [x] special states
- [ ] Windows production build acceptance

## Acceptance
Required final markers:
```text
T5 LOCAL REPRODUCIBILITY: PASS
T5 FINAL CORE CHECKS: PASS
T5 APP BUILD: PASS
```
