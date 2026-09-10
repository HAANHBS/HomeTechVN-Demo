# HomeTechVN — T10 MASTER CHECKLIST

## Scope
T10 — Notification Delivery.

T10 consumes DUE reminders from T9 and creates/delivers notifications through:
- IN_APP
- TELEGRAM
- EMAIL
- ZALO

External provider HTTP calls are performed by Cloudflare Worker, not PostgreSQL.

## Database
- [x] `notifications`
- [x] `notification_logs`
- [x] `reminder_rules.staff_channels`
- [x] `reminder_rules.customer_channels`
- [x] RLS from creation
- [x] authenticated direct writes revoked
- [x] `notification_summary` security_invoker
- [x] `NTF-000001`
- [x] delivery_key dedupe
- [x] outbox status: PENDING / PROCESSING / RETRYING / SENT / FAILED / CANCELLED
- [x] one attempt log per attempt
- [x] retry/backoff
- [x] stale Worker claim recovery
- [x] SKIP LOCKED claim batching
- [x] reminder closed -> unsent outbox auto-cancel
- [x] advisory lock on prepare

## Routing
- [x] staff channels: IN_APP / TELEGRAM
- [x] customer channels: EMAIL / ZALO
- [x] per Reminder Rule routing configuration
- [x] system rule defaults
- [x] customer channels only when destination exists

## Zalo
- [x] ZBS_PHONE mode
- [x] OA_UID mode
- [x] ZBS template_map per rule/event
- [x] customer phone / phone_normalized routing
- [x] customer `zalo` UID routing
- [x] Zalo access token outside DB/frontend
- [x] configurable Worker endpoint/auth header
- [x] DPoP proof variable supported when required by deployment

## Secret safety
- [x] Telegram token uses `env://TELEGRAM_BOT_TOKEN`
- [x] Email key uses `env://EMAIL_API_KEY`
- [x] Zalo token uses `env://ZALO_ACCESS_TOKEN`
- [x] sensitive settings have NULL value
- [x] config JSON rejects sensitive keys recursively
- [x] Worker recursively redacts sensitive metadata
- [x] frontend contains no service-role key/provider token
- [x] `.dev.vars` excluded from Git/package
- [x] `.dev.vars.example` contains placeholders only

## Role / RLS
- [x] Admin/Manager see full outbox
- [x] Admin/Manager see notification logs
- [x] operational users see own IN_APP only
- [x] operational users can mark own IN_APP read
- [x] channel settings require notification.manage + settings.manage
- [x] external batch claim / send result RPCs require service_role
- [x] service_role has no direct notifications SELECT

## Remote runtime
- [x] 2 IN_APP + Telegram + Email + Zalo ZBS prepared
- [x] prepare rerun idempotent
- [x] Sales RLS exposes own IN_APP only
- [x] Sales cannot edit channel config
- [x] Telegram claim -> SENT
- [x] Zalo ZBS claim -> SENT
- [x] Email fail -> RETRYING -> second attempt -> SENT
- [x] Email attempt logs = 2
- [x] Zalo OA UID -> SENT
- [x] secret config key rejection
- [x] rollback cleanup
- [x] Security Advisor: no new T10 issue
- [x] Performance Advisor: no missing-FK-index T10 issue

## Cloudflare Worker
- [x] scheduled pipeline
- [x] protected manual `/run`
- [x] `/health`
- [x] `reminder_generate`
- [x] `notification_prepare`
- [x] stale recovery
- [x] Telegram adapter
- [x] generic HTTP email adapter
- [x] Zalo OA/ZBS adapter
- [x] DRY_RUN support
- [x] Wrangler 4.127.1 pinned
- [x] Worker JS syntax parse
- [x] Windows Wrangler dry-run bundle

## Frontend
- [x] In-app inbox
- [x] mark read / mark all read
- [x] Admin/Manager outbox
- [x] retry/cancel
- [x] routing configuration
- [x] channel configuration
- [x] attempt logs
- [x] Zalo mode/template configuration
- [x] Reminder -> Notification navigation
- [x] TS/TSX syntax parse
- [x] Windows production build

## Final acceptance
- [x] T10 LOCAL REPRODUCIBILITY: PASS
- [x] T10 FINAL CORE CHECKS: PASS
- [x] T10 APP BUILD: PASS
- [x] T10 WORKER CHECK: PASS
