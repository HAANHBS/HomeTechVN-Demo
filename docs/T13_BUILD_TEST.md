# T13 Build / Test

## Remote database — PASS

The live `report_snapshot()` RPC was tested with a rollback transaction.

Validated:

- exact Sales revenue
- payment collection/refund timing
- net cash flow
- current receivable reporting
- Repair completed revenue
- Warranty claim reporting
- Service/License exposure
- Sales cost coverage
- missing Sales cost exclusion
- Repair part-cost coverage
- returned-part exclusion
- missing Repair cost exclusion
- combined known gross profit
- Sales non-profit role privacy
- Cashier module privacy
- Technician access denial
- anon denial
- reverse date rejection
- >366-day rejection
- invalid bucket rejection

Test rows were rolled back. Follow-up check confirmed zero T13 test users/customers.

## Static frontend — PASS

```text
T11 responsive table scan: PASS (31 tables)
T11 RESPONSIVE UI CHECK: PASS

T12 anonymous RPC-only privacy scan: PASS
T12 RESPONSIVE PUBLIC UI CHECK: PASS

T13 report tables responsive: PASS (6 tables)
T13 report RPC-only data access: PASS
T13 profit coverage / missing-cost warnings: PASS
T13 CSV / print / date range controls: PASS
T13 RESPONSIVE UI CHECK: PASS

T13 TS/TSX parse: files=24, errors=0
```

## Build limitation

`npm --prefix app install --no-audit --no-fund` timed out in the artifact
environment. No false production-build PASS is claimed.

Windows `npm run t13:verify` remains the authoritative build acceptance.


## Windows final acceptance — PASS

```text
T13 LOCAL REPRODUCIBILITY: PASS
T13 FINAL CORE CHECKS: PASS
T13 RESPONSIVE UI CHECK: PASS
T13 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T13_LOCAL_VERIFY_20260831_004615.txt
```
