# HomeTechVN T18 — Account and Configuration Register

Do not write secret values in this file. Record only identifiers and the secure
location that stores each secret.

| Item | Account / project / URL | Created or changed | Operator | Variable(s) | Secret location | Verification result | Notes / error |
|---|---|---|---|---|---|---|---|
| Frontend hosting |  |  |  | `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY` | Hosting environment | PENDING |  |
| Supabase production |  |  |  | Project ref / URL | Supabase dashboard | PENDING | Migration #1–#36 only |
| Notification Worker |  |  |  | `SUPABASE_URL`, `WORKER_TRIGGER_KEY` | Worker secrets | PENDING | `WORKER_CRON_ENABLED=false` |
| Worker database key |  |  |  | `SUPABASE_SERVICE_ROLE_KEY` | Worker secret store | PENDING | Never browser-exposed |
| Telegram |  |  |  | `TELEGRAM_BOT_TOKEN` | Worker secret store | NOT CONFIGURED | Optional |
| Email provider |  |  |  | `EMAIL_SEND_URL`, `EMAIL_API_KEY`, `EMAIL_FROM` | Worker secret store | NOT CONFIGURED | Optional |
| Zalo provider |  |  |  | `ZALO_SEND_URL`, `ZALO_ACCESS_TOKEN` | Worker secret store | NOT CONFIGURED | Optional |

## Activation record

| Gate | Date/time | Operator | Evidence / snapshot | Result | Notes |
|---|---|---|---|---|---|
| T18 Windows verifier | 2026-09-04 01:15 local | Project operator | `T18_LOCAL_VERIFY_20260904_011541.txt` | PASS | Release SHA-256 `473e12c80062632f95412e43a8eb39a0e1192e2abc701c96ff76e90e1518547e` |
| Frontend smoke test |  |  |  | PENDING |  |
| Worker `/health` |  |  |  | PENDING |  |
| Worker unauthorized `/run` |  |  |  | PENDING |  |
| Worker dry run |  |  |  | PENDING |  |
| Notification live activation |  |  |  | NOT AUTHORIZED | Requires separate approval |
