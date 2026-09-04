# HomeTechVN — T2 Account / Configuration Register

Date: 29/08/2026
Responsible: HomeTechVN project owner + ChatGPT implementation support

## Supabase (reused from T1; no new account created)

| Field | Value |
|---|---|
| Project | HomeTechVN |
| Project ref | `puqvbenyenwemfbsqpfd` |
| Project URL | `https://puqvbenyenwemfbsqpfd.supabase.co` |
| Region | `ap-southeast-1` |
| Plan | Free |
| Admin Auth email | `hometechvn@outlook.com` |
| T2 remote migration result | PASS |
| T2 RLS/runtime role tests | PASS |
| Security Advisor after T2 | no new T2 warning |

## Frontend environment

| Variable | Purpose | Storage |
|---|---|---|
| `VITE_SUPABASE_URL` | public project URL | `app/.env.local` |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | public browser-safe Supabase key | `app/.env.local` |
| backend Supabase Secret Key | not used by T2 frontend | NOT present in `app/` |

`app/.env.local` is excluded from Git by the root `.gitignore`. The ZIP includes a local DEV copy so the current machine can test immediately.

## Dependency installation

| Item | State |
|---|---|
| versions in `app/package.json` | pinned exactly |
| artifact-runtime npm install | BLOCKED: npm registry DNS timeout |
| Windows npm install | PASS — T2 Windows acceptance completed |
| Dependency lockfiles | Historical retention debt; T16 Windows dependency-lock gate generates/verifies root/app/worker locks and exports them for the accepted checkpoint |
