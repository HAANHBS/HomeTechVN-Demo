# HomeTechVN — T6 MASTER CHECKLIST

## Scope
T6 — Checklist Engine.

## Database
- [x] `checklist_templates`
- [x] `checklist_template_items`
- [x] `checklist_runs`
- [x] `checklist_run_items`
- [x] UUID PKs / FK indexes / audit / updated_at
- [x] RLS from creation
- [x] Explicit Data API SELECT grants only
- [x] RPC-only mutations
- [x] Template versioning
- [x] Active-template uniqueness per template code
- [x] Requirement rules: ALWAYS / OPTIONAL / SALES_HAS_SERIAL
- [x] System-managed run items
- [x] Run lifecycle: OPEN / COMPLETED / CANCELLED
- [x] Manager/Admin reopen/cancel
- [x] Entity-aware RLS
- [x] Sales T4 JSON bridge
- [x] Payment auto-sync
- [x] Refund auto-reopen
- [x] 16-item `SALES_DELIVERY` system template

## Roles
- Admin: checklist.manage + checklist.run
- Manager: checklist.manage + checklist.run
- Sales: checklist.run
- Technician: checklist.run
- Cashier: no checklist access

## Acceptance
- [x] Remote schema/workflow preflight
- [x] Remote role/lifecycle test
- [x] Sales Serial conditional required count test
- [x] System-managed payment guard test
- [x] Legacy Sales → T6 sync test
- [x] T6 → legacy Sales sync test
- [x] Refund → run auto-reopen test
- [x] Remote rollback clean
- [x] Security advisor: no new T6 warning
- [ ] Windows local reproducibility
- [ ] Windows T6 SQL verifier
- [ ] Windows production app build
