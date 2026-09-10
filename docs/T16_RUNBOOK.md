# HomeTechVN — T16 RUNBOOK

Overlay the T16 candidate on the accepted T15 project:

```text
D:\HOMETECHVN
```

Run one command:

```powershell
cd D:\HOMETECHVN
npm run t16:verify
```

## What the verifier does

1. T16 static security/debt source scan.
2. Generate root/app/worker `package-lock.json`.
3. Run `npm ci` for root/app/worker.
4. Export dependency-lock ZIP + hashes.
5. Require exact 36 migrations.
6. Reset/replay local Supabase.
7. Run every SQL verifier T1 through T13.
8. Run T16 security/audit SQL verifier.
9. Re-run T15 full local restore drill on T16 schema.
10. Run 16 concurrent sequence sessions.
11. Run two concurrent inventory ISSUE sessions against stock=1.
12. Re-run T11/T12/T13/T14 static regressions.
13. Run T16 Audit UI/security source check.
14. Build React/TypeScript/Vite PWA.
15. Inspect generated PWA manifest/Service Worker.
16. Run Worker JS syntax check.
17. Write final T16 snapshot.

## Acceptance output

```text
T16 LOCAL REPRODUCIBILITY: PASS
T16 T1-T15 DEBT CLEANUP CHECKS: PASS
T16 SECURITY CORE CHECKS: PASS
T16 CONCURRENCY CHECK: PASS
T16 AUDIT RESPONSIVE UI CHECK: PASS
T16 APP BUILD: PASS
T16 WORKER CHECK: PASS
Dependency lock bundle: ...
Snapshot: ...
```

Keep the generated dependency-lock bundle. It contains no secret and is required
to preserve the transitive dependency state in the final T16 checkpoint.
