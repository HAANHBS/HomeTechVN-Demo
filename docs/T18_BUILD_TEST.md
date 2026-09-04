# HomeTechVN T18 — Build and Test Contract

Run only the authoritative entry point:

```powershell
cd D:\HOMETECHVN
npm run t18:configure   # required once when app/.env.local is absent
npm run t18:verify
```

The verifier must:

1. pass T18 Node and global PowerShell static checks;
2. run the accepted T17 full regression and clean-baseline cleanup;
3. validate the hosted `app/.env.local` without printing its values; the
   separately invoked configure helper provides the missing-config path;
4. build the production app with source maps disabled;
5. check Worker syntax, health, unauthorized access, and cron-off behavior;
6. package from an explicit allowlist and inspect the completed ZIP;
7. prove `app/.env.local` was unchanged and not packaged;
8. write a snapshot and release SHA-256.

Required final markers:

```text
T18 LOCAL REPRODUCIBILITY: PASS
T18 INHERITED REGRESSION CHECKS: PASS
T18 PRODUCTION CONFIG SAFETY: PASS
T18 WORKER SAFE-ACTIVATION CHECK: PASS
T18 PRODUCTION BUILD: PASS
T18 RELEASE PACKAGE SAFETY: PASS
T18 CLEAN BASELINE AFTER VERIFY: PASS
```

Any missing marker, non-zero child exit code, changed runtime-config hash,
unmanaged PowerShell file, altered migration, or forbidden ZIP entry is a fail.
Windows reported all required markers on 2026-09-04. T18 v1.3 is accepted as
**COMPLETE & LOCKED**. The accepted release ZIP SHA-256 is:

```text
473e12c80062632f95412e43a8eb39a0e1192e2abc701c96ff76e90e1518547e
```
