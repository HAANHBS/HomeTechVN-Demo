# T20 build and hosted-test record

Date: 2026-09-04

## Passed in the delivery environment

```text
T20 LOCKED MIGRATION REGRESSION: PASS (#1-#37 unchanged; #38 isolated)
T20 PRIVATE COST RLS SOURCE CONTRACT: PASS
T20 HOSTED DEMO DATA SAFETY: PASS
T20 KNOWN-ERROR REGRESSION CONTRACT: PASS
T20 SOURCE CHECK: PASS
T20 CONFIGURE SELF TEST: PASS
T20 HOSTED READINESS SELF TEST: PASS
T20 CHILD PROCESS DIAGNOSTICS SELF TEST: PASS
T18 PRODUCTION ENV VALIDATION SELF TEST: PASS
T18 POWERSHELL GLOBAL STATIC CHECK: PASS
T20 HOSTED AUTH/API READINESS: PASS
T20 HOSTED ANON ISOLATION: PASS
T20 HOSTED PUBLIC WARRANTY CONTRACT: PASS
T18 PRODUCTION BUILD DEMO/SOURCEMAP EXCLUSION: PASS
APP TYPESCRIPT/VITE/PWA BUILD: PASS
WORKER SYNTAX CHECK: PASS
```

Hosted data assertions:

- three fictional customers and three fictional products;
- one receivable sale with one fictional payment;
- one active repair with one issued fictional part;
- one service schedule and one software license;
- private sales-cost and repair-cost rows were both created after RLS hardening;
- no non-demo customer/product marker was found.

## Pending Windows-only gate

`npm run t20:verify` must still pass on the operator's Windows/Docker/Supabase-local machine before T20 is marked COMPLETE & LOCKED.
