# T12 Build / Test

## Remote database — PASS

T12 was tested through an `anon` role transaction with rollback.

Verified:

- public function execute grant
- no anon SELECT on protected Warranty/Customer tables
- valid opaque token
- invalid token
- unknown token
- ACTIVE payload
- phone masking
- serial masking
- UUID/internal-id exclusion
- claim issue exclusion
- latest claim status only
- cleanup after rollback

## Supabase Advisor — PASS for T12

No new T12 security issue was reported.

Existing project notices remain unchanged:

- `private.sequence_counters`: RLS without policy, intentionally private defense-in-depth.
- leaked-password protection remains a pre-public Auth hardening item.
- `unused_index` findings are INFO from a DEV database with no representative production workload.

## Static UI — PASS

```text
T11 responsive table scan: PASS (25 tables)
T11 touch/focus/mobile foundation: PASS
T11 dashboard responsive structure: PASS
T11 RESPONSIVE UI CHECK: PASS
T12 public route before auth gate: PASS
T12 anonymous RPC-only privacy scan: PASS
T12 QR generate/copy/download/print: PASS
T12 Cloudflare noindex/no-referrer headers: PASS
T12 RESPONSIVE PUBLIC UI CHECK: PASS
```

## Pending

The artifact environment could not finish npm registry installation, so no claim is made here for the real React/Vite production build. Windows `npm run t12:verify` is the final build acceptance.


## v1.1 Windows failure correction

Observed first Windows failure:

```text
ERROR: new row for relation "warranties" violates check constraint "warranties_void_fields"
```

Root cause: verifier fixture `WAR-260830-1203` used `status='VOID'` without the
required `void_reason` field defined by the locked T7 warranty schema.

Correction:

```text
VOID fixture now has: void_reason = 'T12 verifier fixture'
```

No migration or runtime application code was changed for this correction.
The corrected SQL verifier was executed remotely under transaction rollback: PASS.


## Windows final acceptance — PASS

```text
T12 LOCAL REPRODUCIBILITY: PASS
T12 FINAL CORE CHECKS: PASS
T12 RESPONSIVE UI CHECK: PASS
T12 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T12_LOCAL_VERIFY_20260830_235308.txt
```
