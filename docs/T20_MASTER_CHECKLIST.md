# T20 — Hosted Demo Deployment master checklist

Date: 2026-09-04  
Operator: HomeTechVN owner / Codex  
Scope: dedicated hosted demo with fictional data only

## Baseline and migration integrity

- [x] T19 FINAL ZIP SHA-256 matched `621cc2da8587b6c5ad2c7844dd2a59f4eebcbd3f8b94a6fcea56e01cec16a0d0`.
- [x] Migrations #1–#37 remain byte-for-byte locked.
- [x] Hosted migration history repaired to the locked T19 version `20260904014416`.
- [x] T20 migration #38 is isolated as `20260904154351_t20_private_cost_rls_hardening.sql`.
- [x] Next migration is #39.

## Known-error regression gates

- [x] Windows PowerShell 5.1 static scan inherited.
- [x] UTF-8/regex and unmanaged `.bin/*.ps1` checks inherited.
- [x] Auth/DB readiness retry and local key resolver self-tests inherited.
- [x] JWT subject is set before `SET ROLE`.
- [x] Child stdout/stderr uses a 64 MiB buffer and secret redaction.
- [x] Failure and success snapshots contain no raw JWT/key/demo password.
- [x] Cleanup runs even after a primary failure.
- [x] Clean baseline requires zero demo residue and exactly 12 system reminder rules.
- [x] Hosted checks are read-only and refuse local URLs.
- [x] Hosted demo loader refuses any non-empty business database.

## Supabase hosted

- [x] Project status is healthy.
- [x] Migration #37 QR deployed and verified.
- [x] Migration #38 private-cost RLS deployed and verified.
- [x] Direct `anon`/`authenticated` access to private cost/QR tables remains revoked.
- [x] Sale confirmation still writes private sales cost.
- [x] Repair part issue still writes private repair cost.
- [x] Hosted dataset marker says `contains_real_customer_data=false`.
- [x] Only fictional customer/product records were loaded.
- [x] Anonymous internal QR RPC is denied.
- [x] Anonymous invalid public-warranty lookup returns `found=false`.
- [ ] Enable leaked-password protection in Supabase Auth when the plan/dashboard exposes it.

## Frontend and hosting

- [x] Browser uses Project URL plus publishable key only.
- [x] No service-role/secret key or demo password in browser source/bundle.
- [x] Hosted-demo banner is visible.
- [x] TypeScript/Vite/PWA build passes.
- [x] Production bundle contains no sourcemap or local demo account/password.
- [x] Worker syntax check passes.
- [ ] Sites production deployment completed.
- [ ] Production deployment status is `succeeded`.

## Windows final acceptance

- [ ] Run `npm run t20:configure` once with hosted URL and publishable key.
- [ ] Run `npm run t20:verify` on Windows.
- [ ] Confirm every T20 PASS marker and exit code 0.
- [ ] Preserve `T20_LOCAL_VERIFY_*.txt`.
- [ ] Confirm cleanup baseline after verifier.
