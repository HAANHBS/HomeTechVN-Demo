# T9 Runbook

Overlay the candidate over the existing HomeTechVN project.
The ZIP intentionally excludes `app/.env.local`.

Run one command:

```powershell
cd D:\HOMETECHVN
npm run t9:verify
```

The verifier:
1. requires exactly 27 T1–T9 migrations;
2. starts database-only local Supabase;
3. resets/replays migrations + seed;
4. runs `supabase/tests/t9_verify.sql`;
5. checks rule seed, dedupe, lifecycle, role matrix and service-role path;
6. installs pinned app dependencies;
7. runs TypeScript + Vite production build;
8. writes `docs\snapshots\T9_LOCAL_VERIFY_*.txt`.

Expected markers:

```text
T9 LOCAL REPRODUCIBILITY: PASS
T9 FINAL CORE CHECKS: PASS
T9 APP BUILD: PASS
```
