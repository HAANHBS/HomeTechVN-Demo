# HomeTechVN — T17 BUILD / TEST

## Artifact-side static checks

Pending packaging validation includes:

- exact 36 migration chain;
- no T17 DB migration;
- local-only URL safety gate;
- no hosted production URL in demo loader;
- no real service-role key in source;
- no hard-coded frontend demo account/password;
- integrated workflow tokens;
- Auth password/JWT-role test contract;
- inherited T15/T16 regression guards;
- responsive/PWA source regressions.

## Authoritative Windows verifier

`npm run t17:verify` performs:

1. T17 source/security scan.
2. T16 dependency-lock + `npm ci` gate.
3. exact 36 migrations.
4. local DB reset.
5. T1–T13 SQL regressions.
6. T16 Security/Audit SQL regression.
7. T15 full restore drill.
8. T16 multi-session concurrency test.
9. T17 local Auth signup demo user creation.
10. T17 integrated demo dataset.
11. T17 database assertions.
12. five real password logins.
13. five JWT → role assertions.
14. Admin JWT → Dashboard RPC.
15. T11–T14/T17 static UI/privacy/PWA regressions plus T15/T16 concrete regression guards.
16. Vite/PWA production build in demo mode.
17. Worker check.
18. snapshot output.

No Windows PASS is claimed before this completes.


### T17 v1.5 full reliability pass

See `docs/T17_V1_5_FULL_REVIEW.md` and `docs/T17_REAL_REMOTE_VALIDATION.md`. PowerShell source is globally normalized for Windows PowerShell 5.1 and `npm run t17:verify` now performs an independent Node static gate before entering PowerShell.
