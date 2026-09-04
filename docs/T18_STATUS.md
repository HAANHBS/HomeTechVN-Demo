# HomeTechVN T18 — Status

Stage: T18 — Production Release Gate  
Candidate version: v1.3  
Status: **COMPLETE & LOCKED**

Lifecycle: **CANDIDATE -> COMPLETE & LOCKED** after Windows acceptance.

## Implemented

- T17 FINAL integrity and all 36 locked migration hashes are enforced.
- No migration was added; migration #37 remains the next available number.
- Production browser environment validation rejects local/demo/placeholder and
  secret-key configurations.
- A validated `t18:configure` helper handles the legitimate T17 clean-baseline
  case where `app/.env.local` does not yet exist.
- `app/.env.local` remains a permitted local working-copy file, is preserved by
  verification, and is forbidden from the release package.
- Worker scheduled execution requires `WORKER_CRON_ENABLED=true`; shipped
  defaults remain cron-off and dry-run-on.
- Release packaging uses allowlisted copying, opens the final ZIP, checks its
  entries, and performs scoped temporary cleanup.
- Required ZIP entries are represented as plain relative-path strings and
  combined with the archive prefix one at a time, avoiding PowerShell 5.1
  comma-expression array collapse.
- All project PowerShell scripts are managed by the T18 static manifest.

## Windows acceptance — 2026-09-04

The full Windows verifier passed all seven gates:

```text
T18 LOCAL REPRODUCIBILITY: PASS
T18 INHERITED REGRESSION CHECKS: PASS
T18 PRODUCTION CONFIG SAFETY: PASS
T18 WORKER SAFE-ACTIVATION CHECK: PASS
T18 PRODUCTION BUILD: PASS
T18 RELEASE PACKAGE SAFETY: PASS
T18 CLEAN BASELINE AFTER VERIFY: PASS
```

Accepted release artifact:

```text
D:\HOMETECHVN\docs\snapshots\HOMETECHVN_T18_RELEASE_20260904_011535.zip
SHA-256: 473e12c80062632f95412e43a8eb39a0e1192e2abc701c96ff76e90e1518547e
```

Acceptance snapshot:

```text
D:\HOMETECHVN\docs\snapshots\T18_LOCAL_VERIFY_20260904_011541.txt
```

T18 is not a record of production deployment. Hosting configuration, Worker
secrets, dry-run evidence, and explicit live activation remain separate
deployment operations.
