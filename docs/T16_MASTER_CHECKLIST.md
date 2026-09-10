# HomeTechVN — T16 MASTER CHECKLIST

## T1–T15 debt cleanup
- [x] canonical T1–T15 debt register
- [x] stale historical Windows `PENDING` acceptance docs reconciled
- [x] T1 bootstrap stale TODO removed
- [x] T15 GetRelativePath regression remains removed
- [x] T15 pg_terminate_backend regression remains removed
- [x] T15 command-line JSON marker regression remains removed
- [x] T10 provider live-send classified external-credential limitation
- [x] leaked-password warning classified current Free-plan limitation
- [x] unused-index INFO classified workload-dependent, no blind removal
- [x] dependency lock retention debt closed on Windows
- [x] T3/T4 true multi-session concurrency debt closed on Windows

## Database / security
- [x] T1–T13 migration bytes unchanged 33/33
- [x] T16 migration #34 applied remote
- [x] T16 migration #35 applied remote
- [x] T16 migration #36 applied remote
- [x] audit actor UUID preserved independently of Auth-user lifecycle
- [x] total remote migration chain = 36
- [x] sequence deny-all RLS policy
- [x] service_role direct sequence grants revoked
- [x] sequence SECURITY DEFINER helper still works remote
- [x] fn_audit_row search_path=''
- [x] audit UPDATE guard
- [x] audit DELETE guard
- [x] audit TRUNCATE guard
- [x] service_role audit mutation privileges revoked
- [x] bounded audit_search RPC
- [x] audit_search max 200 rows
- [x] audit_search max 366 days
- [x] audit.view required
- [x] anon RPC denied
- [x] Sales audit RPC denied
- [x] security_audit_snapshot RPC
- [x] Security Advisor sequence warning resolved
- [x] remote RLS tables without policy = 0
- [x] remote audit append-only guards = 2
- [x] remote service-role direct sequence privilege = false

## Runtime review
- [x] Auth logs reviewed
- [x] API logs reviewed
- [x] Storage logs reviewed
- [x] Postgres logs reviewed
- [x] historical test/migration errors classified
- [x] no current API/Storage health failure observed

## Audit UI
- [x] audit.view route gate
- [x] Dashboard Audit navigation
- [x] RPC-only data access
- [x] date filter
- [x] table filter
- [x] action filter
- [x] record-id filter
- [x] cursor pagination
- [x] old/new JSON detail
- [x] security posture cards
- [x] responsive table wrapper
- [x] responsive detail modal
- [x] no frontend secret

## Static regression
- [x] T11 responsive source check PASS
- [x] T12 public Warranty/privacy source check PASS
- [x] T13 Reports source check PASS
- [x] T14 PWA source check PASS
- [x] T16 security source check PASS
- [x] Worker JS syntax PASS

## Windows verifier corrections
- [x] T16 v1.0 `t16-concurrency-check.ps1` parser defect reproduced from Windows log
- [x] T16 v1.1 concurrency PowerShell parser regression fixed
- [x] static guard rejects line-leading pipeline regression

## Windows final gate
- [x] dependency lock generation root/app/worker PASS
- [x] npm ci root/app/worker PASS
- [x] T1→T13 SQL regressions PASS on T16 schema
- [x] T16 SECURITY CORE CHECKS PASS
- [x] T15 full restore regression PASS on T16 schema
- [x] 16-session counter concurrency PASS
- [x] stock=1 two-session inventory race PASS
- [x] T16 AUDIT RESPONSIVE UI CHECK PASS
- [x] T16 APP BUILD PASS
- [x] T16 WORKER CHECK PASS
- [x] T16 LOCAL REPRODUCIBILITY PASS
- [x] T16 T1-T15 DEBT CLEANUP CHECKS PASS
