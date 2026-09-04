# T9 Account / Config Register

- Environment: DEV
- Supabase project: HomeTechVN
- Project ref: `puqvbenyenwemfbsqpfd`
- Region: Singapore (`ap-southeast-1`)
- Implementation date: 30/08/2026
- Responsible person: HomeTechVN project owner
- Frontend variables: existing Windows `app/.env.local` retained
- Browser credential: existing publishable key only
- Server execution: future Cloudflare Worker uses server-side service-role authorization
- Secret storage: outside frontend / Git
- Scheduler: Cloudflare Workers/Cron architecture retained; pg_cron not enabled by T9
- Remote T9 test: PASS
- Windows T9 acceptance: PASS
- Error/fix:
  - first service-role generator runtime attempt failed `42501 permission denied for schema private`
  - fixed by `20260830122012_t9_service_role_private_usage.sql`
  - no broader browser privilege was added
