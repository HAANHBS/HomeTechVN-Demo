# T19 — Universal QR Operations

Status: **CANDIDATE — requires Windows/local Supabase verification**

T19 adds one internal QR control plane across the T0–T18 system. It does not modify any of the 36 locked migrations. Migration #37 stores only a SHA-256 token hash, while the QR image carries a random 256-bit token.

## Supported operations

| Resource | Fast actions | Destination |
|---|---|---|
| Customer, device | Create, view, edit | CRM |
| Product, serialized inventory | Create, view, edit | Inventory |
| Sales order | Create, view, edit, sandbox payment | Sales |
| Payment | Create, view, edit | Sales |
| Repair order | Create, view, edit | Repair |
| Warranty, warranty claim | Create, view, edit | Warranty |
| Service schedule, software license | Create, view, edit | Service & License |
| Checklist run | Create, view, edit | Checklist |
| Reminder, notification | Create, view, edit | Reminders / Notifications |

The QR intent caps available actions. A `VIEW` QR never becomes an edit QR. Current role permissions are evaluated again on every scan. Revoked or expired tokens resolve as not found.

## Safety rules

- Internal QR requires a signed-in, active profile; it never bypasses Auth or RLS.
- Private QR tables have explicit deny-all RLS policies and no table grants to `anon` or `authenticated`.
- Browser clients can execute only the three public wrappers: `qr_issue`, `qr_resolve`, and `qr_revoke`.
- Raw tokens are never stored in PostgreSQL; only `digest(token, 'sha256')` is stored.
- Do not encode passwords, service-role keys, license secrets, card data, or personal data in QR images.
- `PAY` opens the existing sales order and payment form. It does not claim that a bank transfer succeeded and is not a real payment-provider integration.
- T12 public warranty links remain separate, anonymous, read-only, masked, and use `/w/<token>`.

## Acceptance markers

```text
T19 LOCAL REPRODUCIBILITY: PASS
T19 LOCKED MIGRATION REGRESSION: PASS
T19 QR DATABASE SECURITY CHECK: PASS
T19 QR AUTH/RBAC INTEGRATION: PASS
T19 QR RESPONSIVE UI CHECK: PASS
T19 APP BUILD: PASS
T19 WORKER CHECK: PASS
T19 CLEAN BASELINE AFTER VERIFY: PASS
```

T19 is not COMPLETE until all markers pass on Windows against local Supabase.
