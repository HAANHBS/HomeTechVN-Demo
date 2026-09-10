# HomeTechVN — T16 SECURITY / AUDIT ARCHITECTURE

Status: T16 candidate.

## 1. T1–T15 prerequisite cleanup

T16 begins only after reconciling technical debt from the accepted T1–T15
checkpoints.

Canonical register:

```text
docs/T1_T15_DEBT_REGISTER.md
```

The register distinguishes:

- fixed defects;
- resolved historical verifier defects;
- current plan limitations;
- external-provider credential limitations;
- informational Advisor findings requiring representative workload.

A limitation is never relabeled as a verified capability.

## 2. Migration chain

T16 adds two migrations:

```text
#34 20260831104002_t16_security_audit_core_hardening.sql
#35 20260831104029_t16_audit_search_and_security_snapshot.sql
#36 20260831105049_t16_audit_actor_history_independence.sql
```

T1–T13 #1–#33 remain byte-locked.

T14 and T15 added no database migration.

## 3. Sequence-counter least privilege

Before T16:

- `private.sequence_counters` had RLS enabled and no policy;
- Security Advisor reported `rls_enabled_no_policy`;
- `service_role` still had direct table privileges even though normal business
  code used postgres-owned SECURITY DEFINER helpers.

T16:

```text
sequence_counters_no_direct_access
USING false
WITH CHECK false
```

and:

```text
REVOKE ALL ... FROM service_role
```

Business code continues through:

```text
private.next_counter
private.next_simple_code
private.next_daily_code
```

These functions are SECURITY DEFINER, owned by postgres and use
`search_path=''`.

Remote post-migration result:

```text
sequence deny policy                    true
service_role direct sequence privilege  false
RLS tables without policy               0
```

## 4. Append-only audit history

The existing generic audit trigger remains the only ordinary write path into
`public.audit_logs`.

T16 hardens `public.fn_audit_row()`:

```text
SECURITY DEFINER
owner postgres
search_path=''
```

All referenced objects are schema-qualified.

Direct mutation is prohibited:

```text
UPDATE    blocked
DELETE    blocked
TRUNCATE  blocked
```

using two database triggers.

`service_role` also loses INSERT/UPDATE/DELETE/TRUNCATE table privileges.

The ordinary authenticated role retains only SELECT subject to the existing
`audit.view` RLS policy.

## 5. Audit search API

Audit UI never reads `audit_logs` directly.

RPC:

```text
public.audit_search(...)
```

Contract:

- authenticated only;
- requires `audit.view`;
- Admin and Manager currently hold `audit.view`;
- default range 30 days;
- maximum range 366 days;
- maximum 200 rows per request;
- cursor pagination via `p_before_id`;
- filters: table, action, actor, record id;
- action limited to INSERT / UPDATE / DELETE.

This bounds payload size and keeps authorization in the database.

## 6. Security posture RPC

```text
public.security_audit_snapshot()
```

requires `audit.view` and returns database posture only:

- total audit rows;
- latest audit timestamp;
- number of audited tables;
- append-only guard count;
- audit trigger search_path;
- count of RLS-enabled application tables;
- count of RLS tables without policy;
- sequence deny-policy state;
- service-role sequence direct-access state.

It never returns:

- database password;
- Supabase API keys;
- Worker secrets;
- SMTP/provider secrets;
- Telegram token;
- Zalo token.

Remote T16 snapshot after migration:

```text
RLS enabled application tables  38
RLS tables without policy       0
Audit rows                       213
Audited tables                   33
Append-only guards               2
Sequence deny policy             true
Service-role direct sequence     false
```

## 7. Supabase Security Advisor

After T16 migration #34:

```text
rls_enabled_no_policy on private.sequence_counters  RESOLVED
```

The only remaining Security Advisor warning is:

```text
Leaked Password Protection Disabled
```

Supabase currently documents leaked-password protection as available on Pro
Plan and above.

The HomeTechVN project is currently Free.

Therefore this is recorded as:

```text
PLAN LIMITATION / N-A ON CURRENT FREE PLAN
```

It remains a mandatory pre-public check if the project is upgraded to Pro+.

T16 does not fake this platform capability in application code.

## 8. Performance Advisor

Performance Advisor currently reports `unused_index` INFO entries.

The DEV database has little representative user workload.

T16 deliberately does not delete operational/FK/search indexes solely to make
an INFO advisor list empty.

Index removal requires representative workload and query-plan evidence.

## 9. Runtime-log review

Last-24-hour review at T16 implementation:

```text
Auth logs     no error records returned
API logs      health/ready calls returned HTTP 200
Storage logs  health/tenant calls returned HTTP 200
```

Postgres logs include historical migration/test-fixture errors and the initial
T15 Session Pooler password failure. Those issues are already resolved by their
accepted stage versions and are recorded in the debt register rather than
silently erased.

## 10. True concurrency gate

T3/T4 had deferred a true parallel-session race test.

T16 closes that debt on Windows:

### Counter race

16 independent PostgreSQL sessions simultaneously call the same logical
counter.

Acceptance:

```text
16 unique codes
RACE-000001 ... RACE-000016
no duplicate
no gap
```

### Inventory race

Fixture stock:

```text
1
```

Two independent authenticated sessions concurrently request:

```text
ISSUE 1
```

Acceptance:

```text
exactly 1 success
exactly 1 insufficient-stock failure
persisted ISSUE rows = 1
```

The product row `FOR UPDATE` lock must serialize the stock decision.

## 11. Dependency reproducibility gate

Historical T2 documentation promised package locks, but accepted artifact ZIPs
did not retain them.

T16 Windows verifier closes this debt by generating and validating:

```text
/package-lock.json
/app/package-lock.json
/worker/package-lock.json
```

for the exact pinned package manifests, then running `npm ci` for all three
package roots.

It exports:

```text
docs/snapshots/T16_DEPENDENCY_LOCKS_<timestamp>.zip
```

with SHA-256 hashes.

This lock bundle is part of T16 final acceptance material.

## 12. Locked inherited policies

T16 does not change:

- T11 responsive PC/tablet/phone standard;
- T12 public Warranty minimal-data contract;
- T13 conservative profit calculation;
- T14 no offline transaction writes / no Background Sync;
- T15 backup FULL gate / restore-to-disposable-target policy.
