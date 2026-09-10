# HomeTechVN — T17 DEMO INTEGRATION ARCHITECTURE

Status: T17 candidate.

## Goal

T17 proves that the accepted modules work together as one coherent system.

T17 is intentionally **local/demo only** and does not seed demo customers,
orders, repairs or credentials into the hosted production Supabase project.

## Database migration policy

T17 adds **zero** database migrations.

```text
T1 → T16 = 36 migrations
T17 DB migration = 0
```

The exact #1–#36 migration chain remains unchanged.

## Local-only safety gate

`scripts/t17-demo-load.ps1` obtains the local Supabase CLI status and refuses
to continue unless the API host is one of:

```text
127.0.0.1
localhost
::1
```

A hosted `https://<project>.supabase.co` URL is rejected.

This prevents the destructive demo reset/seed workflow from being aimed at the
production project.

## Login-capable demo users

Supabase documents that inserting a placeholder row directly into `auth.users`
does not create a password-login user.

T17 therefore creates login-capable demo users through the local Auth signup API
using the LOCAL service-role key held in process memory only.

Accounts:

```text
demo.admin@hometechvn.example       Admin
demo.manager@hometechvn.example     Manager
demo.sales@hometechvn.example       Sales
demo.technician@hometechvn.example  Technician
demo.cashier@hometechvn.example     Cashier
```

Shared LOCAL demo password is injected into `app/.env.local` by the loader.

It is intentionally not hard-coded in frontend source and is not a production
credential.

## Integrated business scenario

The demo dataset crosses module boundaries:

### CRM / Devices

- four fictional customers;
- four fictional devices;
- customer note;
- Vietnamese names/addresses and normalized phone data.

### Products / Inventory

- serialized Dell laptop;
- bulk printer power supply;
- bulk wireless mouse;
- intentionally low-stock toner;
- real inventory receive RPCs;
- serialized inventory-unit tracking;
- private cost snapshots through existing inventory workflow.

### Sales / Payments / Checklist

Completed sale:

```text
Sales creates order
→ serialized + bulk product
→ CONFIRMED
→ Cashier records full payment
→ Sales completes required checklist
→ DELIVERED
→ COMPLETED
```

A second unpaid order remains `PAYMENT_PENDING` to drive the receivable reminder.

### Warranty

The completed serialized laptop sale creates an active SALE warranty.

A warranty claim then follows:

```text
RECEIVED
→ CHECKING
→ APPROVED
→ IN_SERVICE
→ QC
→ READY
→ RETURNED
→ CLOSED
```

The public warranty token is tested through the anonymous public lookup wrapper.

### Repair / Inventory / Warranty

Completed printer repair:

```text
RECEIVED
→ DIAGNOSING
→ AWAITING_CUSTOMER
→ APPROVED
→ planned part
→ issued inventory part
→ REPAIRING
→ QC
→ READY
→ RETURNED
→ COMPLETED
→ REPAIR warranty
```

A second laptop repair intentionally stops at `READY` to demonstrate
ready/uncollected reminders.

### Recurring Service

One active maintenance schedule is due in seven days.

### Software / License

One Microsoft 365 demo license:

- active;
- expires in seven days;
- uses only a `vault://...` secret reference;
- no plaintext license secret is stored.

### Reminders / Notifications

T17 runs:

```text
reminder_generate(now())
notification_prepare(now())
```

The resulting demo is designed to include reminders for multiple source types,
including warranty/license/service/repair/receivable/low-stock conditions.

IN_APP notifications are verified.

### Dashboard / Reports / Audit / Public Warranty

T17 asserts:

- Dashboard snapshot;
- Report snapshot;
- Security/Audit snapshot;
- audit event coverage;
- public Warranty lookup with minimal payload;
- no internal IDs/token metadata exposed by the public lookup contract.

## Real Auth integration

After loading the dataset, the loader performs actual password sign-in against
local Supabase Auth for all five roles.

For each access token it calls:

```text
self-profile RLS + `roles.code` metadata
```

through local PostgREST and verifies the expected role.

Demo Admin also calls:

```text
dashboard_snapshot
```

using the real JWT.

This tests:

```text
Auth → JWT → PostgREST → RLS/permissions → business RPC
```

instead of simulating only a SQL claim.

## UI isolation

The loader writes ignored local configuration:

```text
app/.env.local
```

including:

```text
VITE_HOMETECHVN_DEMO_MODE=true
VITE_HOMETECHVN_DEMO_ACCOUNTS=...
VITE_HOMETECHVN_DEMO_PASSWORD=...
```

When these values are absent:

- no demo account quick-fill buttons render;
- no local-demo banner renders.

The public Warranty route is evaluated before the private authenticated UI and
does not receive the private demo banner.

## Data privacy

All demo customers, phone numbers, devices, serials and company names are
fictional.

The demo marker records:

```text
mode = LOCAL_ONLY
contains_real_customer_data = false
```

T17 must never use real customer data for demo integration acceptance.


## v1.5 Node resolver boundary

Local API/key discovery moved out of Windows PowerShell into `scripts/t17-resolve-local-config.mjs`. Both `t17:verify` and `t17:demo-load` start with Node-based PowerShell static validation and resolver self-tests before PowerShell is invoked.
