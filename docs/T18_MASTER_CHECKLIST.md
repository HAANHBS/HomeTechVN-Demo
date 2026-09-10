# HomeTechVN T18 — Master Checklist

## Candidate construction

- [x] Built from T17 FINAL v1.14.
- [x] T17 integrity-manifest hash pinned.
- [x] Migration hashes #1–#36 checked.
- [x] T18 database migrations = 0; migration #37 reserved.
- [x] Production browser configuration validator and self-tests added.
- [x] Missing-config workflow added with `npm run t18:configure` and self-test.
- [x] Demo/local/secret browser configuration rejected.
- [x] Production source maps disabled.
- [x] Worker ships with `WORKER_CRON_ENABLED=false` and `DRY_RUN=true`.
- [x] Worker health, unauthorized-run, and cron-off self-tests added.
- [x] PowerShell 5.1 managed-source gate covers every shipped `.ps1` file.
- [x] Release packager uses an explicit allowlist.
- [x] `app/.env.local` excluded from staging and ZIP without rejecting the working copy.
- [x] Temporary staging cleanup is scoped and idempotent.
- [x] Required-entry array uses PowerShell 5.1-safe one-string-per-line syntax.
- [x] Regression guard rejects prefix-concatenation expressions ending in commas.

## Windows acceptance

- [x] T18 LOCAL REPRODUCIBILITY: PASS
- [x] T18 INHERITED REGRESSION CHECKS: PASS
- [x] T18 PRODUCTION CONFIG SAFETY: PASS
- [x] T18 WORKER SAFE-ACTIVATION CHECK: PASS
- [x] T18 PRODUCTION BUILD: PASS
- [x] T18 RELEASE PACKAGE SAFETY: PASS
- [x] T18 CLEAN BASELINE AFTER VERIFY: PASS
- [x] Release candidate path and SHA-256 recorded.
- [x] T18 snapshot path recorded.

## Deployment acceptance

- [ ] Frontend host/project ID and operator recorded.
- [ ] Production environment variables configured in the host.
- [ ] No runtime environment file uploaded.
- [ ] Worker secrets configured in its secret store.
- [ ] Worker remains cron-off during smoke tests.
- [ ] Dry-run evidence reviewed.
- [ ] Live provider activation separately approved.

Status: **COMPLETE & LOCKED** for the local Production Release Gate. Deployment
acceptance remains a separately authorized operation.
