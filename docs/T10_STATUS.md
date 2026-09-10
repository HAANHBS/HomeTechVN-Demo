# HomeTechVN — T10 STATUS

Status: **CANDIDATE — waiting for Windows acceptance**

## Remote Supabase result
T10 schema, outbox workflow, role/RLS, retry/logging and Zalo routing tests: PASS.

## T10 migrations

```text
20260830135438_t10_notification_schema_and_channel_config.sql
20260830135738_t10_notification_outbox_workflow.sql
20260830141222_t10_notification_config_secret_guard.sql
```

Total candidate migration chain: **30 migrations T1–T10**.

T1–T9 remain locked and unchanged.

## Supported channels

```text
IN_APP     staff
TELEGRAM   staff
EMAIL      customer
ZALO       customer
```

Zalo modes:

```text
ZBS_PHONE  ZBS Template Message through customer phone
OA_UID     Zalo OA message through customer Zalo UID
```

## Live-provider limitation

Remote runtime tests validate the outbox, routing, provider payload contract,
retry state machine and Worker RPC contract without using real Telegram/email/Zalo
credentials.

A real message to external providers is a deployment/configuration acceptance step.
Do not store provider secrets in the database or frontend.

## Final acceptance

T10 becomes COMPLETE after Windows returns:

```text
T10 LOCAL REPRODUCIBILITY: PASS
T10 FINAL CORE CHECKS: PASS
T10 APP BUILD: PASS
T10 WORKER CHECK: PASS
```


# T10 FINAL STATUS — 30/08/2026

Status: **COMPLETE**

Windows acceptance:

```text
T10 LOCAL REPRODUCIBILITY: PASS
T10 FINAL CORE CHECKS: PASS
T10 APP BUILD: PASS
T10 WORKER CHECK: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T10_LOCAL_VERIFY_20260830_213305.txt
```

The T10 migration chain is now LOCKED.
Do not edit, squash, rename or reorder T1–T10 migrations.
