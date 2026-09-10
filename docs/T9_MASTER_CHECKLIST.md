# HomeTechVN — T9 MASTER CHECKLIST

## Scope
T9 — Reminder Engine.

T9 detects reminder conditions and maintains reminder lifecycle.
Delivery channels (in-app / Telegram / email) belong to T10 Notification.

## Database
- [x] `reminder_rules`
- [x] `reminders`
- [x] RLS enabled from creation
- [x] `reminder_summary` is `security_invoker`
- [x] explicit SELECT-only browser grants
- [x] direct authenticated INSERT / UPDATE / DELETE blocked
- [x] audit + updated_at integration
- [x] `REM-000001` sequence
- [x] unique `dedupe_key`
- [x] source/event indexes
- [x] service-role generator path for future Worker
- [x] no pg_cron architecture change

## Default system rules
- [x] Warranty 30 days
- [x] Warranty 7 days
- [x] License 30 days
- [x] License 7 days
- [x] Maintenance / Service 7 days
- [x] Repair READY immediately
- [x] Uncollected repair 3 days
- [x] Uncollected repair 7 days
- [x] Quote waiting 24 hours
- [x] Repair estimated-completion overdue
- [x] Sales receivable / PAYMENT_PENDING
- [x] Low stock

## Reminder lifecycle
- [x] PENDING
- [x] DUE
- [x] SNOOZED
- [x] ACKNOWLEDGED
- [x] RESOLVED
- [x] CANCELLED reserved
- [x] snooze expiry reconciliation
- [x] acknowledged state preserved while condition remains
- [x] stale condition auto-resolves
- [x] disabled rule auto-resolves
- [x] resolved condition can reopen
- [x] generator advisory lock
- [x] rerun idempotency

## Role behavior
- [x] Admin: view/manage/run/resolve
- [x] Manager: view/manage/run/resolve
- [x] Sales: view/ack/snooze
- [x] Technician: view/ack/snooze
- [x] Cashier: view/ack/snooze
- [x] non-manager generator/rule changes denied

## Runtime tests
- [x] 12 rules -> 12 deterministic reminders
- [x] initial DUE/PENDING = 9/3
- [x] REM code format
- [x] rerun creates no duplicates
- [x] Sales ack + snooze
- [x] Sales manage/generate denied
- [x] rule disable -> RULE_DISABLED
- [x] rule re-enable -> one reminder reopened
- [x] READY -> RETURNED resolves all three READY-derived reminders
- [x] service_role generation
- [x] remote rollback cleanup
- [x] Security Advisor: no new T9 issue
- [x] Performance Advisor: no missing-FK-index T9 issue

## Frontend
- [x] Summary cards
- [x] search/status/event filters
- [x] acknowledgement
- [x] snooze
- [x] manager resolve
- [x] manager run engine
- [x] Rules tab
- [x] create custom rule
- [x] edit/enable/disable rule
- [x] RPC-only mutation scan
- [x] TS/TSX syntax parse 20/20
- [x] Windows production build

## Final acceptance
- [x] T9 LOCAL REPRODUCIBILITY: PASS
- [x] T9 FINAL CORE CHECKS: PASS
- [x] T9 APP BUILD: PASS
