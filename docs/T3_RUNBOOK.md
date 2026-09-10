# HomeTechVN — T3 RUNBOOK

## Install candidate

Extract the T3 ZIP over the existing project folder:

```text
D:\HOMETECHVN
```

Do not delete the working directory first. Local `.env.local` / `config.toml` can remain.

## One-command acceptance

```powershell
cd D:\HOMETECHVN
npm run t3:verify
```

The verifier performs:

1. Validate exactly 8 T1+T2+T3 migration files.
2. Stop old local DB stack cleanly.
3. Start local PostgreSQL only.
4. `supabase db reset --local`.
5. Run `supabase/tests/t3_verify.sql` with `ON_ERROR_STOP=1`.
6. Install/update pinned frontend dependencies.
7. Run `tsc -b && vite build` through `npm --prefix app run build`.
8. Save a verification snapshot.

## Acceptance markers

```text
T3 LOCAL REPRODUCIBILITY: PASS
T3 FINAL CORE CHECKS: PASS
T3 APP BUILD: PASS
```

Historical T3 rule: any failing command blocked acceptance at that time. T3 was subsequently accepted on Windows.

## Daily development after T3 acceptance

Local app:

```powershell
npm run app:dev
```

The inventory module never writes inventory_units or inventory_transactions directly. All stock mutations use:
- inventory_receive
- inventory_issue
- inventory_adjust
