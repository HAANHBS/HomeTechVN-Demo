# HomeTechVN — T12 STATUS

Status: **CANDIDATE — waiting for Windows acceptance**

## T12 migration

```text
20260830154502_t12_public_warranty_lookup.sql
```

Candidate chain: **32 migrations T1–T12**.

T1–T11 remain locked and unchanged.

## Remote acceptance — PASS

- public lookup runs as `anon`
- no anon table SELECT on Warranty/Customer
- payload masking/privacy checks
- invalid and unknown token behavior
- remote rollback cleanup
- Supabase Security Advisor review
- Supabase Performance Advisor review

## Browser route

```text
https://<HomeTechVN-domain>/w/<64-char-opaque-token>
```

Cloudflare Pages can serve the path through its SPA fallback because the app has no top-level `404.html`. `app/public/_headers` applies `noindex`, `no-referrer` and `no-store` to `/w/*`.

## Pending

T12 becomes COMPLETE only after Windows returns:

```text
T12 LOCAL REPRODUCIBILITY: PASS
T12 FINAL CORE CHECKS: PASS
T12 RESPONSIVE UI CHECK: PASS
T12 APP BUILD: PASS
```


## v1.1 verifier fixture correction — 30/08/2026

The first Windows `t12:verify` run correctly stopped on the locked T7 constraint
`warranties_void_fields`: the T12 test fixture inserted `status='VOID'` while
leaving `void_reason` NULL.

v1.1 fixes **test data only**:

- `supabase/tests/t12_verify.sql` now includes `void_reason` for the VOID fixture.
- All 32 migrations T1–T12 are unchanged.
- The corrected full T12 SQL verifier was rerun remotely inside `BEGIN/ROLLBACK`
  and completed without error.
- T12 remains CANDIDATE until the Windows verifier returns all four PASS markers.


# T12 FINAL STATUS — 30/08/2026

Status: **COMPLETE**

Windows acceptance:

```text
T12 LOCAL REPRODUCIBILITY: PASS
T12 FINAL CORE CHECKS: PASS
T12 RESPONSIVE UI CHECK: PASS
T12 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T12_LOCAL_VERIFY_20260830_235308.txt
```

The T12 migration chain is now LOCKED.
Do not edit, squash, rename or reorder T1–T12 migrations.
