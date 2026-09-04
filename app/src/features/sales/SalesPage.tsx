import { useCallback, useEffect, useMemo, useState } from 'react'
import type {
  CustomerRow,
  PaymentRow,
  ProductInventorySummaryRow,
  SalesChecklistItem,
  SalesOrderItemRow,
  SalesOrderRow,
  SalesOrderSummaryRow,
} from '../../lib/database.types'
import type { AppUserContext } from '../../lib/permissions'
import { hasPermission } from '../../lib/permissions'
import { supabase } from '../../lib/supabase'
import { Modal } from '../crm/forms'
import { CreateOrderForm, EditOrderForm, ItemForm, PaymentForm, TextActionForm } from './forms'
import type { QrAction, QrResolved } from '../qr/QrCommandCenter'

function money(value: number | null | undefined) {
  return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND', maximumFractionDigits: 0 }).format(value ?? 0)
}
function dateTime(value: string | null | undefined) {
  return value ? new Date(value).toLocaleString('vi-VN') : '—'
}
function statusClass(status: string | null | undefined) {
  if (status === 'COMPLETED') return 'bg-emerald-950 text-emerald-300'
  if (status === 'CANCELLED') return 'bg-red-950 text-red-300'
  if (status === 'PAID' || status === 'DELIVERED') return 'bg-cyan-950 text-cyan-300'
  if (status === 'PAYMENT_PENDING') return 'bg-amber-950 text-amber-300'
  return 'bg-slate-800 text-slate-300'
}
function parseChecklist(value: SalesOrderRow['checklist']): SalesChecklistItem[] {
  if (!Array.isArray(value)) return []
  return value.filter((x): x is SalesChecklistItem => Boolean(x && typeof x === 'object' && !Array.isArray(x) && 'key' in x && 'label' in x))
}
function ErrorPanel({ message }: { message: string | null }) {
  return message ? <div className="rounded-xl border border-red-900 bg-red-950/30 p-4 text-sm text-red-200">{message}</div> : null
}

function OrderList({
  context,
  onOpen,
  initialCreate = false,
}: {
  context: AppUserContext
  onOpen: (id: string) => void
  initialCreate?: boolean
}) {
  const [rows, setRows] = useState<SalesOrderSummaryRow[]>([])
  const [customers, setCustomers] = useState<CustomerRow[]>([])
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState('ALL')
  const [showCreate, setShowCreate] = useState(false)

  useEffect(() => { if (initialCreate) setShowCreate(true) }, [initialCreate])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const canCreate = hasPermission(context, 'sale.create')

  const load = useCallback(async () => {
    setLoading(true); setError(null)
    try {
      const [orders, customerResult] = await Promise.all([
        supabase.from('sales_order_summary').select('*').order('created_at', { ascending: false }).limit(750),
        supabase.from('customers').select('*').eq('status', 'ACTIVE').order('full_name').limit(750),
      ])
      if (orders.error) throw orders.error
      if (customerResult.error) throw customerResult.error
      setRows(orders.data)
      setCustomers(customerResult.data)
    } catch (err) { setError(err instanceof Error ? err.message : 'Không tải được đơn bán.') }
    finally { setLoading(false) }
  }, [])

  useEffect(() => { void load() }, [load])

  const filtered = useMemo(() => {
    const q = search.trim().toLocaleLowerCase('vi-VN')
    return rows.filter((r) => {
      if (status !== 'ALL' && r.status !== status) return false
      if (!q) return true
      return [r.order_code ?? '', r.customer_code ?? '', r.customer_name ?? '', r.phone ?? '', r.status ?? '']
        .join(' ').toLocaleLowerCase('vi-VN').includes(q)
    })
  }, [rows, search, status])

  return <div className="space-y-4">
    <div className="flex flex-col gap-3 rounded-2xl border border-slate-800 bg-slate-900 p-4 lg:flex-row">
      <input className="min-w-0 flex-1 rounded-xl border border-slate-700 bg-slate-950 px-4 py-2" placeholder="Tìm mã đơn, khách hàng, điện thoại…" value={search} onChange={(e) => setSearch(e.target.value)} />
      <select className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={status} onChange={(e) => setStatus(e.target.value)}>
        <option value="ALL">Tất cả trạng thái</option>
        {['DRAFT','CONFIRMED','PAYMENT_PENDING','PAID','DELIVERED','COMPLETED','CANCELLED'].map((x) => <option key={x} value={x}>{x}</option>)}
      </select>
      <button type="button" onClick={() => void load()} className="rounded-xl border border-slate-700 px-4 py-2 text-sm hover:bg-slate-800">Làm mới</button>
      {canCreate ? <button type="button" onClick={() => setShowCreate(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ Đơn bán</button> : null}
    </div>

    <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[1180px] text-left text-sm">
          <thead className="bg-slate-950/70 text-xs uppercase text-slate-500"><tr>
            <th className="px-4 py-3">Đơn</th><th className="px-4 py-3">Khách hàng</th><th className="px-4 py-3">Tổng</th><th className="px-4 py-3">Đã thu / Còn</th><th className="px-4 py-3">Checklist</th><th className="px-4 py-3">Trạng thái</th><th className="px-4 py-3">Thời gian</th><th className="px-4 py-3 text-right">Mở</th>
          </tr></thead>
          <tbody>{filtered.map((r) => r.id ? (
            <tr key={r.id} className="border-t border-slate-800 hover:bg-slate-800/35">
              <td className="px-4 py-3"><div className="font-mono text-cyan-300">{r.order_code}</div><div className="text-xs text-slate-500">{r.item_count ?? 0} dòng</div></td>
              <td className="px-4 py-3"><div className="font-medium text-white">{r.customer_name}</div><div className="text-xs text-slate-500">{r.customer_code} · {r.phone || '—'}</div></td>
              <td className="px-4 py-3 font-semibold">{money(r.total_amount)}</td>
              <td className="px-4 py-3"><div className="text-emerald-300">{money(r.paid_amount)}</div><div className="text-xs text-amber-300">Còn {money(r.balance_due)}</div></td>
              <td className="px-4 py-3">{r.required_checked_count ?? 0}/{r.required_checklist_count ?? 0}</td>
              <td className="px-4 py-3"><span className={`rounded-lg px-2 py-1 text-xs ${statusClass(r.status)}`}>{r.status}</span></td>
              <td className="px-4 py-3 text-slate-400">{dateTime(r.created_at)}</td>
              <td className="px-4 py-3 text-right"><button type="button" onClick={() => onOpen(r.id!)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs hover:bg-slate-800">Chi tiết</button></td>
            </tr>
          ) : null)}</tbody>
        </table>
      </div>
      {loading ? <p className="p-6 text-center text-slate-500">Đang tải…</p> : null}
      {!loading && filtered.length === 0 ? <p className="p-8 text-center text-slate-500">Chưa có đơn phù hợp.</p> : null}
    </section>
    <ErrorPanel message={error} />
    {showCreate ? <Modal title="Tạo đơn bán" onClose={() => setShowCreate(false)}><CreateOrderForm customers={customers} onCancel={() => setShowCreate(false)} onCreated={(id) => { setShowCreate(false); onOpen(id) }} /></Modal> : null}
  </div>
}

function OrderDetail({
  orderId,
  context,
  onBack,
  initialAction,
}: {
  orderId: string
  context: AppUserContext
  onBack: () => void
  initialAction?: QrAction
}) {
  const [order, setOrder] = useState<SalesOrderRow | null>(null)
  const [items, setItems] = useState<SalesOrderItemRow[]>([])
  const [payments, setPayments] = useState<PaymentRow[]>([])
  const [customers, setCustomers] = useState<CustomerRow[]>([])
  const [products, setProducts] = useState<ProductInventorySummaryRow[]>([])
  const [editingItem, setEditingItem] = useState<SalesOrderItemRow | null>(null)
  const [modal, setModal] = useState<'edit-order'|'add-item'|'payment'|'cancel'|null>(null)

  useEffect(() => {
    if (initialAction === 'PAY') setModal('payment')
    else if (initialAction === 'EDIT') setModal('edit-order')
  }, [initialAction, orderId])
  const [error, setError] = useState<string | null>(null)
  const [busyAction, setBusyAction] = useState<string | null>(null)

  const canUpdate = hasPermission(context, 'sale.update')
  const canCancel = hasPermission(context, 'sale.cancel')
  const canPay = hasPermission(context, 'payment.create')
  const canRefund = hasPermission(context, 'payment.update')

  const load = useCallback(async () => {
    setError(null)
    try {
      const [o,i,p,c,prod] = await Promise.all([
        supabase.from('sales_orders').select('*').eq('id', orderId).single(),
        supabase.from('sales_order_items').select('*').eq('sales_order_id', orderId).order('created_at'),
        supabase.from('payments').select('*').eq('sales_order_id', orderId).order('paid_at', { ascending:false }),
        supabase.from('customers').select('*').eq('status','ACTIVE').order('full_name').limit(750),
        supabase.from('product_inventory_summary').select('*').eq('is_active', true).order('name').limit(750),
      ])
      if (o.error) throw o.error
      if (i.error) throw i.error
      if (p.error && hasPermission(context,'payment.view')) throw p.error
      if (c.error) throw c.error
      if (prod.error) throw prod.error
      setOrder(o.data); setItems(i.data); setPayments(p.data ?? []); setCustomers(c.data); setProducts(prod.data)
    } catch (err) { setError(err instanceof Error ? err.message : 'Không tải được chi tiết đơn.') }
  }, [context, orderId])

  useEffect(() => { void load() }, [load])
  const customer = useMemo(() => customers.find((c) => c.id === order?.customer_id), [customers, order?.customer_id])
  const checklist = useMemo(() => order ? parseChecklist(order.checklist) : [], [order])

  async function rpc(name: 'sale_confirm'|'sale_deliver'|'sale_complete', label: string) {
    if (!order) return
    setBusyAction(label); setError(null)
    try {
      const { error: rpcError } = await supabase.rpc(name, { p_order_id: order.id })
      if (rpcError) throw rpcError
      await load()
    } catch (err) { setError(err instanceof Error ? err.message : `Không ${label}.`) }
    finally { setBusyAction(null) }
  }

  async function removeItem(itemId: string) {
    if (!confirm('Xóa dòng hàng này khỏi đơn DRAFT?')) return
    const { error: rpcError } = await supabase.rpc('sale_remove_item', { p_item_id: itemId })
    if (rpcError) setError(rpcError.message); else await load()
  }

  async function toggleChecklist(item: SalesChecklistItem, checked: boolean) {
    if (!order || !canUpdate || item.key === 'payment_confirmed') return
    const { error: rpcError } = await supabase.rpc('sale_set_checklist_item', { p_order_id: order.id, p_key: item.key, p_checked: checked })
    if (rpcError) setError(rpcError.message); else await load()
  }

  async function refund(payment: PaymentRow) {
    const note = window.prompt('Lý do hoàn tiền:')
    if (!note?.trim()) return
    const { error: rpcError } = await supabase.rpc('sale_refund_payment', { p_payment_id: payment.id, p_refund_note: note.trim() })
    if (rpcError) setError(rpcError.message); else await load()
  }

  if (!order) return <div className="space-y-4"><button onClick={onBack} className="rounded-xl border border-slate-700 px-4 py-2">← Danh sách</button><ErrorPanel message={error} /><p className="text-slate-500">Đang tải đơn…</p></div>

  return <div className="space-y-5">
    <div className="flex flex-wrap items-center justify-between gap-3">
      <div><button type="button" onClick={onBack} className="text-sm text-cyan-300 hover:underline">← Danh sách đơn</button><h2 className="mt-2 font-mono text-2xl font-bold text-white">{order.order_code}</h2><p className="text-sm text-slate-500">{customer?.full_name ?? order.customer_id} · {customer?.phone || '—'}</p></div>
      <span className={`rounded-xl px-3 py-2 text-sm font-semibold ${statusClass(order.status)}`}>{order.status}</span>
    </div>

    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-3"><div className="text-xs text-slate-500">Tạm tính</div><div className="mt-1 font-semibold">{money(order.subtotal)}</div></div>
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-3"><div className="text-xs text-slate-500">Giảm</div><div className="mt-1 font-semibold">{money(order.discount_amount)}</div></div>
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-3"><div className="text-xs text-slate-500">Tổng</div><div className="mt-1 font-semibold text-cyan-300">{money(order.total_amount)}</div></div>
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-3"><div className="text-xs text-slate-500">Đã thu</div><div className="mt-1 font-semibold text-emerald-300">{money(order.paid_amount)}</div></div>
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-3"><div className="text-xs text-slate-500">Còn</div><div className="mt-1 font-semibold text-amber-300">{money(order.balance_due)}</div></div>
    </div>

    <div className="flex flex-wrap gap-2 rounded-2xl border border-slate-800 bg-slate-900 p-4">
      {order.status === 'DRAFT' && canUpdate ? <button onClick={() => setModal('edit-order')} className="rounded-xl border border-slate-700 px-3 py-2 text-sm">Sửa đơn</button> : null}
      {order.status === 'DRAFT' && canUpdate ? <button onClick={() => setModal('add-item')} className="rounded-xl border border-cyan-900 px-3 py-2 text-sm text-cyan-300">+ Dòng hàng</button> : null}
      {order.status === 'DRAFT' && canUpdate && items.length > 0 ? <button disabled={Boolean(busyAction)} onClick={() => void rpc('sale_confirm','xác nhận đơn')} className="rounded-xl bg-cyan-500 px-3 py-2 text-sm font-semibold text-slate-950">Xác nhận & trừ kho</button> : null}
      {(order.status === 'CONFIRMED' || order.status === 'PAYMENT_PENDING') && canPay && (order.balance_due ?? 0) > 0 ? <button onClick={() => setModal('payment')} className="rounded-xl bg-emerald-500 px-3 py-2 text-sm font-semibold text-slate-950">Thu tiền</button> : null}
      {order.status === 'PAID' && canUpdate ? <button disabled={Boolean(busyAction)} onClick={() => void rpc('sale_deliver','bàn giao')} className="rounded-xl bg-violet-500 px-3 py-2 text-sm font-semibold text-white">Bàn giao</button> : null}
      {order.status === 'DELIVERED' && canUpdate ? <button disabled={Boolean(busyAction)} onClick={() => void rpc('sale_complete','hoàn tất')} className="rounded-xl bg-emerald-500 px-3 py-2 text-sm font-semibold text-slate-950">COMPLETED</button> : null}
      {['DRAFT','CONFIRMED','PAYMENT_PENDING'].includes(order.status) && canCancel && order.paid_amount === 0 ? <button onClick={() => setModal('cancel')} className="rounded-xl border border-red-900 px-3 py-2 text-sm text-red-300">Hủy đơn</button> : null}
    </div>

    <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900">
      <div className="flex items-center justify-between border-b border-slate-800 px-4 py-3"><h3 className="font-semibold text-white">Dòng hàng</h3><span className="text-xs text-slate-500">{items.length} sản phẩm</span></div>
      <div className="overflow-x-auto"><table className="w-full min-w-[900px] text-left text-sm"><thead className="bg-slate-950/50 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Sản phẩm</th><th className="px-4 py-3">SL</th><th className="px-4 py-3">Đơn giá</th><th className="px-4 py-3">Giảm</th><th className="px-4 py-3">Thành tiền</th><th className="px-4 py-3">Serial units</th><th className="px-4 py-3 text-right">Sửa</th></tr></thead><tbody>
        {items.map((i) => <tr key={i.id} className="border-t border-slate-800"><td className="px-4 py-3"><div className="font-medium text-white">{i.product_name_snapshot}</div><div className="font-mono text-xs text-cyan-400">{i.sku_snapshot}</div></td><td className="px-4 py-3">{i.quantity}</td><td className="px-4 py-3">{money(i.unit_price)}</td><td className="px-4 py-3">{money(i.discount_amount)}</td><td className="px-4 py-3 font-semibold">{money(i.line_total)}</td><td className="px-4 py-3">{i.inventory_unit_ids.length || '—'}</td><td className="px-4 py-3 text-right">{order.status === 'DRAFT' && canUpdate ? <div className="flex justify-end gap-1"><button onClick={() => setEditingItem(i)} className="rounded-lg border border-slate-700 px-2 py-1 text-xs">Sửa</button><button onClick={() => void removeItem(i.id)} className="rounded-lg border border-red-900 px-2 py-1 text-xs text-red-300">Xóa</button></div> : '—'}</td></tr>)}
      </tbody></table></div>
      {items.length === 0 ? <p className="p-6 text-center text-slate-500">Đơn chưa có dòng hàng.</p> : null}
    </section>

    <section className="rounded-2xl border border-slate-800 bg-slate-900 p-4">
      <div className="mb-3 flex items-center justify-between"><h3 className="font-semibold text-white">Checklist bàn giao · 16 mục</h3><span className="text-xs text-slate-500">Mục bắt buộc phải đạt trước COMPLETED</span></div>
      <div className="grid gap-2 md:grid-cols-2">
        {checklist.map((item) => <label key={item.key} className={`flex items-start gap-3 rounded-xl border p-3 ${item.checked ? 'border-emerald-900 bg-emerald-950/20' : 'border-slate-800 bg-slate-950/40'}`}>
          <input type="checkbox" className="mt-1" checked={Boolean(item.checked)} disabled={!canUpdate || ['COMPLETED','CANCELLED'].includes(order.status) || item.key === 'payment_confirmed'} onChange={(e) => void toggleChecklist(item,e.target.checked)} />
          <span><span className="text-sm text-slate-200">{item.label}</span>{item.required || item.key === 'serial_numbers' ? <span className="ml-2 rounded bg-amber-950 px-1.5 py-0.5 text-[10px] text-amber-300">{item.required ? 'BẮT BUỘC' : 'BẮT BUỘC KHI CÓ SERIAL'}</span> : null}{item.key === 'payment_confirmed' ? <div className="mt-1 text-[11px] text-slate-500">Tự động theo số tiền đã thu.</div> : null}</span>
        </label>)}
      </div>
    </section>

    <section className="rounded-2xl border border-slate-800 bg-slate-900 p-4">
      <h3 className="mb-3 font-semibold text-white">Thanh toán</h3>
      <div className="space-y-2">{payments.map((p) => <div key={p.id} className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-800 bg-slate-950/50 p-3 text-sm"><div><div className="font-mono text-cyan-300">{p.payment_code}</div><div className="mt-1 text-slate-400">{p.payment_method} · {dateTime(p.paid_at)} {p.reference_no ? `· ${p.reference_no}` : ''}</div></div><div className="flex items-center gap-3"><div className={p.status === 'COMPLETED' ? 'font-semibold text-emerald-300' : 'font-semibold text-red-300'}>{money(p.amount)} · {p.status}</div>{p.status === 'COMPLETED' && canRefund && !['DELIVERED','COMPLETED','CANCELLED'].includes(order.status) ? <button onClick={() => void refund(p)} className="rounded-lg border border-red-900 px-2 py-1 text-xs text-red-300">Hoàn tiền</button> : null}</div></div>)}</div>
      {payments.length === 0 ? <p className="text-sm text-slate-500">Chưa có thanh toán.</p> : null}
    </section>

    <div className="rounded-2xl border border-slate-800 bg-slate-900 p-4 text-sm text-slate-400">
      <div>Xác nhận: {dateTime(order.confirmed_at)} · Giao: {dateTime(order.delivered_at)} · Hoàn tất: {dateTime(order.completed_at)}</div>
      {order.cancelled_at ? <div className="mt-2 text-red-300">Hủy: {dateTime(order.cancelled_at)} · {order.cancelled_reason}</div> : null}
      {order.note ? <div className="mt-2">Ghi chú: {order.note}</div> : null}
    </div>

    <ErrorPanel message={error} />

    {modal === 'edit-order' ? <Modal title="Sửa đơn DRAFT" onClose={() => setModal(null)}><EditOrderForm order={order} customers={customers} onCancel={() => setModal(null)} onDone={() => { setModal(null); void load() }} /></Modal> : null}
    {modal === 'add-item' ? <Modal title="Thêm dòng hàng" onClose={() => setModal(null)}><ItemForm orderId={order.id} products={products} onCancel={() => setModal(null)} onDone={() => { setModal(null); void load() }} /></Modal> : null}
    {editingItem ? <Modal title="Sửa dòng hàng" onClose={() => setEditingItem(null)}><ItemForm orderId={order.id} products={products} initial={editingItem} onCancel={() => setEditingItem(null)} onDone={() => { setEditingItem(null); void load() }} /></Modal> : null}
    {modal === 'payment' ? <Modal title="Thu tiền" onClose={() => setModal(null)}><PaymentForm order={order} onCancel={() => setModal(null)} onDone={() => { setModal(null); void load() }} /></Modal> : null}
    {modal === 'cancel' ? <Modal title="Hủy đơn" onClose={() => setModal(null)}><TextActionForm title="Không hủy được đơn" placeholder="Nhập lý do hủy…" submitLabel="Xác nhận hủy" onCancel={() => setModal(null)} onSubmit={async (reason) => { const { error: rpcError } = await supabase.rpc('sale_cancel',{p_order_id:order.id,p_reason:reason}); if (rpcError) throw rpcError; await load() }} /></Modal> : null}
  </div>
}

export function SalesPage({
  context,
  initialTarget,
  initialAction,
  onOpenCrm,
  onOpenInventory,
  onOpenRepair,
  onOpenChecklist,
  onOpenWarranty,
}: {
  context: AppUserContext
  initialTarget?: QrResolved
  initialAction?: QrAction
  onOpenCrm?: () => void
  onOpenInventory?: () => void
  onOpenRepair?: () => void
  onOpenChecklist?: () => void
  onOpenWarranty?: () => void
}) {
  const [orderId, setOrderId] = useState<string | null>(initialTarget?.resource_type === 'SALES_ORDER' ? initialTarget.resource_id ?? null : null)
  useEffect(() => {
    if (initialTarget?.resource_type === 'SALES_ORDER' && initialTarget.resource_id) setOrderId(initialTarget.resource_id)
    else if (initialTarget?.resource_type === 'PAYMENT' && initialTarget.resource_id) {
      void supabase.from('payments').select('sales_order_id').eq('id',initialTarget.resource_id).single()
        .then(({data}) => { if (data?.sales_order_id) setOrderId(data.sales_order_id) })
    }
  }, [initialTarget])
  if (!hasPermission(context,'sale.view')) {
    return <main className="grid min-h-screen place-items-center bg-slate-950 text-slate-200"><div className="rounded-2xl border border-amber-900 p-6">Vai trò hiện tại không có quyền xem Sales.</div></main>
  }
  return <main className="min-h-screen bg-slate-950 text-slate-200">
    <header className="border-b border-slate-800 bg-slate-900/90 px-4 py-4 sm:px-6">
      <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4">
        <div><div className="text-sm font-semibold uppercase tracking-[0.24em] text-cyan-400">HomeTechVN</div><h1 className="mt-1 text-xl font-bold text-white">Bán hàng & Thanh toán</h1></div>
        <div className="flex flex-wrap items-center gap-2 text-sm">
          {onOpenCrm ? <button onClick={onOpenCrm} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">CRM</button> : null}
          {onOpenInventory ? <button onClick={onOpenInventory} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Kho</button> : null}
          {onOpenRepair ? <button onClick={onOpenRepair} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Sửa chữa</button> : null}
          {onOpenChecklist ? <button onClick={onOpenChecklist} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Checklist</button> : null}
          {onOpenWarranty ? <button onClick={onOpenWarranty} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Bảo hành</button> : null}
          <div className="px-2 text-right"><div className="font-medium text-white">{context.fullName || context.email || 'Người dùng'}</div><div className="text-xs text-slate-500">{context.roleName} · {context.roleCode}</div></div>
          <button onClick={() => void supabase.auth.signOut()} className="rounded-xl border border-slate-700 px-3 py-2">Đăng xuất</button>
        </div>
      </div>
    </header>
    <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
      {orderId ? <OrderDetail orderId={orderId} context={context} initialAction={initialAction} onBack={() => setOrderId(null)} /> : <OrderList context={context} onOpen={setOrderId} initialCreate={initialAction === 'CREATE' && initialTarget?.resource_type === 'SALES_ORDER'} />}
    </div>
  </main>
}
