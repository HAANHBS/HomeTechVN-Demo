# HomeTechVN — T17 v1.11 FIX NOTE

Date: 01/09/2026

## Windows v1.10 evidence

JWT subject setup returned a real UUID, then the T17 Admin guard failed:

```text
ERROR 42501: permission denied for function current_role_code
```

## Root cause

`private.current_role_code()` is intentionally not executable by the
`authenticated` role. Live Supabase verification confirms:

```text
private.current_role_code()
  authenticated EXECUTE = false

private.has_permission(text)
  authenticated EXECUTE = true
```

v1.10 violated the T1 security boundary by calling the internal role helper
after switching to `authenticated`.

## v1.11 correction

No security grant is relaxed.

Each T17 phase now uses:

```text
postgres context
→ set JWT subject
→ verify profiles.role_id -> roles.code while still postgres
→ SET LOCAL ROLE authenticated
→ assert auth.uid() is present
→ assert required permission via private.has_permission(...)
→ run business workflow
```

Direct `private.current_role_code()` calls in T17 dataset/assert SQL are zero.

Role correctness is still validated by both the privileged SQL mapping and the
real password-login/JWT/PostgREST role metadata test.

## Database impact

None.

```text
T1 → T16 migrations = 36/36 unchanged
T17 DB migration = 0
```

Ephemeral demo cleanup and empty-first-run policies remain unchanged.
