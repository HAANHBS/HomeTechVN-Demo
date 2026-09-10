# HomeTechVN — T10 FINAL ACCEPTANCE

Date: 30/08/2026

## Result

**T10 — Notification + Zalo: COMPLETE**

## Windows runtime evidence

```text
T10 LOCAL REPRODUCIBILITY: PASS
T10 FINAL CORE CHECKS: PASS
T10 APP BUILD: PASS
T10 WORKER CHECK: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T10_LOCAL_VERIFY_20260830_213305.txt
```

## Accepted delivery channels

```text
IN_APP
TELEGRAM
EMAIL
ZALO
```

## Accepted Zalo modes

```text
ZBS_PHONE
OA_UID
```

## Accepted T10 capabilities

- Notification outbox
- Attempt logs
- Delivery dedupe
- Retry/backoff
- Stale worker recovery
- Per-rule routing
- In-app read state
- Telegram staff delivery contract
- Email customer delivery contract
- Zalo ZBS_PHONE routing
- Zalo OA_UID routing
- Cloudflare Worker scheduled pipeline
- Worker protected manual trigger
- Recursive secret/config protection
- Provider secrets outside frontend/database values

## Locked T10 migrations

```text
20260830135438_t10_notification_schema_and_channel_config.sql
20260830135738_t10_notification_outbox_workflow.sql
20260830141222_t10_notification_config_secret_guard.sql
```

T1 through T10 migrations are now LOCKED.
T11 and later stages must add new migrations only.
