# T7 Runbook

Overlay this candidate onto the existing project. The ZIP excludes `app/.env.local`.

```powershell
cd D:\HOMETECHVN
npm run t7:verify
```

The verifier requires exactly 21 migrations, resets the local DB, runs `t7_verify.sql`, installs app dependencies, runs `tsc -b && vite build`, and writes a T7 snapshot.
