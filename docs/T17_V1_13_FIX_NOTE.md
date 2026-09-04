# HomeTechVN — T17 v1.13 FIX NOTE

Date: 01/09/2026

## Windows v1.12 evidence

The integrated dataset completed and committed successfully. The failure was in
the public-warranty assertion:

```text
ERROR 42501: permission denied for table warranties
HINT: GRANT SELECT ON public.warranties TO anon
```

The correct response is **not** to grant that permission.

## Root cause

The T12 public warranty contract intentionally allows:

```text
anon EXECUTE public.warranty_public_lookup(text)
```

while intentionally denying:

```text
anon SELECT public.warranties
```

The v1.12 assertion switched to `anon` and then tried to fetch the test token
directly from `public.warranties`. The assertion itself violated the security
boundary.

Live connected-Supabase verification confirms:

```text
anon SELECT public.warranties                 = false
anon EXECUTE public.warranty_public_lookup    = true

authenticated EXECUTE dashboard_snapshot      = true
authenticated EXECUTE report_snapshot         = true
authenticated EXECUTE security_audit_snapshot = true
authenticated SELECT profiles                 = true
authenticated SELECT roles                    = true
```

## v1.13 correction

The public-warranty test now does:

```text
postgres test harness
→ read fixture lookup_token
→ store token in transaction-local custom setting
→ SET LOCAL ROLE anon
→ call public.warranty_public_lookup(token)
→ assert found=true
→ assert no internal fields leak
```

The `anon` block performs **zero direct table reads**.

## Global T17 source audit added

The T17 source checker now rejects:

- direct `FROM/JOIN/INSERT/UPDATE/DELETE public.*` inside the anon assertion
  block;
- business-table reads inside the authenticated RPC assertion block;
- token acquisition after switching to anon;
- reintroduction of `private.current_role_code()` direct calls;
- incorrect JWT-sub-before-role ordering;
- non-ASCII characters in T17 SQL fixture/assertion files.

## Windows SQL transport hardening

The fictional T17 SQL dataset and assertion text are now ASCII-only. This avoids
Windows console/code-page mojibake on the Node -> Docker -> psql verification
path.

This does **not** remove Vietnamese text from the HomeTechVN application UI.
Only temporary LOCAL verification fixture strings are normalized.

## Database impact

None.

```text
T1 → T16 migrations = 36/36 unchanged
T17 DB migration = 0
```

No GRANT/REVOKE or RLS policy is changed.
