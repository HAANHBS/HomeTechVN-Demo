# HomeTechVN — T13 REPORT DEFINITIONS

Status: T13 candidate metric contract.

All business-day boundaries use `Asia/Bangkok`.
The report period is inclusive by local date and may span 1–366 days.

## 1. Access rules

`report.view` is required to call `report_snapshot()`.

Module data is returned only when the same account also has that module's view
permission.

`report.profit` is separate. Only Admin/Manager currently have it.

A role without `report.profit` receives:

```json
"profit": null
```

and receives no product/part cost values in report summaries or charts.

## 2. Sales

Recognized sales revenue:

- order status: `PAID`, `DELIVERED`, or `COMPLETED`
- period anchor: `sales_orders.paid_at`
- measure: `sales_orders.total_amount`

This is an operational sales-revenue report, not an accounting revenue
recognition policy.

Current receivables:

- current `PAYMENT_PENDING` orders
- `balance_due > 0`
- generated `balance_due = total_amount - paid_amount`

Receivables are a **current snapshot**, not historical receivables as of the
report end date.

Top-product `line_value_before_order_discount` comes from sales-order item
line totals. Order-level discounts are not allocated to products, so this value
is not used for profit calculations.

## 3. Cash collection and refunds

Gross collected:

- payment amount counted by `paid_at`
- includes a payment that may later be refunded

Refunds:

- `status = REFUNDED`
- counted by `refunded_at`

Net cash flow:

```text
gross collected - refunds
```

This definition correctly handles a payment collected in one period and
refunded in another.

## 4. Repair

Completed repair revenue:

- `repair_orders.status = COMPLETED`
- period anchor: `completed_at`
- value: `final_amount`

Average turnaround:

```text
completed_at - created_at
```

`NO_FIX` events are counted from `repair_status_history.changed_at`, not from
the order's latest `updated_at`.

Current open/READY/overdue counts are current operational snapshots.

## 5. Inventory

T13 reports:

- active product count
- low-stock count
- out-of-stock count
- serialized units currently in stock
- inventory movement quantities by type

T13 **does not estimate current inventory valuation**. The existing data model
does not provide a sufficiently rigorous lot/valuation method for an auditable
current-stock value.

## 6. Warranty

Reports include:

- warranties created in period
- active current warranties
- current warranties expiring within 30 days
- active records whose end date has passed
- claims received in period
- claims closed in period
- claim-status distribution

## 7. Recurring service

`service_schedules` stores:

- `completion_count`
- `last_completed_at`
- `last_completion_id`

It does not store a separate completion-history event for every occurrence.

Therefore T13 reports only schedules whose **latest completion** falls in the
period. It does not infer or invent a historical count of all service
completions in the period.

## 8. Software / License

The current `software_licenses` row is updated when renewed.

Without a renewal-history event table, T13 reports:

- licenses created in period
- current active/expired exposure
- current 30-day expiry exposure
- current auto-renew count
- current configured renewal-cost exposure

It does **not** invent historical renewal-event revenue.

## 9. Sales gross profit

Only accounts with `report.profit` receive this section.

Sales item cost comes from:

```text
private.sales_order_item_costs
```

A paid order is cost-complete only when **every item in that order** has a
non-null captured `total_cost`.

For a cost-complete order:

```text
known gross profit = order total_amount - sum(captured item costs)
```

If any item cost is missing:

- the whole order revenue is excluded from `gross_profit_known`
- the revenue is counted in `excluded_revenue_missing_cost`
- the missing cost is **never interpreted as 0**

Coverage:

```text
cost_coverage_revenue_pct =
  cost-covered sales revenue / total sales revenue × 100
```

## 10. Repair gross profit after parts

Repair cost comes from:

```text
private.repair_part_costs
```

Only parts whose current `repair_parts.status = ISSUED` count toward cost.

Parts that were issued and later `RETURNED` are excluded, even though their
historical cost snapshot remains stored.

A completed repair is cost-complete when every currently ISSUED part has a
non-null cost snapshot. A labor-only repair with no issued parts is considered
parts-cost complete.

Known repair gross profit:

```text
final_amount - recorded cost of currently ISSUED parts
```

This is explicitly **gross profit after recorded parts**, not net profit.

## 11. Combined gross profit

Combined known gross profit combines only cost-covered Sales and Repair revenue.

The calculation excludes:

- labor/payroll
- rent
- electricity/utilities
- tax
- bank/payment fees
- marketing
- depreciation
- other overhead

Therefore no T13 figure should be labeled "net profit".

## 12. Interpretation rule

Always inspect `cost_coverage_revenue_pct` before using gross-profit numbers.

If coverage is materially below 100%, do not extrapolate the known gross margin
to uncovered revenue without separate analysis.
