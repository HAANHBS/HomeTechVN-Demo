# HomeTechVN — T17 LOCAL DEMO GUIDE

## Load/reset demo

From the project root:

```powershell
npm run t17:demo-load
```

This command is destructive to the **local Supabase database only**.

It refuses non-local Supabase API URLs.

The command:

1. starts local Supabase;
2. resets local DB from migrations + base seed;
3. creates five login-capable demo users through local Auth signup API;
4. loads the integrated demo dataset;
5. runs database integration assertions;
6. signs in all five users with passwords through real local Auth;
7. verifies JWT → database role mapping;
8. verifies Demo Admin Dashboard RPC;
9. writes `app/.env.local` for the local stack and enables demo UI.

## Demo accounts

All are fictional and LOCAL only:

```text
demo.admin@hometechvn.example
demo.manager@hometechvn.example
demo.sales@hometechvn.example
demo.technician@hometechvn.example
demo.cashier@hometechvn.example
```

Shared password after `t17:demo-load`:

```text
HomeTechVN#Demo2026!
```

This is a deliberately public LOCAL demo password, not a production secret.

## UI

With the demo environment enabled, the login page shows quick-fill role buttons.

Authenticated pages display:

```text
LOCAL DEMO · KHÔNG DÙNG DỮ LIỆU THẬT
```

## Important

Do not copy `app/.env.local` into a hosted deployment.

T18 Production must build without the demo environment variables.


## v1.5 Node resolver boundary

Local API/key discovery moved out of Windows PowerShell into `scripts/t17-resolve-local-config.mjs`. Both `t17:verify` and `t17:demo-load` start with Node-based PowerShell static validation and resolver self-tests before PowerShell is invoked.
