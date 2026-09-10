# T13 Runbook

Overlay the T13 candidate over the existing HomeTechVN directory.

The ZIP intentionally excludes:

- `app/.env.local`
- `worker/.dev.vars`
- `node_modules`
- `dist`
- `.wrangler`

Run one command:

```powershell
cd D:\HOMETECHVN
npm run t13:verify
```

The verifier:

1. requires exactly 33 T1–T13 migrations;
2. verifies the exact migration filenames;
3. starts database-only local Supabase;
4. resets and replays the complete migration chain;
5. runs `supabase/tests/t13_verify.sql`;
6. checks deterministic Sales/Payment/Repair profit coverage;
7. checks Admin/Sales/Cashier/Technician/anon permissions;
8. runs the T11 global responsive regression;
9. runs the T12 public QR/privacy regression;
10. runs the T13 Reports responsive/RPC-only checks;
11. installs pinned app dependencies;
12. runs the production TypeScript/Vite build;
13. writes `docs\snapshots\T13_LOCAL_VERIFY_*.txt`.

Expected:

```text
T13 LOCAL REPRODUCIBILITY: PASS
T13 FINAL CORE CHECKS: PASS
T13 RESPONSIVE UI CHECK: PASS
T13 APP BUILD: PASS
```
