# HomeTechVN — T17 v1.14 FIX NOTE

Date: 01/09/2026

## Windows v1.13 evidence

After the final local database reset, the verifier failed with:

```text
T17 final baseline is not empty: reminder_rules=12
```

and then printed:

```text
[T17 CLEANUP WARNING] Could not restore app/.env.local after failure.
```

## Root cause 1 — reminder_rules are system foundation data

The 12 rows in `public.reminder_rules` are not demo/business data. They are
locked system configuration inserted by the T9 migration:

```text
WARRANTY_30D
WARRANTY_7D
LICENSE_30D
LICENSE_7D
MAINTENANCE_7D
REPAIR_READY
REPAIR_UNCOLLECTED_3D
REPAIR_UNCOLLECTED_7D
QUOTE_WAITING_24H
REPAIR_OVERDUE
RECEIVABLE_DUE
LOW_STOCK
```

A correct first-run baseline must therefore contain exactly:

```text
reminder_rules total      = 12
system rules              = 12
non-system/demo rules     = 0
```

All transactional/Auth/business data must still be zero.

v1.13 incorrectly treated every table in the baseline query as a zero-row
business table.

## Root cause 2 — app env restore ran twice

The success path restored `app/.env.local` before the final DB reset and deleted
the temporary backup.

When the incorrect reminder-rule assertion then failed, the catch block tried
to restore the same env backup a second time. The backup was already removed,
so the verifier printed a cleanup warning.

## v1.14 correction

The clean-baseline gate now requires:

```text
Auth users/profiles             = 0
customers/devices               = 0
products/inventory              = 0
sales/payments                  = 0
repairs                         = 0
warranties/claims               = 0
services/licenses               = 0
reminder instances              = 0
notifications/logs              = 0

system reminder_rules           = exactly the locked 12
non-system reminder_rules       = 0
```

The exact rule-code set is verified, not only the count.

`app/.env.local` restoration now has an explicit completion flag, so catch
cleanup is idempotent and will not attempt a second restore after success.

## Database impact

None.

```text
T1 → T16 migrations = 36/36 unchanged
T17 DB migration = 0
```
