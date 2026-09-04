# T20 Windows runbook

## 1. Preserve local configuration

Do not delete `D:\HOMETECHVN`. Extract the T20 candidate over the current folder so ignored local configuration can be preserved.

## 2. Configure the hosted demo

```powershell
cd D:\HOMETECHVN
npm run t20:configure
```

Enter only:

- `https://puqvbenyenwemfbsqpfd.supabase.co`
- the active browser-safe publishable key from Supabase Connect / API Keys.

Never enter a secret key, service-role key, database password, access token, or JWT.

If `app\.env.local` already contains the correct hosted values and `VITE_HOMETECHVN_HOSTED_DEMO=true`, skip this step.

## 3. Verify

```powershell
npm run t20:verify
```

The verifier may reset Supabase **local** during inherited integration tests. It refuses to reset the hosted URL. It restores the pre-existing `app\.env.local`, runs read-only hosted checks, builds the app/worker, and finally resets local Supabase to the clean baseline.

Required final markers:

```text
T20 LOCAL REPRODUCIBILITY: PASS
T20 LOCKED MIGRATION REGRESSION: PASS
T20 QR DATABASE SECURITY CHECK: PASS
T20 QR AUTH/RBAC INTEGRATION: PASS
T20 PRIVATE COST RLS CHECK: PASS
T20 HOSTED AUTH/API READINESS: PASS
T20 HOSTED ANON ISOLATION: PASS
T20 HOSTED PUBLIC WARRANTY CONTRACT: PASS
T20 APP BUILD: PASS
T20 WORKER CHECK: PASS
T20 CLEAN BASELINE AFTER VERIFY: PASS
T20 QR RESPONSIVE UI CHECK: PASS
```

On failure, send `docs\snapshots\T20_FAILURE_*.txt`. It contains redacted diagnostics and the cleanup result.
