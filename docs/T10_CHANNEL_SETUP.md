# T10 Channel Setup

## 1. Security rule

Never put a real provider token/API key in:
- source code
- `app/.env.local`
- a database setting `value`
- Notification channel JSON config
- README/checklist
- Git

Cloudflare Worker secrets are the runtime source of truth.
Database rows only record `env://...` references.

## 2. Required Worker secrets

From the `worker` directory, configure secrets with Wrangler:

```powershell
npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY
npx wrangler secret put WORKER_TRIGGER_KEY
```

Telegram:

```powershell
npx wrangler secret put TELEGRAM_BOT_TOKEN
```

Email:

```powershell
npx wrangler secret put EMAIL_API_KEY
```

Zalo:

```powershell
npx wrangler secret put ZALO_ACCESS_TOKEN
```

`SUPABASE_URL`, provider URLs and non-secret routing values may be configured
as Worker variables or deployment environment configuration.

## 3. Telegram

Worker variables/secrets:

```text
TELEGRAM_BOT_TOKEN     secret
```

Database config example:

```json
{
  "enabled": true,
  "recipients": [
    {
      "profile_id": "<HomeTechVN profile UUID>",
      "chat_id": "<Telegram chat id>"
    }
  ],
  "parse_mode": "HTML"
}
```

Only active staff profiles that have `notification.view` are accepted by
the outbox preparation function.

## 4. Email

Worker values:

```text
EMAIL_SEND_URL
EMAIL_API_KEY          secret
EMAIL_FROM
```

The T10 adapter is intentionally provider-neutral. It sends an HTTP JSON payload:

```json
{
  "from": "support@example.com",
  "to": "customer@example.com",
  "subject": "...",
  "text": "...",
  "html": "...",
  "metadata": {}
}
```

If the selected email provider uses another request contract, adapt only the
Worker adapter; do not change Notification database semantics.

## 5. Zalo

T10 supports two routing modes.

### ZBS_PHONE

Use when sending a ZBS Template Message through the customer's phone number.

Database config shape:

```json
{
  "enabled": true,
  "mode": "ZBS_PHONE",
  "template_map": {
    "WARRANTY_7D": "<approved-template-id>",
    "LICENSE_7D": "<approved-template-id>",
    "REPAIR_READY": "<approved-template-id>"
  }
}
```

Customer destination:
- `phone_normalized`, falling back to `phone`.

The outbox will not create a ZBS notification when no matching template exists.

### OA_UID

Use when the business has the customer's Zalo OA user ID and the message is
eligible under the current Zalo OA messaging rules.

Database config shape:

```json
{
  "enabled": true,
  "mode": "OA_UID",
  "template_map": {}
}
```

Customer destination:
- `customers.zalo`

## 6. Zalo Worker variables

```text
ZALO_SEND_URL
ZALO_ACCESS_TOKEN      secret
ZALO_AUTH_HEADER       default: access_token
ZALO_AUTH_SCHEME       optional
ZALO_DPOP_PROOF        optional
```

`ZALO_SEND_URL` and authorization details are deployment configuration so they
can track the exact current Zalo API generation without rewriting database
migrations.

## 7. Dry run

Before enabling real sending:

```powershell
cd D:\HOMETECHVN\worker
```

Use a local `.dev.vars` copied from `.dev.vars.example`, fill only local test
credentials, and set:

```text
DRY_RUN=true
```

Run the Worker in local development mode, then verify Notification outbox/logs.
Never commit `.dev.vars`.

## 8. Production activation order

1. Keep external channels disabled.
2. Deploy Worker with secrets.
3. Verify `/health`.
4. Test one Telegram recipient.
5. Test one email customer.
6. Test one approved Zalo ZBS template and/or OA UID.
7. Confirm `notification_logs`.
8. Enable channel routing on selected reminder rules.
9. Enable scheduled Cron.
