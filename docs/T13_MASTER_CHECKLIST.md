# HomeTechVN — T13 MASTER CHECKLIST

## Database / security
- [x] exactly one T13 report migration
- [x] live migration ledger aligned to `20260830171108`
- [x] no new report table
- [x] `report_snapshot` requires authenticated user
- [x] `report.view` required
- [x] `report.profit` separately enforced
- [x] module-level permission gates retained
- [x] public/anon EXECUTE revoked
- [x] private implementation is SECURITY DEFINER
- [x] `search_path=''`
- [x] date range limited to 1–366 days
- [x] DAY / WEEK / MONTH buckets only
- [x] Asia/Bangkok boundaries

## Report domains
- [x] sales revenue / AOV / discounts
- [x] current receivables
- [x] gross cash collected
- [x] refunds
- [x] net cash flow
- [x] payment methods
- [x] sales timeline
- [x] top products
- [x] repair completed/revenue/turnaround
- [x] repair current workload
- [x] repair timeline
- [x] top technicians
- [x] inventory movement quantities
- [x] low/out-of-stock current exposure
- [x] warranty/claim metrics
- [x] service current exposure with history limitation
- [x] license current exposure with history limitation

## Profit integrity
- [x] profit only with `report.profit`
- [x] Sales cost from captured item-cost snapshot only
- [x] missing Sales cost never treated as zero
- [x] whole missing-cost order excluded from known profit
- [x] Sales cost coverage percentage
- [x] Repair cost from captured part-cost snapshot only
- [x] currently RETURNED repair parts excluded
- [x] missing issued-part cost excludes that repair from known profit
- [x] Repair cost coverage percentage
- [x] combined known gross profit + coverage
- [x] no inventory valuation invented
- [x] no service completion history invented
- [x] no license renewal history invented
- [x] no "net profit" claim

## Remote runtime
- [x] Sales revenue 1,500 deterministic test
- [x] gross collected 1,500
- [x] refunds 500
- [x] net cash flow 1,000
- [x] Sales known cost 600
- [x] Sales known gross profit 400
- [x] Sales missing-cost revenue excluded = 500
- [x] Sales coverage = 66.67%
- [x] Repair revenue = 1,200
- [x] Repair returned-part cost excluded
- [x] Repair known parts cost = 200
- [x] Repair known gross profit = 600
- [x] Repair missing-cost revenue excluded = 400
- [x] Combined known gross profit = 1,000
- [x] Combined coverage = 66.67%
- [x] Sales role receives no profit payload
- [x] Cashier Service/License hidden
- [x] Technician denied because no `report.view`
- [x] anon denied
- [x] invalid date/bucket checks
- [x] transaction rollback cleanup
- [x] Security Advisor: no new T13 issue
- [x] Performance Advisor: no new T13 missing-index issue

## Frontend
- [x] Reports module + permission gate
- [x] Dashboard quick navigation
- [x] custom start/end date
- [x] quick 7/30/90/365 ranges
- [x] DAY/WEEK/MONTH selector
- [x] overview cards
- [x] sales / cash reporting
- [x] repair reporting
- [x] operational tables
- [x] Profit tab only when permitted
- [x] coverage warning
- [x] excluded missing-cost revenue visible
- [x] CSV export
- [x] print report
- [x] RPC-only report data access
- [x] no report frontend secret
- [x] T11 global responsive regression PASS
- [x] T12 public warranty regression PASS
- [x] T13 responsive checker PASS
- [x] TS/TSX parse 24/24
- [x] Windows production build

## Final acceptance
- [x] T13 LOCAL REPRODUCIBILITY: PASS
- [x] T13 FINAL CORE CHECKS: PASS
- [x] T13 RESPONSIVE UI CHECK: PASS
- [x] T13 APP BUILD: PASS
