# HomeTechVN T1 — psql NOTICE fix v2.1

Observed runtime:

```text
docker inspect ... -> running
docker exec ... psql ...
[T1 FAIL]
NOTICE: T1 FINAL CORE CHECKS: PASS
```

This is a verifier bug, not a SQL failure.

PostgreSQL `RAISE NOTICE` is emitted on stderr. Windows PowerShell with
`$ErrorActionPreference = 'Stop'` can convert native stderr into a terminating
error before the script evaluates `$LASTEXITCODE`.

v2.1 temporarily changes ErrorActionPreference to `Continue` only around
the native `docker exec ... psql` call, captures stdout+stderr, records
`$LASTEXITCODE`, restores the previous preference, then applies both acceptance
conditions:

1. psql exit code == 0
2. output contains `T1 FINAL CORE CHECKS: PASS`

Because v2.0 already successfully completed local db start/reset on the user's
machine, v2.1 also adds a non-destructive finalizer:

```powershell
npm run t1:finalize
```

It re-runs SQL verification and creates the snapshot without resetting the DB.
