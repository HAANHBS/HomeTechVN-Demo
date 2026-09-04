import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import type { AppUserContext } from '../../lib/permissions'
import { supabase } from '../../lib/supabase'

type NumberMap = Record<string, number | null>

type DashboardSnapshot = {
  generated_at: string
  timezone: string
  period: { days: number; start_date: string; end_date: string }
  permissions: Record<string, boolean>
  kpis: {
    customers: NumberMap | null
    sales: NumberMap | null
    repairs: NumberMap | null
    inventory: NumberMap | null
    warranty: NumberMap | null
    service: NumberMap | null
    license: NumberMap | null
    reminders: NumberMap | null
    notifications: NumberMap | null
  }
  charts: {
    sales_daily: Array<{ date: string; orders: number; value: number }>
    repair_status: Array<{ status: string; count: number }>
    notification_channels: Array<{ channel: string; sent: number; failed: number; pending: number }>
  }
  attention: {
    low_stock: Array<{ product_id: string; sku: string; name: string; stock_qty: number; min_stock: number; track_serial: boolean }>
    repairs: Array<{ id: string; repair_code: string; status: string; priority: string; estimated_completion_at: string | null; ready_at: string | null; created_at: string; customer_name: string | null; rank_key: number }>
    reminders: Array<{ id: string; reminder_code: string; title: string; message: string; priority: string; due_at: string; source_type: string; source_label: string | null; priority_rank: number }>
  }
}

type NavItem = {
  key: string
  label: string
  short: string
  enabled: boolean
  onClick?: () => void
}

function number(value: unknown) {
  return new Intl.NumberFormat('vi-VN').format(Number(value ?? 0))
}

function money(value: unknown) {
  return new Intl.NumberFormat('vi-VN', {
    style: 'currency',
    currency: 'VND',
    maximumFractionDigits: 0,
  }).format(Number(value ?? 0))
}

function dateTime(value: string | null | undefined) {
  return value ? new Date(value).toLocaleString('vi-VN') : '—'
}

function date(value: string | null | undefined) {
  if (!value) return '—'
  return new Date(`${value}T00:00:00`).toLocaleDateString('vi-VN')
}

function ErrorPanel({ message }: { message: string | null }) {
  return message ? <div className="rounded-2xl border border-red-900/70 bg-red-950/30 p-4 text-sm text-red-200">{message}</div> : null
}

function KpiCard({
  label,
  value,
  note,
  tone = 'cyan',
  onClick,
}: {
  label: string
  value: string
  note?: string
  tone?: 'cyan' | 'emerald' | 'amber' | 'red' | 'violet' | 'slate'
  onClick?: () => void
}) {
  const toneClass = {
    cyan: 'border-cyan-900/70 bg-cyan-950/20 text-cyan-300',
    emerald: 'border-emerald-900/70 bg-emerald-950/20 text-emerald-300',
    amber: 'border-amber-900/70 bg-amber-950/20 text-amber-300',
    red: 'border-red-900/70 bg-red-950/20 text-red-300',
    violet: 'border-violet-900/70 bg-violet-950/20 text-violet-300',
    slate: 'border-slate-800 bg-slate-900 text-slate-300',
  }[tone]

  const content = <>
    <div className={`text-xs font-semibold uppercase tracking-[0.14em] ${toneClass.split(' ').at(-1)}`}>{label}</div>
    <div className="mt-2 text-2xl font-bold leading-none text-white sm:text-3xl">{value}</div>
    {note ? <div className="mt-2 text-xs leading-5 text-slate-400">{note}</div> : null}
  </>

  if (onClick) {
    return <button type="button" onClick={onClick} className={`min-w-0 rounded-2xl border p-4 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-cyan-700 ${toneClass}`}>{content}</button>
  }
  return <article className={`min-w-0 rounded-2xl border p-4 shadow-sm ${toneClass}`}>{content}</article>
}

function SectionCard({ title, subtitle, children }: { title: string; subtitle?: string; children: ReactNode }) {
  return <section className="min-w-0 rounded-3xl border border-slate-800 bg-slate-900/90 p-4 shadow-sm sm:p-5">
    <div className="mb-4">
      <h2 className="font-semibold text-white">{title}</h2>
      {subtitle ? <p className="mt-1 text-xs leading-5 text-slate-500">{subtitle}</p> : null}
    </div>
    {children}
  </section>
}

function SalesBars({ rows }: { rows: DashboardSnapshot['charts']['sales_daily'] }) {
  const max = Math.max(1, ...rows.map((x) => Number(x.value || 0)))
  if (!rows.length) return <p className="py-8 text-center text-sm text-slate-500">Không có dữ liệu doanh số trong kỳ.</p>

  return <div className="overflow-x-auto pb-2">
    <div className="flex min-h-52 items-end gap-2" style={{ minWidth: `${Math.max(520, rows.length * 28)}px` }}>
      {rows.map((row) => {
        const height = Math.max(row.value > 0 ? 8 : 2, Math.round((row.value / max) * 150))
        return <div key={row.date} className="flex min-w-5 flex-1 flex-col items-center justify-end gap-2" title={`${date(row.date)} · ${money(row.value)} · ${row.orders} đơn`}>
          <div className="text-[10px] text-slate-500">{row.orders || ''}</div>
          <div className="w-full max-w-7 rounded-t-lg bg-cyan-500/80" style={{ height }} />
          <div className="-rotate-45 whitespace-nowrap text-[9px] text-slate-500">{new Date(`${row.date}T00:00:00`).toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit' })}</div>
        </div>
      })}
    </div>
  </div>
}

function StatusBars({ rows }: { rows: DashboardSnapshot['charts']['repair_status'] }) {
  const max = Math.max(1, ...rows.map((x) => Number(x.count || 0)))
  return <div className="space-y-3">
    {rows.length ? rows.map((row) => <div key={row.status}>
      <div className="mb-1 flex items-center justify-between gap-3 text-xs"><span className="text-slate-300">{row.status}</span><strong className="text-white">{number(row.count)}</strong></div>
      <div className="h-2 overflow-hidden rounded-full bg-slate-800"><div className="h-full rounded-full bg-cyan-500" style={{ width: `${Math.max(4, (row.count / max) * 100)}%` }} /></div>
    </div>) : <p className="py-6 text-center text-sm text-slate-500">Không có phiếu sửa chữa đang mở.</p>}
  </div>
}

export function DashboardPage({
  context,
  onOpenCrm,
  onOpenInventory,
  onOpenSales,
  onOpenRepair,
  onOpenChecklist,
  onOpenWarranty,
  onOpenServiceLicense,
  onOpenReminders,
  onOpenNotifications,
  onOpenReports,
  onOpenAudit,
}: {
  context: AppUserContext
  onOpenCrm?: () => void
  onOpenInventory?: () => void
  onOpenSales?: () => void
  onOpenRepair?: () => void
  onOpenChecklist?: () => void
  onOpenWarranty?: () => void
  onOpenServiceLicense?: () => void
  onOpenReminders?: () => void
  onOpenNotifications?: () => void
  onOpenReports?: () => void
  onOpenAudit?: () => void
}) {
  const [days, setDays] = useState<7 | 30 | 90>(30)
  const [data, setData] = useState<DashboardSnapshot | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data: result, error: rpcError } = await supabase.rpc('dashboard_snapshot', { p_days: days })
      if (rpcError) throw rpcError
      setData(result as unknown as DashboardSnapshot)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tải được Dashboard.')
    } finally {
      setLoading(false)
    }
  }, [days])

  useEffect(() => { void load() }, [load])

  const navItems = useMemo<NavItem[]>(() => [
    { key: 'crm', label: 'Khách hàng & thiết bị', short: 'CRM', enabled: Boolean(onOpenCrm), onClick: onOpenCrm },
    { key: 'inventory', label: 'Sản phẩm & kho', short: 'Kho', enabled: Boolean(onOpenInventory), onClick: onOpenInventory },
    { key: 'sales', label: 'Bán hàng', short: 'Bán hàng', enabled: Boolean(onOpenSales), onClick: onOpenSales },
    { key: 'repair', label: 'Sửa chữa', short: 'Sửa chữa', enabled: Boolean(onOpenRepair), onClick: onOpenRepair },
    { key: 'checklist', label: 'Checklist', short: 'Checklist', enabled: Boolean(onOpenChecklist), onClick: onOpenChecklist },
    { key: 'warranty', label: 'Bảo hành', short: 'Bảo hành', enabled: Boolean(onOpenWarranty), onClick: onOpenWarranty },
    { key: 'service', label: 'Dịch vụ & License', short: 'Dịch vụ', enabled: Boolean(onOpenServiceLicense), onClick: onOpenServiceLicense },
    { key: 'reminder', label: 'Nhắc việc', short: 'Nhắc việc', enabled: Boolean(onOpenReminders), onClick: onOpenReminders },
    { key: 'notification', label: 'Thông báo', short: 'Thông báo', enabled: Boolean(onOpenNotifications), onClick: onOpenNotifications },
    { key: 'reports', label: 'Báo cáo', short: 'Báo cáo', enabled: Boolean(onOpenReports), onClick: onOpenReports },
    { key: 'audit', label: 'Bảo mật & Audit', short: 'Audit', enabled: Boolean(onOpenAudit), onClick: onOpenAudit },
  ].filter((x) => x.enabled), [onOpenAudit, onOpenChecklist, onOpenCrm, onOpenInventory, onOpenNotifications, onOpenReminders, onOpenRepair, onOpenReports, onOpenSales, onOpenServiceLicense, onOpenWarranty])

  const sales = data?.kpis.sales
  const repairs = data?.kpis.repairs
  const inventory = data?.kpis.inventory
  const warranty = data?.kpis.warranty
  const service = data?.kpis.service
  const license = data?.kpis.license
  const reminders = data?.kpis.reminders
  const notifications = data?.kpis.notifications
  const customers = data?.kpis.customers

  return <main className="min-h-screen bg-slate-950 text-slate-200">
    <header className="sticky top-0 z-40 border-b border-slate-800/90 bg-slate-950/90 px-3 py-3 backdrop-blur-xl sm:px-6">
      <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-3">
        <div className="min-w-0">
          <div className="text-xs font-semibold uppercase tracking-[0.24em] text-cyan-400">HomeTechVN</div>
          <div className="mt-1 flex min-w-0 items-baseline gap-2"><h1 className="truncate text-lg font-bold text-white sm:text-xl">Tổng quan điều hành</h1><span className="hidden text-xs text-slate-500 md:inline">Asia/Bangkok</span></div>
        </div>
        <div className="flex items-center gap-2">
          <button type="button" onClick={() => void load()} disabled={loading} className="rounded-xl border border-slate-700 px-3 py-2 text-sm hover:bg-slate-800 disabled:opacity-50">{loading ? 'Đang tải…' : 'Làm mới'}</button>
          <div className="hidden text-right sm:block"><div className="max-w-48 truncate text-sm font-medium text-white">{context.fullName || context.email || 'Người dùng'}</div><div className="text-xs text-slate-500">{context.roleName}</div></div>
          <button type="button" onClick={() => void supabase.auth.signOut()} className="rounded-xl border border-slate-700 px-3 py-2 text-sm">Đăng xuất</button>
        </div>
      </div>
    </header>

    <div className="mx-auto max-w-7xl space-y-5 px-3 py-5 pb-24 sm:px-6 sm:py-6 lg:pb-8">
      <section className="rounded-3xl border border-slate-800 bg-slate-900/90 p-3 sm:p-4">
        <div className="flex items-center justify-between gap-3">
          <div><h2 className="text-sm font-semibold text-white">Đi nhanh đến module</h2><p className="mt-1 hidden text-xs text-slate-500 sm:block">Tự động ẩn module không có quyền.</p></div>
          <div className="flex rounded-xl border border-slate-700 bg-slate-950 p-1">
            {([7, 30, 90] as const).map((value) => <button key={value} type="button" onClick={() => setDays(value)} className={`min-h-9 rounded-lg px-3 py-1 text-xs font-semibold ${days === value ? 'bg-cyan-500 text-slate-950' : 'text-slate-400'}`}>{value} ngày</button>)}
          </div>
        </div>
        <div className="mt-3 flex gap-2 overflow-x-auto pb-1">
          {navItems.map((item) => <button key={item.key} type="button" onClick={item.onClick} title={item.label} className="shrink-0 rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-200 hover:border-cyan-800 hover:text-cyan-300">{item.short}</button>)}
        </div>
      </section>

      <ErrorPanel message={error} />

      {data ? <>
        <section className="grid grid-cols-2 gap-3 lg:grid-cols-4">
          {sales ? <KpiCard label="Doanh số hôm nay" value={money(sales.sales_value_today)} note={`${number(sales.orders_today)} đơn hôm nay`} tone="cyan" onClick={onOpenSales} /> : null}
          {sales && sales.payments_received_today != null ? <KpiCard label="Thu tiền hôm nay" value={money(sales.payments_received_today)} note={`Trong kỳ: ${money(sales.payments_received_period)}`} tone="emerald" onClick={onOpenSales} /> : null}
          {repairs ? <KpiCard label="Phiếu sửa đang mở" value={number(repairs.open)} note={`${number(repairs.ready)} sẵn sàng · ${number(repairs.overdue)} quá hạn`} tone={Number(repairs.overdue) > 0 ? 'red' : 'amber'} onClick={onOpenRepair} /> : null}
          {reminders ? <KpiCard label="Việc cần xử lý" value={number(reminders.due)} note={`${number(reminders.urgent_due)} khẩn cấp · ${number(notifications?.in_app_unread)} thông báo chưa đọc`} tone={Number(reminders.urgent_due) > 0 ? 'red' : 'violet'} onClick={onOpenReminders} /> : null}
        </section>

        <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
          {customers ? <KpiCard label="Khách hàng" value={number(customers.active)} note={`+${number(customers.new_period)} trong ${days} ngày`} tone="slate" onClick={onOpenCrm} /> : null}
          {inventory ? <KpiCard label="Tồn thấp" value={number(inventory.low_stock)} note={`${number(inventory.out_of_stock)} hết hàng`} tone={Number(inventory.low_stock) > 0 ? 'amber' : 'slate'} onClick={onOpenInventory} /> : null}
          {warranty ? <KpiCard label="BH sắp hết 7 ngày" value={number(warranty.expiring_7d)} note={`${number(warranty.expiring_30d)} trong 30 ngày`} tone="slate" onClick={onOpenWarranty} /> : null}
          {service ? <KpiCard label="Dịch vụ đến hạn 7 ngày" value={number(service.due_7d)} note={`${number(service.overdue)} quá hạn`} tone={Number(service.overdue) > 0 ? 'amber' : 'slate'} onClick={onOpenServiceLicense} /> : null}
          {license ? <KpiCard label="License hết hạn 7 ngày" value={number(license.expiring_7d)} note={`${number(license.expiring_30d)} trong 30 ngày`} tone="slate" onClick={onOpenServiceLicense} /> : null}
          {sales ? <KpiCard label="Công nợ bán hàng" value={money(sales.balance_due)} note={`${number(sales.payment_pending_orders)} đơn chờ thu`} tone={Number(sales.balance_due) > 0 ? 'amber' : 'slate'} onClick={onOpenSales} /> : null}
        </section>

        <section className="grid gap-5 xl:grid-cols-[1.6fr_1fr]">
          {sales ? <SectionCard title={`Doanh số ${days} ngày`} subtitle={`${date(data.period.start_date)} → ${date(data.period.end_date)} · giá trị các đơn PAID/DELIVERED/COMPLETED`}><SalesBars rows={data.charts.sales_daily} /><div className="mt-4 grid grid-cols-2 gap-3 border-t border-slate-800 pt-4 sm:grid-cols-3"><div><div className="text-xs text-slate-500">Giá trị kỳ</div><div className="mt-1 font-semibold text-white">{money(sales.sales_value_period)}</div></div><div><div className="text-xs text-slate-500">Số đơn</div><div className="mt-1 font-semibold text-white">{number(sales.orders_period)}</div></div>{sales.payments_received_period != null ? <div><div className="text-xs text-slate-500">Đã thu</div><div className="mt-1 font-semibold text-emerald-300">{money(sales.payments_received_period)}</div></div> : null}</div></SectionCard> : null}
          {repairs ? <SectionCard title="Trạng thái sửa chữa" subtitle="Chỉ các phiếu chưa hoàn tất/hủy"><StatusBars rows={data.charts.repair_status} /></SectionCard> : null}
        </section>

        <section className="grid gap-5 lg:grid-cols-3">
          {inventory ? <SectionCard title="Kho cần chú ý" subtitle="Tối đa 8 sản phẩm tồn thấp nhất">
            <div className="space-y-2">{data.attention.low_stock.length ? data.attention.low_stock.map((row) => <button type="button" onClick={onOpenInventory} key={row.product_id} className="flex w-full items-center justify-between gap-3 rounded-xl border border-slate-800 bg-slate-950/60 px-3 py-3 text-left hover:border-amber-800"><div className="min-w-0"><div className="truncate text-sm font-medium text-white">{row.name}</div><div className="font-mono text-xs text-cyan-400">{row.sku}</div></div><div className="shrink-0 text-right"><div className="font-semibold text-amber-300">{number(row.stock_qty)}</div><div className="text-[10px] text-slate-500">min {number(row.min_stock)}</div></div></button>) : <p className="py-8 text-center text-sm text-emerald-400">Kho không có cảnh báo tồn thấp.</p>}</div>
          </SectionCard> : null}

          {repairs ? <SectionCard title="Sửa chữa cần chú ý" subtitle="Ưu tiên quá hạn, READY, chờ khách">
            <div className="space-y-2">{data.attention.repairs.length ? data.attention.repairs.map((row) => <button type="button" onClick={onOpenRepair} key={row.id} className="w-full rounded-xl border border-slate-800 bg-slate-950/60 p-3 text-left hover:border-cyan-800"><div className="flex items-start justify-between gap-2"><div><div className="font-mono text-xs text-cyan-400">{row.repair_code}</div><div className="mt-1 text-sm font-medium text-white">{row.customer_name || 'Khách hàng'}</div></div><span className="rounded-lg bg-slate-800 px-2 py-1 text-[10px] text-slate-300">{row.status}</span></div><div className="mt-2 text-xs text-slate-500">Dự kiến: {dateTime(row.estimated_completion_at)}</div></button>) : <p className="py-8 text-center text-sm text-emerald-400">Không có phiếu sửa chữa cần cảnh báo.</p>}</div>
          </SectionCard> : null}

          {reminders ? <SectionCard title="Nhắc việc đến hạn" subtitle="Tối đa 8 mục ưu tiên cao nhất">
            <div className="space-y-2">{data.attention.reminders.length ? data.attention.reminders.map((row) => <button type="button" onClick={onOpenReminders} key={row.id} className="w-full rounded-xl border border-slate-800 bg-slate-950/60 p-3 text-left hover:border-violet-800"><div className="flex items-start justify-between gap-2"><div className="min-w-0"><div className="font-mono text-xs text-violet-300">{row.reminder_code}</div><div className="mt-1 truncate text-sm font-medium text-white">{row.title}</div></div><span className={`rounded-lg px-2 py-1 text-[10px] ${row.priority === 'URGENT' ? 'bg-red-950 text-red-300' : row.priority === 'HIGH' ? 'bg-amber-950 text-amber-300' : 'bg-slate-800 text-slate-300'}`}>{row.priority}</span></div><div className="mt-2 text-xs text-slate-500">{row.source_type} · {row.source_label ?? '—'} · {dateTime(row.due_at)}</div></button>) : <p className="py-8 text-center text-sm text-emerald-400">Không có reminder đang DUE.</p>}</div>
          </SectionCard> : null}
        </section>

        {data.permissions.notification_manage && data.charts.notification_channels.length ? <SectionCard title="Chất lượng gửi thông báo" subtitle="Tổng hợp trạng thái theo kênh trong kỳ">
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">{data.charts.notification_channels.map((row) => <article key={row.channel} className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4"><div className="font-semibold text-white">{row.channel}</div><div className="mt-3 grid grid-cols-3 gap-2 text-center text-xs"><div><div className="text-lg font-bold text-emerald-300">{number(row.sent)}</div><div className="text-slate-500">Sent</div></div><div><div className="text-lg font-bold text-red-300">{number(row.failed)}</div><div className="text-slate-500">Failed</div></div><div><div className="text-lg font-bold text-amber-300">{number(row.pending)}</div><div className="text-slate-500">Chờ</div></div></div></article>)}</div>
        </SectionCard> : null}

        <div className="flex flex-wrap items-center justify-between gap-2 px-1 text-[11px] text-slate-600"><span>Cập nhật: {dateTime(data.generated_at)}</span><span>KPI được lọc theo quyền của tài khoản hiện tại.</span></div>
      </> : loading ? <div className="grid min-h-80 place-items-center rounded-3xl border border-slate-800 bg-slate-900"><div className="text-slate-400">Đang tổng hợp Dashboard…</div></div> : null}
    </div>
  </main>
}
