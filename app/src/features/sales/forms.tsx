import { useEffect, useMemo, useState, type FormEvent } from 'react'
import type {
  CustomerRow,
  InventoryUnitRow,
  ProductInventorySummaryRow,
  SalesOrderItemRow,
  SalesOrderRow,
} from '../../lib/database.types'
import { supabase } from '../../lib/supabase'
import { CustomerQuickPicker } from '../crm/forms'

function parseNumber(value: string) {
  const n = Number(value)
  return Number.isFinite(n) ? n : 0
}

function ErrorBox({ message }: { message: string | null }) {
  if (!message) return null
  return <div role="alert" aria-live="assertive" className="rounded-xl border border-red-900 bg-red-950/30 p-3 text-sm text-red-200">{message}</div>
}

function Actions({ busy, onCancel, label }: { busy: boolean; onCancel: () => void; label: string }) {
  return (
    <div className="flex justify-end gap-2 pt-2">
      <button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2 text-sm hover:bg-slate-800">Đóng</button>
      <button disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950 disabled:opacity-50">{busy ? 'Đang xử lý…' : label}</button>
    </div>
  )
}

export function CreateOrderForm({
  customers,
  canCreateCustomer,
  onCancel,
  onCreated,
}: {
  customers: CustomerRow[]
  canCreateCustomer: boolean
  onCancel: () => void
  onCreated: (orderId: string) => void
}) {
  const [customerId, setCustomerId] = useState(customers[0]?.id ?? '')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!customerId) {
      setError('Hãy chọn hoặc thêm nhanh khách hàng trước khi tạo đơn.')
      return
    }
    setBusy(true); setError(null)
    try {
      const { data, error: rpcError } = await supabase.rpc('sale_create', {
        p_customer_id: customerId,
        p_note: note.trim() || undefined,
      })
      if (rpcError) throw rpcError
      const orderId = typeof data === 'object' && data && !Array.isArray(data) ? String((data as Record<string, unknown>).id ?? '') : ''
      if (!orderId) throw new Error('Hệ thống không trả về mã đơn bán.')
      onCreated(orderId)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tạo được đơn bán.')
    } finally { setBusy(false) }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <CustomerQuickPicker customers={customers} value={customerId} onChange={setCustomerId} canCreate={canCreateCustomer} />
    <label className="block text-sm font-medium">Ghi chú
      <textarea className="mt-2 min-h-24 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={note} onChange={(e) => setNote(e.target.value)} />
    </label>
    <Actions busy={busy} onCancel={onCancel} label="Tạo đơn" />
    <ErrorBox message={error} />
  </form>
}

export function EditOrderForm({
  order,
  customers,
  canCreateCustomer,
  onCancel,
  onDone,
}: {
  order: SalesOrderRow
  customers: CustomerRow[]
  canCreateCustomer: boolean
  onCancel: () => void
  onDone: () => void
}) {
  const [customerId, setCustomerId] = useState(order.customer_id)
  const [discount, setDiscount] = useState(String(order.discount_amount))
  const [note, setNote] = useState(order.note ?? '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError(null)
    try {
      const { error: rpcError } = await supabase.rpc('sale_update_draft', {
        p_order_id: order.id,
        p_customer_id: customerId,
        p_discount_amount: Math.max(0, parseNumber(discount)),
        p_note: note.trim() || undefined,
      })
      if (rpcError) throw rpcError
      onDone()
    } catch (err) { setError(err instanceof Error ? err.message : 'Không cập nhật được đơn.') }
    finally { setBusy(false) }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <CustomerQuickPicker customers={customers} value={customerId} onChange={setCustomerId} canCreate={canCreateCustomer} />
    <label className="block text-sm font-medium">Giảm giá toàn đơn
      <input type="number" min="0" step="1000" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={discount} onChange={(e) => setDiscount(e.target.value)} />
    </label>
    <label className="block text-sm font-medium">Ghi chú
      <textarea className="mt-2 min-h-24 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={note} onChange={(e) => setNote(e.target.value)} />
    </label>
    <Actions busy={busy} onCancel={onCancel} label="Lưu đơn" />
    <ErrorBox message={error} />
  </form>
}

export function ItemForm({
  orderId,
  products,
  initial,
  onCancel,
  onDone,
}: {
  orderId: string
  products: ProductInventorySummaryRow[]
  initial?: SalesOrderItemRow
  onCancel: () => void
  onDone: () => void
}) {
  const initialProductId = initial?.product_id ?? products[0]?.product_id ?? ''
  const [productId, setProductId] = useState(initialProductId ?? '')
  const [quantity, setQuantity] = useState(String(initial?.quantity ?? 1))
  const selectedProduct = useMemo(() => products.find((p) => p.product_id === productId), [productId, products])
  const [price, setPrice] = useState(String(initial?.unit_price ?? selectedProduct?.sale_price ?? 0))
  const [discount, setDiscount] = useState(String(initial?.discount_amount ?? 0))
  const [units, setUnits] = useState<InventoryUnitRow[]>([])
  const [selectedUnits, setSelectedUnits] = useState<string[]>(initial?.inventory_unit_ids ?? [])
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!initial) setPrice(String(selectedProduct?.sale_price ?? 0))
  }, [initial, selectedProduct])

  useEffect(() => {
    let cancelled = false
    async function loadUnits() {
      if (!selectedProduct?.track_serial || !productId) { setUnits([]); return }
      const { data, error: queryError } = await supabase
        .from('inventory_units')
        .select('*')
        .eq('product_id', productId)
        .eq('status', 'IN_STOCK')
        .order('serial_number')
      if (!cancelled) {
        if (queryError) setError(queryError.message)
        else setUnits(data)
      }
    }
    void loadUnits()
    return () => { cancelled = true }
  }, [productId, selectedProduct?.track_serial])

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError(null)
    const qty = parseNumber(quantity)
    try {
      if (selectedProduct?.track_serial && selectedUnits.length !== Math.trunc(qty)) {
        throw new Error(`Cần chọn đúng ${Math.trunc(qty)} Serial.`)
      }
      if (initial) {
        const { error: rpcError } = await supabase.rpc('sale_update_item', {
          p_item_id: initial.id,
          p_quantity: qty,
          p_unit_price: Math.max(0, parseNumber(price)),
          p_discount_amount: Math.max(0, parseNumber(discount)),
          p_inventory_unit_ids: selectedProduct?.track_serial ? selectedUnits : [],
        })
        if (rpcError) throw rpcError
      } else {
        const { error: rpcError } = await supabase.rpc('sale_add_item', {
          p_order_id: orderId,
          p_product_id: productId,
          p_quantity: qty,
          p_unit_price: Math.max(0, parseNumber(price)),
          p_discount_amount: Math.max(0, parseNumber(discount)),
          p_inventory_unit_ids: selectedProduct?.track_serial ? selectedUnits : [],
        })
        if (rpcError) throw rpcError
      }
      onDone()
    } catch (err) { setError(err instanceof Error ? err.message : 'Không lưu được hàng trong đơn.') }
    finally { setBusy(false) }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <label className="block text-sm font-medium">Sản phẩm
      <select
        disabled={Boolean(initial)}
        className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 disabled:opacity-60"
        value={productId}
        onChange={(e) => { setProductId(e.target.value); setSelectedUnits([]) }}
        required
      >
        {products.filter((p) => p.product_id).map((p) => <option key={p.product_id!} value={p.product_id!}>{p.sku} · {p.name} · tồn {p.stock_qty ?? 0}</option>)}
      </select>
    </label>
    <div className="grid gap-4 sm:grid-cols-3">
      <label className="text-sm font-medium">Số lượng
        <input type="number" min="0.001" step={selectedProduct?.track_serial ? '1' : '0.001'} className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={quantity} onChange={(e) => setQuantity(e.target.value)} />
      </label>
      <label className="text-sm font-medium">Đơn giá
        <input type="number" min="0" step="1000" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={price} onChange={(e) => setPrice(e.target.value)} />
      </label>
      <label className="text-sm font-medium">Giảm dòng
        <input type="number" min="0" step="1000" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={discount} onChange={(e) => setDiscount(e.target.value)} />
      </label>
    </div>

    {selectedProduct?.track_serial ? (
      <div>
        <div className="mb-2 text-sm font-medium">Chọn Serial ({selectedUnits.length}/{Math.max(0, Math.trunc(parseNumber(quantity)))})</div>
        <div className="max-h-56 space-y-1 overflow-y-auto rounded-xl border border-slate-800 bg-slate-950 p-2">
          {units.map((u) => (
            <label key={u.id} className="flex items-center gap-2 rounded-lg px-2 py-1.5 text-sm hover:bg-slate-900">
              <input
                type="checkbox"
                checked={selectedUnits.includes(u.id)}
                onChange={(e) => setSelectedUnits((prev) => e.target.checked ? [...prev, u.id] : prev.filter((id) => id !== u.id))}
              />
              <span className="font-mono text-cyan-300">{u.serial_number}</span>
              <span className="text-xs text-slate-500">{u.location || ''}</span>
            </label>
          ))}
          {units.length === 0 ? <p className="p-3 text-sm text-slate-500">Không có Serial đang trong kho.</p> : null}
        </div>
      </div>
    ) : null}

    <Actions busy={busy} onCancel={onCancel} label={initial ? 'Cập nhật hàng' : 'Thêm hàng vào đơn'} />
    <ErrorBox message={error} />
  </form>
}

export function PaymentForm({
  order,
  onCancel,
  onDone,
}: {
  order: SalesOrderRow
  onCancel: () => void
  onDone: () => void
}) {
  const amount = Number(order.balance_due ?? 0)
  const [method, setMethod] = useState('CASH')
  const [reference, setReference] = useState('')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError(null)
    try {
      if (amount <= 0) throw new Error('Đơn không còn số tiền phải thu.')
      const totalMinor = Math.round(Number(order.total_amount ?? 0) * 100)
      const paidMinor = Math.round(Number(order.paid_amount ?? 0) * 100)
      const amountMinor = Math.round(amount * 100)
      if (totalMinor - paidMinor !== amountMinor) {
        throw new Error('Số còn phải thu không khớp với giá bán. Hãy đóng cửa sổ và tải lại đơn.')
      }
      const { data, error: rpcError } = await supabase.rpc('sale_record_payment', {
        p_order_id: order.id,
        p_amount: amount,
        p_payment_method: method,
        p_reference_no: reference.trim() || undefined,
        p_note: note.trim() || undefined,
      })
      if (rpcError) throw rpcError
      const updatedOrder = typeof data === 'object' && data && !Array.isArray(data)
        ? ((data as Record<string, unknown>).order as Record<string, unknown> | undefined)
        : undefined
      if (!updatedOrder || Math.round(Number(updatedOrder.paid_amount) * 100) !== Math.round(Number(updatedOrder.total_amount) * 100)) {
        throw new Error('Thanh toán chưa khớp tổng giá bán. Hệ thống chưa xác nhận giao dịch.')
      }
      onDone()
    } catch (err) { setError(err instanceof Error ? err.message : 'Không ghi được thanh toán.') }
    finally { setBusy(false) }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <div className="grid gap-2 rounded-xl border border-slate-800 bg-slate-950/60 p-3 text-sm sm:grid-cols-3">
      <div>Giá bán: <strong className="block text-cyan-300">{new Intl.NumberFormat('vi-VN').format(order.total_amount ?? 0)} đ</strong></div>
      <div>Đã thu: <strong className="block text-emerald-300">{new Intl.NumberFormat('vi-VN').format(order.paid_amount ?? 0)} đ</strong></div>
      <div>Thu lần này: <strong className="block text-amber-300">{new Intl.NumberFormat('vi-VN').format(amount)} đ</strong></div>
    </div>
    <div className="grid gap-4 sm:grid-cols-2">
      <label className="text-sm font-medium">Số tiền
        <input type="number" readOnly aria-readonly="true" className="mt-2 w-full cursor-not-allowed rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-amber-200" value={amount} />
        <span className="mt-1 block text-xs text-slate-500">Khóa theo số còn phải thu để không lệch giá bán.</span>
      </label>
      <label className="text-sm font-medium">Phương thức
        <select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={method} onChange={(e) => setMethod(e.target.value)}>
          <option value="CASH">Tiền mặt</option><option value="BANK_TRANSFER">Chuyển khoản</option><option value="CARD">Thẻ</option><option value="EWALLET">Ví điện tử</option><option value="OTHER">Khác</option>
        </select>
      </label>
    </div>
    <label className="block text-sm font-medium">Mã tham chiếu
      <input className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={reference} onChange={(e) => setReference(e.target.value)} />
    </label>
    <label className="block text-sm font-medium">Ghi chú
      <input className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={note} onChange={(e) => setNote(e.target.value)} />
    </label>
    <Actions busy={busy} onCancel={onCancel} label={`Thu đủ ${new Intl.NumberFormat('vi-VN').format(amount)} đ`} />
    <ErrorBox message={error} />
  </form>
}

export function TextActionForm({
  title,
  placeholder,
  submitLabel,
  onCancel,
  onSubmit,
}: {
  title: string
  placeholder: string
  submitLabel: string
  onCancel: () => void
  onSubmit: (text: string) => Promise<void>
}) {
  const [text, setText] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError(null)
    try { await onSubmit(text.trim()); onCancel() }
    catch (err) { setError(err instanceof Error ? err.message : title) }
    finally { setBusy(false) }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <textarea autoFocus required className="min-h-28 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" placeholder={placeholder} value={text} onChange={(e) => setText(e.target.value)} />
    <Actions busy={busy} onCancel={onCancel} label={submitLabel} />
    <ErrorBox message={error} />
  </form>
}
