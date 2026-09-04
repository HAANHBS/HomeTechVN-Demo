import { useCallback, useEffect, useMemo, useState, type FormEvent, type ReactNode } from 'react'
import type { AppUserContext } from '../../lib/permissions'
import { supabase } from '../../lib/supabase'

type NumberMap = Record<string, number | null>

type ReportSnapshot = {
  generated_at: string
  timezone: string
  period: {
    start_date: string
    end_date: string
    days: number
    bucket: 'DAY' | 'WEEK' | 'MONTH'
  }
  permissions: {
    profit: boolean
    sales: boolean
    payments: boolean
    repairs: boolean
    inventory: boolean
    warranty: boolean
    service: boolean
    license: boolean
  }
  summary: {
    sales: NumberMap | null
    payments: NumberMap | null
    repairs: NumberMap | null
    inventory: NumberMap | null
    warranty: NumberMap | null
    service: NumberMap | null
    license: NumberMap | null
    profit: {
      sales: NumberMap | null
      repair: NumberMap | null
      combined: NumberMap
    } | null
  }
  charts: {
    sales_timeline: Array<{ bucket: string; orders: number; revenue: number }>
    payment_timeline: Array<{ bucket: string; gross_collected: number; refunds: number; net_cash_flow: number }>
    repair_timeline: Array<{ bucket: string; completed: number; revenue: number }>
    payment_methods: Array<{ payment_method: string; gross_collected: number; refunds: number; net_cash_flow: number }>
    inventory_movements: Array<{ transaction_type: string; transactions: number; quantity: number }>
    warranty_claim_status: Array<{ status: string; count: number }>
    top_products: Array<{ product_id: string | null; sku: string; product_name: string; quantity: number; line_value_before_order_discount: number }>
    top_technicians: Array<{ technician_id: string | null; technician_name: string; completed: number; revenue: number }>
  }
  receivables: Array<{
    id: string
    order_code: string
    customer_id: string
    customer_code: string
    customer_name: string
    total_amount: number
    paid_amount: number
    balance_due: number
    payment_pending_at: string | null
    created_at: string
  }>
  data_quality: Record<string, string | boolean>
}

type Tab = 'overview' | 'sales' | 'repair' | 'operations' | 'profit'

function localIsoDate(date: Date) {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

function quickRange(days: number) {
  const end = new Date()
  const start = new Date()
  start.setDate(end.getDate() - (days - 1))
  return { start: localIsoDate(start), end: localIsoDate(end) }
}

function money(value: unknown) {
  return new Intl.NumberFormat('vi-VN', {
    style: 'currency',
    currency: 'VND',
    maximumFractionDigits: 0,
  }).format(Number(value ?? 0))
}

function number(value: unknown, digits = 0) {
  return new Intl.NumberFormat('vi-VN', {
    maximumFractionDigits: digits,
  }).format(Number(value ?? 0))
}

function date(value: string | null | undefined) {
  if (!value) return '—'
  return new Date(`${value}T00:00:00`).toLocaleDateString('vi-VN')
}

function dateTime(value: string | null | undefined) {
  return value ? new Date(value).toLocaleString('vi-VN') : '—'
}

function percent(value: unknown) {
  if (value === null || value === undefined) return '—'
  return `${number(value, 2)}%`
}

function ErrorPanel({ message }: { message: string | null }) {
  return message ? (
    <div className="rounded-2xl border border-red-900/70 bg-red-950/30 p-4 text-sm text-red-200">
      {message}
    </div>
  ) : null
}

function Card({
  label,
  value,
  note,
  tone = 'slate',
}: {
  label: string
  value: string
  note?: string
  tone?: 'slate' | 'cyan' | 'emerald' | 'amber' | 'red' | 'violet'
}) {
  const styles = {
    slate: 'border-slate-800 bg-slate-900',
    cyan: 'border-cyan-900/70 bg-cyan-950/20',
    emerald: 'border-emerald-900/70 bg-emerald-950/20',
    amber: 'border-amber-900/70 bg-amber-950/20',
    red: 'border-red-900/70 bg-red-950/20',
    violet: 'border-violet-900/70 bg-violet-950/20',
  }[tone]

  return (
    <article className={`min-w-0 rounded-2xl border p-4 ${styles}`}>
      <div className="text-xs font-semibold uppercase tracking-[0.12em] text-slate-400">{label}</div>
      <div className="mt-2 break-words text-xl font-bold text-white sm:text-2xl">{value}</div>
      {note ? <div className="mt-2 text-xs leading-5 text-slate-500">{note}</div> : null}
    </article>
  )
}

function Section({
  title,
  subtitle,
  children,
}: {
  title: string
  subtitle?: string
  children: ReactNode
}) {
  return (
    <section className="min-w-0 rounded-3xl border border-slate-800 bg-slate-900/90 p-4 sm:p-5">
      <div className="mb-4">
        <h2 className="font-semibold text-white">{title}</h2>
        {subtitle ? <p className="mt-1 text-xs leading-5 text-slate-500">{subtitle}</p> : null}
      </div>
      {children}
    </section>
  )
}

function Timeline({
  rows,
  valueKey,
  valueLabel,
}: {
  rows: Array<Record<string, string | number>>
  valueKey: string
  valueLabel: string
}) {
  const max = Math.max(1, ...rows.map((row) => Number(row[valueKey] ?? 0)))
  if (!rows.length) {
    return <div className="py-10 text-center text-sm text-slate-500">Không có dữ liệu trong kỳ.</div>
  }

  return (
    <div className="overflow-x-auto pb-3">
      <div className="flex min-h-52 items-end gap-2" style={{ minWidth: `${Math.max(520, rows.length * 44)}px` }}>
        {rows.map((row) => {
          const value = Number(row[valueKey] ?? 0)
          const height = Math.max(value > 0 ? 8 : 2, Math.round((value / max) * 145))
          const bucket = String(row.bucket ?? '')
          return (
            <div
              key={`${bucket}-${value}`}
              className="flex min-w-8 flex-1 flex-col items-center justify-end gap-2"
              title={`${date(bucket)} · ${valueLabel}: ${money(value)}`}
            >
              <div className="text-[10px] text-slate-500">{value ? number(value) : ''}</div>
              <div className="w-full max-w-9 rounded-t-lg bg-cyan-500/80" style={{ height }} />
              <div className="-rotate-45 whitespace-nowrap text-[9px] text-slate-500">{date(bucket)}</div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

function escapeCsv(value: unknown) {
  const text = String(value ?? '')
  if (/[",\n]/.test(text)) return `"${text.replaceAll('"', '""')}"`
  return text
}

function downloadCsv(filename: string, rows: Array<Record<string, unknown>>) {
  if (!rows.length) return
  const headers = Array.from(new Set(rows.flatMap((row) => Object.keys(row))))
  const csv = [
    headers.map(escapeCsv).join(','),
    ...rows.map((row) => headers.map((header) => escapeCsv(row[header])).join(',')),
  ].join('\r\n')
  const blob = new Blob([`\uFEFF${csv}`], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = filename
  anchor.click()
  URL.revokeObjectURL(url)
}

export function ReportsPage({
  context,
}: {
  context: AppUserContext
}) {
  const initial = useMemo(() => quickRange(30), [])
  const [startDate, setStartDate] = useState(initial.start)
  const [endDate, setEndDate] = useState(initial.end)
  const [bucket, setBucket] = useState<'DAY' | 'WEEK' | 'MONTH'>('DAY')
  const [tab, setTab] = useState<Tab>('overview')
  const [data, setData] = useState<ReportSnapshot | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async (start = startDate, end = endDate, nextBucket = bucket) => {
    setLoading(true)
    setError(null)
    try {
      const { data: result, error: rpcError } = await supabase.rpc('report_snapshot', {
        p_start_date: start,
        p_end_date: end,
        p_bucket: nextBucket,
      })
      if (rpcError) throw rpcError
      setData(result as unknown as ReportSnapshot)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tải được báo cáo.')
    } finally {
      setLoading(false)
    }
  }, [bucket, endDate, startDate])

  useEffect(() => {
    void load(initial.start, initial.end, 'DAY')
    // Intentional initial fetch only; later date edits are submitted explicitly.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  function applyQuick(days: number) {
    const range = quickRange(days)
    const suggestedBucket: 'DAY' | 'WEEK' | 'MONTH' = days <= 30 ? 'DAY' : days <= 90 ? 'WEEK' : 'MONTH'
    setStartDate(range.start)
    setEndDate(range.end)
    setBucket(suggestedBucket)
    void load(range.start, range.end, suggestedBucket)
  }

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    void load()
  }

  const exportRows = useMemo<Array<Record<string, unknown>>>(() => {
    if (!data) return []
    if (tab === 'sales') {
      return data.charts.top_products.map((row) => ({
        sku: row.sku,
        product_name: row.product_name,
        quantity: row.quantity,
        line_value_before_order_discount: row.line_value_before_order_discount,
      }))
    }
    if (tab === 'repair') {
      return data.charts.top_technicians.map((row) => ({
        technician_name: row.technician_name,
        completed: row.completed,
        revenue: row.revenue,
      }))
    }
    if (tab === 'operations') {
      return data.receivables.map((row) => ({
        order_code: row.order_code,
        customer_code: row.customer_code,
        customer_name: row.customer_name,
        total_amount: row.total_amount,
        paid_amount: row.paid_amount,
        balance_due: row.balance_due,
        payment_pending_at: row.payment_pending_at,
      }))
    }
    if (tab === 'profit' && data.summary.profit) {
      const p = data.summary.profit
      return [
        { scope: 'sales', ...(p.sales ?? {}) },
        { scope: 'repair', ...(p.repair ?? {}) },
        { scope: 'combined', ...p.combined },
      ]
    }

    return [
      {
        metric: 'sales_revenue',
        value: data.summary.sales?.revenue ?? null,
      },
      {
        metric: 'net_cash_flow',
        value: data.summary.payments?.net_cash_flow ?? null,
      },
      {
        metric: 'current_receivables',
        value: data.summary.sales?.current_receivables ?? null,
      },
      {
        metric: 'repair_revenue',
        value: data.summary.repairs?.completed_revenue ?? null,
      },
    ]
  }, [data, tab])

  const sales = data?.summary.sales
  const payments = data?.summary.payments
  const repairs = data?.summary.repairs
  const inventory = data?.summary.inventory
  const warranty = data?.summary.warranty
  const service = data?.summary.service
  const license = data?.summary.license
  const profit = data?.summary.profit

  const tabs: Array<{ key: Tab; label: string; visible: boolean }> = [
    { key: 'overview', label: 'Tổng hợp', visible: true },
    { key: 'sales', label: 'Bán hàng & thu tiền', visible: Boolean(data?.permissions.sales || data?.permissions.payments) },
    { key: 'repair', label: 'Sửa chữa', visible: Boolean(data?.permissions.repairs) },
    { key: 'operations', label: 'Vận hành', visible: true },
    { key: 'profit', label: 'Lợi nhuận', visible: Boolean(data?.permissions.profit && profit) },
  ]

  return (
    <main className="min-h-screen bg-slate-950 text-slate-200 print:bg-white print:text-black">
      <header className="sticky top-0 z-40 border-b border-slate-800/90 bg-slate-950/90 px-3 py-3 backdrop-blur-xl print:static print:border-0 print:bg-white sm:px-6">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-3">
          <div>
            <div className="text-xs font-semibold uppercase tracking-[0.24em] text-cyan-400">HomeTechVN</div>
            <h1 className="mt-1 text-lg font-bold text-white print:text-black sm:text-xl">Báo cáo điều hành</h1>
          </div>
          <div className="flex items-center gap-2 print:hidden">
            <button
              type="button"
              onClick={() => downloadCsv(`hometechvn-${tab}-${startDate}-${endDate}.csv`, exportRows)}
              disabled={!exportRows.length}
              className="rounded-xl border border-cyan-900 px-3 py-2 text-sm text-cyan-300 disabled:opacity-40"
            >
              Xuất CSV
            </button>
            <button type="button" onClick={() => window.print()} className="rounded-xl border border-slate-700 px-3 py-2 text-sm">
              In báo cáo
            </button>
            <button type="button" onClick={() => void supabase.auth.signOut()} className="rounded-xl border border-slate-700 px-3 py-2 text-sm">
              Đăng xuất
            </button>
          </div>
        </div>
      </header>

      <div className="mx-auto max-w-7xl space-y-5 px-3 py-5 pb-24 sm:px-6 sm:py-6 lg:pb-8">
        <form onSubmit={submit} className="rounded-3xl border border-slate-800 bg-slate-900/90 p-4 print:border-slate-300 print:bg-white sm:p-5">
          <div className="grid gap-3 md:grid-cols-[1fr_1fr_180px_auto]">
            <label className="text-sm font-medium">
              Từ ngày
              <input
                type="date"
                required
                value={startDate}
                onChange={(event) => setStartDate(event.target.value)}
                className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 print:border-slate-300 print:bg-white"
              />
            </label>
            <label className="text-sm font-medium">
              Đến ngày
              <input
                type="date"
                required
                value={endDate}
                onChange={(event) => setEndDate(event.target.value)}
                className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 print:border-slate-300 print:bg-white"
              />
            </label>
            <label className="text-sm font-medium">
              Nhóm thời gian
              <select
                value={bucket}
                onChange={(event) => setBucket(event.target.value as 'DAY' | 'WEEK' | 'MONTH')}
                className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 print:border-slate-300 print:bg-white"
              >
                <option value="DAY">Theo ngày</option>
                <option value="WEEK">Theo tuần</option>
                <option value="MONTH">Theo tháng</option>
              </select>
            </label>
            <button disabled={loading} className="self-end rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-50 print:hidden">
              {loading ? 'Đang tổng hợp…' : 'Xem báo cáo'}
            </button>
          </div>

          <div className="mt-4 flex flex-wrap gap-2 print:hidden">
            {[7, 30, 90, 365].map((days) => (
              <button key={days} type="button" onClick={() => applyQuick(days)} className="rounded-xl border border-slate-700 px-3 py-2 text-xs hover:border-cyan-800">
                {days} ngày
              </button>
            ))}
          </div>
        </form>

        <ErrorPanel message={error} />

        {data ? (
          <>
            <div className="flex gap-2 overflow-x-auto pb-1 print:hidden">
              {tabs.filter((item) => item.visible).map((item) => (
                <button
                  key={item.key}
                  type="button"
                  onClick={() => setTab(item.key)}
                  className={`shrink-0 rounded-xl px-4 py-2 text-sm ${tab === item.key ? 'bg-cyan-500 font-semibold text-slate-950' : 'border border-slate-700'}`}
                >
                  {item.label}
                </button>
              ))}
            </div>

            <div className="rounded-2xl border border-slate-800 bg-slate-900/60 px-4 py-3 text-xs text-slate-400 print:border-slate-300 print:bg-white print:text-slate-700">
              Kỳ báo cáo: <strong>{date(data.period.start_date)} → {date(data.period.end_date)}</strong> · {data.period.days} ngày · {data.period.bucket} · tạo lúc {dateTime(data.generated_at)}
            </div>

            {tab === 'overview' ? (
              <>
                <section className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                  {sales ? <Card label="Doanh thu bán hàng" value={money(sales.revenue)} note={`${number(sales.orders_paid)} đơn đã ghi nhận`} tone="cyan" /> : null}
                  {payments ? <Card label="Dòng tiền thuần" value={money(payments.net_cash_flow)} note={`Thu ${money(payments.gross_collected)} · Hoàn ${money(payments.refunds)}`} tone="emerald" /> : null}
                  {sales ? <Card label="Công nợ hiện tại" value={money(sales.current_receivables)} note={`${number(sales.current_receivable_orders)} đơn PAYMENT_PENDING`} tone={Number(sales.current_receivables) > 0 ? 'amber' : 'slate'} /> : null}
                  {repairs ? <Card label="Doanh thu sửa chữa" value={money(repairs.completed_revenue)} note={`${number(repairs.completed)} phiếu hoàn thành`} tone="violet" /> : null}
                </section>

                <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
                  {inventory ? <Card label="Tồn thấp" value={number(inventory.low_stock)} note={`${number(inventory.out_of_stock)} hết hàng`} tone={Number(inventory.low_stock) > 0 ? 'amber' : 'slate'} /> : null}
                  {warranty ? <Card label="Claim bảo hành" value={number(warranty.claims_received)} note={`${number(warranty.claims_closed)} claim đóng trong kỳ`} /> : null}
                  {service ? <Card label="Dịch vụ quá hạn" value={number(service.overdue_current)} note={`${number(service.due_30d)} đến hạn 30 ngày`} tone={Number(service.overdue_current) > 0 ? 'amber' : 'slate'} /> : null}
                  {license ? <Card label="License sắp hết" value={number(license.expiring_30d)} note={`Exposure gia hạn ${money(license.renewal_cost_exposure)}`} /> : null}
                  {repairs ? <Card label="Sửa chữa quá hạn" value={number(repairs.current_overdue)} note={`${number(repairs.current_ready)} READY`} tone={Number(repairs.current_overdue) > 0 ? 'red' : 'slate'} /> : null}
                  {inventory ? <Card label="Xuất kho trong kỳ" value={number(inventory.movement_out_qty)} note={`Nhập/hoàn ${number(inventory.movement_in_qty)}`} /> : null}
                </section>

                {sales ? (
                  <Section title="Xu hướng doanh thu bán hàng" subtitle="Neo theo paid_at, chỉ PAID / DELIVERED / COMPLETED.">
                    <Timeline rows={data.charts.sales_timeline as Array<Record<string, string | number>>} valueKey="revenue" valueLabel="Doanh thu" />
                  </Section>
                ) : null}

                <Section title="Chất lượng dữ liệu" subtitle="Các giới hạn được ghi rõ để không biến dữ liệu thiếu thành số liệu giả.">
                  <div className="grid gap-3 md:grid-cols-2">
                    {Object.entries(data.data_quality)
                      .filter(([, value]) => typeof value === 'string')
                      .map(([key, value]) => (
                        <article key={key} className="rounded-xl border border-slate-800 bg-slate-950/60 p-3 print:border-slate-300 print:bg-white">
                          <div className="font-mono text-[10px] uppercase text-cyan-400">{key}</div>
                          <p className="mt-2 text-xs leading-5 text-slate-400 print:text-slate-700">{String(value)}</p>
                        </article>
                      ))}
                  </div>
                </Section>
              </>
            ) : null}

            {tab === 'sales' ? (
              <>
                <section className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                  {sales ? <Card label="Doanh thu" value={money(sales.revenue)} note={`${number(sales.orders_paid)} đơn`} tone="cyan" /> : null}
                  {sales ? <Card label="Giảm giá" value={money(sales.discounts)} note={`AOV ${money(sales.average_order_value)}`} /> : null}
                  {payments ? <Card label="Đã thu" value={money(payments.gross_collected)} note={`${number(payments.payment_count)} giao dịch`} tone="emerald" /> : null}
                  {payments ? <Card label="Đã hoàn" value={money(payments.refunds)} note={`${number(payments.refund_count)} giao dịch hoàn`} tone={Number(payments.refunds) > 0 ? 'amber' : 'slate'} /> : null}
                </section>

                {payments ? (
                  <Section title="Dòng tiền" subtitle="Gross theo paid_at; refund theo refunded_at; net = gross − refund.">
                    <Timeline rows={data.charts.payment_timeline as Array<Record<string, string | number>>} valueKey="net_cash_flow" valueLabel="Dòng tiền thuần" />
                  </Section>
                ) : null}

                <div className="grid gap-5 xl:grid-cols-2">
                  <Section title="Sản phẩm bán nhiều" subtitle="Giá trị dòng trước phân bổ giảm giá cấp đơn; không dùng để tính profit.">
                    <div className="overflow-x-auto">
                      <table className="w-full min-w-[720px] text-left text-sm">
                        <thead className="text-xs uppercase text-slate-500"><tr><th className="px-3 py-2">SKU</th><th className="px-3 py-2">Sản phẩm</th><th className="px-3 py-2 text-right">SL</th><th className="px-3 py-2 text-right">Giá trị dòng</th></tr></thead>
                        <tbody>{data.charts.top_products.map((row) => <tr key={`${row.product_id}-${row.sku}`} className="border-t border-slate-800"><td className="px-3 py-3 font-mono text-cyan-300">{row.sku}</td><td className="px-3 py-3">{row.product_name}</td><td className="px-3 py-3 text-right">{number(row.quantity)}</td><td className="px-3 py-3 text-right">{money(row.line_value_before_order_discount)}</td></tr>)}</tbody>
                      </table>
                    </div>
                  </Section>

                  <Section title="Theo phương thức thanh toán">
                    <div className="overflow-x-auto">
                      <table className="w-full min-w-[620px] text-left text-sm">
                        <thead className="text-xs uppercase text-slate-500"><tr><th className="px-3 py-2">Phương thức</th><th className="px-3 py-2 text-right">Thu</th><th className="px-3 py-2 text-right">Hoàn</th><th className="px-3 py-2 text-right">Thuần</th></tr></thead>
                        <tbody>{data.charts.payment_methods.map((row) => <tr key={row.payment_method} className="border-t border-slate-800"><td className="px-3 py-3">{row.payment_method}</td><td className="px-3 py-3 text-right">{money(row.gross_collected)}</td><td className="px-3 py-3 text-right">{money(row.refunds)}</td><td className="px-3 py-3 text-right font-semibold text-emerald-300">{money(row.net_cash_flow)}</td></tr>)}</tbody>
                      </table>
                    </div>
                  </Section>
                </div>
              </>
            ) : null}

            {tab === 'repair' ? (
              <>
                <section className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                  {repairs ? <Card label="Phiếu hoàn thành" value={number(repairs.completed)} note={`${number(repairs.created)} phiếu tạo trong kỳ`} tone="cyan" /> : null}
                  {repairs ? <Card label="Doanh thu sửa chữa" value={money(repairs.completed_revenue)} /> : null}
                  {repairs ? <Card label="Turnaround TB" value={`${number(repairs.average_turnaround_hours, 1)} giờ`} note="completed_at − created_at" /> : null}
                  {repairs ? <Card label="Đang quá hạn" value={number(repairs.current_overdue)} note={`${number(repairs.current_open)} phiếu đang mở`} tone={Number(repairs.current_overdue) > 0 ? 'red' : 'slate'} /> : null}
                </section>

                <Section title="Xu hướng hoàn thành sửa chữa">
                  <Timeline rows={data.charts.repair_timeline as Array<Record<string, string | number>>} valueKey="revenue" valueLabel="Doanh thu sửa chữa" />
                </Section>

                <Section title="Hiệu suất kỹ thuật viên" subtitle="Theo phiếu COMPLETED trong kỳ; doanh thu là final_amount.">
                  <div className="overflow-x-auto">
                    <table className="w-full min-w-[660px] text-left text-sm">
                      <thead className="text-xs uppercase text-slate-500"><tr><th className="px-3 py-2">Kỹ thuật viên</th><th className="px-3 py-2 text-right">Hoàn thành</th><th className="px-3 py-2 text-right">Doanh thu</th></tr></thead>
                      <tbody>{data.charts.top_technicians.map((row) => <tr key={`${row.technician_id}-${row.technician_name}`} className="border-t border-slate-800"><td className="px-3 py-3">{row.technician_name}</td><td className="px-3 py-3 text-right">{number(row.completed)}</td><td className="px-3 py-3 text-right">{money(row.revenue)}</td></tr>)}</tbody>
                    </table>
                  </div>
                </Section>
              </>
            ) : null}

            {tab === 'operations' ? (
              <>
                <Section title="Công nợ hiện tại" subtitle="Snapshot hiện tại, không phải lịch sử công nợ tại ngày cuối kỳ.">
                  <div className="overflow-x-auto">
                    <table className="w-full min-w-[980px] text-left text-sm">
                      <thead className="text-xs uppercase text-slate-500"><tr><th className="px-3 py-2">Đơn</th><th className="px-3 py-2">Khách hàng</th><th className="px-3 py-2 text-right">Tổng</th><th className="px-3 py-2 text-right">Đã trả</th><th className="px-3 py-2 text-right">Còn nợ</th><th className="px-3 py-2">Chờ từ</th></tr></thead>
                      <tbody>{data.receivables.map((row) => <tr key={row.id} className="border-t border-slate-800"><td className="px-3 py-3 font-mono text-cyan-300">{row.order_code}</td><td className="px-3 py-3">{row.customer_name}<div className="text-xs text-slate-500">{row.customer_code}</div></td><td className="px-3 py-3 text-right">{money(row.total_amount)}</td><td className="px-3 py-3 text-right">{money(row.paid_amount)}</td><td className="px-3 py-3 text-right font-semibold text-amber-300">{money(row.balance_due)}</td><td className="px-3 py-3 text-xs">{dateTime(row.payment_pending_at)}</td></tr>)}</tbody>
                    </table>
                  </div>
                </Section>

                <div className="grid gap-5 xl:grid-cols-2">
                  <Section title="Biến động kho" subtitle="Chỉ số lượng giao dịch; T13 không định giá tồn hiện tại.">
                    <div className="overflow-x-auto">
                      <table className="w-full min-w-[580px] text-left text-sm">
                        <thead className="text-xs uppercase text-slate-500"><tr><th className="px-3 py-2">Loại</th><th className="px-3 py-2 text-right">Giao dịch</th><th className="px-3 py-2 text-right">Số lượng</th></tr></thead>
                        <tbody>{data.charts.inventory_movements.map((row) => <tr key={row.transaction_type} className="border-t border-slate-800"><td className="px-3 py-3">{row.transaction_type}</td><td className="px-3 py-3 text-right">{number(row.transactions)}</td><td className="px-3 py-3 text-right">{number(row.quantity)}</td></tr>)}</tbody>
                      </table>
                    </div>
                  </Section>

                  <Section title="Warranty Claim theo trạng thái">
                    <div className="overflow-x-auto">
                      <table className="w-full min-w-[520px] text-left text-sm">
                        <thead className="text-xs uppercase text-slate-500"><tr><th className="px-3 py-2">Trạng thái</th><th className="px-3 py-2 text-right">Số claim</th></tr></thead>
                        <tbody>{data.charts.warranty_claim_status.map((row) => <tr key={row.status} className="border-t border-slate-800"><td className="px-3 py-3">{row.status}</td><td className="px-3 py-3 text-right">{number(row.count)}</td></tr>)}</tbody>
                      </table>
                    </div>
                  </Section>
                </div>
              </>
            ) : null}

            {tab === 'profit' && profit ? (
              <>
                <div className="rounded-3xl border border-amber-800/70 bg-amber-950/25 p-4 text-sm leading-6 text-amber-100">
                  <strong>Lợi nhuận gộp có dữ liệu cost, không phải lợi nhuận ròng.</strong> Chỉ dòng có cost snapshot đầy đủ được tính. Lao động, tiền thuê, thuế, điện nước và chi phí chung chưa được trừ.
                </div>

                <section className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                  <Card label="Doanh thu tổng" value={money(profit.combined.revenue_total)} />
                  <Card label="Doanh thu đủ cost" value={money(profit.combined.cost_covered_revenue)} note={`Coverage ${percent(profit.combined.cost_coverage_revenue_pct)}`} tone="cyan" />
                  <Card label="Gross profit đã biết" value={money(profit.combined.gross_profit_known)} tone="emerald" />
                  <Card
                    label="Coverage doanh thu"
                    value={percent(profit.combined.cost_coverage_revenue_pct)}
                    note="Coverage thấp ⇒ chưa nên suy rộng gross profit cho toàn kỳ."
                    tone={Number(profit.combined.cost_coverage_revenue_pct) < 90 ? 'amber' : 'slate'}
                  />
                </section>

                <div className="grid gap-5 xl:grid-cols-2">
                  {profit.sales ? (
                    <Section title="Lợi nhuận gộp bán hàng">
                      <div className="grid grid-cols-2 gap-3">
                        <Card label="Revenue total" value={money(profit.sales.revenue_total)} />
                        <Card label="Covered revenue" value={money(profit.sales.cost_covered_revenue)} />
                        <Card label="Cost đã ghi" value={money(profit.sales.recorded_product_cost)} />
                        <Card label="Gross profit known" value={money(profit.sales.gross_profit_known)} tone="emerald" />
                        <Card label="Margin known" value={percent(profit.sales.gross_margin_known_pct)} />
                        <Card label="Revenue thiếu cost" value={money(profit.sales.excluded_revenue_missing_cost)} tone={Number(profit.sales.excluded_revenue_missing_cost) > 0 ? 'amber' : 'slate'} />
                      </div>
                    </Section>
                  ) : null}

                  {profit.repair ? (
                    <Section title="Lợi nhuận gộp sửa chữa sau linh kiện">
                      <div className="grid grid-cols-2 gap-3">
                        <Card label="Revenue total" value={money(profit.repair.revenue_total)} />
                        <Card label="Covered revenue" value={money(profit.repair.cost_covered_revenue)} />
                        <Card label="Cost linh kiện" value={money(profit.repair.recorded_parts_cost)} />
                        <Card label="Gross profit known" value={money(profit.repair.gross_profit_after_parts_known)} tone="emerald" />
                        <Card label="Margin known" value={percent(profit.repair.gross_margin_after_parts_known_pct)} />
                        <Card label="Revenue thiếu cost" value={money(profit.repair.excluded_revenue_missing_cost)} tone={Number(profit.repair.excluded_revenue_missing_cost) > 0 ? 'amber' : 'slate'} />
                      </div>
                    </Section>
                  ) : null}
                </div>
              </>
            ) : null}

            <div className="px-1 text-[11px] text-slate-600 print:text-slate-500">
              Người xem: {context.fullName || context.email || context.roleName} · Quyền profit: {data.permissions.profit ? 'Có' : 'Không'}
            </div>
          </>
        ) : loading ? (
          <div className="grid min-h-80 place-items-center rounded-3xl border border-slate-800 bg-slate-900">
            <div className="text-slate-400">Đang tổng hợp báo cáo…</div>
          </div>
        ) : null}
      </div>
    </main>
  )
}
