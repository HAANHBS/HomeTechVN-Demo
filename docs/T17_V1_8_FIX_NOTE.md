# HomeTechVN — T17 v1.8 FIX NOTE

Date: 01/09/2026

## Windows v1.7 evidence

The Windows verifier proved the inherited baseline:

```text
T15 FULL LOCAL RESTORE DRILL: PASS
T15 APP DATA RESTORE DRILL: PASS
T16 CONCURRENCY CHECK: PASS
```

The T17 failure occurred only when resolving the local client API key after a
fresh reset. The resolver saw the database, but no publishable/anon key.

## Root cause

T17 previously used:

```text
supabase db start
```

after `supabase stop --no-backup`.

That starts the database-oriented local path but T17 requires the full local
stack, including Auth/GoTrue and the API gateway.

Supabase's own local-stack runtime documents a second timing behavior: `DB_URL`
is available as soon as Postgres is up, while `API_URL` and `PUBLISHABLE_KEY`
are reported only after GoTrue/Auth is ready. Their test harness retries
`supabase status -o json` for this reason.

The observed Windows output — `DB_URL` without a client API key immediately
after reset — matches this condition.

## v1.8 correction

### Full-stack startup

T17 now uses:

```text
supabase start
```

instead of:

```text
supabase db start
```

in both the verifier and standalone demo loader.

### Auth-readiness retry

`t17-resolve-local-config.mjs` retries structured:

```text
supabase status -o json
```

until the local stack reports both API URL and publishable/anon key.

Only after the readiness retry does it use compatibility fallbacks:

```text
status -o env
status pretty output
actual running Docker container environment
```

No secret/service-role key is required.

### No second Auth restart

The authoritative T17 verifier already starts/resets the clean local stack
before inherited regression tests.

It now invokes:

```text
t17-demo-load.mjs --no-reset
```

so T17 does not reset/restart Auth immediately before the real login/JWT tests.

## Database impact

None.

```text
T1 → T16 migrations = 36/36 unchanged
T17 DB migration = 0
```
