# HomeTechVN — T2 Build Test Record

Date: 29/08/2026

## Database remote

Runtime verified directly against HomeTechVN Supabase project:
- T2 migrations 3/3 applied.
- T2 schema/RLS/role tests PASS.
- Transaction fixtures rolled back; remote test data count returned to zero.
- Security Advisor: no new T2 security warning.

## Frontend source checks in artifact environment

PASS:
- 10 TypeScript/TSX source files parsed with the TypeScript compiler parser.
- Structural `tsc` check with temporary ambient stubs PASS.
- No `SUPABASE_SECRET_KEY`, `sb_secret_`, or `service_role` material exists under `app/`.
- No physical `.delete()` call exists under `app/src/`.
- Exactly six migration files are packaged (3 locked T1 + 3 T2).

## Production build limitation

Attempted:

```text
npm install --no-audit --no-fund --ignore-scripts
```

Result: timeout because this artifact runtime cannot resolve/reach the npm registry.
Therefore `tsc -b && vite build` is **not marked PASS here**.

This is deliberately not hidden or downgraded to a false PASS.

## Required Windows acceptance

Run from `D:\HOMETECHVN`:

```powershell
npm run t2:verify
```

The verifier will:
1. check all 6 migrations;
2. rebuild the local Supabase DB from scratch;
3. run `supabase/tests/t2_verify.sql`;
4. install app packages when `app/node_modules` is absent;
5. create/update `app/package-lock.json`;
6. run the real `tsc -b && vite build`;
7. save a T2 snapshot.

Acceptance markers:

```text
T2 LOCAL REPRODUCIBILITY: PASS
T2 FINAL CORE CHECKS: PASS
T2 APP BUILD: PASS
```
