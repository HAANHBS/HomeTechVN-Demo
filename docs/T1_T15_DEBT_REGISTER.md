# HomeTechVN — T1 → T15 TECHNICAL DEBT REGISTER

Reviewed: 31/08/2026  
T16 prerequisite: no known unresolved code/database correctness defect may be silently carried forward.

| ID | Origin | Item | Classification | T16 disposition |
|---|---|---|---|---|
| D01 | T1 | `private.sequence_counters` RLS enabled without policy | SECURITY WARN | **FIXED** by T16 #34: explicit deny-all policy |
| D02 | T1 | `service_role` had direct table grants on sequence storage | LEAST-PRIVILEGE | **FIXED** by T16 #34: all direct grants revoked; SECURITY DEFINER helpers retained |
| D03 | T1 | `fn_audit_row()` SECURITY DEFINER search path was `public, auth` | HARDENING | **FIXED** by T16 #34: `search_path=''`, all names qualified |
| D04 | T1–T15 | `audit_logs` could be directly mutated by sufficiently privileged backend code | AUDIT INTEGRITY | **FIXED** by T16 #34: append-only UPDATE/DELETE/TRUNCATE guards + service-role mutation grants revoked |
| D05 | T1–T15 | Audit browsing had no bounded RPC/UI | OPERABILITY | **FIXED** by T16 #35 + Audit UI: permission gate, max 200/request, max 366 days |
| D06 | T1/T2 | Leaked Password Protection Advisor warning | PLAN LIMITATION | **NOT FIXABLE ON CURRENT FREE PLAN**. Supabase documents feature as Pro+. Pre-public checklist now plan-aware. |
| D07 | T3/T4 | True multi-session race test was deferred | TEST COVERAGE | **CLOSING IN T16 WINDOWS GATE**: concurrent sequence generation + concurrent single-stock inventory issue |
| D08 | T2 onward | `package-lock.json` promised but not retained in artifact checkpoints | REPRODUCIBILITY | **CLOSING IN T16 WINDOWS GATE**: root/app/worker lock generation + `npm ci` + exported lock bundle |
| D09 | T10 | Telegram/Email/Zalo real provider send not executed | EXTERNAL CREDENTIAL LIMITATION | **NOT A CODE PASS CLAIM**. Outbox/Worker contract remains tested; real live-send stays external until credentials are intentionally supplied. |
| D10 | T1–T15 | Performance Advisor `unused_index` INFO on low-workload DEV DB | ACCEPTED INFO | **NO BLIND INDEX REMOVAL**. Re-evaluate with representative production workload/query stats. |
| D11 | T1–T15 | Old STATUS/CHECKLIST files retained stale `PENDING` text after later Windows acceptance | DOCUMENTATION DEBT | **FIXED**: historical acceptance entries reconciled to authoritative PASS evidence |
| D12 | T1 | Bootstrap helper retained `TODO` marker | DOCUMENTATION/OPS | **FIXED**: replaced by explicit REQUIRED INPUT guard; still never stores password |
| D13 | T15 | Windows PowerShell `GetRelativePath` incompatibility | RESOLVED RUNTIME BUG | **FIXED in T15 v1.1**, regression guard retained |
| D14 | T15 | restore drill attempted privileged backend termination / active DB clone | RESOLVED VERIFIER BUG | **FIXED in T15 v1.2** with independent `template0` scratch DB |
| D15 | T15 | JSON literal quoting through PowerShell → docker → psql | RESOLVED VERIFIER BUG | **FIXED in T15 v1.3** via PostgreSQL `jsonb_build_object` |
| D16 | Historical logs | Earlier fixture/migration authoring errors appear in Postgres log | HISTORICAL/RESOLVED | Corresponding accepted stage verifier now PASS; not treated as current production defect |
| D17 | T14 | Offline business writes | BY-DESIGN PROHIBITION | Remains locked: no Background Sync / no offline transaction replay |
| D18 | T15 | Storage backup credentials absent while Storage is empty | CONDITIONALLY N/A | Current accepted backup had zero Storage objects. Once object count > 0, T15 refuses FULL until S3/rclone backup is configured. |

## Exit criteria before T16 finalization

T16 Windows verifier must close D07 and D08 and prove:

- exact migration chain T1→T16;
- old 33 migration hashes unchanged;
- T16 security SQL tests PASS;
- parallel counter generation has no duplicate codes;
- two concurrent inventory issues against stock=1 produce exactly one success;
- dependency locks generated and `npm ci` works;
- Audit UI responsive + RPC-only;
- T11–T15 regression checks;
- app build + Worker syntax check.

Items D06, D09 and D10 are not hidden:

- D06 = platform plan limitation;
- D09 = absent external-provider credentials;
- D10 = non-actionable INFO without representative workload.

None is allowed to be mislabeled as a verified capability.
