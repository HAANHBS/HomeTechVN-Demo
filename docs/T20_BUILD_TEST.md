# T20.2 build and hosted-test record

Date: 2026-09-09

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

## Operational acceptance added in T20.2

```text
T20 AUTOMATED FAKE-DATA ACCEPTANCE: PASS
T20 HOSTED COMPLETED SERIAL/WARRANTY DEMO: PASS
T20 LOCKED MIGRATION REGRESSION: PASS (#1-#40 hosted hashes locked)
T20 PAYMENT/WORKFLOW DATABASE CONTRACT: PASS
T20 ACTION ERROR PLACEMENT CHECK: PASS
T20 WORKFLOW GUIDANCE UI CHECK: PASS
T20 AUTOMATED DEMO SOURCE/BUILD GATE: PASS
T20 PC ACCEPTANCE REQUIRED: NO
```

The hosted scanner resolved `DEMO-T20-SN-001` to an ACTIVE sale warranty and
returned the related order, product and customer. No Windows/PC acceptance is
required from T20.2 onward.
