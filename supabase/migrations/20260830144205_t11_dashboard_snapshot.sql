create or replace function private.dashboard_snapshot_impl(
  p_days integer default 30,
  p_now timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_days integer:=coalesce(p_days,30);
  v_now timestamptz:=coalesce(p_now,now());
  v_today date;
  v_start_date date;
  v_start_at timestamptz;
  v_end_at timestamptz;
  v_today_start timestamptz;
  v_today_end timestamptz;
  v_result jsonb;
  v_sales jsonb:=null;
  v_repairs jsonb:=null;
  v_inventory jsonb:=null;
  v_warranty jsonb:=null;
  v_service jsonb:=null;
  v_license jsonb:=null;
  v_reminders jsonb:=null;
  v_notifications jsonb:=null;
  v_customers jsonb:=null;
  v_sales_daily jsonb:='[]'::jsonb;
  v_repair_status jsonb:='[]'::jsonb;
  v_notification_channels jsonb:='[]'::jsonb;
  v_low_stock jsonb:='[]'::jsonb;
  v_repair_attention jsonb:='[]'::jsonb;
  v_reminder_attention jsonb:='[]'::jsonb;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not private.has_permission('dashboard.view') then raise exception 'Missing permission dashboard.view'; end if;
  if v_days not in (7,30,90) then raise exception 'Dashboard period must be 7, 30 or 90 days'; end if;

  v_today:=timezone('Asia/Bangkok',v_now)::date;
  v_start_date:=v_today-(v_days-1);
  v_start_at:=(v_start_date::timestamp at time zone 'Asia/Bangkok');
  v_end_at:=((v_today+1)::timestamp at time zone 'Asia/Bangkok');
  v_today_start:=(v_today::timestamp at time zone 'Asia/Bangkok');
  v_today_end:=((v_today+1)::timestamp at time zone 'Asia/Bangkok');

  if private.has_permission('customer.view') then
    select jsonb_build_object(
      'active',count(*) filter(where status='ACTIVE'),
      'new_period',count(*) filter(where created_at>=v_start_at and created_at<v_end_at),
      'new_today',count(*) filter(where created_at>=v_today_start and created_at<v_today_end)
    ) into v_customers from public.customers;
  end if;

  if private.has_permission('sale.view') then
    select jsonb_build_object(
      'orders_period',count(*) filter(where status<>'CANCELLED' and created_at>=v_start_at and created_at<v_end_at),
      'orders_today',count(*) filter(where status<>'CANCELLED' and created_at>=v_today_start and created_at<v_today_end),
      'sales_value_period',coalesce(sum(total_amount) filter(where status in ('PAID','DELIVERED','COMPLETED') and created_at>=v_start_at and created_at<v_end_at),0),
      'sales_value_today',coalesce(sum(total_amount) filter(where status in ('PAID','DELIVERED','COMPLETED') and created_at>=v_today_start and created_at<v_today_end),0),
      'balance_due',coalesce(sum(balance_due) filter(where status='PAYMENT_PENDING' and balance_due>0),0),
      'payment_pending_orders',count(*) filter(where status='PAYMENT_PENDING' and balance_due>0)
    ) into v_sales from public.sales_orders;

    select coalesce(jsonb_agg(jsonb_build_object('date',d.day_value,'orders',coalesce(s.orders,0),'value',coalesce(s.value,0)) order by d.day_value),'[]'::jsonb)
    into v_sales_daily
    from (select generate_series(v_start_date,v_today,interval '1 day')::date as day_value) d
    left join (
      select timezone('Asia/Bangkok',created_at)::date as day_value,
             count(*) filter(where status<>'CANCELLED') as orders,
             coalesce(sum(total_amount) filter(where status in ('PAID','DELIVERED','COMPLETED')),0) as value
      from public.sales_orders
      where created_at>=v_start_at and created_at<v_end_at
      group by 1
    ) s on s.day_value=d.day_value;
  end if;

  if private.has_permission('payment.view') then
    v_sales:=coalesce(v_sales,'{}'::jsonb)||jsonb_build_object(
      'payments_received_period',coalesce((select sum(amount) from public.payments where status='COMPLETED' and paid_at>=v_start_at and paid_at<v_end_at),0),
      'payments_received_today',coalesce((select sum(amount) from public.payments where status='COMPLETED' and paid_at>=v_today_start and paid_at<v_today_end),0)
    );
  end if;

  if private.has_permission('repair.view') then
    select jsonb_build_object(
      'open',count(*) filter(where status not in ('COMPLETED','CANCELLED','NO_FIX','CUSTOMER_REJECTED')),
      'ready',count(*) filter(where status='READY'),
      'waiting_part',count(*) filter(where status='WAITING_PART'),
      'awaiting_customer',count(*) filter(where status='AWAITING_CUSTOMER'),
      'overdue',count(*) filter(where estimated_completion_at is not null and estimated_completion_at<v_now and status in ('RECEIVED','DIAGNOSING','QUOTED','AWAITING_CUSTOMER','APPROVED','WAITING_PART','REPAIRING','QC')),
      'completed_period',count(*) filter(where completed_at>=v_start_at and completed_at<v_end_at),
      'completed_today',count(*) filter(where completed_at>=v_today_start and completed_at<v_today_end)
    ) into v_repairs from public.repair_orders;

    select coalesce(jsonb_agg(jsonb_build_object('status',status,'count',cnt) order by cnt desc,status),'[]'::jsonb)
    into v_repair_status
    from (select status,count(*) as cnt from public.repair_orders where status not in ('COMPLETED','CANCELLED') group by status) x;

    select coalesce(jsonb_agg(to_jsonb(x) order by x.rank_key,x.created_at),'[]'::jsonb)
    into v_repair_attention
    from (
      select ro.id,ro.repair_code,ro.status,ro.priority,ro.estimated_completion_at,ro.ready_at,ro.created_at,
             c.full_name as customer_name,
             case when ro.estimated_completion_at is not null and ro.estimated_completion_at<v_now then 0 when ro.status='READY' then 1 when ro.status='AWAITING_CUSTOMER' then 2 else 3 end as rank_key
      from public.repair_orders ro
      left join public.customers c on c.id=ro.customer_id
      where ro.status in ('READY','AWAITING_CUSTOMER','WAITING_PART','REPAIRING','QC')
         or (ro.estimated_completion_at is not null and ro.estimated_completion_at<v_now and ro.status not in ('COMPLETED','CANCELLED','NO_FIX','CUSTOMER_REJECTED'))
      order by rank_key,ro.created_at
      limit 8
    ) x;
  end if;

  if private.has_permission('inventory.view') then
    select jsonb_build_object(
      'active_products',count(*) filter(where is_active),
      'low_stock',count(*) filter(where is_active and low_stock),
      'out_of_stock',count(*) filter(where is_active and stock_qty<=0),
      'serialized_in_stock',coalesce((select count(*) from public.inventory_units where status='IN_STOCK'),0)
    ) into v_inventory from public.product_inventory_summary;

    select coalesce(jsonb_agg(to_jsonb(x) order by x.stock_qty,x.sku),'[]'::jsonb)
    into v_low_stock
    from (
      select product_id,sku,name,stock_qty,min_stock,track_serial
      from public.product_inventory_summary
      where is_active and low_stock
      order by stock_qty,sku
      limit 8
    ) x;
  end if;

  if private.has_permission('warranty.view') then
    select jsonb_build_object(
      'active',count(*) filter(where status='ACTIVE'),
      'expiring_7d',count(*) filter(where status='ACTIVE' and end_date between v_today and v_today+7),
      'expiring_30d',count(*) filter(where status='ACTIVE' and end_date between v_today and v_today+30),
      'expired_unclosed',count(*) filter(where status='ACTIVE' and end_date<v_today)
    ) into v_warranty from public.warranties;
  end if;

  if private.has_permission('service.view') then
    select jsonb_build_object(
      'active',count(*) filter(where status='ACTIVE'),
      'due_7d',count(*) filter(where status='ACTIVE' and next_due_date between v_today and v_today+7),
      'overdue',count(*) filter(where status='ACTIVE' and next_due_date<v_today),
      'completed_period',coalesce(sum(completion_count) filter(where last_completed_at>=v_start_at and last_completed_at<v_end_at),0)
    ) into v_service from public.service_schedules;
  end if;

  if private.has_permission('license.view') then
    select jsonb_build_object(
      'active',count(*) filter(where status='ACTIVE'),
      'expiring_7d',count(*) filter(where status in ('ACTIVE','SUSPENDED') and end_date between v_today and v_today+7),
      'expiring_30d',count(*) filter(where status in ('ACTIVE','SUSPENDED') and end_date between v_today and v_today+30),
      'expired',count(*) filter(where status='EXPIRED' or (status in ('ACTIVE','SUSPENDED') and end_date<v_today))
    ) into v_license from public.software_licenses;
  end if;

  if private.has_permission('notification.view') or private.has_permission('notification.manage') then
    select jsonb_build_object(
      'due',count(*) filter(where status='DUE'),
      'pending',count(*) filter(where status='PENDING'),
      'snoozed',count(*) filter(where status='SNOOZED'),
      'urgent_due',count(*) filter(where status='DUE' and priority='URGENT')
    ) into v_reminders from public.reminders;

    select coalesce(jsonb_agg(to_jsonb(x) order by x.priority_rank,x.due_at),'[]'::jsonb)
    into v_reminder_attention
    from (
      select id,reminder_code,title,message,priority,due_at,source_type,source_label,
             case priority when 'URGENT' then 0 when 'HIGH' then 1 when 'NORMAL' then 2 else 3 end as priority_rank
      from public.reminders
      where status='DUE'
      order by priority_rank,due_at
      limit 8
    ) x;

    select jsonb_build_object(
      'in_app_unread',count(*) filter(where channel='IN_APP' and recipient_profile_id=v_uid and read_at is null),
      'failed',case when private.has_permission('notification.manage') then count(*) filter(where status='FAILED') else null end,
      'retrying',case when private.has_permission('notification.manage') then count(*) filter(where status='RETRYING') else null end
    ) into v_notifications from public.notifications;

    if private.has_permission('notification.manage') then
      select coalesce(jsonb_agg(jsonb_build_object('channel',channel,'sent',sent,'failed',failed,'pending',pending) order by channel),'[]'::jsonb)
      into v_notification_channels
      from (
        select channel,
               count(*) filter(where status='SENT' and created_at>=v_start_at and created_at<v_end_at) as sent,
               count(*) filter(where status='FAILED' and created_at>=v_start_at and created_at<v_end_at) as failed,
               count(*) filter(where status in ('PENDING','RETRYING','PROCESSING')) as pending
        from public.notifications
        group by channel
      ) x;
    end if;
  end if;

  v_result:=jsonb_build_object(
    'generated_at',v_now,
    'timezone','Asia/Bangkok',
    'period',jsonb_build_object('days',v_days,'start_date',v_start_date,'end_date',v_today),
    'permissions',jsonb_build_object(
      'customers',private.has_permission('customer.view'),
      'sales',private.has_permission('sale.view'),
      'payments',private.has_permission('payment.view'),
      'repairs',private.has_permission('repair.view'),
      'inventory',private.has_permission('inventory.view'),
      'warranty',private.has_permission('warranty.view'),
      'service',private.has_permission('service.view'),
      'license',private.has_permission('license.view'),
      'notifications',private.has_permission('notification.view') or private.has_permission('notification.manage'),
      'notification_manage',private.has_permission('notification.manage')
    ),
    'kpis',jsonb_build_object(
      'customers',v_customers,
      'sales',v_sales,
      'repairs',v_repairs,
      'inventory',v_inventory,
      'warranty',v_warranty,
      'service',v_service,
      'license',v_license,
      'reminders',v_reminders,
      'notifications',v_notifications
    ),
    'charts',jsonb_build_object(
      'sales_daily',v_sales_daily,
      'repair_status',v_repair_status,
      'notification_channels',v_notification_channels
    ),
    'attention',jsonb_build_object(
      'low_stock',v_low_stock,
      'repairs',v_repair_attention,
      'reminders',v_reminder_attention
    )
  );

  return v_result;
end;
$$;

revoke execute on function private.dashboard_snapshot_impl(integer,timestamptz) from public,anon,authenticated;
grant execute on function private.dashboard_snapshot_impl(integer,timestamptz) to authenticated;

create or replace function public.dashboard_snapshot(
  p_days integer default 30,
  p_now timestamptz default now()
)
returns jsonb
language sql
set search_path=''
as $$
  select private.dashboard_snapshot_impl(p_days,p_now);
$$;

revoke execute on function public.dashboard_snapshot(integer,timestamptz) from public,anon;
grant execute on function public.dashboard_snapshot(integer,timestamptz) to authenticated;
