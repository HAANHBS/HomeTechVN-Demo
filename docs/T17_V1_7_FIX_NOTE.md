# HomeTechVN — T17 v1.7 FIX NOTE

Date: 01/09/2026

## Root cause found from the Windows v1.6 log

`t17-demo-load.ps1` contained **two definitions** of `Read-SupabaseEnv`:

- the newer definition accepted `-Node` and delegated discovery to Node;
- a stale older definition later in the same file accepted `-Npx`.

PowerShell keeps the last function definition, so the stale function silently
overrode the new one. The later call:

```text
Read-SupabaseEnv -Node $node
```

therefore failed with:

```text
A parameter cannot be found that matches parameter name 'Node'.
```

The same stale block also referenced helper functions left over from earlier
iterations, so another patch inside that PowerShell loader would not be a
reliable fix.

## v1.7 architecture correction

The T17 demo loader is rewritten in Node.js:

```text
scripts/t17-demo-load.mjs
```

It now owns:

- local Supabase start/reset;
- local config resolution;
- Auth signup;
- SQL demo load/assertion through Docker psql;
- password sign-in;
- JWT/RLS role verification;
- Dashboard RPC verification;
- local demo `.env.local` generation;
- sanitized demo snapshot.

`t17-demo-load.ps1` is now only a tiny function-free compatibility wrapper.
The authoritative T17 verifier invokes the Node loader directly, so the old
PowerShell loader implementation is no longer on the acceptance path.

## New regression gates

Before Windows runtime work:

- Node loader self-test;
- local-config resolver self-test;
- managed PowerShell lexical check;
- duplicate PowerShell function-name detection;
- source check that rejects any verifier call to `t17-demo-load.ps1`.

## Connected Supabase validation

The connected HomeTechVN project was checked directly before packaging v1.7:

```text
migration history: 36
demo users: 0
demo customers: 0
required T17 RPC signatures: present
RLS-enabled application tables without policy: 0
```

No T17 database migration is added.
