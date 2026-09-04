import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react'
import type { Json, NotificationLogRow, NotificationSummaryRow, ReminderRuleRow } from '../../lib/database.types'
import { hasPermission, type AppUserContext } from '../../lib/permissions'
import { supabase } from '../../lib/supabase'
import { Modal } from '../crm/forms'
import type { QrAction, QrResolved } from '../qr/QrCommandCenter'

type Tab = 'inbox' | 'outbox' | 'routes' | 'channels' | 'logs'
type SettingRow = {
  key: string
  value: Json | null
  description: string | null
  is_sensitive: boolean
  secret_ref: string | null
}

function dateTime(value: string | null | undefined) {
  return value ? new Date(value).toLocaleString('vi-VN') : '—'
}

function statusClass(status: string | null | undefined) {
  if (status === 'SENT') return 'bg-emerald-950 text-emerald-300'
  if (status === 'FAILED') return 'bg-red-950 text-red-300'
  if (status === 'RETRYING') return 'bg-amber-950 text-amber-300'
  if (status === 'PROCESSING') return 'bg-violet-950 text-violet-300'
  if (status === 'CANCELLED') return 'bg-slate-800 text-slate-400'
  return 'bg-cyan-950 text-cyan-300'
}

function ErrorPanel({ message }: { message: string | null }) {
  return message ? <div className="rounded-xl border border-red-900 bg-red-950/30 p-4 text-sm text-red-200">{message}</div> : null
}

function jsonObject(value: Json | null): Record<string, Json> {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, Json> : {}
}

function RuleRouteEditor({
  rule,
  onCancel,
  onDone,
}: {
  rule: ReminderRuleRow
  onCancel: () => void
  onDone: () => void
}) {
  const [staff, setStaff] = useState<string[]>(rule.staff_channels)
  const [customer, setCustomer] = useState<string[]>(rule.customer_channels)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  function toggle(list: string[], value: string, setter: (next: string[]) => void) {
    setter(list.includes(value) ? list.filter((x) => x !== value) : [...list, value])
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)
    try {
      const { error: rpcError } = await supabase.rpc('notification_rule_configure', {
        p_rule_id: rule.id,
        p_staff_channels: staff,
        p_customer_channels: customer,
      })
      if (rpcError) throw rpcError
      onDone()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không lưu được routing.')
    } finally {
      setBusy(false)
    }
  }

  return <form className="space-y-5" onSubmit={submit}>
    <div className="rounded-xl border border-slate-800 bg-slate-950/50 p-4">
      <div className="font-mono text-cyan-300">{rule.rule_code}</div>
      <div className="mt-1 text-sm text-slate-300">{rule.name}</div>
    </div>

    <fieldset className="space-y-2">
      <legend className="font-semibold text-white">Kênh nội bộ</legend>
      {['IN_APP','TELEGRAM'].map((channel) => <label key={channel} className="flex items-center gap-2 rounded-xl border border-slate-800 p-3">
        <input type="checkbox" checked={staff.includes(channel)} onChange={() => toggle(staff, channel, setStaff)} />
        {channel === 'IN_APP' ? 'In-app cho nhân viên' : 'Telegram cho nhân viên'}
      </label>)}
    </fieldset>

    <fieldset className="space-y-2">
      <legend className="font-semibold text-white">Kênh khách hàng</legend>
      {['EMAIL','ZALO'].map((channel) => <label key={channel} className="flex items-center gap-2 rounded-xl border border-slate-800 p-3">
        <input type="checkbox" checked={customer.includes(channel)} onChange={() => toggle(customer, channel, setCustomer)} />
        {channel === 'EMAIL' ? 'Email khách hàng' : 'Zalo khách hàng'}
      </label>)}
    </fieldset>

    <ErrorPanel message={error} />
    <div className="flex justify-end gap-2">
      <button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button>
      <button disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-50">{busy ? 'Đang lưu…' : 'Lưu routing'}</button>
    </div>
  </form>
}

function ChannelEditor({
  channel,
  setting,
  secret,
  onCancel,
  onDone,
}: {
  channel: 'IN_APP' | 'TELEGRAM' | 'EMAIL' | 'ZALO'
  setting: SettingRow | undefined
  secret: SettingRow | undefined
  onCancel: () => void
  onDone: () => void
}) {
  const current = jsonObject(setting?.value ?? null)
  const [enabled, setEnabled] = useState(Boolean(current.enabled))
  const [secretRef, setSecretRef] = useState(secret?.secret_ref ?? '')
  const [text, setText] = useState(() => {
    const clone = { ...current }
    delete clone.enabled
    return JSON.stringify(clone, null, 2)
  })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)
    try {
      let config: Json = {}
      try {
        const parsed = JSON.parse(text || '{}')
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('Config phải là JSON object.')
        config = parsed as Json
      } catch (err) {
        throw new Error(err instanceof Error ? err.message : 'JSON không hợp lệ.')
      }

      const { error: rpcError } = await supabase.rpc('notification_channel_configure', {
        p_channel: channel,
        p_enabled: enabled,
        p_config: config,
        p_secret_ref: secretRef.trim() || undefined,
      })
      if (rpcError) throw rpcError
      onDone()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không lưu được cấu hình kênh.')
    } finally {
      setBusy(false)
    }
  }

  const helper = channel === 'TELEGRAM'
    ? 'Ví dụ recipients: [{"profile_id":"<UUID profile>","chat_id":"123456"}], parse_mode: "HTML".'
    : channel === 'EMAIL'
      ? 'Ví dụ provider: "HTTP", from: "support@example.com". URL/API key nằm ở Worker secret.'
      : channel === 'ZALO'
        ? 'mode: "ZBS_PHONE" hoặc "OA_UID". ZBS_PHONE cần template_map theo rule_code/event_type.'
        : 'In-app chỉ cần enabled=true.'

  return <form className="space-y-4" onSubmit={submit}>
    <label className="flex items-center gap-2"><input type="checkbox" checked={enabled} onChange={(e) => setEnabled(e.target.checked)} /> Bật kênh {channel}</label>
    <label className="block text-sm font-medium">Config JSON
      <textarea className="mt-2 min-h-48 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 font-mono text-xs" value={text} onChange={(e) => setText(e.target.value)} />
      <span className="mt-1 block text-xs text-slate-500">{helper}</span>
    </label>
    {channel !== 'IN_APP' ? <label className="block text-sm font-medium">Secret reference
      <input className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 font-mono text-sm" value={secretRef} onChange={(e) => setSecretRef(e.target.value)} placeholder="env://..." />
      <span className="mt-1 block text-xs text-amber-300">Không nhập token/API key thật vào đây. Chỉ nhập URI tham chiếu secret.</span>
    </label> : null}
    <ErrorPanel message={error} />
    <div className="flex justify-end gap-2">
      <button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button>
      <button disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-50">{busy ? 'Đang lưu…' : 'Lưu kênh'}</button>
    </div>
  </form>
}

export function NotificationPage({
  context,
  initialTarget,
  initialAction,
  onOpenCrm,
  onOpenReminders,
}: {
  context: AppUserContext
  initialTarget?: QrResolved
  initialAction?: QrAction
  onOpenCrm?: () => void
  onOpenReminders?: () => void
}) {
  const canView = hasPermission(context, 'notification.view') || hasPermission(context, 'notification.manage')
  const canManage = hasPermission(context, 'notification.manage')
  const canSettings = hasPermission(context, 'settings.manage')

  const [tab, setTab] = useState<Tab>('inbox')
  const [notifications, setNotifications] = useState<NotificationSummaryRow[]>([])
  const [logs, setLogs] = useState<NotificationLogRow[]>([])
  const [rules, setRules] = useState<ReminderRuleRow[]>([])
  const [settings, setSettings] = useState<SettingRow[]>([])
  const [editingRule, setEditingRule] = useState<ReminderRuleRow | null>(null)
  const [editingChannel, setEditingChannel] = useState<'IN_APP' | 'TELEGRAM' | 'EMAIL' | 'ZALO' | null>(null)
  const [filterChannel, setFilterChannel] = useState('ALL')
  const [filterStatus, setFilterStatus] = useState('ALL')
  const [busy, setBusy] = useState(false)
  const [lastPrepare, setLastPrepare] = useState<Json | null>(null)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setError(null)
    try {
      const n = await supabase.from('notification_summary').select('*').order('created_at', { ascending: false }).limit(2000)
      if (n.error) throw n.error
      setNotifications(n.data)

      if (canManage) {
        const [r, l] = await Promise.all([
          supabase.from('reminder_rules').select('*').order('rule_code'),
          supabase.from('notification_logs').select('*').order('id', { ascending: false }).limit(1000),
        ])
        if (r.error) throw r.error
        if (l.error) throw l.error
        setRules(r.data)
        setLogs(l.data)
      }

      if (canSettings) {
        const s = await supabase.from('settings').select('*').like('key', 'notification.%').order('key')
        if (s.error) throw s.error
        setSettings(s.data as SettingRow[])
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tải được Notification Center.')
    }
  }, [canManage, canSettings])

  useEffect(() => { void load() }, [load])
  useEffect(() => {
    if (initialTarget?.resource_type !== 'NOTIFICATION') return
    if (initialAction === 'CREATE') setTab('routes')
    else if (initialTarget.resource_id) {
      const row=notifications.find((item) => item.id === initialTarget.resource_id)
      if (row) setTab(row.channel === 'IN_APP' ? 'inbox' : 'outbox')
    }
  }, [initialTarget, initialAction, notifications])

  const inbox = useMemo(() => notifications.filter((x) => x.channel === 'IN_APP' && (!initialTarget?.resource_id || initialTarget.resource_type !== 'NOTIFICATION' || x.id === initialTarget.resource_id)), [notifications, initialTarget])
  const unread = inbox.filter((x) => !x.read_at).length
  const outbox = useMemo(() => notifications.filter((x) =>
    (!initialTarget?.resource_id || initialTarget.resource_type !== 'NOTIFICATION' || x.id === initialTarget.resource_id)
    &&
    (filterChannel === 'ALL' || x.channel === filterChannel)
    && (filterStatus === 'ALL' || x.status === filterStatus)
  ), [notifications, filterChannel, filterStatus, initialTarget])

  async function prepare() {
    setBusy(true)
    setError(null)
    try {
      const { data, error: rpcError } = await supabase.rpc('notification_prepare', {})
      if (rpcError) throw rpcError
      setLastPrepare(data)
      await load()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không prepare được outbox.')
    } finally {
      setBusy(false)
    }
  }

  async function markRead(id: string) {
    const { error: rpcError } = await supabase.rpc('notification_mark_read', { p_notification_id: id })
    if (rpcError) setError(rpcError.message); else await load()
  }

  async function markAllRead() {
    const { error: rpcError } = await supabase.rpc('notification_mark_all_read', {})
    if (rpcError) setError(rpcError.message); else await load()
  }

  async function retry(id: string) {
    const { error: rpcError } = await supabase.rpc('notification_retry', { p_notification_id: id })
    if (rpcError) setError(rpcError.message); else await load()
  }

  async function cancel(id: string) {
    const reason = window.prompt('Lý do hủy notification:')
    if (!reason?.trim()) return
    const { error: rpcError } = await supabase.rpc('notification_cancel', { p_notification_id: id, p_reason: reason.trim() })
    if (rpcError) setError(rpcError.message); else await load()
  }

  function setting(key: string) {
    return settings.find((x) => x.key === key)
  }

  if (!canView) {
    return <main className="grid min-h-screen place-items-center bg-slate-950 text-slate-200"><div className="rounded-2xl border border-amber-900 p-6">Vai trò hiện tại không có quyền Notification.</div></main>
  }

  return <main className="min-h-screen bg-slate-950 text-slate-200">
    <header className="border-b border-slate-800 bg-slate-900/90 px-4 py-4 sm:px-6">
      <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4">
        <div><div className="text-sm font-semibold uppercase tracking-[0.24em] text-cyan-400">HomeTechVN</div><h1 className="mt-1 text-xl font-bold text-white">Notification Center</h1></div>
        <div className="flex flex-wrap items-center gap-2 text-sm">
          {onOpenCrm ? <button onClick={onOpenCrm} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">CRM</button> : null}
          {onOpenReminders ? <button onClick={onOpenReminders} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Reminder</button> : null}
          <div className="px-2 text-right"><div className="font-medium text-white">{context.fullName || context.email || 'Người dùng'}</div><div className="text-xs text-slate-500">{context.roleName} · {context.roleCode}</div></div>
          <button onClick={() => void supabase.auth.signOut()} className="rounded-xl border border-slate-700 px-3 py-2">Đăng xuất</button>
        </div>
      </div>
    </header>

    <div className="mx-auto max-w-7xl space-y-5 px-4 py-6 sm:px-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap gap-2">
          <button onClick={() => setTab('inbox')} className={`rounded-xl px-4 py-2 text-sm ${tab === 'inbox' ? 'bg-cyan-500 font-semibold text-slate-950' : 'border border-slate-700'}`}>In-app {unread ? `(${unread})` : ''}</button>
          {canManage ? <button onClick={() => setTab('outbox')} className={`rounded-xl px-4 py-2 text-sm ${tab === 'outbox' ? 'bg-cyan-500 font-semibold text-slate-950' : 'border border-slate-700'}`}>Outbox</button> : null}
          {canManage ? <button onClick={() => setTab('routes')} className={`rounded-xl px-4 py-2 text-sm ${tab === 'routes' ? 'bg-cyan-500 font-semibold text-slate-950' : 'border border-slate-700'}`}>Routing</button> : null}
          {canSettings ? <button onClick={() => setTab('channels')} className={`rounded-xl px-4 py-2 text-sm ${tab === 'channels' ? 'bg-cyan-500 font-semibold text-slate-950' : 'border border-slate-700'}`}>Kênh</button> : null}
          {canManage ? <button onClick={() => setTab('logs')} className={`rounded-xl px-4 py-2 text-sm ${tab === 'logs' ? 'bg-cyan-500 font-semibold text-slate-950' : 'border border-slate-700'}`}>Logs</button> : null}
        </div>
        <div className="flex gap-2">
          <button onClick={() => void load()} className="rounded-xl border border-slate-700 px-4 py-2 text-sm">Làm mới</button>
          {canManage ? <button disabled={busy} onClick={() => void prepare()} className="rounded-xl border border-emerald-800 px-4 py-2 text-sm font-semibold text-emerald-300 disabled:opacity-50">{busy ? 'Đang prepare…' : 'Prepare outbox'}</button> : null}
        </div>
      </div>

      {lastPrepare ? <div className="rounded-xl border border-emerald-900 bg-emerald-950/20 p-3 text-xs text-emerald-300"><code>{JSON.stringify(lastPrepare)}</code></div> : null}

      {tab === 'inbox' ? <section className="space-y-2">
        <div className="flex justify-end">{unread ? <button onClick={() => void markAllRead()} className="rounded-lg border border-cyan-900 px-3 py-2 text-xs text-cyan-300">Đánh dấu tất cả đã đọc</button> : null}</div>
        {inbox.map((n) => n.id ? <article key={n.id} className={`rounded-2xl border p-4 ${n.read_at ? 'border-slate-800 bg-slate-900' : 'border-cyan-900 bg-cyan-950/20'}`}>
          <div className="flex items-start justify-between gap-3">
            <div><div className="font-mono text-xs text-cyan-400">{n.notification_code}</div><h2 className="mt-1 font-semibold text-white">{n.subject}</h2><p className="mt-1 text-sm text-slate-300">{n.body}</p><div className="mt-2 text-xs text-slate-500">{dateTime(n.created_at)} · {n.event_type}</div></div>
            {!n.read_at ? <button onClick={() => void markRead(n.id!)} className="rounded-lg border border-cyan-900 px-2 py-1 text-xs text-cyan-300">Đã đọc</button> : null}
          </div>
        </article> : null)}
        {!inbox.length ? <div className="rounded-2xl border border-slate-800 bg-slate-900 p-8 text-center text-slate-500">Chưa có thông báo in-app.</div> : null}
      </section> : null}

      {tab === 'outbox' && canManage ? <>
        <div className="grid gap-3 rounded-2xl border border-slate-800 bg-slate-900 p-4 sm:grid-cols-2">
          <select value={filterChannel} onChange={(e) => setFilterChannel(e.target.value)} className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2"><option value="ALL">Tất cả kênh</option>{['IN_APP','TELEGRAM','EMAIL','ZALO'].map((x) => <option key={x}>{x}</option>)}</select>
          <select value={filterStatus} onChange={(e) => setFilterStatus(e.target.value)} className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2"><option value="ALL">Tất cả trạng thái</option>{['PENDING','PROCESSING','RETRYING','SENT','FAILED','CANCELLED'].map((x) => <option key={x}>{x}</option>)}</select>
        </div>
        <div className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900"><div className="overflow-x-auto"><table className="w-full min-w-[1250px] text-left text-sm">
          <thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Notification</th><th className="px-4 py-3">Kênh</th><th className="px-4 py-3">Người nhận</th><th className="px-4 py-3">Nội dung</th><th className="px-4 py-3">Attempt</th><th className="px-4 py-3">Status</th><th className="px-4 py-3 text-right">Thao tác</th></tr></thead>
          <tbody>{outbox.map((n) => n.id ? <tr key={n.id} className="border-t border-slate-800"><td className="px-4 py-3"><div className="font-mono text-cyan-300">{n.notification_code}</div><div className="text-xs text-slate-500">{n.rule_code_snapshot}</div></td><td className="px-4 py-3">{n.channel}<div className="text-xs text-slate-500">{n.provider}</div></td><td className="px-4 py-3">{n.recipient_profile_name ?? n.customer_name ?? '—'}<div className="max-w-56 truncate text-xs text-slate-500">{n.recipient_address ?? '—'}</div></td><td className="max-w-md px-4 py-3"><div className="font-medium text-white">{n.subject}</div><div className="line-clamp-2 text-xs text-slate-400">{n.body}</div></td><td className="px-4 py-3">{n.attempt_count}/{n.max_attempts}<div className="text-xs text-slate-500">{dateTime(n.last_attempt_at)}</div></td><td className="px-4 py-3"><span className={`rounded-lg px-2 py-1 text-xs ${statusClass(n.status)}`}>{n.status}</span>{n.last_error_message ? <div className="mt-1 max-w-56 truncate text-xs text-red-300">{n.last_error_code}: {n.last_error_message}</div> : null}</td><td className="px-4 py-3 text-right"><div className="flex justify-end gap-1">{n.status === 'FAILED' ? <button onClick={() => void retry(n.id!)} className="rounded-lg border border-amber-800 px-2 py-1 text-xs text-amber-300">Retry</button> : null}{!['SENT','CANCELLED'].includes(n.status ?? '') ? <button onClick={() => void cancel(n.id!)} className="rounded-lg border border-red-900 px-2 py-1 text-xs text-red-300">Hủy</button> : null}</div></td></tr> : null)}</tbody>
        </table></div></div>
      </> : null}

      {tab === 'routes' && canManage ? <div className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900"><div className="overflow-x-auto"><table className="w-full min-w-[1050px] text-left text-sm">
        <thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Rule</th><th className="px-4 py-3">Staff</th><th className="px-4 py-3">Khách hàng</th><th className="px-4 py-3 text-right">Cấu hình</th></tr></thead>
        <tbody>{rules.map((r) => <tr key={r.id} className="border-t border-slate-800"><td className="px-4 py-3"><div className="font-mono text-cyan-300">{r.rule_code}</div><div className="text-xs text-slate-400">{r.name}</div></td><td className="px-4 py-3">{r.staff_channels.join(', ') || '—'}</td><td className="px-4 py-3">{r.customer_channels.join(', ') || '—'}</td><td className="px-4 py-3 text-right"><button onClick={() => setEditingRule(r)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs">Sửa</button></td></tr>)}</tbody>
      </table></div></div> : null}

      {tab === 'channels' && canSettings ? <div className="grid gap-4 sm:grid-cols-2">
        {(['IN_APP','TELEGRAM','EMAIL','ZALO'] as const).map((channel) => {
          const key = channel === 'IN_APP' ? 'notification.in_app' : `notification.${channel.toLowerCase()}.config`
          const secretKey = channel === 'IN_APP' ? '' : `notification.${channel.toLowerCase()}.token`
          const current = setting(key)
          const cfg = jsonObject(current?.value ?? null)
          return <article key={channel} className="rounded-2xl border border-slate-800 bg-slate-900 p-5">
            <div className="flex items-center justify-between"><h2 className="font-semibold text-white">{channel}</h2><span className={cfg.enabled ? 'text-emerald-300' : 'text-slate-500'}>{cfg.enabled ? 'ON' : 'OFF'}</span></div>
            <pre className="mt-3 max-h-40 overflow-auto rounded-xl bg-slate-950 p-3 text-xs text-slate-400">{JSON.stringify(cfg, null, 2)}</pre>
            {secretKey ? <div className="mt-2 font-mono text-xs text-amber-300">{setting(secretKey)?.secret_ref ?? 'Chưa có secret_ref'}</div> : null}
            <button onClick={() => setEditingChannel(channel)} className="mt-4 rounded-lg border border-cyan-900 px-3 py-2 text-xs text-cyan-300">Cấu hình</button>
          </article>
        })}
      </div> : null}

      {tab === 'logs' && canManage ? <div className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900"><div className="overflow-x-auto"><table className="w-full min-w-[1000px] text-left text-sm">
        <thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Attempt</th><th className="px-4 py-3">Kênh</th><th className="px-4 py-3">Status</th><th className="px-4 py-3">External ID</th><th className="px-4 py-3">Error</th><th className="px-4 py-3">Thời gian</th></tr></thead>
        <tbody>{logs.map((l) => <tr key={l.id} className="border-t border-slate-800"><td className="px-4 py-3">#{l.attempt_no}<div className="font-mono text-[10px] text-slate-500">{l.notification_id}</div></td><td className="px-4 py-3">{l.channel}<div className="text-xs text-slate-500">{l.provider}</div></td><td className="px-4 py-3"><span className={`rounded-lg px-2 py-1 text-xs ${statusClass(l.status)}`}>{l.status}</span></td><td className="px-4 py-3 font-mono text-xs">{l.external_message_id ?? '—'}</td><td className="px-4 py-3 text-xs text-red-300">{l.error_code ? `${l.error_code}: ${l.error_message ?? ''}` : '—'}</td><td className="px-4 py-3 text-xs">{dateTime(l.started_at)}<br/>{dateTime(l.finished_at)}</td></tr>)}</tbody>
      </table></div></div> : null}

      <ErrorPanel message={error} />
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-3 text-xs text-slate-500">
        Token Telegram, email API key và Zalo access token không được lưu trong frontend/DB value. Worker đọc secret từ Cloudflare và database chỉ giữ `env://...` reference.
      </div>
    </div>

    {editingRule ? <Modal title="Routing notification" onClose={() => setEditingRule(null)}><RuleRouteEditor rule={editingRule} onCancel={() => setEditingRule(null)} onDone={() => { setEditingRule(null); void load() }} /></Modal> : null}
    {editingChannel ? <Modal title={`Cấu hình ${editingChannel}`} onClose={() => setEditingChannel(null)}><ChannelEditor
      channel={editingChannel}
      setting={setting(editingChannel === 'IN_APP' ? 'notification.in_app' : `notification.${editingChannel.toLowerCase()}.config`)}
      secret={editingChannel === 'IN_APP' ? undefined : setting(`notification.${editingChannel.toLowerCase()}.token`)}
      onCancel={() => setEditingChannel(null)}
      onDone={() => { setEditingChannel(null); void load() }}
    /></Modal> : null}
  </main>
}
