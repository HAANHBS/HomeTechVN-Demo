# T11 Build / Test

## Remote database test — PASS

Deterministic rollback test validates:

- 2 sales orders in period
- 2,000,000 VND recognized sales value
- 2,000,000 VND received payment
- 2 open repairs
- 1 overdue repair
- 1 low-stock product
- Warranty due within 7 days
- Service due within 7 days
- License due within 7 days
- 1 urgent reminder
- 30-day daily sales series
- low-stock attention queue
- Cashier Service/License hidden
- Technician received-payment KPI hidden

## UI static test — PASS

```text
T11 responsive table scan: PASS (25 tables)
T11 touch/focus/mobile foundation: PASS
T11 dashboard responsive structure: PASS
T11 RESPONSIVE UI CHECK: PASS
```

## TypeScript source

```text
T11 TS/TSX parse: files=22, errors=0
Dashboard focused semantic errors=0
```

## Historical pre-Windows note

The artifact environment timed out downloading npm packages, therefore no claim is
made for the real Vite production build here. Windows `t11:verify` is the final
build acceptance.
