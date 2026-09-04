create or replace function private.report_snapshot_impl(
  p_start_date date,
  p_end_date date,
  p_bucket text default 'DAY',
  p_now timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_bucket text:=upper(coalesce(nullif(btrim(p_bucket),''),'DAY'));
  v_now timestamptz:=coalesce(p_now,now());
  v_today date:=timezone('Asia/Bangkok',coalesce(p_now,now()))::date;
  v_start date:=p_start_date;
  v_end date:=p_end_date;
  v_days integer;
  v_start_at timestamptz;
  v_end_at timestamptz;

  v_sales jsonb:=null;
  v_payments jsonb:=null;
  v_repairs jsonb:=null;
  v_inventory jsonb:=null;
  v_warranty jsonb:=null;
  v_service jsonb:=null;
  v_license jsonb:=null;
  v_profit jsonb:=null;

  v_sales_timeline jsonb:='[]'::jsonb;
  v_payment_timeline jsonb:='[]'::jsonb;
  v_repair_timeline jsonb:='[]'::jsonb;
  v_payment_methods jsonb:='[]'::jsonb;
  v_inventory_movements jsonb:='[]'::jsonb;
  v_claim_status jsonb:='[]'::jsonb;
  v_top_products jsonb:='[]'::jsonb;
  v_top_technicians jsonb:='[]'::jsonb;
  v_receivables jsonb:='[]'::jsonb;

  v_sales_profit jsonb:=null;
  v_repair_profit jsonb:=null;
  v_sales_known_revenue numeric:=0;
  v_sales_known_profit numeric:=0;
  v_sales_total_revenue numeric:=0;
  v_repair_known_revenue numeric:=0;
  v_repair_known_profit numeric:=0;
  v_repair_total_revenue numeric:=0;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;
  if not private.has_permission('report.view') then
    raise exception 'Missing permission report.view';
  end if;

  if v_start is null or v_end is null then
    raise exception 'Report start_date and end_date are required';
  end if;
  if v_start>v_end then
    raise exception 'Report start_date must be on or before end_date';
  end if;

  v_days:=v_end-v_start+1;
  if v_days<1 or v_days>366 then
    raise exception 'Report date range must be between 1 and 366 days';
  end if;
  if v_bucket not in ('DAY','WEEK','MONTH') then
    raise exception 'Report bucket must be DAY, WEEK or MONTH';
  end if;

  v_start_at:=(v_start::timestamp at time zone 'Asia/Bangkok');
  v_end_at:=((v_end+1)::timestamp at time zone 'Asia/Bangkok');

  -- SALES
  if private.has_permission('sale.view') then
    select jsonb_build_object(
      'orders_paid',count(*),
      'revenue',coalesce(sum(total_amount),0),
      'discounts',coalesce(sum(discount_amount),0),
      'average_order_value',coalesce(avg(total_amount),0),
      'current_receivable_orders',(
        select count(*) from public.sales_orders
        where status='PAYMENT_PENDING' and balance_due>0
      ),
      'current_receivables',(
        select coalesce(sum(balance_due),0) from public.sales_orders
        where status='PAYMENT_PENDING' and balance_due>0
      )
    )
    into v_sales
    from public.sales_orders
    where status in ('PAID','DELIVERED','COMPLETED')
      and paid_at>=v_start_at and paid_at<v_end_at;

    with grouped as (
      select
        case v_bucket
          when 'DAY' then date_trunc('day',timezone('Asia/Bangkok',paid_at))::date
          when 'WEEK' then date_trunc('week',timezone('Asia/Bangkok',paid_at))::date
          else date_trunc('month',timezone('Asia/Bangkok',paid_at))::date
        end as bucket,
        count(*) as orders,
        coalesce(sum(total_amount),0) as revenue
      from public.sales_orders
      where status in ('PAID','DELIVERED','COMPLETED')
        and paid_at>=v_start_at and paid_at<v_end_at
      group by 1
    )
    select coalesce(jsonb_agg(
      jsonb_build_object('bucket',bucket,'orders',orders,'revenue',revenue)
      order by bucket
    ),'[]'::jsonb)
    into v_sales_timeline
    from grouped;

    with ranked as (
      select
        i.product_id,
        i.sku_snapshot as sku,
        i.product_name_snapshot as product_name,
        coalesce(sum(i.quantity),0) as quantity,
        coalesce(sum(i.line_total),0) as line_value_before_order_discount
      from public.sales_order_items i
      join public.sales_orders o on o.id=i.sales_order_id
      where o.status in ('PAID','DELIVERED','COMPLETED')
        and o.paid_at>=v_start_at and o.paid_at<v_end_at
      group by i.product_id,i.sku_snapshot,i.product_name_snapshot
      order by quantity desc,line_value_before_order_discount desc
      limit 15
    )
    select coalesce(jsonb_agg(to_jsonb(ranked)),'[]'::jsonb)
    into v_top_products
    from ranked;

    with due as (
      select
        o.id,o.order_code,o.customer_id,c.customer_code,c.full_name as customer_name,
        o.total_amount,o.paid_amount,o.balance_due,o.payment_pending_at,o.created_at
      from public.sales_orders o
      join public.customers c on c.id=o.customer_id
      where o.status='PAYMENT_PENDING' and o.balance_due>0
      order by coalesce(o.payment_pending_at,o.created_at),o.order_code
      limit 50
    )
    select coalesce(jsonb_agg(to_jsonb(due)),'[]'::jsonb)
    into v_receivables from due;
  end if;

  -- CASH COLLECTION
  if private.has_permission('payment.view') then
    select jsonb_build_object(
      'gross_collected',coalesce(sum(amount) filter(where paid_at>=v_start_at and paid_at<v_end_at),0),
      'refunds',coalesce(sum(amount) filter(where status='REFUNDED' and refunded_at>=v_start_at and refunded_at<v_end_at),0),
      'net_cash_flow',
        coalesce(sum(amount) filter(where paid_at>=v_start_at and paid_at<v_end_at),0)
        - coalesce(sum(amount) filter(where status='REFUNDED' and refunded_at>=v_start_at and refunded_at<v_end_at),0),
      'payment_count',count(*) filter(where paid_at>=v_start_at and paid_at<v_end_at),
      'refund_count',count(*) filter(where status='REFUNDED' and refunded_at>=v_start_at and refunded_at<v_end_at)
    )
    into v_payments
    from public.payments;

    with buckets as (
      select
        case v_bucket
          when 'DAY' then date_trunc('day',timezone('Asia/Bangkok',x.event_at))::date
          when 'WEEK' then date_trunc('week',timezone('Asia/Bangkok',x.event_at))::date
          else date_trunc('month',timezone('Asia/Bangkok',x.event_at))::date
        end as bucket,
        sum(x.gross) as gross_collected,
        sum(x.refund) as refunds
      from (
        select paid_at as event_at,amount as gross,0::numeric as refund
        from public.payments
        where paid_at>=v_start_at and paid_at<v_end_at
        union all
        select refunded_at as event_at,0::numeric as gross,amount as refund
        from public.payments
        where status='REFUNDED'
          and refunded_at>=v_start_at and refunded_at<v_end_at
      ) x
      group by 1
    )
    select coalesce(jsonb_agg(jsonb_build_object(
      'bucket',bucket,
      'gross_collected',gross_collected,
      'refunds',refunds,
      'net_cash_flow',gross_collected-refunds
    ) order by bucket),'[]'::jsonb)
    into v_payment_timeline
    from buckets;

    with methods as (
      select payment_method,
             coalesce(sum(amount) filter(where paid_at>=v_start_at and paid_at<v_end_at),0) as gross_collected,
             coalesce(sum(amount) filter(where status='REFUNDED' and refunded_at>=v_start_at and refunded_at<v_end_at),0) as refunds
      from public.payments
      group by payment_method
    )
    select coalesce(jsonb_agg(jsonb_build_object(
      'payment_method',payment_method,
      'gross_collected',gross_collected,
      'refunds',refunds,
      'net_cash_flow',gross_collected-refunds
    ) order by gross_collected desc,payment_method),'[]'::jsonb)
    into v_payment_methods
    from methods
    where gross_collected<>0 or refunds<>0;
  end if;

  -- REPAIR
  if private.has_permission('repair.view') then
    select jsonb_build_object(
      'completed',count(*) filter(where status='COMPLETED' and completed_at>=v_start_at and completed_at<v_end_at),
      'completed_revenue',coalesce(sum(final_amount) filter(where status='COMPLETED' and completed_at>=v_start_at and completed_at<v_end_at),0),
      'average_turnaround_hours',coalesce(avg(extract(epoch from (completed_at-created_at))/3600)
        filter(where status='COMPLETED' and completed_at>=v_start_at and completed_at<v_end_at),0),
      'created',count(*) filter(where created_at>=v_start_at and created_at<v_end_at),
      'no_fix',(select count(*) from public.repair_status_history
        where to_status='NO_FIX' and changed_at>=v_start_at and changed_at<v_end_at),
      'cancelled',count(*) filter(where status='CANCELLED' and cancelled_at>=v_start_at and cancelled_at<v_end_at),
      'current_open',count(*) filter(where status not in ('COMPLETED','CANCELLED','NO_FIX','CUSTOMER_REJECTED')),
      'current_ready',count(*) filter(where status='READY'),
      'current_overdue',count(*) filter(where estimated_completion_at<v_now and status in ('RECEIVED','DIAGNOSING','QUOTED','AWAITING_CUSTOMER','APPROVED','WAITING_PART','REPAIRING','QC'))
    )
    into v_repairs
    from public.repair_orders;

    with grouped as (
      select
        case v_bucket
          when 'DAY' then date_trunc('day',timezone('Asia/Bangkok',completed_at))::date
          when 'WEEK' then date_trunc('week',timezone('Asia/Bangkok',completed_at))::date
          else date_trunc('month',timezone('Asia/Bangkok',completed_at))::date
        end as bucket,
        count(*) as completed,
        coalesce(sum(final_amount),0) as revenue
      from public.repair_orders
      where status='COMPLETED'
        and completed_at>=v_start_at and completed_at<v_end_at
      group by 1
    )
    select coalesce(jsonb_agg(jsonb_build_object(
      'bucket',bucket,'completed',completed,'revenue',revenue
    ) order by bucket),'[]'::jsonb)
    into v_repair_timeline from grouped;

    with ranked as (
      select
        ro.assigned_technician_id as technician_id,
        coalesce(p.full_name,p.email,'Chưa gán') as technician_name,
        count(*) as completed,
        coalesce(sum(ro.final_amount),0) as revenue
      from public.repair_orders ro
      left join public.profiles p on p.id=ro.assigned_technician_id
      where ro.status='COMPLETED'
        and ro.completed_at>=v_start_at and ro.completed_at<v_end_at
      group by ro.assigned_technician_id,p.full_name,p.email
      order by completed desc,revenue desc
      limit 15
    )
    select coalesce(jsonb_agg(to_jsonb(ranked)),'[]'::jsonb)
    into v_top_technicians from ranked;
  end if;

  -- INVENTORY: movement quantities only. T13 intentionally does not estimate stock value.
  if private.has_permission('inventory.view') then
    select jsonb_build_object(
      'active_products',count(*) filter(where is_active),
      'low_stock',count(*) filter(where is_active and low_stock),
      'out_of_stock',count(*) filter(where is_active and stock_qty<=0),
      'serialized_in_stock',(select count(*) from public.inventory_units where status='IN_STOCK'),
      'movement_in_qty',coalesce((select sum(quantity) from public.inventory_transactions
        where transaction_type in ('RECEIVE','ADJUST_IN','RETURN_IN')
          and occurred_at>=v_start_at and occurred_at<v_end_at),0),
      'movement_out_qty',coalesce((select sum(quantity) from public.inventory_transactions
        where transaction_type in ('ISSUE','ADJUST_OUT')
          and occurred_at>=v_start_at and occurred_at<v_end_at),0)
    )
    into v_inventory
    from public.product_inventory_summary;

    with movement as (
      select transaction_type,count(*) as transactions,coalesce(sum(quantity),0) as quantity
      from public.inventory_transactions
      where occurred_at>=v_start_at and occurred_at<v_end_at
      group by transaction_type
      order by transaction_type
    )
    select coalesce(jsonb_agg(to_jsonb(movement)),'[]'::jsonb)
    into v_inventory_movements from movement;
  end if;

  -- WARRANTY
  if private.has_permission('warranty.view') then
    select jsonb_build_object(
      'created',count(*) filter(where created_at>=v_start_at and created_at<v_end_at),
      'active_current',count(*) filter(where status='ACTIVE' and end_date>=v_today),
      'expiring_30d',count(*) filter(where status='ACTIVE' and end_date between v_today and v_today+30),
      'expired_unclosed',count(*) filter(where status='ACTIVE' and end_date<v_today),
      'claims_received',(select count(*) from public.warranty_claims where received_at>=v_start_at and received_at<v_end_at),
      'claims_closed',(select count(*) from public.warranty_claims where closed_at>=v_start_at and closed_at<v_end_at)
    )
    into v_warranty from public.warranties;

    with x as (
      select status,count(*) as count
      from public.warranty_claims
      where received_at>=v_start_at and received_at<v_end_at
      group by status
      order by count desc,status
    )
    select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb)
    into v_claim_status from x;
  end if;

  -- SERVICE: schema stores only last completion, not a completion-history event table.
  if private.has_permission('service.view') then
    select jsonb_build_object(
      'active_current',count(*) filter(where status='ACTIVE'),
      'overdue_current',count(*) filter(where status='ACTIVE' and next_due_date<v_today),
      'due_30d',count(*) filter(where status='ACTIVE' and next_due_date between v_today and v_today+30),
      'schedules_last_completed_in_period',count(*) filter(where last_completed_at>=v_start_at and last_completed_at<v_end_at)
    )
    into v_service
    from public.service_schedules;
  end if;

  -- LICENSE: renewals overwrite the row; T13 reports current exposure + creations, not historical renewal events.
  if private.has_permission('license.view') then
    select jsonb_build_object(
      'created',count(*) filter(where created_at>=v_start_at and created_at<v_end_at),
      'active_current',count(*) filter(where status='ACTIVE'),
      'expiring_30d',count(*) filter(where status in ('ACTIVE','SUSPENDED') and end_date between v_today and v_today+30),
      'expired_current',count(*) filter(where status='EXPIRED' or (status in ('ACTIVE','SUSPENDED') and end_date<v_today)),
      'auto_renew_current',count(*) filter(where status='ACTIVE' and auto_renew),
      'renewal_cost_exposure',coalesce(sum(renewal_cost) filter(where status='ACTIVE' and renewal_cost is not null),0)
    )
    into v_license
    from public.software_licenses;
  end if;

  -- PROFIT: only users with report.profit. These are gross-profit measures before overhead/labor.
  if private.has_permission('report.profit') then
    if private.has_permission('sale.view') then
      with order_cost as (
        select
          o.id,o.total_amount,
          count(i.id) as item_count,
          count(i.id) filter(where c.total_cost is null) as missing_cost_items,
          coalesce(sum(c.total_cost) filter(where c.total_cost is not null),0) as recorded_cost
        from public.sales_orders o
        join public.sales_order_items i on i.sales_order_id=o.id
        left join private.sales_order_item_costs c on c.sales_order_item_id=i.id
        where o.status in ('PAID','DELIVERED','COMPLETED')
          and o.paid_at>=v_start_at and o.paid_at<v_end_at
        group by o.id,o.total_amount
      )
      select
        jsonb_build_object(
          'revenue_total',coalesce(sum(total_amount),0),
          'orders_total',count(*),
          'orders_cost_complete',count(*) filter(where item_count>0 and missing_cost_items=0),
          'orders_missing_cost',count(*) filter(where missing_cost_items>0),
          'cost_covered_revenue',coalesce(sum(total_amount) filter(where item_count>0 and missing_cost_items=0),0),
          'excluded_revenue_missing_cost',coalesce(sum(total_amount) filter(where missing_cost_items>0),0),
          'recorded_product_cost',coalesce(sum(recorded_cost) filter(where item_count>0 and missing_cost_items=0),0),
          'gross_profit_known',
            coalesce(sum(total_amount-recorded_cost) filter(where item_count>0 and missing_cost_items=0),0),
          'gross_margin_known_pct',
            case when coalesce(sum(total_amount) filter(where item_count>0 and missing_cost_items=0),0)>0
              then round(100*sum(total_amount-recorded_cost) filter(where item_count>0 and missing_cost_items=0)
                / sum(total_amount) filter(where item_count>0 and missing_cost_items=0),2)
              else null end,
          'cost_coverage_revenue_pct',
            case when coalesce(sum(total_amount),0)>0
              then round(100*coalesce(sum(total_amount) filter(where item_count>0 and missing_cost_items=0),0)/sum(total_amount),2)
              else null end
        ),
        coalesce(sum(total_amount),0),
        coalesce(sum(total_amount) filter(where item_count>0 and missing_cost_items=0),0),
        coalesce(sum(total_amount-recorded_cost) filter(where item_count>0 and missing_cost_items=0),0)
      into v_sales_profit,v_sales_total_revenue,v_sales_known_revenue,v_sales_known_profit
      from order_cost;
    end if;

    if private.has_permission('repair.view') then
      with repair_cost as (
        select
          ro.id,coalesce(ro.final_amount,0) as revenue,
          count(rp.id) filter(where rp.status='ISSUED') as issued_parts,
          count(rp.id) filter(where rp.status='ISSUED' and c.total_cost is null) as missing_cost_parts,
          coalesce(sum(c.total_cost) filter(where rp.status='ISSUED' and c.total_cost is not null),0) as recorded_parts_cost
        from public.repair_orders ro
        left join public.repair_parts rp on rp.repair_order_id=ro.id
        left join private.repair_part_costs c on c.repair_part_id=rp.id
        where ro.status='COMPLETED'
          and ro.completed_at>=v_start_at and ro.completed_at<v_end_at
        group by ro.id,ro.final_amount
      )
      select
        jsonb_build_object(
          'revenue_total',coalesce(sum(revenue),0),
          'repairs_total',count(*),
          'repairs_cost_complete',count(*) filter(where missing_cost_parts=0),
          'repairs_missing_cost',count(*) filter(where missing_cost_parts>0),
          'cost_covered_revenue',coalesce(sum(revenue) filter(where missing_cost_parts=0),0),
          'excluded_revenue_missing_cost',coalesce(sum(revenue) filter(where missing_cost_parts>0),0),
          'recorded_parts_cost',coalesce(sum(recorded_parts_cost) filter(where missing_cost_parts=0),0),
          'gross_profit_after_parts_known',
            coalesce(sum(revenue-recorded_parts_cost) filter(where missing_cost_parts=0),0),
          'gross_margin_after_parts_known_pct',
            case when coalesce(sum(revenue) filter(where missing_cost_parts=0),0)>0
              then round(100*sum(revenue-recorded_parts_cost) filter(where missing_cost_parts=0)
                / sum(revenue) filter(where missing_cost_parts=0),2)
              else null end,
          'cost_coverage_revenue_pct',
            case when coalesce(sum(revenue),0)>0
              then round(100*coalesce(sum(revenue) filter(where missing_cost_parts=0),0)/sum(revenue),2)
              else null end
        ),
        coalesce(sum(revenue),0),
        coalesce(sum(revenue) filter(where missing_cost_parts=0),0),
        coalesce(sum(revenue-recorded_parts_cost) filter(where missing_cost_parts=0),0)
      into v_repair_profit,v_repair_total_revenue,v_repair_known_revenue,v_repair_known_profit
      from repair_cost;
    end if;

    v_profit:=jsonb_build_object(
      'sales',v_sales_profit,
      'repair',v_repair_profit,
      'combined',jsonb_build_object(
        'revenue_total',v_sales_total_revenue+v_repair_total_revenue,
        'cost_covered_revenue',v_sales_known_revenue+v_repair_known_revenue,
        'gross_profit_known',v_sales_known_profit+v_repair_known_profit,
        'cost_coverage_revenue_pct',
          case when (v_sales_total_revenue+v_repair_total_revenue)>0
            then round(100*(v_sales_known_revenue+v_repair_known_revenue)
              /(v_sales_total_revenue+v_repair_total_revenue),2)
            else null end
      )
    );
  end if;

  return jsonb_build_object(
    'generated_at',v_now,
    'timezone','Asia/Bangkok',
    'period',jsonb_build_object(
      'start_date',v_start,'end_date',v_end,'days',v_days,'bucket',v_bucket
    ),
    'permissions',jsonb_build_object(
      'profit',private.has_permission('report.profit'),
      'sales',private.has_permission('sale.view'),
      'payments',private.has_permission('payment.view'),
      'repairs',private.has_permission('repair.view'),
      'inventory',private.has_permission('inventory.view'),
      'warranty',private.has_permission('warranty.view'),
      'service',private.has_permission('service.view'),
      'license',private.has_permission('license.view')
    ),
    'summary',jsonb_build_object(
      'sales',v_sales,
      'payments',v_payments,
      'repairs',v_repairs,
      'inventory',v_inventory,
      'warranty',v_warranty,
      'service',v_service,
      'license',v_license,
      'profit',v_profit
    ),
    'charts',jsonb_build_object(
      'sales_timeline',v_sales_timeline,
      'payment_timeline',v_payment_timeline,
      'repair_timeline',v_repair_timeline,
      'payment_methods',v_payment_methods,
      'inventory_movements',v_inventory_movements,
      'warranty_claim_status',v_claim_status,
      'top_products',v_top_products,
      'top_technicians',v_top_technicians
    ),
    'receivables',v_receivables,
    'data_quality',jsonb_build_object(
      'profit_available',private.has_permission('report.profit'),
      'profit_basis','Gross profit from recorded product/part cost snapshots only; excludes labor, rent, tax and other overhead.',
      'sales_profit_rule','Only fully cost-covered paid orders are included in gross_profit_known. Missing-cost order revenue is excluded, never treated as zero cost.',
      'repair_profit_rule','Only completed repairs whose currently ISSUED parts all have cost snapshots are included. RETURNED parts are excluded.',
      'top_product_value_rule','line_value_before_order_discount excludes order-level discount allocation and is not used for profit.',
      'inventory_value_rule','T13 does not estimate current stock valuation.',
      'service_history_limit','service_schedules stores only last_completed_at/completion_count; T13 does not invent per-period completion events.',
      'license_history_limit','software_licenses renewal updates the current row; T13 does not invent historical renewal events.'
    )
  );
end;
$$;

revoke execute on function private.report_snapshot_impl(date,date,text,timestamptz)
from public,anon,authenticated;
grant execute on function private.report_snapshot_impl(date,date,text,timestamptz)
to authenticated;

create or replace function public.report_snapshot(
  p_start_date date,
  p_end_date date,
  p_bucket text default 'DAY',
  p_now timestamptz default now()
)
returns jsonb
language sql
set search_path=''
as $$
  select private.report_snapshot_impl(p_start_date,p_end_date,p_bucket,p_now);
$$;

revoke execute on function public.report_snapshot(date,date,text,timestamptz)
from public,anon;
grant execute on function public.report_snapshot(date,date,text,timestamptz)
to authenticated;
