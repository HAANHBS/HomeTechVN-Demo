import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import { supabase } from '../../lib/supabase'
import type {
  Database,
  InventoryUnitRow,
  ProductCategoryRow,
  ProductInventorySummaryRow,
  ProductRow,
} from '../../lib/database.types'

function nullable(value: string) {
  const trimmed = value.trim()
  return trimmed ? trimmed : null
}

function parseNumber(value: string, fallback = 0) {
  const number = Number(value.replace(',', '.'))
  return Number.isFinite(number) ? number : fallback
}

function parseLines(value: string) {
  return value
    .split(/\r?\n/)
    .map((item) => item.trim())
    .filter(Boolean)
}

function ErrorBox({ message }: { message: string | null }) {
  if (!message) return null
  return (
    <div className="rounded-xl border border-red-900/70 bg-red-950/40 px-4 py-3 text-sm text-red-200">
      {message}
    </div>
  )
}

function FormActions({
  busy,
  onCancel,
  submitLabel,
}: {
  busy: boolean
  onCancel: () => void
  submitLabel: string
}) {
  return (
    <div className="flex justify-end gap-2 pt-2">
      <button
        type="button"
        onClick={onCancel}
        className="rounded-xl border border-slate-700 px-4 py-2 text-sm hover:bg-slate-800"
      >
        Hủy
      </button>
      <button
        type="submit"
        disabled={busy}
        className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {busy ? 'Đang lưu…' : submitLabel}
      </button>
    </div>
  )
}

export function CategoryForm({
  initial,
  onCancel,
  onSaved,
}: {
  initial?: ProductCategoryRow
  onCancel: () => void
  onSaved: (row: ProductCategoryRow) => void
}) {
  const [name, setName] = useState(initial?.name ?? '')
  const [description, setDescription] = useState(initial?.description ?? '')
  const [sortOrder, setSortOrder] = useState(String(initial?.sort_order ?? 0))
  const [active, setActive] = useState(initial?.is_active ?? true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)

    const payload = {
      name: name.trim(),
      description: nullable(description),
      sort_order: Math.max(0, Math.trunc(parseNumber(sortOrder))),
      is_active: active,
    }

    try {
      const query = initial
        ? supabase.from('product_categories').update(payload).eq('id', initial.id)
        : supabase.from('product_categories').insert(payload)
      const { data, error: queryError } = await query.select('*').single()
      if (queryError) throw queryError
      onSaved(data)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không lưu được danh mục.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className="space-y-4" onSubmit={handleSubmit}>
      <label className="block text-sm font-medium">
        Tên danh mục
        <input
          className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500"
          value={name}
          onChange={(event) => setName(event.target.value)}
          required
          autoFocus
        />
      </label>
      <label className="block text-sm font-medium">
        Mô tả
        <textarea
          className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500"
          value={description}
          onChange={(event) => setDescription(event.target.value)}
        />
      </label>
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="block text-sm font-medium">
          Thứ tự
          <input
            type="number"
            min="0"
            step="1"
            className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500"
            value={sortOrder}
            onChange={(event) => setSortOrder(event.target.value)}
          />
        </label>
        <label className="mt-7 flex items-center gap-2 text-sm">
          <input type="checkbox" checked={active} onChange={(event) => setActive(event.target.checked)} />
          Đang sử dụng
        </label>
      </div>
      <ErrorBox message={error} />
      <FormActions busy={busy} onCancel={onCancel} submitLabel={initial ? 'Cập nhật' : 'Tạo danh mục'} />
    </form>
  )
}

export function ProductForm({
  initial,
  categories,
  onCancel,
  onSaved,
}: {
  initial?: ProductRow
  categories: ProductCategoryRow[]
  onCancel: () => void
  onSaved: (row: ProductRow) => void
}) {
  const [sku, setSku] = useState(initial?.sku ?? '')
  const [name, setName] = useState(initial?.name ?? '')
  const [categoryId, setCategoryId] = useState(initial?.category_id ?? '')
  const [brand, setBrand] = useState(initial?.brand ?? '')
  const [model, setModel] = useState(initial?.model ?? '')
  const [barcode, setBarcode] = useState(initial?.barcode ?? '')
  const [unit, setUnit] = useState(initial?.unit ?? 'cái')
  const [description, setDescription] = useState(initial?.description ?? '')
  const [salePrice, setSalePrice] = useState(String(initial?.sale_price ?? 0))
  const [minStock, setMinStock] = useState(String(initial?.min_stock ?? 0))
  const [trackSerial, setTrackSerial] = useState(initial?.track_serial ?? false)
  const [warrantyMonths, setWarrantyMonths] = useState(String(initial?.warranty_months ?? 0))
  const [active, setActive] = useState(initial?.is_active ?? true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)

    const payload = {
      sku: sku.trim(),
      name: name.trim(),
      category_id: categoryId || null,
      brand: nullable(brand),
      model: nullable(model),
      barcode: nullable(barcode),
      unit: unit.trim(),
      description: nullable(description),
      sale_price: Math.max(0, parseNumber(salePrice)),
      min_stock: Math.max(0, parseNumber(minStock)),
      track_serial: trackSerial,
      warranty_months: Math.max(0, Math.trunc(parseNumber(warrantyMonths))),
      is_active: active,
    }

    try {
      const query = initial
        ? supabase.from('products').update(payload).eq('id', initial.id)
        : supabase.from('products').insert(payload)
      const { data, error: queryError } = await query.select('*').single()
      if (queryError) throw queryError
      onSaved(data)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không lưu được sản phẩm.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className="space-y-4" onSubmit={handleSubmit}>
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="block text-sm font-medium">
          SKU
          <input
            className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 font-mono outline-none focus:border-cyan-500 disabled:opacity-60"
            value={sku}
            onChange={(event) => setSku(event.target.value)}
            disabled={Boolean(initial)}
            required
            autoFocus={!initial}
          />
        </label>
        <label className="block text-sm font-medium">
          Tên sản phẩm
          <input
            className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500"
            value={name}
            onChange={(event) => setName(event.target.value)}
            required
          />
        </label>
        <label className="block text-sm font-medium">
          Danh mục
          <select
            className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500"
            value={categoryId}
            onChange={(event) => setCategoryId(event.target.value)}
          >
            <option value="">— Chưa phân loại —</option>
            {categories.filter((item) => item.is_active || item.id === categoryId).map((item) => (
              <option key={item.id} value={item.id}>{item.name}</option>
            ))}
          </select>
        </label>
        <label className="block text-sm font-medium">
          Đơn vị
          <input
            className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500"
            value={unit}
            onChange={(event) => setUnit(event.target.value)}
            required
          />
        </label>
        <label className="block text-sm font-medium">
          Hãng
          <input className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={brand} onChange={(event) => setBrand(event.target.value)} />
        </label>
        <label className="block text-sm font-medium">
          Model
          <input className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={model} onChange={(event) => setModel(event.target.value)} />
        </label>
        <label className="block text-sm font-medium">
          Barcode
          <input className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 font-mono outline-none focus:border-cyan-500" value={barcode} onChange={(event) => setBarcode(event.target.value)} />
        </label>
        <label className="block text-sm font-medium">
          Giá bán
          <input type="number" min="0" step="1000" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={salePrice} onChange={(event) => setSalePrice(event.target.value)} />
        </label>
        <label className="block text-sm font-medium">
          Tồn tối thiểu
          <input type="number" min="0" step="0.001" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={minStock} onChange={(event) => setMinStock(event.target.value)} />
        </label>
        <label className="block text-sm font-medium">
          Bảo hành (tháng)
          <input type="number" min="0" step="1" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={warrantyMonths} onChange={(event) => setWarrantyMonths(event.target.value)} />
        </label>
      </div>

      <label className="block text-sm font-medium">
        Mô tả
        <textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={description} onChange={(event) => setDescription(event.target.value)} />
      </label>

      <div className="flex flex-wrap gap-5 rounded-xl border border-slate-800 bg-slate-950/50 px-4 py-3 text-sm">
        <label className="flex items-center gap-2">
          <input type="checkbox" checked={trackSerial} onChange={(event) => setTrackSerial(event.target.checked)} />
          Quản lý theo Serial
        </label>
        <label className="flex items-center gap-2">
          <input type="checkbox" checked={active} onChange={(event) => setActive(event.target.checked)} />
          Đang kinh doanh
        </label>
      </div>
      {initial ? <p className="text-xs text-slate-500">SKU không thể đổi. Chế độ Serial chỉ đổi được trước khi sản phẩm có phát sinh kho.</p> : null}
      <ErrorBox message={error} />
      <FormActions busy={busy} onCancel={onCancel} submitLabel={initial ? 'Cập nhật sản phẩm' : 'Tạo sản phẩm'} />
    </form>
  )
}

function ProductLabel({ product }: { product: ProductInventorySummaryRow }) {
  return (
    <div className="rounded-xl border border-slate-800 bg-slate-950/60 px-4 py-3 text-sm">
      <div className="font-mono text-cyan-300">{product.sku}</div>
      <div className="mt-1 font-medium text-white">{product.name}</div>
      <div className="mt-1 text-xs text-slate-500">Tồn: {product.stock_qty ?? 0} {product.unit ?? ''} · {product.track_serial ? 'Theo Serial' : 'Theo số lượng'}</div>
    </div>
  )
}

export function ReceiveForm({
  product,
  canViewCost,
  onCancel,
  onDone,
}: {
  product: ProductInventorySummaryRow
  canViewCost: boolean
  onCancel: () => void
  onDone: () => void
}) {
  const [quantity, setQuantity] = useState('1')
  const [unitCost, setUnitCost] = useState('')
  const [serialText, setSerialText] = useState('')
  const [location, setLocation] = useState('')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const serials = useMemo(() => parseLines(serialText), [serialText])

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!product.product_id) return
    setBusy(true)
    setError(null)

    const effectiveQuantity = product.track_serial ? serials.length : parseNumber(quantity)
    if (effectiveQuantity <= 0) {
      setError(product.track_serial ? 'Nhập ít nhất 1 Serial.' : 'Số lượng phải lớn hơn 0.')
      setBusy(false)
      return
    }

    const args: Database['public']['Functions']['inventory_receive']['Args'] = {
      p_product_id: product.product_id,
      p_quantity: effectiveQuantity,
      p_note: note.trim() || undefined,
      p_reference_type: 'MANUAL',
      p_location: location.trim() || undefined,
    }
    if (product.track_serial) args.p_serial_numbers = serials
    if (canViewCost && unitCost.trim()) args.p_unit_cost = Math.max(0, parseNumber(unitCost))

    try {
      const { error: rpcError } = await supabase.rpc('inventory_receive', args)
      if (rpcError) throw rpcError
      onDone()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Nhập kho thất bại.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className="space-y-4" onSubmit={handleSubmit}>
      <ProductLabel product={product} />
      {product.track_serial ? (
        <label className="block text-sm font-medium">
          Serial — mỗi dòng một Serial ({serials.length})
          <textarea
            className="mt-2 min-h-36 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 font-mono text-sm outline-none focus:border-cyan-500"
            value={serialText}
            onChange={(event) => setSerialText(event.target.value)}
            placeholder={'SN001\nSN002'}
            required
          />
        </label>
      ) : (
        <label className="block text-sm font-medium">
          Số lượng
          <input type="number" min="0.001" step="0.001" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={quantity} onChange={(event) => setQuantity(event.target.value)} required />
        </label>
      )}
      <div className="grid gap-4 sm:grid-cols-2">
        {canViewCost ? (
          <label className="block text-sm font-medium">
            Giá nhập / đơn vị
            <input type="number" min="0" step="1" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={unitCost} onChange={(event) => setUnitCost(event.target.value)} placeholder="Có thể để trống" />
          </label>
        ) : null}
        <label className="block text-sm font-medium">
          Vị trí kho
          <input className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={location} onChange={(event) => setLocation(event.target.value)} placeholder="VD: Kệ A1" />
        </label>
      </div>
      <label className="block text-sm font-medium">
        Ghi chú
        <textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={note} onChange={(event) => setNote(event.target.value)} />
      </label>
      <ErrorBox message={error} />
      <FormActions busy={busy} onCancel={onCancel} submitLabel="Nhập kho" />
    </form>
  )
}

function UnitSelector({
  units,
  selected,
  onToggle,
}: {
  units: InventoryUnitRow[]
  selected: Set<string>
  onToggle: (id: string) => void
}) {
  if (units.length === 0) {
    return <div className="rounded-xl border border-slate-800 p-4 text-sm text-slate-500">Không có Serial đang tồn.</div>
  }
  return (
    <div className="max-h-64 space-y-2 overflow-auto rounded-xl border border-slate-800 p-2">
      {units.map((unit) => (
        <label key={unit.id} className="flex cursor-pointer items-center gap-3 rounded-lg px-3 py-2 hover:bg-slate-800">
          <input type="checkbox" checked={selected.has(unit.id)} onChange={() => onToggle(unit.id)} />
          <span className="font-mono text-sm text-cyan-200">{unit.serial_number}</span>
          <span className="ml-auto text-xs text-slate-500">{unit.location || 'Chưa có vị trí'}</span>
        </label>
      ))}
    </div>
  )
}

function useInStockUnits(productId: string | null) {
  const [units, setUnits] = useState<InventoryUnitRow[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!productId) return
    let cancelled = false
    setLoading(true)
    setError(null)

    void supabase
      .from('inventory_units')
      .select('*')
      .eq('product_id', productId)
      .eq('status', 'IN_STOCK')
      .order('serial_number')
      .then(({ data, error: queryError }) => {
        if (cancelled) return
        if (queryError) {
          setError(queryError.message)
          setUnits([])
        } else {
          setUnits(data)
        }
        setLoading(false)
      })

    return () => { cancelled = true }
  }, [productId])

  return { units, loading, error }
}

export function IssueForm({
  product,
  onCancel,
  onDone,
}: {
  product: ProductInventorySummaryRow
  onCancel: () => void
  onDone: () => void
}) {
  const [quantity, setQuantity] = useState('1')
  const [note, setNote] = useState('')
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const { units, loading, error: unitError } = useInStockUnits(product.track_serial ? product.product_id : null)

  function toggle(id: string) {
    setSelected((current) => {
      const next = new Set(current)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!product.product_id) return
    setBusy(true)
    setError(null)

    const effectiveQuantity = product.track_serial ? selected.size : parseNumber(quantity)
    if (effectiveQuantity <= 0) {
      setError(product.track_serial ? 'Chọn ít nhất 1 Serial.' : 'Số lượng phải lớn hơn 0.')
      setBusy(false)
      return
    }

    const args: Database['public']['Functions']['inventory_issue']['Args'] = {
      p_product_id: product.product_id,
      p_quantity: effectiveQuantity,
      p_note: note.trim() || undefined,
      p_reference_type: 'MANUAL',
    }
    if (product.track_serial) args.p_inventory_unit_ids = [...selected]

    try {
      const { error: rpcError } = await supabase.rpc('inventory_issue', args)
      if (rpcError) throw rpcError
      onDone()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Xuất kho thất bại.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className="space-y-4" onSubmit={handleSubmit}>
      <ProductLabel product={product} />
      {product.track_serial ? (
        <div>
          <div className="mb-2 text-sm font-medium">Chọn Serial xuất ({selected.size})</div>
          {loading ? <div className="text-sm text-slate-500">Đang tải Serial…</div> : <UnitSelector units={units} selected={selected} onToggle={toggle} />}
          <ErrorBox message={unitError} />
        </div>
      ) : (
        <label className="block text-sm font-medium">
          Số lượng
          <input type="number" min="0.001" step="0.001" max={product.stock_qty ?? undefined} className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={quantity} onChange={(event) => setQuantity(event.target.value)} required />
        </label>
      )}
      <label className="block text-sm font-medium">
        Ghi chú
        <textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={note} onChange={(event) => setNote(event.target.value)} />
      </label>
      <ErrorBox message={error} />
      <FormActions busy={busy} onCancel={onCancel} submitLabel="Xuất kho" />
    </form>
  )
}

export function AdjustForm({
  product,
  canViewCost,
  onCancel,
  onDone,
}: {
  product: ProductInventorySummaryRow
  canViewCost: boolean
  onCancel: () => void
  onDone: () => void
}) {
  const [direction, setDirection] = useState<'IN' | 'OUT'>('IN')
  const [delta, setDelta] = useState('1')
  const [serialText, setSerialText] = useState('')
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [unitCost, setUnitCost] = useState('')
  const [location, setLocation] = useState('')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const serials = useMemo(() => parseLines(serialText), [serialText])
  const { units, loading, error: unitError } = useInStockUnits(product.track_serial && direction === 'OUT' ? product.product_id : null)

  function toggle(id: string) {
    setSelected((current) => {
      const next = new Set(current)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!product.product_id) return
    setBusy(true)
    setError(null)

    let quantityDelta: number
    if (product.track_serial) {
      const count = direction === 'IN' ? serials.length : selected.size
      if (count <= 0) {
        setError(direction === 'IN' ? 'Nhập ít nhất 1 Serial.' : 'Chọn ít nhất 1 Serial.')
        setBusy(false)
        return
      }
      quantityDelta = direction === 'IN' ? count : -count
    } else {
      const amount = Math.abs(parseNumber(delta))
      if (amount <= 0) {
        setError('Số lượng điều chỉnh phải lớn hơn 0.')
        setBusy(false)
        return
      }
      quantityDelta = direction === 'IN' ? amount : -amount
    }

    if (!note.trim()) {
      setError('Bắt buộc ghi lý do điều chỉnh.')
      setBusy(false)
      return
    }

    const args: Database['public']['Functions']['inventory_adjust']['Args'] = {
      p_product_id: product.product_id,
      p_quantity_delta: quantityDelta,
      p_note: note.trim(),
      p_location: location.trim() || undefined,
    }
    if (product.track_serial && direction === 'IN') args.p_serial_numbers = serials
    if (product.track_serial && direction === 'OUT') args.p_inventory_unit_ids = [...selected]
    if (direction === 'IN' && canViewCost && unitCost.trim()) args.p_unit_cost = Math.max(0, parseNumber(unitCost))

    try {
      const { error: rpcError } = await supabase.rpc('inventory_adjust', args)
      if (rpcError) throw rpcError
      onDone()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Điều chỉnh kho thất bại.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className="space-y-4" onSubmit={handleSubmit}>
      <ProductLabel product={product} />
      <div className="flex gap-2">
        <button type="button" onClick={() => { setDirection('IN'); setSelected(new Set()) }} className={`rounded-xl px-4 py-2 text-sm ${direction === 'IN' ? 'bg-emerald-500 font-semibold text-slate-950' : 'border border-slate-700'}`}>Điều chỉnh tăng</button>
        <button type="button" onClick={() => { setDirection('OUT'); setSelected(new Set()) }} className={`rounded-xl px-4 py-2 text-sm ${direction === 'OUT' ? 'bg-amber-500 font-semibold text-slate-950' : 'border border-slate-700'}`}>Điều chỉnh giảm</button>
      </div>

      {product.track_serial ? direction === 'IN' ? (
        <label className="block text-sm font-medium">
          Serial bổ sung — mỗi dòng một Serial ({serials.length})
          <textarea className="mt-2 min-h-32 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 font-mono text-sm outline-none focus:border-cyan-500" value={serialText} onChange={(event) => setSerialText(event.target.value)} required />
        </label>
      ) : (
        <div>
          <div className="mb-2 text-sm font-medium">Chọn Serial đưa ra khỏi tồn ({selected.size})</div>
          {loading ? <div className="text-sm text-slate-500">Đang tải Serial…</div> : <UnitSelector units={units} selected={selected} onToggle={toggle} />}
          <ErrorBox message={unitError} />
        </div>
      ) : (
        <label className="block text-sm font-medium">
          Số lượng {direction === 'IN' ? 'tăng' : 'giảm'}
          <input type="number" min="0.001" step="0.001" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={delta} onChange={(event) => setDelta(event.target.value)} required />
        </label>
      )}

      <div className="grid gap-4 sm:grid-cols-2">
        {direction === 'IN' && canViewCost ? (
          <label className="block text-sm font-medium">
            Giá vốn / đơn vị
            <input type="number" min="0" step="1" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={unitCost} onChange={(event) => setUnitCost(event.target.value)} placeholder="Có thể để trống" />
          </label>
        ) : null}
        {direction === 'IN' ? (
          <label className="block text-sm font-medium">
            Vị trí kho
            <input className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={location} onChange={(event) => setLocation(event.target.value)} />
          </label>
        ) : null}
      </div>
      <label className="block text-sm font-medium">
        Lý do điều chỉnh
        <textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 outline-none focus:border-cyan-500" value={note} onChange={(event) => setNote(event.target.value)} required />
      </label>
      <ErrorBox message={error} />
      <FormActions busy={busy} onCancel={onCancel} submitLabel="Xác nhận điều chỉnh" />
    </form>
  )
}
