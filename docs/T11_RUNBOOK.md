# T11 Runbook

Overlay this candidate onto the existing HomeTechVN directory.
The package excludes `app/.env.local` and all dependency/build output.

Run one command:

```powershell
cd D:\HOMETECHVN
npm run t11:verify
```

The verifier:

1. requires exactly 31 T1–T11 migrations;
2. starts local database-only Supabase;
3. resets/replays the entire migration baseline;
4. runs `supabase/tests/t11_verify.sql`;
5. runs `scripts/t11-ui-check.mjs`;
6. verifies all TSX tables keep narrow-screen overflow protection;
7. installs pinned app dependencies;
8. runs `tsc -b && vite build`;
9. writes `docs\snapshots\T11_LOCAL_VERIFY_*.txt`.
