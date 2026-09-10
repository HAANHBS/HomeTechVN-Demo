# T10 Runbook

Overlay this candidate onto the existing HomeTechVN project.
The ZIP intentionally excludes:
- `app/.env.local`
- `worker/.dev.vars`
- `node_modules`
- build output

Run one command:

```powershell
cd D:\HOMETECHVN
npm run t10:verify
```

The verifier:
1. requires exactly 30 T1–T10 migrations;
2. starts database-only local Supabase;
3. resets/replays migrations + seed;
4. runs `supabase/tests/t10_verify.sql`;
5. verifies IN_APP / Telegram / Email / Zalo ZBS / Zalo OA paths;
6. verifies RLS, dedupe, retry and attempt logs;
7. installs/builds the React app;
8. installs Worker dependencies;
9. runs `node --check`;
10. runs `wrangler deploy --dry-run`;
11. writes `docs\snapshots\T10_LOCAL_VERIFY_*.txt`.

Expected final markers:

```text
T10 LOCAL REPRODUCIBILITY: PASS
T10 FINAL CORE CHECKS: PASS
T10 APP BUILD: PASS
T10 WORKER CHECK: PASS
```
