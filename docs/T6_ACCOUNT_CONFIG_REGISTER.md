# T6 Account / Config Register

- Environment: DEV
- Supabase project: HomeTechVN
- Project ref: `puqvbenyenwemfbsqpfd`
- Region: Singapore (`ap-southeast-1`)
- Responsible person: project owner / HomeTechVN
- Created / implementation date: 30/08/2026
- Frontend environment variables: existing `app/.env.local` retained on the Windows machine
- Secret storage: backend secrets remain outside frontend/Git
- T6 remote test: PASS
- T6 Windows acceptance: PASS
- Error notes:
  - Initial T6 RLS runtime test returned `42501` because RLS helper EXECUTE had been revoked.
  - Fixed by `20260830093439_t6_rls_helper_execute.sql`.
