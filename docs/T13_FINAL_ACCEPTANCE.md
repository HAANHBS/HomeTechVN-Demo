# HomeTechVN — T13 FINAL ACCEPTANCE

Date: 31/08/2026

## Result

**T13 — Reports: COMPLETE**

## Windows runtime evidence

```text
T13 LOCAL REPRODUCIBILITY: PASS
T13 FINAL CORE CHECKS: PASS
T13 RESPONSIVE UI CHECK: PASS
T13 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T13_LOCAL_VERIFY_20260831_004615.txt
```

## Accepted T13 capabilities

- Permission-aware operational reports
- Custom date range up to 366 days
- Quick 7 / 30 / 90 / 365 day ranges
- DAY / WEEK / MONTH grouping
- Sales revenue reporting
- Cash collection / refund / net cash-flow reporting
- Current receivables snapshot
- Repair revenue / turnaround / workload reporting
- Technician performance reporting
- Inventory movement reporting
- Warranty / claim reporting
- Service / License exposure reporting
- CSV export
- Print report
- Responsive PC / tablet / phone UI
- `report.view` access control
- `report.profit` separate profit access
- Conservative missing-cost treatment
- Sales cost-coverage reporting
- Repair cost-coverage reporting
- RETURNED repair parts excluded from current repair cost
- No invented inventory valuation
- No invented service completion history
- No invented license renewal history
- No false "net profit" claim

## Locked T13 migration

```text
20260830171108_t13_reports_snapshot.sql
```

T1 through T13 migrations are now LOCKED.
T14 and later stages must add new migrations only.

The global responsive UI/UX standard introduced in T11 remains mandatory.
