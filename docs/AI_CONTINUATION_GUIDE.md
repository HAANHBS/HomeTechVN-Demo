# HomeTechVN — AI continuation entrypoint

Read `docs/HANDOFF_T23_2026-09-15.md` completely before editing.

## Non-negotiable constraints

- Migrations #1–#47 are immutable; the next database migration is #48.
- Never put `service_role` credentials in frontend code, bundles, logs, fixtures or documentation.
- Preserve RLS/RPC security boundaries; do not grant extra access merely to make a test pass.
- Keep exactly one authenticated application shell header: `operations-header`.
- Run `npm run t23:verify` before pushing or deploying.
- Clearly distinguish static/build verification, deployment status and production smoke testing.

## Required response structure for every task

1. Reproduction/current evidence.
2. Root-cause hypothesis and affected files.
3. Security, migration and data impact.
4. Smallest safe implementation.
5. Tests actually run and exact result.
6. Commit/deployment identifiers.
7. Remaining risks and next action.

Do not claim completion without matching evidence.
