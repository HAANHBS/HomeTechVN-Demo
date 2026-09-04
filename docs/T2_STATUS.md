# HomeTechVN — T2 STATUS

Date: 29/08/2026

## Remote Supabase

Project: HomeTechVN (`puqvbenyenwemfbsqpfd`)

Remote migration history added:

- `20260829162450_t2_crm_customer_devices`
- `20260829162924_t2_client_insert_defaults`
- `20260829162949_t2_device_types_access`

### Runtime tests already PASS remotely

- 3 CRM tables created.
- RLS enabled 3/3.
- Admin insert customer/device/note through authenticated RLS.
- Generated code `CUS-000001`, `DEV-000001` inside rollback transaction.
- Phone `+84 912.345.678` normalized to `0912345678`.
- Email normalized to lowercase.
- Test transaction rollback restored rows/counters to zero.
- Unknown UID: no view/create permissions, 0 rows visible, INSERT rejected by RLS 42501.
- Technician: `customer.view=true`, create/update customer false; `device.view=true`, `device.create=false`, `device.update=true`; actual device UPDATE succeeds; customer UPDATE affects 0 rows.
- Sales: creates customer/device/note successfully.
- Cashier: customer/device view true, create/update false.
- Customer/device codes immutable.
- Audit INSERT + UPDATE actor verified.
- Sales can read only `crm.device_types` from Settings through narrow policy.
- Final test cleanup: customers/devices/notes = 0; real account role = admin.

### Advisor

Security Advisor has no T2-specific issue. Remaining items are T1/pre-public items:

- private `sequence_counters` RLS without policy — intentional inaccessible private table.
- leaked-password protection — deferred before public deployment.

Performance Advisor reports unused indexes only because the project is new and has no workload yet; indexes are retained.

## Current acceptance

Remote database portion: **PASS**.

App source/build and Windows local reproducibility are validated separately before T2 COMPLETE.


## App source verification — artifact environment

PASS:
- TypeScript/TSX syntax parse: 10/10 files.
- Structural typecheck with temporary dependency stubs: PASS.
- Backend secret/service-role scan in app: PASS (none found).
- Physical `.delete()` operation scan: PASS (none found).
- T1+T2 migration file set: exactly 6.
- React type-only imports corrected for `verbatimModuleSyntax`.

NOT YET ACCEPTED:
- Real `npm install` / `tsc -b` / `vite build` inside artifact runtime.

Reason:
- This artifact environment cannot resolve/reach `registry.npmjs.org`; `npm install` timed out.
- A real production build therefore cannot be claimed here.

Windows acceptance:
- `npm run t2:verify` installs app dependencies if needed, creates/updates `app/package-lock.json`, resets the local DB, runs `t2_verify.sql`, and runs the real production build.
- T2 is not COMPLETE until Windows outputs all three PASS markers.


## Exact T2 verifier remote execution

The SQL body of `supabase/tests/t2_verify.sql` (excluding only the psql meta-command `\set ON_ERROR_STOP on`) was executed directly against remote HomeTechVN inside a transaction.

Result:
```text
T2 FINAL CORE CHECKS: PASS
customer_code = CUS-000001
device_code = DEV-000001
normalized_phone = 0912345678
```
Transaction rolled back after verification.


# T2 FINAL ACCEPTANCE — 30/08/2026

## STATUS

**T2 — CRM + CUSTOMER DEVICES: COMPLETE**

Runtime acceptance evidence from Windows machine:

```text
T2 LOCAL REPRODUCIBILITY: PASS
T2 FINAL CORE CHECKS: PASS
T2 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T2_LOCAL_VERIFY_20260830_091410.txt
```

## Accepted runtime checks

- Local migration replay: PASS
- T2 SQL verification: PASS
- React/TypeScript production build: PASS
- customers: PASS
- customer_devices: PASS
- customer_notes: PASS
- Customer code generator CUS-xxxxxx: PASS
- Device code generator DEV-xxxxxx: PASS
- Phone normalization: PASS
- RLS role matrix: PASS
- Audit integration: PASS
- Device type access policy: PASS
- No physical delete workflow in T2 UI: PASS
- Remote Supabase T2 foundation: PASS

## Locked T2 migrations

```text
20260829162450_t2_crm_customer_devices.sql
20260829162924_t2_client_insert_defaults.sql
20260829162949_t2_device_types_access.sql
```

These migrations must not be rewritten or squashed.
T3 and later stages must add new migrations only.

## Checkpoint rule

Code -> Test -> Checklist -> Fix -> Acceptance -> Final backup

T2 is now locked as the baseline for T3.
