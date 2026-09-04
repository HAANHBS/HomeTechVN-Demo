# HomeTechVN — T17 v1.12 FIX NOTE

Date: 01/09/2026

## Windows v1.11 evidence

The T17 integrated dataset completed all major workflows:

- completed sale;
- full payment;
- delivery checklist;
- sale warranty;
- closed warranty claim;
- completed repair;
- repair warranty;
- READY repair;
- recurring service;
- expiring software license;
- reminder generation;
- notification preparation.

The dataset committed successfully. The first integration assertion then failed:

```text
T17 DEMO FAIL: receivable fixture missing
```

## Root cause

The demo SQL comment said the second order would remain `PAYMENT_PENDING`, but
the SQL only executed:

```text
sale_create
→ sale_add_item
→ sale_confirm
```

The actual T4 state machine intentionally makes `sale_confirm()` return:

```text
CONFIRMED
```

for a non-zero order.

`PAYMENT_PENDING` is entered only through `sale_record_payment()` when the
recorded total paid is greater than zero but less than the order total. That
RPC also sets `payment_pending_at`, which the T9 `RECEIVABLE_DUE` reminder
requires.

Therefore the assertion was correct; the T17 dataset fixture was incomplete.

## v1.12 correction

The receivable order is now created and confirmed during the existing Sales
phase. During the existing Cashier phase T17 records:

```text
partial payment = 100000
order total     = 660000
balance due     = 560000
```

Expected resulting order:

```text
status             = PAYMENT_PENDING
paid_amount        = 100000
balance_due        = 560000
payment_pending_at = NOT NULL
```

The integration assertion also verifies the actual payment record and requires
a `RECEIVABLE_DUE` reminder for this order.

## Log compaction

The T17 SQL scripts now redirect normal query-result output to `/dev/null`.

The Windows verifier keeps:

- T17 SQL phase markers;
- PASS/FAIL markers;
- PostgreSQL errors and context.

It no longer prints multi-kilobyte JSON rows for every RPC call. This makes the
next failure, if any, directly readable.

## Database impact

None.

```text
T1 → T16 migrations = 36/36 unchanged
T17 DB migration = 0
```

The T17 fixture remains local/ephemeral and the final empty-first-run cleanup
policy remains unchanged.
