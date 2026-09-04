import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react'
import type { Json, ReminderRuleRow, ReminderSummaryRow } from '../../lib/database.types'
import { hasPermission, type AppUserContext } from '../../lib/permissions'
import { supabase } from '../../lib/supabase'
import { Modal } from '../crm/forms'
import type { QrAction, QrResolved } from '../qr/QrCommandCenter'

type Tab = 'reminders' | 'rules'

const EVENT_TYPES = [
  'WARRANTY_END',
  'LICENSE_END',
  'SERVICE_DUE',
  'REPAIR_READY',
  'REPAIR_AWAITING_CUSTOMER',
  'REPAIR_ESTIMATED_COMPLETION',
  'SALES_PAYMENT_PENDING',
  'PRODUCT_LOW_STOCK',
] as const

function dateTime(value: string | null | undefined) {
  return value ? new Date(value).toLocaleString('vi-VN') : '—'
}

function statusClass(status: string | null | undefined) {
  if (status === 'DUE') return 'bg-red-950 text-red-300'
  if (status === 'PENDING') return 'bg-cyan-950 text-cyan-300'
  if (status === 'SNOOZED') return 'bg-amber-950 text-amber-300'
  if (status === 'ACKNOWLEDGED') return 'bg-violet-950 text-violet-300'
  if (status === 'RESOLVED') return 'bg-emerald-950 text-emerald-300'
  return 'bg-slate-800 text-slate-300'
}

function priorityClass(priority: string | null | undefined) {
  if (priority === 'URGENT') return 'text-red-300'
  if (priority === 'HIGH') return 'text-amber-300'
  if (priority === 'LOW') return 'text-slate-500'
  return 'text-cyan-300'
}

function formatOffset(minutes: number) {
  if (minutes === 0) return 'Đúng thời điểm'
  const abs = Math.abs(minutes)
  const direction = minutes < 0 ? 'trước' : 'sau'
  if (abs % 1440 === 0) return `${abs / 1440} ngày ${direction}`
  if (abs % 60 === 0) return `${abs / 60} giờ ${direction}`
  return `${abs} phút ${direction}`
}

function ErrorPanel({ message }: { message: string | null }) {
  if (!message) return null
  return <div className="rounded-xl border border-red-900 bg-red-950/30 p-4 text-sm text-red-200">{message}</div>
}

function RuleForm({
  initial,
  onCancel,
  onDone,
}: {
  initial?: ReminderRuleRow
  onCancel: () => void
  onDone: () => void
}) {
  const [code, setCode] = useState(initial?.rule_code ?? '')
  const [name, setName] = useState(initial?.name ?? '')
  const [eventType, setEventType] = useState(initial?.event_type ?? 'WARRANTY_END')
  const [offset, setOffset] = useState(String(initial?.offset_minutes ?? 0))
  const [priority, setPriority] = useState(initial?.priority ?? 'NORMAL')
  const [active, setActive] = useState(initial?.is_active ?? true)
  const [description, setDescription] = useState(initial?.description ?? '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)
    try {
      const minutes = Math.trunc(Number(offset) || 0)
      if (initial) {
        const { error: rpcError } = await supabase.rpc('reminder_rule_update', {
          p_rule_id: initial.id,
          p_name: name.trim(),
          p_offset_minutes: minutes,
          p_priority: priority,
          p_is_active: active,
          p_description: description.trim() || undefined,
        })
        if (rpcError) throw rpcError
      } else {
        const { error: rpcError } = await supabase.rpc('reminder_rule_create', {
          p_rule_code: code.trim().toUpperCase(),
          p_name: name.trim(),
          p_event_type: eventType,
          p_offset_minutes: minutes,
          p_priority: priority,
          p_description: description.trim() || undefined,
          p_is_active: active,
        })
        if (rpcError) throw rpcError
      }
      onDone()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không lưu được reminder rule.')
    } finally {
      setBusy(false)
    }
  }

  return <form className="space-y-4" onSubmit={submit}>
    {!initial ? <label className="block text-sm font-medium">Rule code
      <input required pattern="[A-Za-z0-9_]+" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 uppercase" value={code} onChange={(e) => setCode(e.target.value)} placeholder="CUSTOM_RULE" />
    </label> : <div className="rounded-xl border border-slate-800 bg-slate-950/50 p-3"><div className="font-mono text-sm text-cyan-300">{initial.rule_code}</div><div className="mt-1 text-xs text-slate-500">{initial.event_type} · {initial.is_system ? 'SYSTEM' : 'CUSTOM'}</div></div>}
    <label className="block text-sm font-medium">Tên
      <input required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={name} onChange={(e) => setName(e.target.value)} />
    </label>
    {!initial ? <label className="block text-sm font-medium">Event
      <select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={eventType} onChange={(e) => setEventType(e.target.value)}>
        {EVENT_TYPES.map((x) => <option key={x}>{x}</option>)}
      </select>
    </label> : null}
    <div className="grid gap-4 sm:grid-cols-2">
      <label className="text-sm font-medium">Offset (phút)
        <input type="number" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={offset} onChange={(e) => setOffset(e.target.value)} />
        <span className="mt-1 block text-xs text-slate-500">Âm = trước mốc, dương = sau mốc. Hiện tại: {formatOffset(Math.trunc(Number(offset) || 0))}.</span>
      </label>
      <label className="text-sm font-medium">Ưu tiên
        <select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={priority} onChange={(e) => setPriority(e.target.value)}>
          {['LOW','NORMAL','HIGH','URGENT'].map((x) => <option key={x}>{x}</option>)}
        </select>
      </label>
    </div>
    <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} /> Rule đang hoạt động</label>
    <label className="block text-sm font-medium">Mô tả
      <textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={description} onChange={(e) => setDescription(e.target.value)} />
    </label>
    <ErrorPanel message={error} />
    <div className="flex justify-end gap-2">
      <button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button>
      <button disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-50">{busy ? 'Đang lưu…' : 'Lưu rule'}</button>
    </div>
  </form>
}

export function ReminderPage({
  context,
  initialTarget,
  initialAction,
  onOpenCrm,
  onOpenRepair,
  onOpenWarranty,
  onOpenServiceLicense,
  onOpenInventory,
  onOpenNotifications,
}: {
  context: AppUserContext
  initialTarget?: QrResolved
  initialAction?: QrAction
  onOpenCrm?: () => void
  onOpenRepair?: () => void
  onOpenWarranty?: () => void
  onOpenServiceLicense?: () => void
  onOpenInventory?: () => void
  onOpenNotifications?: () => void
}) {
  const canView = hasPermission(context, 'notification.view') || hasPermission(context, 'notification.manage')
  const canManage = hasPermission(context, 'notification.manage')
  const [tab, setTab] = useState<Tab>('reminders')
  const [rules, setRules] = useState<ReminderRuleRow[]>([])
  const [reminders, setReminders] = useState<ReminderSummaryRow[]>([])
  const [statusFilter, setStatusFilter] = useState('ACTIVE')
  const [eventFilter, setEventFilter] = useState('ALL')
  const [search, setSearch] = useState(initialTarget?.resource_type === 'REMINDER' ? initialTarget.resource_id ?? '' : '')
  const [showCreateRule, setShowCreateRule] = useState(false)
  const [editingRule, setEditingRule] = useState<ReminderRuleRow | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [lastRun, setLastRun] = useState<Json | null>(null)

  const load = useCallback(async () => {
    setError(null)
    try {
      const rulesResult = await supabase.from('reminder_rules').select('*').order('rule_code')
      if (rulesResult.error) throw rulesResult.error
      const reminderResult = await supabase.from('reminder_summary').select('*').order('due_at', { ascending: true }).limit(2000)
      if (reminderResult.error) throw reminderResult.error
      setRules(rulesResult.data)
      setReminders(reminderResult.data)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tải được Reminder Engine.')
    }
  }, [])

  useEffect(() => { void load() }, [load])
  useEffect(() => {
    if (initialTarget?.resource_type === 'REMINDER') {
      setTab('reminders')
      if (initialTarget.resource_id) setSearch(initialTarget.resource_id)
      if (initialAction === 'VIEW' || initialAction === 'EDIT') setStatusFilter('ALL')
    }
  }, [initialTarget, initialAction])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return reminders.filter((r) => {
      const statusOk = statusFilter === 'ALL'
        || (statusFilter === 'ACTIVE' && ['PENDING','DUE','SNOOZED','ACKNOWLEDGED'].includes(r.status ?? ''))
        || r.status === statusFilter
      const eventOk = eventFilter === 'ALL' || r.event_type === eventFilter
      const searchOk = !q || [r.id,r.reminder_code,r.title,r.message,r.source_label,r.customer_name,r.phone,r.rule_code_snapshot]
        .some((x) => x?.toLowerCase().includes(q))
      return statusOk && eventOk && searchOk
    })
  }, [reminders, statusFilter, eventFilter, search])

  const counts = useMemo(() => ({
    due: reminders.filter((r) => r.status === 'DUE').length,
    pending: reminders.filter((r) => r.status === 'PENDING').length,
    snoozed: reminders.filter((r) => r.status === 'SNOOZED').length,
    acknowledged: reminders.filter((r) => r.status === 'ACKNOWLEDGED').length,
  }), [reminders])

  async function runEngine() {
    setBusy(true)
    setError(null)
    try {
      const { data, error: rpcError } = await supabase.rpc('reminder_generate', {})
      if (rpcError) throw rpcError
      setLastRun(data)
      await load()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không chạy được Reminder Engine.')
    } finally {
      setBusy(false)
    }
  }

  async function acknowledge(row: ReminderSummaryRow) {
    if (!row.id) return
    const note = window.prompt('Ghi chú xác nhận:', row.operator_note ?? '') ?? ''
    const { error: rpcError } = await supabase.rpc('reminder_acknowledge', {
      p_reminder_id: row.id,
      p_note: note.trim() || undefined,
    })
    if (rpcError) setError(rpcError.message); else await load()
  }

  async function snooze(row: ReminderSummaryRow) {
    if (!row.id) return
    const raw = window.prompt('Tạm hoãn bao nhiêu giờ?', '4')
    if (!raw) return
    const hours = Number(raw)
    if (!Number.isFinite(hours) || hours <= 0) {
      setError('Số giờ snooze phải lớn hơn 0.')
      return
    }
    const until = new Date(Date.now() + hours * 3600_000).toISOString()
    const { error: rpcError } = await supabase.rpc('reminder_snooze', {
      p_reminder_id: row.id,
      p_snoozed_until: until,
      p_note: `Snooze ${hours} giờ`,
    })
    if (rpcError) setError(rpcError.message); else await load()
  }

  async function resolve(row: ReminderSummaryRow) {
    if (!row.id) return
    const reason = window.prompt('Lý do resolve reminder:')
    if (!reason?.trim()) return
    const { error: rpcError } = await supabase.rpc('reminder_resolve', {
      p_reminder_id: row.id,
      p_reason: reason.trim(),
    })
    if (rpcError) setError(rpcError.message); else await load()
  }

  if (!canView) {
    return <main className="grid min-h-screen place-items-center bg-slate-950 text-slate-200"><div className="rounded-2xl border border-amber-900 p-6">Vai trò hiện tại không có quyền xem nhắc việc.</div></main>
  }

  return <main className="min-h-screen bg-slate-950 text-slate-200">
    <header className="border-b border-slate-800 bg-slate-900/90 px-4 py-4 sm:px-6">
      <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4">
        <div><div className="text-sm font-semibold uppercase tracking-[0.24em] text-cyan-400">HomeTechVN</div><h1 className="mt-1 text-xl font-bold text-white">Reminder Engine</h1></div>
        <div className="flex flex-wrap items-center gap-2 text-sm">
          {onOpenCrm ? <button onClick={onOpenCrm} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">CRM</button> : null}
          {onOpenRepair ? <button onClick={onOpenRepair} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Sửa chữa</button> : null}
          {onOpenWarranty ? <button onClick={onOpenWarranty} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Bảo hành</button> : null}
          {onOpenServiceLicense ? <button onClick={onOpenServiceLicense} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Dịch vụ</button> : null}
          {onOpenInventory ? <button onClick={onOpenInventory} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Kho</button> : null}
          {onOpenNotifications ? <button onClick={onOpenNotifications} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Thông báo</button> : null}
          <div className="px-2 text-right"><div className="font-medium text-white">{context.fullName || context.email || 'Người dùng'}</div><div className="text-xs text-slate-500">{context.roleName} · {context.roleCode}</div></div>
          <button onClick={() => void supabase.auth.signOut()} className="rounded-xl border border-slate-700 px-3 py-2">Đăng xuất</button>
        </div>
      </div>
    </header>

    <div className="mx-auto max-w-7xl space-y-5 px-4 py-6 sm:px-6">
      <div className="grid gap-3 sm:grid-cols-4">
        <div className="rounded-2xl border border-red-900/60 bg-red-950/20 p-4"><div className="text-xs uppercase text-red-400">Đến hạn</div><div className="mt-1 text-3xl font-bold text-white">{counts.due}</div></div>
        <div className="rounded-2xl border border-cyan-900/60 bg-cyan-950/20 p-4"><div className="text-xs uppercase text-cyan-400">Sắp tới</div><div className="mt-1 text-3xl font-bold text-white">{counts.pending}</div></div>
        <div className="rounded-2xl border border-amber-900/60 bg-amber-950/20 p-4"><div className="text-xs uppercase text-amber-400">Snoozed</div><div className="mt-1 text-3xl font-bold text-white">{counts.snoozed}</div></div>
        <div className="rounded-2xl border border-violet-900/60 bg-violet-950/20 p-4"><div className="text-xs uppercase text-violet-400">Đã xác nhận</div><div className="mt-1 text-3xl font-bold text-white">{counts.acknowledged}</div></div>
      </div>

      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex gap-2">
          <button onClick={() => setTab('reminders')} className={`rounded-xl px-4 py-2 text-sm ${tab === 'reminders' ? 'bg-cyan-500 font-semibold text-slate-950' : 'border border-slate-700'}`}>Nhắc việc</button>
          {canManage ? <button onClick={() => setTab('rules')} className={`rounded-xl px-4 py-2 text-sm ${tab === 'rules' ? 'bg-cyan-500 font-semibold text-slate-950' : 'border border-slate-700'}`}>Rules</button> : null}
        </div>
        <div className="flex gap-2">
          <button onClick={() => void load()} className="rounded-xl border border-slate-700 px-4 py-2 text-sm">Làm mới</button>
          {canManage ? <button disabled={busy} onClick={() => void runEngine()} className="rounded-xl border border-emerald-800 px-4 py-2 text-sm font-semibold text-emerald-300 disabled:opacity-50">{busy ? 'Đang quét…' : 'Chạy engine'}</button> : null}
          {tab === 'rules' && canManage ? <button onClick={() => setShowCreateRule(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ Rule</button> : null}
        </div>
      </div>

      {lastRun ? <div className="rounded-xl border border-emerald-900 bg-emerald-950/20 p-3 text-xs text-emerald-300">Lần chạy gần nhất: <code>{JSON.stringify(lastRun)}</code></div> : null}

      {tab === 'reminders' ? <>
        <div className="grid gap-3 rounded-2xl border border-slate-800 bg-slate-900 p-4 sm:grid-cols-3">
          <input className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm" value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Tìm mã, khách, nguồn, nội dung…" />
          <select className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
            <option value="ACTIVE">Đang hoạt động</option><option value="ALL">Tất cả</option>
            {['DUE','PENDING','SNOOZED','ACKNOWLEDGED','RESOLVED','CANCELLED'].map((x) => <option key={x}>{x}</option>)}
          </select>
          <select className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm" value={eventFilter} onChange={(e) => setEventFilter(e.target.value)}>
            <option value="ALL">Tất cả event</option>{EVENT_TYPES.map((x) => <option key={x}>{x}</option>)}
          </select>
        </div>

        <section className="space-y-2">
          {filtered.map((r) => r.id ? <article key={r.id} className="rounded-2xl border border-slate-800 bg-slate-900 p-4">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-mono text-xs text-cyan-400">{r.reminder_code}</span>
                  <span className={`rounded-lg px-2 py-1 text-[10px] font-semibold ${statusClass(r.status)}`}>{r.status}</span>
                  <span className={`text-xs font-semibold ${priorityClass(r.priority)}`}>{r.priority}</span>
                  <span className="rounded bg-slate-800 px-2 py-1 text-[10px] text-slate-400">{r.event_type}</span>
                </div>
                <h2 className="mt-2 font-semibold text-white">{r.title}</h2>
                <p className="mt-1 text-sm text-slate-300">{r.message}</p>
                <div className="mt-2 flex flex-wrap gap-x-5 gap-y-1 text-xs text-slate-500">
                  <span>Nguồn: {r.source_type} · {r.source_label ?? '—'}</span>
                  <span>Khách: {r.customer_name ?? '—'} {r.phone ? `· ${r.phone}` : ''}</span>
                  <span>Due: <strong className="text-slate-300">{dateTime(r.due_at)}</strong></span>
                  {r.snoozed_until ? <span>Snooze đến: {dateTime(r.snoozed_until)}</span> : null}
                </div>
                {r.operator_note ? <div className="mt-2 text-xs text-slate-400">Ghi chú: {r.operator_note}</div> : null}
                {r.resolution_reason ? <div className="mt-2 text-xs text-emerald-400">Resolve: {r.resolution_reason}</div> : null}
              </div>
              {!['RESOLVED','CANCELLED'].includes(r.status ?? '') ? <div className="flex flex-wrap gap-1">
                <button onClick={() => void acknowledge(r)} className="rounded-lg border border-violet-800 px-2 py-1 text-xs text-violet-300">Đã xử lý/xem</button>
                <button onClick={() => void snooze(r)} className="rounded-lg border border-amber-800 px-2 py-1 text-xs text-amber-300">Snooze</button>
                {canManage ? <button onClick={() => void resolve(r)} className="rounded-lg border border-emerald-800 px-2 py-1 text-xs text-emerald-300">Resolve</button> : null}
              </div> : null}
            </div>
          </article> : null)}
          {filtered.length === 0 ? <div className="rounded-2xl border border-slate-800 bg-slate-900 p-8 text-center text-slate-500">Không có reminder phù hợp.</div> : null}
        </section>
      </> : null}

      {tab === 'rules' && canManage ? <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900">
        <div className="overflow-x-auto"><table className="w-full min-w-[1100px] text-left text-sm">
          <thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Rule</th><th className="px-4 py-3">Event</th><th className="px-4 py-3">Offset</th><th className="px-4 py-3">Priority</th><th className="px-4 py-3">Active</th><th className="px-4 py-3">Mô tả</th><th className="px-4 py-3 text-right">Sửa</th></tr></thead>
          <tbody>{rules.map((r) => <tr key={r.id} className="border-t border-slate-800"><td className="px-4 py-3"><div className="font-mono text-cyan-300">{r.rule_code}</div><div className="text-xs text-slate-400">{r.name}{r.is_system ? ' · SYSTEM' : ''}</div></td><td className="px-4 py-3">{r.event_type}</td><td className="px-4 py-3">{formatOffset(r.offset_minutes)}<div className="text-xs text-slate-500">{r.offset_minutes} phút</div></td><td className={`px-4 py-3 font-semibold ${priorityClass(r.priority)}`}>{r.priority}</td><td className="px-4 py-3">{r.is_active ? <span className="text-emerald-300">ON</span> : <span className="text-slate-500">OFF</span>}</td><td className="max-w-sm px-4 py-3 text-slate-400">{r.description ?? '—'}</td><td className="px-4 py-3 text-right"><button onClick={() => setEditingRule(r)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs">Sửa</button></td></tr>)}</tbody>
        </table></div>
      </section> : null}

      <ErrorPanel message={error} />
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-3 text-xs text-slate-500">
        T9 chỉ sinh và quản lý reminder. Việc gửi in-app / Telegram / email thuộc T10 Notification. Lịch gọi tự động sẽ đi qua Worker/Cron theo kiến trúc dự án.
      </div>
    </div>

    {showCreateRule ? <Modal title="Tạo Reminder Rule" onClose={() => setShowCreateRule(false)}><RuleForm onCancel={() => setShowCreateRule(false)} onDone={() => { setShowCreateRule(false); void load() }} /></Modal> : null}
    {editingRule ? <Modal title="Sửa Reminder Rule" onClose={() => setEditingRule(null)}><RuleForm initial={editingRule} onCancel={() => setEditingRule(null)} onDone={() => { setEditingRule(null); void load() }} /></Modal> : null}
  </main>
}
