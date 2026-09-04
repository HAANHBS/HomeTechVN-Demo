# T7 Account / Config Register

- Environment: DEV
- Supabase project: HomeTechVN
- Project ref: `puqvbenyenwemfbsqpfd`
- Region: Singapore (`ap-southeast-1`)
- Implementation date: 30/08/2026
- Responsible person: HomeTechVN project owner
- Frontend environment: existing Windows `app/.env.local` retained
- Browser credential: existing publishable key only
- Server lookup: server/service-role only; no browser execution
- Secret storage: outside frontend/Git
- Remote T7 test: PASS
- Windows T7 acceptance: PASS
- Error note: missing covering FK index for `warranties.inventory_unit_id` was found by Advisor and fixed in `20260830110102_t7_warranty_inventory_unit_index.sql`.
