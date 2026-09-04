# T19 Runbook — Universal QR

## Install candidate

Extract the candidate contents over `D:\HOMETECHVN`. Keep `app/.env.local`; the candidate does not include or overwrite it.

## Verify on Windows

```powershell
cd D:\HOMETECHVN
npm run t19:verify
```

The verifier refuses a hosted Supabase URL for destructive demo/reset operations. It saves the existing `app/.env.local` in memory, starts/resets local Supabase, loads T17 fake demo data, performs real Auth/RBAC QR calls, restores the original environment file, builds the app, resets local Supabase again, and checks the clean foundation baseline.

If verification fails, send the full block beginning with `[T19 FAIL]`. Cleanup is attempted even after a primary test failure, and a cleanup error is reported separately.

## Manual acceptance

1. Sign in with each local demo role.
2. Open **Quét QR**, create a `VIEW` customer QR, download it, scan it, and confirm only **Xem** appears.
3. Create an `EDIT` repair-order QR and confirm the current role still needs `repair.update`.
4. Create a `PAY` sales-order QR for an order with balance due, sign in as Cashier, scan it, and record only a fake test payment.
5. Revoke a QR and confirm it no longer resolves.
6. Confirm camera denial falls back to pasted link/token.
7. Check 360 px, 768 px, and desktop layouts.

Never test with real customer data, real payment confirmation, passwords, secret API keys, card details, or license secrets.
