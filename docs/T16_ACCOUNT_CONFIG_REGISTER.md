# T16 Account / Config Register

- Environment: DEV / T16 candidate
- Supabase project: HomeTechVN
- Project ref: `puqvbenyenwemfbsqpfd`
- Plan: Free
- Region: Singapore (`ap-southeast-1`)
- PostgreSQL: 17.6
- Implementation date: 31/08/2026
- Responsible person: HomeTechVN project owner
- T16 migrations:
  - `20260831104002_t16_security_audit_core_hardening.sql`
  - `20260831104029_t16_audit_search_and_security_snapshot.sql`
- Audit access permission: `audit.view`
- Roles currently mapped to audit.view: Admin, Manager
- T16 new secret: none
- Frontend credential model: existing Supabase publishable key only
- Worker secrets: unchanged; never moved into browser/database plaintext
- Leaked Password Protection: Free-plan limitation; Pro+ pre-public gate
- Security Advisor sequence warning: RESOLVED
- Performance Advisor: unused-index INFO accepted pending representative workload
- Dependency locks: generated/verified by Windows `npm run t16:verify`
- Concurrency validation: Windows `npm run t16:verify`
- Windows acceptance: PASS


## Final Windows evidence

- Dependency-lock bundle: `D:\HOMETECHVN\docs\snapshots\T16_DEPENDENCY_LOCKS_20260831_182122.zip`
- Verification snapshot: `D:\HOMETECHVN\docs\snapshots\T16_LOCAL_VERIFY_20260831_182440.txt`
- Concurrency validation: PASS
- T1–T15 debt cleanup: PASS
- App production build: PASS
- Worker check: PASS
