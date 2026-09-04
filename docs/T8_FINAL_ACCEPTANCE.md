# HomeTechVN — T8 FINAL ACCEPTANCE

Date: 30/08/2026

## Result

**T8 — Service + Software/License: COMPLETE**

## Windows runtime evidence

```text
T8 LOCAL REPRODUCIBILITY: PASS
T8 FINAL CORE CHECKS: PASS
T8 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T8_LOCAL_VERIFY_20260830_190457.txt
```

## Accepted scope

### Recurring Service
- `services`
- `service_schedules`
- recurring intervals: DAYS / MONTHS / YEARS
- ACTIVE / PAUSED / CANCELLED / COMPLETED
- per-occurrence `last_completion_id`
- completion count and next due date progression
- SERVICE-source Warranty integration
- multiple warranties for different completed occurrences of the same schedule

### Software / License
- `software_products`
- `software_licenses`
- locked T0 categories
- license code `LIC-000001`
- ACTIVE / EXPIRED / SUSPENDED / CANCELLED
- renewal flow
- subscription end-date calculation
- no plaintext license/product key columns
- external URI-only `secret_ref`

### Security / Roles
- Admin: Service + License manage/view
- Manager: Service + License manage/view
- Sales: Service + License manage/view
- Technician: view only
- Cashier: no Service/License access
- direct authenticated writes blocked
- RPC-only mutations
- RLS enabled
- security_invoker summary views
- audit integration

## Locked T8 migrations

```text
20260830113613_t8_service_license_schema.sql
20260830113900_t8_service_license_workflow.sql
```

T1 through T8 migrations are now locked.
T9 and later stages must add new migrations only.
