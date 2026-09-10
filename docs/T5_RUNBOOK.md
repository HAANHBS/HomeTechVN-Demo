# HomeTechVN T5 — Windows Runbook

1. Extract T5 candidate over the existing `D:\HOMETECHVN` folder.
2. Do not delete `app\.env.local`; it is intentionally not shipped in the ZIP.
3. Run only:

```powershell
cd D:\HOMETECHVN
npm run t5:verify
```

The verifier:
- checks exactly 14 locked migrations
- starts local PostgreSQL only
- resets/replays migrations + seed
- runs `t5_verify.sql` in a rollback-safe transaction
- installs pinned app dependencies
- runs `tsc -b && vite build`
- writes `docs\snapshots\T5_LOCAL_VERIFY_<timestamp>.txt`

T5 is accepted only when all three final PASS markers are printed.
