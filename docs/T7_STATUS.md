# HomeTechVN — T7 STATUS

Status: **CANDIDATE — waiting for Windows acceptance**

Remote T7: schema, workflow, claim lifecycle, role matrix, masking, Warranty Checklist integration, rollback cleanup and Advisors are PASS.

T7 migrations:
```text
20260830105628_t7_warranty_schema.sql
20260830105854_t7_warranty_workflow.sql
20260830110030_t7_server_public_lookup_contract.sql
20260830110102_t7_warranty_inventory_unit_index.sql
```

T1–T6 migrations remain locked and unchanged.

T7 is COMPLETE only after Windows returns:
```text
T7 LOCAL REPRODUCIBILITY: PASS
T7 FINAL CORE CHECKS: PASS
T7 APP BUILD: PASS
```


## T7 v1.1 — Windows TypeScript build fix

Windows T7 v1.0 already returned:

```text
T7 FINAL CORE CHECKS: PASS
```

Confirmed frontend compiler issue:

```text
TS2739: PostgrestFilterBuilder is missing Promise properties catch/finally
```

Root cause:
- `ClaimDetail.call()` required callback type `Promise<...>`.
- `supabase.rpc()` returns a PostgREST builder implementing `PromiseLike`, not a native `Promise`.

Fix:
- `Promise<...>` -> `PromiseLike<...>` for the action callback.
- No RPC behavior changed.
- No database object changed.
- No migration added/reordered/rewritten.
- Migration chain remains exactly 21/21.
- Added `npm run t7:finalize` to re-run rollback-based T7 SQL verification and the frontend production build without resetting the local database.


# T7 FINAL ACCEPTANCE — 30/08/2026

## STATUS

**T7 — WARRANTY: COMPLETE**

Runtime acceptance evidence from Windows machine:

```text
T7 LOCAL REPRODUCIBILITY: PASS
T7 FINAL CORE CHECKS: PASS
T7 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T7_LOCAL_VERIFY_20260830_182912.txt
```

## Accepted runtime checks

- Local migration replay: PASS
- T7 SQL verification: PASS
- React/TypeScript production build: PASS
- Warranty creation from Sale: PASS
- Warranty creation from Repair: PASS
- WAR code generation: PASS
- WCL code generation: PASS
- Opaque 64-hex token: PASS
- Claim lifecycle: PASS
- QC fail/pass loop: PASS
- Rejected claim flow: PASS
- VOID guard: PASS
- Cashier read-only: PASS
- Warranty Checklist integration: PASS
- Masked server lookup contract: PASS
- RPC-only frontend mutations: PASS
- Audit integration: PASS
- Advisor FK/index fix: PASS

## Locked T7 migrations

```text
20260830105628_t7_warranty_schema.sql
20260830105854_t7_warranty_workflow.sql
20260830110030_t7_server_public_lookup_contract.sql
20260830110102_t7_warranty_inventory_unit_index.sql
```

These migrations must not be rewritten or squashed.
T8 and later stages must add new migrations only.
