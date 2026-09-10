# HomeTechVN — T6 STATUS

Status: **CANDIDATE — waiting for Windows acceptance**

Remote Supabase:
- T6 schema migration: PASS
- T6 workflow + Sales bridge: PASS
- RLS helper patch: PASS
- Runtime role matrix: PASS
- Sales 16-item template: PASS
- Sales with Serial: 11 required items: PASS
- Payment system-managed sync: PASS
- Refund auto-reopen: PASS
- Generic template/run: PASS
- Rollback clean: PASS

Current T6 migration chain:
```text
20260830093152_t6_checklist_schema.sql
20260830093342_t6_checklist_workflow_and_sales_bridge.sql
20260830093439_t6_rls_helper_execute.sql
```

T1–T5 migrations remain locked and unchanged.

T6 is COMPLETE only after Windows returns:
```text
T6 LOCAL REPRODUCIBILITY: PASS
T6 FINAL CORE CHECKS: PASS
T6 APP BUILD: PASS
```


# T6 FINAL ACCEPTANCE — 30/08/2026

## STATUS

**T6 — CHECKLIST ENGINE: COMPLETE**

Runtime acceptance evidence from Windows machine:

```text
T6 LOCAL REPRODUCIBILITY: PASS
T6 FINAL CORE CHECKS: PASS
T6 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T6_LOCAL_VERIFY_20260830_174843.txt
```

## Locked T6 migrations

```text
20260830093152_t6_checklist_schema.sql
20260830093342_t6_checklist_workflow_and_sales_bridge.sql
20260830093439_t6_rls_helper_execute.sql
```

T7 and later stages must add new migrations only.
