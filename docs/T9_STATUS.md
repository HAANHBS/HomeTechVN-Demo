# HomeTechVN — T9 STATUS

Status: **CANDIDATE — waiting for Windows acceptance**

## Remote result
Reminder Engine runtime: PASS.

Current remote/local T9 migrations:

```text
20260830121533_t9_reminder_schema.sql
20260830121806_t9_reminder_engine.sql
20260830122012_t9_service_role_private_usage.sql
20260830123046_t9_manual_resolve_rearm.sql
```

Total candidate migration chain: **27 migrations T1–T9**.

T1–T8 remain locked and unchanged.

## Default reminder policy
```text
WARRANTY_30D              warranty end -30 days
WARRANTY_7D               warranty end -7 days
LICENSE_30D               license end -30 days
LICENSE_7D                license end -7 days
MAINTENANCE_7D            service due -7 days
REPAIR_READY              READY immediately
REPAIR_UNCOLLECTED_3D     READY +3 days
REPAIR_UNCOLLECTED_7D     READY +7 days
QUOTE_WAITING_24H         AWAITING_CUSTOMER +24 hours
REPAIR_OVERDUE            estimated_completion_at
RECEIVABLE_DUE            PAYMENT_WINDOWS-ACCEPTED / balance_due > 0
LOW_STOCK                 stock_qty < min_stock
```

`RECEIVABLE_DUE` is currently anchored at `sales_orders.payment_pending_at`,
because T1–T8 do not contain a separate receivable due-date field.

## Scheduler
T9 does not enable `pg_cron`. The locked architecture uses Cloudflare Workers/Cron.
T9 exposes `reminder_generate()` for Admin/Manager manual runs and service-role
server execution. Automatic scheduling is wired in the Worker/Notification phase.

## Final acceptance
T9 is COMPLETE only after Windows returns:

```text
T9 LOCAL REPRODUCIBILITY: PASS
T9 FINAL CORE CHECKS: PASS
T9 APP BUILD: PASS
```


# T9 FINAL STATUS

**COMPLETE**

```text
T9 LOCAL REPRODUCIBILITY: PASS
T9 FINAL CORE CHECKS: PASS
T9 APP BUILD: PASS
```

T1–T9 migrations are LOCKED.
