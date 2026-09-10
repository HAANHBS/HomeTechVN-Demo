# T6 Runbook

Extract the T6 candidate over the existing project folder. The ZIP intentionally
does not include `app/.env.local`.

Run:

```powershell
cd D:\HOMETECHVN
npm run t6:verify
```

The verifier:
1. requires the exact 17-migration T1–T6 chain;
2. starts database-only local Supabase;
3. resets local Postgres from migrations + seed;
4. runs `supabase/tests/t6_verify.sql`;
5. installs pinned app dependencies;
6. runs TypeScript + Vite production build;
7. writes `docs\snapshots\T6_LOCAL_VERIFY_*.txt`.
