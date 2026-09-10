# T12 Runbook

Overlay the T12 candidate onto the existing HomeTechVN folder.

The ZIP intentionally excludes:

- `app/.env.local`
- `worker/.dev.vars`
- `node_modules`
- `dist`
- `.wrangler`

Run one command:

```powershell
cd D:\HOMETECHVN
npm run t12:verify
```

The verifier:

1. requires exactly 32 T1–T12 migrations;
2. starts database-only local Supabase;
3. resets/replays the complete migration chain;
4. runs `supabase/tests/t12_verify.sql` as part of local Postgres verification;
5. verifies anonymous lookup and privacy boundaries;
6. reruns the global T11 responsive UI regression gate;
7. runs T12 public-route/QR/privacy static checks;
8. installs pinned app dependencies, including QR generator;
9. runs `tsc -b && vite build`;
10. writes `docs\snapshots\T12_LOCAL_VERIFY_*.txt`.

Expected final markers:

```text
T12 LOCAL REPRODUCIBILITY: PASS
T12 FINAL CORE CHECKS: PASS
T12 RESPONSIVE UI CHECK: PASS
T12 APP BUILD: PASS
```


## v1.1

If v1.0 failed on `warranties_void_fields`, overlay the **contents** of
`HOMETECHVN_T12_v1.1` onto `D:\HOMETECHVN` and rerun the same one-command verifier.
No database migration repair/reset outside the verifier is required.
