import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react'
import type {
  ChecklistRunItemRow,
  ChecklistRunRow,
  ChecklistRunSummaryRow,
  ChecklistTemplateItemRow,
  ChecklistTemplateRow,
  Json,
  RepairOrderSummaryRow,
  SalesOrderSummaryRow,
} from '../../lib/database.types'
import { hasPermission, type AppUserContext } from '../../lib/permissions'
import { supabase } from '../../lib/supabase'
import { Modal } from '../crm/forms'
import type { QrAction, QrResolved } from '../qr/QrCommandCenter'

type Tab = 'runs' | 'templates'

function dateTime(value: string | null | undefined) {
  return value ? new Date(value).toLocaleString('vi-VN') : '—'
}

function jsonId(value: Json): string {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return ''
  const id = value.id
  return typeof id === 'string' ? id : ''
}

function statusClass(status: string | null | undefined) {
  if (status === 'COMPLETED') return 'bg-emerald-950 text-emerald-300'
  if (status === 'CANCELLED') return 'bg-red-950 text-red-300'
  return 'bg-amber-950 text-amber-300'
}

function ErrorPanel({ message }: { message: string | null }) {
  return message ? <div className="rounded-xl border border-red-900 bg-red-950/30 p-4 text-sm text-red-200">{message}</div> : null
}

function StartRunForm({
  templates,
  sales,
  repairs,
  onCancel,
  onStarted,
}: {
  templates: ChecklistTemplateRow[]
  sales: SalesOrderSummaryRow[]
  repairs: RepairOrderSummaryRow[]
  onCancel: () => void
  onStarted: (id: string) => void
}) {
  const active = templates.filter((t) => t.is_active)
  const [templateId, setTemplateId] = useState(active[0]?.id ?? '')
  const template = useMemo(() => active.find((t) => t.id === templateId), [active, templateId])
  const [entityId, setEntityId] = useState('')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!template) return
    if (template.entity_type === 'SALES_ORDER') {
      setEntityId(sales.find((x) => x.id)?.id ?? '')
    } else if (template.entity_type === 'REPAIR_ORDER') {
      setEntityId(repairs.find((x) => x.id)?.id ?? '')
    } else if (template.entity_type === 'GENERIC') {
      setEntityId(crypto.randomUUID())
    } else {
      setEntityId('')
    }
  }, [template?.id, template?.entity_type, sales, repairs])

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!template || !entityId) return
    setBusy(true)
    setError(null)
    try {
      const { data, error: rpcError } = await supabase.rpc('checklist_run_start', {
        p_template_id: template.id,
        p_entity_type: template.entity_type,
        p_entity_id: entityId,
        p_note: note.trim() || undefined,
      })
      if (rpcError) throw rpcError
      const id = jsonId(data)
      if (!id) throw new Error('RPC không trả run id.')
      onStarted(id)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tạo được checklist run.')
    } finally {
      setBusy(false)
    }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <label className="block text-sm font-medium">Template
      <select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={templateId} onChange={(e) => setTemplateId(e.target.value)} required>
        {active.map((t) => <option key={t.id} value={t.id}>{t.template_code} v{t.version} · {t.name}</option>)}
      </select>
    </label>

    {template?.entity_type === 'SALES_ORDER' ? <label className="block text-sm font-medium">Đơn bán
      <select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={entityId} onChange={(e) => setEntityId(e.target.value)} required>
        <option value="">— Chọn đơn —</option>
        {sales.filter((x) => x.id).map((x) => <option key={x.id!} value={x.id!}>{x.order_code} · {x.customer_name} · {x.status}</option>)}
      </select>
    </label> : null}

    {template?.entity_type === 'REPAIR_ORDER' ? <label className="block text-sm font-medium">Phiếu sửa chữa
      <select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={entityId} onChange={(e) => setEntityId(e.target.value)} required>
        <option value="">— Chọn phiếu —</option>
        {repairs.filter((x) => x.id).map((x) => <option key={x.id!} value={x.id!}>{x.repair_code} · {x.customer_name} · {x.status}</option>)}
      </select>
    </label> : null}

    {template?.entity_type === 'GENERIC' ? <label className="block text-sm font-medium">Entity UUID
      <div className="mt-2 flex gap-2">
        <input className="min-w-0 flex-1 rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 font-mono text-xs" value={entityId} onChange={(e) => setEntityId(e.target.value)} required />
        <button type="button" onClick={() => setEntityId(crypto.randomUUID())} className="rounded-xl border border-slate-700 px-3 py-2 text-xs">UUID mới</button>
      </div>
    </label> : null}

    <label className="block text-sm font-medium">Ghi chú
      <textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={note} onChange={(e) => setNote(e.target.value)} />
    </label>
    <ErrorPanel message={error} />
    <div className="flex justify-end gap-2">
      <button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button>
      <button disabled={busy || !templateId || !entityId} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-50">{busy ? 'Đang tạo…' : 'Bắt đầu checklist'}</button>
    </div>
  </form>
}

function CreateTemplateForm({ onCancel, onCreated }: { onCancel: () => void; onCreated: (id: string) => void }) {
  const [code, setCode] = useState('')
  const [name, setName] = useState('')
  const [module, setModule] = useState('GENERIC')
  const [entityType, setEntityType] = useState('GENERIC')
  const [description, setDescription] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)
    try {
      const { data, error: rpcError } = await supabase.rpc('checklist_template_create', {
        p_template_code: code.trim().toUpperCase(),
        p_name: name.trim(),
        p_module: module,
        p_entity_type: entityType,
        p_description: description.trim() || undefined,
      })
      if (rpcError) throw rpcError
      const id = jsonId(data)
      if (!id) throw new Error('RPC không trả template id.')
      onCreated(id)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tạo được template.')
    } finally {
      setBusy(false)
    }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <div className="grid gap-4 sm:grid-cols-2">
      <label className="text-sm font-medium">Template code
        <input required pattern="[A-Za-z0-9_]+" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 uppercase" value={code} onChange={(e) => setCode(e.target.value)} placeholder="REPAIR_QC" />
      </label>
      <label className="text-sm font-medium">Tên template
        <input required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={name} onChange={(e) => setName(e.target.value)} />
      </label>
      <label className="text-sm font-medium">Module
        <select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={module} onChange={(e) => setModule(e.target.value)}>
          {['SALES','REPAIR','WARRANTY','SERVICE','GENERIC'].map((x) => <option key={x}>{x}</option>)}
        </select>
      </label>
      <label className="text-sm font-medium">Entity type
        <select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={entityType} onChange={(e) => setEntityType(e.target.value)}>
          {['SALES_ORDER','REPAIR_ORDER','WARRANTY','SERVICE','GENERIC'].map((x) => <option key={x}>{x}</option>)}
        </select>
      </label>
    </div>
    <label className="block text-sm font-medium">Mô tả
      <textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={description} onChange={(e) => setDescription(e.target.value)} />
    </label>
    <ErrorPanel message={error} />
    <div className="flex justify-end gap-2">
      <button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button>
      <button disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-50">{busy ? 'Đang tạo…' : 'Tạo version mới'}</button>
    </div>
  </form>
}

function AddTemplateItemForm({
  template,
  nextSort,
  onCancel,
  onDone,
}: {
  template: ChecklistTemplateRow
  nextSort: number
  onCancel: () => void
  onDone: () => void
}) {
  const [key, setKey] = useState('')
  const [label, setLabel] = useState('')
  const [sortOrder, setSortOrder] = useState(String(nextSort))
  const [rule, setRule] = useState('OPTIONAL')
  const [systemManaged, setSystemManaged] = useState(false)
  const [description, setDescription] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)
    try {
      const { error: rpcError } = await supabase.rpc('checklist_template_add_item', {
        p_template_id: template.id,
        p_item_key: key.trim(),
        p_label: label.trim(),
        p_sort_order: Math.max(1, Number(sortOrder) || 1),
        p_requirement_rule: rule,
        p_system_managed: systemManaged,
        p_description: description.trim() || undefined,
      })
      if (rpcError) throw rpcError
      onDone()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không thêm được item.')
    } finally {
      setBusy(false)
    }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <div className="grid gap-4 sm:grid-cols-2">
      <label className="text-sm font-medium">Item key
        <input required pattern="[a-z0-9_]+" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={key} onChange={(e) => setKey(e.target.value.toLowerCase())} />
      </label>
      <label className="text-sm font-medium">Thứ tự
        <input required type="number" min="1" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={sortOrder} onChange={(e) => setSortOrder(e.target.value)} />
      </label>
    </div>
    <label className="block text-sm font-medium">Nội dung kiểm tra
      <input required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={label} onChange={(e) => setLabel(e.target.value)} />
    </label>
    <label className="block text-sm font-medium">Requirement
      <select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={rule} onChange={(e) => setRule(e.target.value)}>
        <option value="ALWAYS">ALWAYS — bắt buộc</option>
        <option value="OPTIONAL">OPTIONAL — tùy chọn</option>
        {template.entity_type === 'SALES_ORDER' ? <option value="SALES_HAS_SERIAL">SALES_HAS_SERIAL — bắt buộc khi đơn có Serial</option> : null}
      </select>
    </label>
    <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={systemManaged} onChange={(e) => setSystemManaged(e.target.checked)} /> Hệ thống tự quản lý trạng thái item</label>
    <label className="block text-sm font-medium">Mô tả
      <textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={description} onChange={(e) => setDescription(e.target.value)} />
    </label>
    <ErrorPanel message={error} />
    <div className="flex justify-end gap-2">
      <button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button>
      <button disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-50">{busy ? 'Đang thêm…' : 'Thêm item'}</button>
    </div>
  </form>
}

function RunDetail({
  runId,
  context,
  onBack,
  onChanged,
}: {
  runId: string
  context: AppUserContext
  onBack: () => void
  onChanged: () => void
}) {
  const [run, setRun] = useState<ChecklistRunRow | null>(null)
  const [items, setItems] = useState<ChecklistRunItemRow[]>([])
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const canManage = hasPermission(context, 'checklist.manage')

  const load = useCallback(async () => {
    setError(null)
    try {
      const [r, i] = await Promise.all([
        supabase.from('checklist_runs').select('*').eq('id', runId).single(),
        supabase.from('checklist_run_items').select('*').eq('run_id', runId).order('sort_order'),
      ])
      if (r.error) throw r.error
      if (i.error) throw i.error
      setRun(r.data)
      setItems(i.data)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tải được checklist run.')
    }
  }, [runId])

  useEffect(() => { void load() }, [load])

  async function toggle(item: ChecklistRunItemRow, checked: boolean) {
    const note = item.note ?? undefined
    const { error: rpcError } = await supabase.rpc('checklist_run_set_item', {
      p_run_item_id: item.id,
      p_checked: checked,
      p_note: note,
    })
    if (rpcError) setError(rpcError.message)
    else { await load(); onChanged() }
  }

  async function action(name: 'checklist_run_refresh' | 'checklist_run_complete') {
    setBusy(true)
    setError(null)
    try {
      const { error: rpcError } = await supabase.rpc(name, { p_run_id: runId })
      if (rpcError) throw rpcError
      await load()
      onChanged()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không thực hiện được thao tác.')
    } finally {
      setBusy(false)
    }
  }

  async function reopen() {
    const note = window.prompt('Ghi chú mở lại checklist:') ?? ''
    const { error: rpcError } = await supabase.rpc('checklist_run_reopen', { p_run_id: runId, p_note: note || undefined })
    if (rpcError) setError(rpcError.message); else { await load(); onChanged() }
  }

  async function cancel() {
    const note = window.prompt('Lý do hủy checklist:')
    if (!note?.trim()) return
    const { error: rpcError } = await supabase.rpc('checklist_run_cancel', { p_run_id: runId, p_note: note.trim() })
    if (rpcError) setError(rpcError.message); else { await load(); onChanged() }
  }

  if (!run) return <div className="space-y-4"><button onClick={onBack} className="text-cyan-300">← Danh sách</button><ErrorPanel message={error} /><p className="text-slate-500">Đang tải…</p></div>

  const required = items.filter((x) => x.required)
  const requiredDone = required.filter((x) => x.checked).length

  return <div className="space-y-5">
    <div className="flex flex-wrap items-start justify-between gap-4">
      <div>
        <button onClick={onBack} className="text-sm text-cyan-300 hover:underline">← Danh sách checklist</button>
        <h2 className="mt-2 text-2xl font-bold text-white">{run.template_code_snapshot} v{run.template_version}</h2>
        <p className="mt-1 font-mono text-xs text-slate-500">{run.entity_type} · {run.entity_id}</p>
      </div>
      <span className={`rounded-xl px-3 py-2 text-sm font-semibold ${statusClass(run.status)}`}>{run.status}</span>
    </div>

    <div className="grid gap-3 sm:grid-cols-3">
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-4"><div className="text-xs text-slate-500">Tiến độ bắt buộc</div><div className="mt-1 text-xl font-bold text-white">{requiredDone}/{required.length}</div></div>
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-4"><div className="text-xs text-slate-500">Tổng item</div><div className="mt-1 text-xl font-bold text-white">{items.filter((x) => x.checked).length}/{items.length}</div></div>
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-4"><div className="text-xs text-slate-500">Bắt đầu</div><div className="mt-1 text-sm text-white">{dateTime(run.started_at)}</div></div>
    </div>

    <div className="flex flex-wrap gap-2 rounded-2xl border border-slate-800 bg-slate-900 p-4">
      {run.status === 'OPEN' ? <button disabled={busy} onClick={() => void action('checklist_run_refresh')} className="rounded-xl border border-cyan-900 px-3 py-2 text-sm text-cyan-300">Đồng bộ</button> : null}
      {run.status === 'OPEN' ? <button disabled={busy} onClick={() => void action('checklist_run_complete')} className="rounded-xl bg-emerald-500 px-3 py-2 text-sm font-semibold text-slate-950">Hoàn tất checklist</button> : null}
      {run.status === 'COMPLETED' && canManage ? <button onClick={() => void reopen()} className="rounded-xl border border-amber-800 px-3 py-2 text-sm text-amber-300">Mở lại</button> : null}
      {run.status !== 'CANCELLED' && canManage ? <button onClick={() => void cancel()} className="rounded-xl border border-red-900 px-3 py-2 text-sm text-red-300">Hủy run</button> : null}
    </div>

    <section className="space-y-2">
      {items.map((item) => <label key={item.id} className={`flex items-start gap-3 rounded-xl border p-4 ${item.checked ? 'border-emerald-900 bg-emerald-950/20' : 'border-slate-800 bg-slate-900'}`}>
        <input
          type="checkbox"
          className="mt-1"
          checked={item.checked}
          disabled={run.status !== 'OPEN' || item.system_managed}
          onChange={(e) => void toggle(item, e.target.checked)}
        />
        <span className="min-w-0 flex-1">
          <span className="text-sm text-slate-100">{item.label}</span>
          <span className="ml-2 text-[10px] text-slate-500">#{item.sort_order}</span>
          {item.required ? <span className="ml-2 rounded bg-amber-950 px-1.5 py-0.5 text-[10px] text-amber-300">BẮT BUỘC</span> : null}
          {item.system_managed ? <span className="ml-2 rounded bg-violet-950 px-1.5 py-0.5 text-[10px] text-violet-300">SYSTEM</span> : null}
          {item.description ? <div className="mt-1 text-xs text-slate-500">{item.description}</div> : null}
          {item.note ? <div className="mt-1 text-xs text-slate-400">Ghi chú: {item.note}</div> : null}
        </span>
        <span className="text-xs text-slate-500">{item.checked ? dateTime(item.checked_at) : ''}</span>
      </label>)}
    </section>

    <ErrorPanel message={error} />
  </div>
}

function TemplatePanel({
  template,
  onBack,
  onChanged,
}: {
  template: ChecklistTemplateRow
  onBack: () => void
  onChanged: () => void
}) {
  const [items, setItems] = useState<ChecklistTemplateItemRow[]>([])
  const [showAdd, setShowAdd] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    const { data, error: queryError } = await supabase.from('checklist_template_items').select('*').eq('template_id', template.id).order('sort_order')
    if (queryError) setError(queryError.message)
    else setItems(data)
  }, [template.id])

  useEffect(() => { void load() }, [load])

  async function activate() {
    const { error: rpcError } = await supabase.rpc('checklist_template_activate', { p_template_id: template.id })
    if (rpcError) setError(rpcError.message)
    else { onChanged(); onBack() }
  }

  return <div className="space-y-5">
    <div className="flex flex-wrap items-start justify-between gap-4">
      <div><button onClick={onBack} className="text-sm text-cyan-300">← Templates</button><h2 className="mt-2 text-2xl font-bold text-white">{template.template_code} v{template.version}</h2><p className="text-sm text-slate-500">{template.name} · {template.module} · {template.entity_type}</p></div>
      <div className="flex gap-2">{template.is_system ? <span className="rounded-xl bg-violet-950 px-3 py-2 text-xs text-violet-300">SYSTEM</span> : null}{template.is_active ? <span className="rounded-xl bg-emerald-950 px-3 py-2 text-xs text-emerald-300">ACTIVE</span> : <button onClick={() => void activate()} className="rounded-xl bg-emerald-500 px-3 py-2 text-sm font-semibold text-slate-950">Activate</button>}</div>
    </div>

    {!template.is_active ? <button onClick={() => setShowAdd(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ Item</button> : null}

    <div className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900">
      <div className="overflow-x-auto"><table className="w-full min-w-[680px] text-left text-sm"><thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">#</th><th className="px-4 py-3">Key / Nội dung</th><th className="px-4 py-3">Rule</th><th className="px-4 py-3">System</th></tr></thead><tbody>
        {items.map((i) => <tr key={i.id} className="border-t border-slate-800"><td className="px-4 py-3">{i.sort_order}</td><td className="px-4 py-3"><div className="font-medium text-white">{i.label}</div><div className="font-mono text-xs text-cyan-400">{i.item_key}</div></td><td className="px-4 py-3">{i.requirement_rule}</td><td className="px-4 py-3">{i.system_managed ? '✓' : '—'}</td></tr>)}
      </tbody></table></div>
    </div>
    <ErrorPanel message={error} />
    {showAdd ? <Modal title="Thêm checklist item" onClose={() => setShowAdd(false)}><AddTemplateItemForm template={template} nextSort={(items.at(-1)?.sort_order ?? 0) + 1} onCancel={() => setShowAdd(false)} onDone={() => { setShowAdd(false); void load() }} /></Modal> : null}
  </div>
}

export function ChecklistPage({
  context,
  initialTarget,
  initialAction,
  onOpenCrm,
  onOpenInventory,
  onOpenSales,
  onOpenRepair,
  onOpenWarranty,
}: {
  context: AppUserContext
  initialTarget?: QrResolved
  initialAction?: QrAction
  onOpenCrm?: () => void
  onOpenInventory?: () => void
  onOpenSales?: () => void
  onOpenRepair?: () => void
  onOpenWarranty?: () => void
}) {
  const canRun = hasPermission(context, 'checklist.run')
  const canManage = hasPermission(context, 'checklist.manage')
  const [tab, setTab] = useState<Tab>('runs')
  const [templates, setTemplates] = useState<ChecklistTemplateRow[]>([])
  const [runs, setRuns] = useState<ChecklistRunSummaryRow[]>([])
  const [sales, setSales] = useState<SalesOrderSummaryRow[]>([])
  const [repairs, setRepairs] = useState<RepairOrderSummaryRow[]>([])
  const [runId, setRunId] = useState<string | null>(initialTarget?.resource_type === 'CHECKLIST_RUN' ? initialTarget.resource_id ?? null : null)
  const [templateId, setTemplateId] = useState<string | null>(null)
  const [showStart, setShowStart] = useState(false)
  const [showCreate, setShowCreate] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setError(null)
    try {
      const [t, r, s, p] = await Promise.all([
        supabase.from('checklist_templates').select('*').order('template_code').order('version', { ascending: false }),
        supabase.from('checklist_run_summary').select('*').order('created_at', { ascending: false }).limit(1000),
        supabase.from('sales_order_summary').select('*').order('created_at', { ascending: false }).limit(500),
        supabase.from('repair_order_summary').select('*').order('created_at', { ascending: false }).limit(500),
      ])
      if (t.error) throw t.error
      if (r.error) throw r.error
      if (s.error) throw s.error
      if (p.error) throw p.error
      setTemplates(t.data)
      setRuns(r.data)
      setSales(s.data)
      setRepairs(p.data)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tải được Checklist Engine.')
    }
  }, [])

  useEffect(() => { void load() }, [load])
  useEffect(() => {
    if (initialTarget?.resource_type === 'CHECKLIST_RUN' && initialTarget.resource_id) {
      setTab('runs')
      setRunId(initialTarget.resource_id)
    } else if (initialAction === 'CREATE' && initialTarget?.resource_type === 'CHECKLIST_RUN') {
      setTab('runs')
      setShowStart(true)
    }
  }, [initialTarget, initialAction])

  const selectedTemplate = useMemo(() => templates.find((x) => x.id === templateId) ?? null, [templates, templateId])

  if (!canRun && !canManage) {
    return <main className="grid min-h-screen place-items-center bg-slate-950 text-slate-200"><div className="rounded-2xl border border-amber-900 p-6">Vai trò hiện tại không có quyền Checklist.</div></main>
  }

  return <main className="min-h-screen bg-slate-950 text-slate-200">
    <header className="border-b border-slate-800 bg-slate-900/90 px-4 py-4 sm:px-6">
      <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4">
        <div><div className="text-sm font-semibold uppercase tracking-[0.24em] text-cyan-400">HomeTechVN</div><h1 className="mt-1 text-xl font-bold text-white">Checklist Engine</h1></div>
        <div className="flex flex-wrap items-center gap-2 text-sm">
          {onOpenCrm ? <button onClick={onOpenCrm} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">CRM</button> : null}
          {onOpenInventory ? <button onClick={onOpenInventory} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Kho</button> : null}
          {onOpenSales ? <button onClick={onOpenSales} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Bán hàng</button> : null}
          {onOpenRepair ? <button onClick={onOpenRepair} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Sửa chữa</button> : null}
          {onOpenWarranty ? <button onClick={onOpenWarranty} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Bảo hành</button> : null}
          <div className="px-2 text-right"><div className="font-medium text-white">{context.fullName || context.email || 'Người dùng'}</div><div className="text-xs text-slate-500">{context.roleName} · {context.roleCode}</div></div>
          <button onClick={() => void supabase.auth.signOut()} className="rounded-xl border border-slate-700 px-3 py-2">Đăng xuất</button>
        </div>
      </div>
    </header>

    <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
      {runId ? <RunDetail runId={runId} context={context} onBack={() => setRunId(null)} onChanged={() => void load()} /> :
       selectedTemplate && canManage ? <TemplatePanel template={selectedTemplate} onBack={() => setTemplateId(null)} onChanged={() => void load()} /> :
       <div className="space-y-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex gap-2">
            <button onClick={() => setTab('runs')} className={`rounded-xl px-4 py-2 text-sm ${tab === 'runs' ? 'bg-cyan-500 font-semibold text-slate-950' : 'border border-slate-700'}`}>Runs</button>
            {canManage ? <button onClick={() => setTab('templates')} className={`rounded-xl px-4 py-2 text-sm ${tab === 'templates' ? 'bg-cyan-500 font-semibold text-slate-950' : 'border border-slate-700'}`}>Templates</button> : null}
          </div>
          <div className="flex gap-2">
            <button onClick={() => void load()} className="rounded-xl border border-slate-700 px-4 py-2 text-sm">Làm mới</button>
            {tab === 'runs' && canRun ? <button onClick={() => setShowStart(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ Start run</button> : null}
            {tab === 'templates' && canManage ? <button onClick={() => setShowCreate(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ Template version</button> : null}
          </div>
        </div>

        {tab === 'runs' ? <div className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900">
          <div className="overflow-x-auto"><table className="w-full min-w-[1000px] text-left text-sm"><thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Template</th><th className="px-4 py-3">Entity</th><th className="px-4 py-3">Tiến độ</th><th className="px-4 py-3">Status</th><th className="px-4 py-3">Bắt đầu</th><th className="px-4 py-3 text-right">Mở</th></tr></thead><tbody>
            {runs.map((r) => r.id ? <tr key={r.id} className="border-t border-slate-800 hover:bg-slate-800/30"><td className="px-4 py-3"><div className="font-medium text-white">{r.template_name}</div><div className="font-mono text-xs text-cyan-400">{r.template_code_snapshot} v{r.template_version}</div></td><td className="px-4 py-3"><div>{r.entity_type}</div><div className="max-w-xs truncate font-mono text-[11px] text-slate-500">{r.entity_id}</div></td><td className="px-4 py-3">{r.required_checked_count ?? 0}/{r.required_count ?? 0} bắt buộc · {r.checked_count ?? 0}/{r.item_count ?? 0} tổng</td><td className="px-4 py-3"><span className={`rounded-lg px-2 py-1 text-xs ${statusClass(r.status)}`}>{r.status}</span></td><td className="px-4 py-3 text-slate-400">{dateTime(r.started_at)}</td><td className="px-4 py-3 text-right"><button onClick={() => setRunId(r.id!)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs">Chi tiết</button></td></tr> : null)}
          </tbody></table></div>
          {runs.length === 0 ? <p className="p-8 text-center text-slate-500">Chưa có checklist run.</p> : null}
        </div> : null}

        {tab === 'templates' && canManage ? <div className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900">
          <div className="overflow-x-auto"><table className="w-full min-w-[900px] text-left text-sm"><thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Code</th><th className="px-4 py-3">Tên</th><th className="px-4 py-3">Module / Entity</th><th className="px-4 py-3">Trạng thái</th><th className="px-4 py-3 text-right">Mở</th></tr></thead><tbody>
            {templates.map((t) => <tr key={t.id} className="border-t border-slate-800"><td className="px-4 py-3 font-mono text-cyan-300">{t.template_code} v{t.version}</td><td className="px-4 py-3">{t.name}{t.is_system ? <span className="ml-2 rounded bg-violet-950 px-1.5 py-0.5 text-[10px] text-violet-300">SYSTEM</span> : null}</td><td className="px-4 py-3">{t.module} · {t.entity_type}</td><td className="px-4 py-3">{t.is_active ? <span className="text-emerald-300">ACTIVE</span> : <span className="text-slate-500">DRAFT/OLD</span>}</td><td className="px-4 py-3 text-right"><button onClick={() => setTemplateId(t.id)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs">Chi tiết</button></td></tr>)}
          </tbody></table></div>
        </div> : null}
        <ErrorPanel message={error} />
       </div>}
    </div>

    {showStart ? <Modal title="Bắt đầu checklist run" onClose={() => setShowStart(false)}><StartRunForm templates={templates} sales={sales} repairs={repairs} onCancel={() => setShowStart(false)} onStarted={(id) => { setShowStart(false); setRunId(id); void load() }} /></Modal> : null}
    {showCreate ? <Modal title="Tạo template version" onClose={() => setShowCreate(false)}><CreateTemplateForm onCancel={() => setShowCreate(false)} onCreated={(id) => { setShowCreate(false); void load(); setTemplateId(id) }} /></Modal> : null}
  </main>
}
