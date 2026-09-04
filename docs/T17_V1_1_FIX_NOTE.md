# HomeTechVN — T17 v1.1 FIX NOTE

Date: 31/08/2026

## Windows v1.0 finding

The local database reset completed all 36 migrations and the base seed.
T17 then failed because the loader required only legacy CLI variable names:

```text
ANON_KEY
SERVICE_ROLE_KEY
```

Current Supabase tooling is transitioning to publishable/secret API keys.

## v1.1 correction

T17 no longer requires a secret/service-role key for demo-user creation.

Login-capable local demo users are created through:

```text
POST /auth/v1/signup
```

using only the local public client key.

Accepted key aliases:

```text
PUBLISHABLE_KEY
SUPABASE_PUBLISHABLE_KEY
ANON_KEY
SUPABASE_ANON_KEY
```

The loader still refuses hosted/non-local API hosts and captures
`supabase status -o env` silently.

## Database impact

None.

```text
T1 → T16 = 36 migrations unchanged
T17 DB migration = 0
```
