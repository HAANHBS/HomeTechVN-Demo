# HomeTechVN T18 — Production Release Gate

T18 converts the accepted T17 local-demo checkpoint into a production-release
candidate. It does not deploy, change the hosted database, or enable external
notification delivery.

## Locked baseline

- T17 FINAL v1.14 is the immutable input.
- Migrations #1–#36 must match `docs/T17_FINAL_INTEGRITY.txt` byte-for-byte.
- T18 adds zero database migrations; migration #37 remains reserved for the
  next real schema change.
- The full T17 verifier must pass and finish on its clean operational baseline.

## Production safety gates

The browser build must use an HTTPS non-local Supabase URL and either a modern
publishable key or a legacy `anon` JWT. A secret/service-role key, placeholder,
local URL, or any `VITE_HOMETECHVN_DEMO_*` value fails the gate.

`app/.env.local` is a working-copy file. It may remain on the Windows machine,
must be preserved byte-for-byte by the verifier, and must never appear in a
release ZIP.

The accepted T17 clean baseline may legitimately have no `app/.env.local`.
Before the first T18 verification, create it with `npm run t18:configure`. The
helper accepts only a hosted HTTPS Project URL plus a browser-safe Publishable
key (or legacy `anon` key); it rejects placeholders and elevated keys.

The Worker ships with:

```text
WORKER_CRON_ENABLED=false
DRY_RUN=true
```

The scheduled handler returns without claiming or sending notifications until
`WORKER_CRON_ENABLED` is explicitly set to `true` in the deployment platform.

## Packaging rule

The release package is built from an explicit top-level allowlist. Local config,
dependencies, build output, snapshots, backups, logs, and existing ZIP files are
excluded during staging. The completed ZIP is opened and checked before:

```text
T18 RELEASE PACKAGE SAFETY: PASS
```

The presence of `app/.env.local` in the working copy is not itself an error.
Only its presence in the staged release or ZIP is an error.
