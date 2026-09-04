# HomeTechVN — T8 MASTER CHECKLIST

## Scope
T8 — Recurring Service + Software / License.

## Database
- [x] `services`
- [x] `service_schedules`
- [x] `software_products`
- [x] `software_licenses`
- [x] RLS enabled from creation
- [x] security_invoker summary views
- [x] audit / updated_at triggers
- [x] FK covering indexes
- [x] direct authenticated writes revoked
- [x] RPC-only mutations
- [x] Service interval DAYS / MONTHS / YEARS
- [x] Schedule ACTIVE / PAUSED / CANCELLED / COMPLETED
- [x] Per-occurrence `last_completion_id`
- [x] Warranty source SERVICE integration
- [x] Software categories locked from T0
- [x] License code `LIC-000001`
- [x] License ACTIVE / EXPIRED / SUSPENDED / CANCELLED
- [x] License renewal
- [x] No plaintext key/password columns
- [x] `secret_ref` requires external URI

## Roles
- [x] Admin: Service + License manage/view
- [x] Manager: Service + License manage/view
- [x] Sales: Service + License manage/view
- [x] Technician: Service + License view only
- [x] Cashier: no Service/License access

## Runtime acceptance already completed remotely
- [x] Service creation
- [x] Recurring schedule creation
- [x] Two schedule completions
- [x] Two distinct SERVICE warranties from two completions
- [x] Plaintext-looking product key rejected
- [x] Vault URI secret_ref accepted
- [x] License creation
- [x] License renew
- [x] Suspend / activate / cancel
- [x] Technician manage denied
- [x] Cashier read/manage denied
- [x] Paused schedule cannot complete
- [x] Rollback cleanup
- [x] Security Advisor: no new T8 issue
- [x] Performance Advisor: no missing-index T8 issue

## Frontend
- [x] Lịch dịch vụ tab
- [x] Danh mục dịch vụ tab
- [x] License tab
- [x] Software product tab
- [x] Role-gated actions
- [x] Secret reference URI warning
- [x] RPC-only writes
- [x] Windows production build

## Final acceptance
- [x] T8 LOCAL REPRODUCIBILITY: PASS
- [x] T8 FINAL CORE CHECKS: PASS
- [x] T8 APP BUILD: PASS
