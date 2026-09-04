# HomeTechVN — T17 v1.10 FIX NOTE

Date: 01/09/2026

## Windows v1.9 evidence

The local integration stack was healthy enough for T17:

```text
Local API/key resolution: PASS
Local Auth signup x5: PASS
Local DB container resolution: PASS
```

The SQL dataset then stopped immediately after:

```text
SET
set_config
------------
```

with an empty `set_config` result.

## Root cause

The T17 SQL established role context in the wrong order:

```sql
set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  (select id::text
   from public.profiles
   where lower(email)='demo.admin@hometechvn.example'),
  true
);
```

`public.profiles` is protected by RLS.

After switching to `authenticated`, `auth.uid()` is still NULL because the JWT
subject has not been established yet. Therefore the subquery cannot see the
profile row and returns no ID. The JWT subject remains NULL, and the first
RLS-protected business INSERT is rejected.

The inherited T3 regression did not expose this because it assigns a literal
UUID to `request.jwt.claim.sub` rather than querying `profiles` after RLS is
active.

## v1.10 correction

Every T17 authenticated role block now uses:

```text
RESET ROLE
→ resolve profile ID while current role is postgres
→ set_config(request.jwt.claim.sub)
→ SET LOCAL ROLE authenticated
→ assert auth.uid()
→ assert expected role
→ assert required permission
→ execute business workflow
```

The same correction is applied to `t17_demo_assert.sql`.

There are 11 authenticated role phases and the source checker now rejects the
old unsafe order.

## SQL diagnostics

T17 SQL execution now:

- enables verbose psql errors;
- enables SQL-error echo;
- emits named phase markers;
- prints the final Node failure detail to stdout.

This prevents Windows PowerShell from collapsing useful PostgreSQL stderr into
`System.Management.Automation.RemoteException`.

## Database impact

None.

```text
T1 → T16 migrations = 36/36 unchanged
T17 DB migration = 0
```

T17 demo fixtures remain ephemeral and the v1.9 clean-baseline-after-verify
policy is preserved.
