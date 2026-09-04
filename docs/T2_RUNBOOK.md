# HomeTechVN — T2 RUNBOOK

## One-command local acceptance on Windows

After extracting/copying this T2 package into `D:\HOMETECHVN`:

```powershell
cd D:\HOMETECHVN
npm install
npm run t2:verify
```

`t2:verify` will:

1. verify exactly 6 T1+T2 migrations;
2. start local Postgres only;
3. reset local DB from migrations + seed;
4. run `supabase/tests/t2_verify.sql`;
5. install app packages with `npm install --no-audit --no-fund` when needed (this also creates `app/package-lock.json` on the first Windows acceptance run);
6. run TypeScript + Vite production build;
7. save a T2 snapshot.

Required final output:

```text
T2 LOCAL REPRODUCIBILITY: PASS
T2 FINAL CORE CHECKS: PASS
T2 APP BUILD: PASS
```

## Start the app

```powershell
npm run app:dev
```

Default Vite URL is printed in the console, normally `http://localhost:5173`.

The packaged `app/.env.local` already points at the HomeTechVN remote Supabase project using its publishable key. No Secret Key is included in frontend code.
