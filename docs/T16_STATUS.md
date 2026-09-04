# HomeTechVN — T16 STATUS

Status: **CANDIDATE v1.1 — Windows concurrency verifier parser fix applied; acceptance pending**

## Remote migration

```text
#34 20260831104002_t16_security_audit_core_hardening.sql
#35 20260831104029_t16_audit_search_and_security_snapshot.sql
#36 20260831105049_t16_audit_actor_history_independence.sql
```

Total:

```text
T1 → T16 = 36 migrations
```

The first 33 migrations remain locked and unchanged.

## Remote security result

Functional transaction test: **PASS**.

Validated remotely:

```text
sequence deny policy                    PASS
service_role direct sequence access     BLOCKED
sequence helper after revoke            PASS
fn_audit_row search_path=''             PASS
audit append-only UPDATE                BLOCKED
audit_search Admin                      PASS
audit_search Sales                      DENIED
security_audit_snapshot                 PASS
```

Current posture snapshot:

```text
RLS enabled application tables          38
RLS tables without policy               0
Audit rows                              213
Audited tables                          33
Append-only audit guards                2
Sequence deny policy                    true
Service-role direct sequence privilege  false
```

## Security Advisor

Resolved:

```text
private.sequence_counters RLS no-policy warning
```

Remaining:

```text
Leaked Password Protection Disabled
```

Disposition:

```text
PLAN LIMITATION — current project is Free.
Supabase documents this feature as Pro+.
```

It remains in `PRE_PUBLIC_AUTH_SECURITY.md` as a plan-aware launch gate.

## Performance Advisor

Only `unused_index` INFO entries.

No index is removed merely because the pre-production database has not yet
generated representative index usage statistics.

## T1–T15 cleanup

See:

```text
docs/T1_T15_DEBT_REGISTER.md
```

All known current code/database defects found in review have either:

- been fixed;
- already been resolved in the accepted stage;
- or are explicitly classified as platform/external/workload limitations.

Two test/reproducibility debts require the Windows T16 gate:

```text
true multi-session concurrency
root/app/worker package locks + npm ci
```

## Pending Windows

Run:

```powershell
npm run t16:verify
```

Required final markers:

```text
T16 LOCAL REPRODUCIBILITY: PASS
T16 T1-T15 DEBT CLEANUP CHECKS: PASS
T16 SECURITY CORE CHECKS: PASS
T16 CONCURRENCY CHECK: PASS
T16 AUDIT RESPONSIVE UI CHECK: PASS
T16 APP BUILD: PASS
T16 WORKER CHECK: PASS
```

The verifier also creates:

```text
docs\snapshots\T16_DEPENDENCY_LOCKS_*.zip
docs\snapshots\T16_LOCAL_VERIFY_*.txt
```


## v1.1 correction

Windows v1.0 stopped in `t16-concurrency-check.ps1` with a PowerShell 5.1
parser error before concurrency assertions executed.

v1.1 fixes only the verifier expression used to read the final persisted ISSUE
count. Database migrations #1–#36 are unchanged.

Run the complete verifier again:

```powershell
npm run t16:verify
```


# T16 FINAL STATUS — 31/08/2026

Status: **COMPLETE & LOCKED**

Authoritative Windows acceptance:

```text
T16 LOCAL REPRODUCIBILITY: PASS
T16 T1-T15 DEBT CLEANUP CHECKS: PASS
T16 SECURITY CORE CHECKS: PASS
T16 CONCURRENCY CHECK: PASS
T16 AUDIT RESPONSIVE UI CHECK: PASS
T16 APP BUILD: PASS
T16 WORKER CHECK: PASS
Dependency lock bundle: D:\HOMETECHVN\docs\snapshots\T16_DEPENDENCY_LOCKS_20260831_182122.zip
Snapshot: D:\HOMETECHVN\docs\snapshots\T16_LOCAL_VERIFY_20260831_182440.txt
```

Database chain:

```text
T1 → T16 = 36 migrations
```

T1–T13 #1–#33 remain locked byte-for-byte.
T16 #34–#36 are now also locked.
