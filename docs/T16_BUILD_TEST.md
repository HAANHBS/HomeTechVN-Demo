# HomeTechVN — T16 BUILD / TEST

## Remote — PASS

Two T16 migrations applied successfully.

Remote functional transaction verified:

- sequence deny policy;
- sequence service-role direct privilege revoked;
- counter helper still works;
- audit trigger empty search path;
- append-only audit mutation rejection;
- Admin audit query;
- Sales audit rejection;
- security posture snapshot.

## Advisor — reviewed

Security Advisor:

```text
sequence RLS no-policy        RESOLVED
leaked-password protection    PLAN LIMITATION (Free plan; Pro+ feature)
```

Performance Advisor:

```text
unused_index INFO only
```

No blind index deletion was performed.

## Runtime logs — reviewed

```text
Auth     no errors returned
API      health/ready 200
Storage  health/tenant 200
Postgres historical authoring/test errors catalogued in debt register
```

## Static source — PASS

```text
T11 RESPONSIVE UI CHECK: PASS
T12 RESPONSIVE PUBLIC UI CHECK: PASS
T13 RESPONSIVE UI CHECK: PASS
T14 PWA SOURCE CHECK: PASS
T16 SECURITY SOURCE CHECK: PASS
Worker node --check: PASS
```

## Windows — PENDING

The artifact environment cannot truthfully run:

- Windows PowerShell background jobs;
- Docker Desktop local Supabase;
- multi-session race tests;
- registry-backed package-lock generation;
- real `npm ci`;
- final Vite PWA build with the Windows-generated lock.

Those are mandatory T16 acceptance gates and are not marked PASS here.


## T16 v1.1 Windows verifier correction

Initial v1.0 Windows execution stopped before the concurrency test with a
PowerShell parser error:

```text
Missing closing ')' in expression.
Unexpected token ')' in expression or statement.
```

Root cause:

```powershell
$issueCount = (
    Invoke-DockerSql ...
    | Select-Object -Last 1
).Trim()
```

The pipeline operator started a new physical line inside the grouped
expression and Windows PowerShell 5.1 parsed the construct incorrectly.

T16 v1.1 replaces it with a parser-safe sequence:

```powershell
$issueCountLines = @(Invoke-DockerSql -Sql $issueCountSql)
$issueCount = ([string]$issueCountLines[$issueCountLines.Count - 1]).Trim()
```

This is a verifier-script defect only. The failure occurred before the
inventory race assertion, so it does not indicate a database, RLS, sequence,
or inventory concurrency failure.

A T16 static regression guard now rejects:

- line-leading PowerShell pipeline operators in the concurrency script;
- return of the old `$issueCount = (` expression.


## Windows final acceptance — PASS

```text
T16 LOCAL REPRODUCIBILITY: PASS
T16 T1-T15 DEBT CLEANUP CHECKS: PASS
T16 SECURITY CORE CHECKS: PASS
T16 CONCURRENCY CHECK: PASS
T16 AUDIT RESPONSIVE UI CHECK: PASS
T16 APP BUILD: PASS
T16 WORKER CHECK: PASS
Dependency lock bundle: D:\HOMETECHVN\docs\snapshots\T16_DEPENDENCY_LOCKS_20260831_182122.zip
Snapshot: D:\HOMETECHVN\docs\snapshots\T16_LOCAL_VERIFY_20260831_182440.txt
```
