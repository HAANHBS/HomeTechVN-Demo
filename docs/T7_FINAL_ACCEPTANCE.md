# HomeTechVN — T7 FINAL ACCEPTANCE

Date: 30/08/2026

## Result

T7 — Warranty is officially COMPLETE.

## Runtime evidence

```text
T7 LOCAL REPRODUCIBILITY: PASS
T7 FINAL CORE CHECKS: PASS
T7 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T7_LOCAL_VERIFY_20260830_182912.txt
```

## Locked deliverables

- `warranties`
- `warranty_claims`
- `warranty_status_history`
- Warranty code `WAR-YYMMDD-0001`
- Claim code `WCL-YYMMDD-0001`
- SALE / REPAIR warranty sources
- SERVICE source reserved for T8 integration
- Full warranty-claim state machine
- QC fail/pass loop
- Claim rejection / closure
- Warranty VOID guard
- Opaque lookup token
- Masked server-only lookup contract
- Warranty entity in Checklist Engine
- Role-specific warranty access
- RPC-only frontend mutations
- Warranty UI
- Production app build verification
- Local database reproducibility verification

## Rule from T8 onward

Do not edit or squash T1–T7 migrations.
Every schema change must be introduced in a new migration.
