# T8 Runbook

Overlay the T8 candidate onto the existing HomeTechVN folder.
The ZIP intentionally excludes `app/.env.local`.

Run:

```powershell
cd D:\HOMETECHVN
npm run t8:verify
```

The verifier:
1. requires exactly 23 T1–T8 migrations;
2. starts database-only local Supabase;
3. resets/replays the local database;
4. runs `supabase/tests/t8_verify.sql`;
5. verifies Service, SERVICE Warranty, License security and role matrix;
6. installs app dependencies;
7. runs `tsc -b && vite build`;
8. creates `docs\snapshots\T8_LOCAL_VERIFY_*.txt`.
