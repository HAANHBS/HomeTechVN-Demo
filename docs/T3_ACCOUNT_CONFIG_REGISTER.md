# HomeTechVN — T3 ACCOUNT / CONFIG REGISTER

Date: 30/08/2026
Responsible: HomeTechVN project owner + ChatGPT implementation assistant

## Supabase

- Project: HomeTechVN
- Project ref: puqvbenyenwemfbsqpfd
- Region: ap-southeast-1 (Singapore)
- Plan: Free
- Project URL: https://puqvbenyenwemfbsqpfd.supabase.co
- Admin Auth account: hometechvn@outlook.com
- Environment: DEV

## Environment variables

Frontend requires:
- VITE_SUPABASE_URL
- VITE_SUPABASE_PUBLISHABLE_KEY

Storage location:
- `app/.env.local` on the development PC
- example only in `app/.env.example`

Backend secret/service keys are not used in T3 frontend code.

## T3 migrations

- 20260830051756 — t3_product_inventory — remote PASS
- 20260830052012 — t3_performance_indexes_and_settings_policy — remote PASS

## Test result

Remote database tests: PASS.
Windows local reset + app production build: PASS — accepted after T3 verification.

## Error / limitation notes

- Artifact environment npm registry access timed out, therefore no false production-build PASS was recorded there.
- Parallel concurrent-session stock test is not yet performed; database functions use product-row `FOR UPDATE` locking by design and sequential negative-stock protection is verified.
