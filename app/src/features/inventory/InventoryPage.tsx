import { useCallback, useEffect, useMemo, useState } from 'react'
import type { AppUserContext } from '../../lib/permissions'
import { hasPermission } from '../../lib/permissions'
import { supabase } from '../../lib/supabase'
import type {
  InventoryTransactionViewRow,
  InventoryUnitRow,
  ProductCategoryRow,
  ProductInventorySummaryRow,
  ProductRow,
} from '../../lib/database.types'
import { Modal } from '../crm/forms'
import { AdjustForm, CategoryForm, IssueForm, ProductForm, ReceiveForm } from './forms'
import type { QrAction, QrResolved } from '../qr/QrCommandCenter'

type Tab = 'products' | 'serials' | 'transactions' | 'categories'
type ProductAction =
  | { type: 'edit'; product: ProductRow }
  | { type: 'receive'; product: ProductInventorySummaryRow }
  | { type: 'issue'; product: ProductInventorySummaryRow }
  | { type: 'adjust'; product: ProductInventorySummaryRow }
  | null

function money(value: number | null | undefined) {
  if (value == null) return '—'
  return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND', maximumFractionDigits: 0 }).format(value)
}

function number(value: number | null | undefined) {
  return new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 3 }).format(value ?? 0)
}

function normalize(value: string) {
  return value.trim().toLocaleLowerCase('vi-VN')
}

function ErrorPanel({ message }: { message: string | null }) {
  if (!message) return null
  return <div className="rounded-xl border border-red-900 bg-red-950/30 p-4 text-sm text-red-200">{message}</div>
}

function ProductsTab({ context, initialTarget, initialAction }: { context: AppUserContext; initialTarget?: QrResolved; initialAction?: QrAction }) {
  const [products, setProducts] = useState<ProductRow[]>([])
  const [summaries, setSummaries] = useState<ProductInventorySummaryRow[]>([])
  const [categories, setCategories] = useState<ProductCategoryRow[]>([])
  const [search, setSearch] = useState(initialTarget?.resource_type === 'PRODUCT' ? initialTarget.resource_id ?? '' : '')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [showCreate, setShowCreate] = useState(false)
  const [action, setAction] = useState<ProductAction>(null)

  const canManage = hasPermission(context, 'product.manage')
  const canReceive = hasPermission(context, 'inventory.receive')
  const canIssue = hasPermission(context, 'inventory.issue')
  const canAdjust = hasPermission(context, 'inventory.adjust')
  const canViewCost = hasPermission(context, 'cost_price.view')

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [productsResult, summaryResult, categoryResult] = await Promise.all([
        supabase.from('products').select('*').order('updated_at', { ascending: false }).limit(500),
        supabase.from('product_inventory_summary').select('*').order('name').limit(500),
        supabase.from('product_categories').select('*').order('sort_order').order('name').limit(250),
      ])
      if (productsResult.error) throw productsResult.error
      if (summaryResult.error) throw summaryResult.error
      if (categoryResult.error) throw categoryResult.error
      setProducts(productsResult.data)
      setSummaries(summaryResult.data)
      setCategories(categoryResult.data)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tải được dữ liệu sản phẩm.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { void load() }, [load])
  useEffect(() => {
    if (initialTarget?.resource_type !== 'PRODUCT') return
    if (initialTarget.resource_id) setSearch(initialTarget.resource_id)
    if (initialAction === 'CREATE') setShowCreate(true)
    if (initialAction === 'EDIT' && initialTarget.resource_id) {
      const product=products.find((row) => row.id === initialTarget.resource_id)
      if (product) setAction({ type:'edit', product })
    }
  }, [initialTarget, initialAction, products])

  const summaryById = useMemo(
    () => new Map(summaries.flatMap((row) => row.product_id ? [[row.product_id, row] as const] : [])),
    [summaries],
  )
  const categoryById = useMemo(() => new Map(categories.map((row) => [row.id, row.name])), [categories])

  const filtered = useMemo(() => {
    const query = normalize(search)
    if (!query) return products
    return products.filter((row) => [row.id, row.sku, row.name, row.brand ?? '', row.model ?? '', row.barcode ?? '', categoryById.get(row.category_id ?? '') ?? '']
      .join(' ')
      .toLocaleLowerCase('vi-VN')
      .includes(query))
  }, [categoryById, products, search])

  function finishAction() {
    setAction(null)
    void load()
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-col gap-3 rounded-2xl border border-slate-800 bg-slate-900 p-4 lg:flex-row lg:items-center">
        <input
          className="min-w-0 flex-1 rounded-xl border border-slate-700 bg-slate-950 px-4 py-2 outline-none focus:border-cyan-500"
          placeholder="Tìm SKU, tên, hãng, model, barcode, danh mục…"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
        <div className="flex flex-wrap gap-2">
          <button type="button" onClick={() => void load()} className="rounded-xl border border-slate-700 px-4 py-2 text-sm hover:bg-slate-800">Làm mới</button>
          {canManage ? <button type="button" onClick={() => setShowCreate(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ Sản phẩm</button> : null}
        </div>
      </div>

      <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[1250px] text-left text-sm">
            <thead className="bg-slate-950/70 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">SKU / Sản phẩm</th>
                <th className="px-4 py-3">Danh mục</th>
                <th className="px-4 py-3">Giá bán</th>
                <th className="px-4 py-3">Tồn</th>
                {canViewCost ? <th className="px-4 py-3">Giá vốn gần nhất</th> : null}
                <th className="px-4 py-3">Quản lý</th>
                <th className="px-4 py-3">Trạng thái</th>
                <th className="px-4 py-3 text-right">Thao tác</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((row) => {
                const summary = summaryById.get(row.id)
                const stockQty = summary?.stock_qty ?? 0
                return (
                  <tr key={row.id} className="border-t border-slate-800 align-top hover:bg-slate-800/35">
                    <td className="px-4 py-3">
                      <div className="font-mono text-cyan-300">{row.sku}</div>
                      <div className="mt-1 font-medium text-white">{row.name}</div>
                      <div className="mt-1 text-xs text-slate-500">{[row.brand, row.model].filter(Boolean).join(' ') || '—'}</div>
                    </td>
                    <td className="px-4 py-3">{categoryById.get(row.category_id ?? '') ?? '—'}</td>
                    <td className="px-4 py-3">{money(row.sale_price)}</td>
                    <td className="px-4 py-3">
                      <div className={summary?.low_stock ? 'font-semibold text-amber-300' : 'font-semibold text-emerald-300'}>{number(stockQty)} {row.unit}</div>
                      <div className="mt-1 text-xs text-slate-500">Tối thiểu: {number(row.min_stock)}</div>
                    </td>
                    {canViewCost ? <td className="px-4 py-3 text-slate-300">{money(summary?.last_unit_cost)}</td> : null}
                    <td className="px-4 py-3">{row.track_serial ? <span className="rounded-lg bg-violet-950 px-2 py-1 text-xs text-violet-300">Theo Serial</span> : <span className="text-slate-500">Số lượng</span>}</td>
                    <td className="px-4 py-3">{row.is_active ? 'Đang bán' : 'Ngừng'}</td>
                    <td className="px-4 py-3">
                      <div className="flex flex-wrap justify-end gap-1.5">
                        {canManage ? <button type="button" onClick={() => setAction({ type: 'edit', product: row })} className="rounded-lg border border-slate-700 px-2.5 py-1 text-xs hover:bg-slate-800">Sửa</button> : null}
                        {summary && canReceive ? <button type="button" onClick={() => setAction({ type: 'receive', product: summary })} className="rounded-lg border border-emerald-800 px-2.5 py-1 text-xs text-emerald-300 hover:bg-emerald-950/40">Nhập</button> : null}
                        {summary && canIssue && stockQty > 0 ? <button type="button" onClick={() => setAction({ type: 'issue', product: summary })} className="rounded-lg border border-amber-800 px-2.5 py-1 text-xs text-amber-300 hover:bg-amber-950/40">Xuất</button> : null}
                        {summary && canAdjust ? <button type="button" onClick={() => setAction({ type: 'adjust', product: summary })} className="rounded-lg border border-violet-800 px-2.5 py-1 text-xs text-violet-300 hover:bg-violet-950/40">Điều chỉnh</button> : null}
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
        {loading ? <p className="p-6 text-center text-slate-500">Đang tải…</p> : null}
        {!loading && filtered.length === 0 ? <p className="p-8 text-center text-slate-500">Không có sản phẩm phù hợp.</p> : null}
      </section>
      <ErrorPanel message={error} />

      {showCreate ? (
        <Modal title="Thêm sản phẩm" onClose={() => setShowCreate(false)}>
          <ProductForm categories={categories} onCancel={() => setShowCreate(false)} onSaved={() => { setShowCreate(false); void load() }} />
        </Modal>
      ) : null}

      {action?.type === 'edit' ? (
        <Modal title="Cập nhật sản phẩm" onClose={() => setAction(null)}>
          <ProductForm initial={action.product} categories={categories} onCancel={() => setAction(null)} onSaved={finishAction} />
        </Modal>
      ) : null}
      {action?.type === 'receive' ? (
        <Modal title="Nhập kho" onClose={() => setAction(null)}><ReceiveForm product={action.product} canViewCost={canViewCost} onCancel={() => setAction(null)} onDone={finishAction} /></Modal>
      ) : null}
      {action?.type === 'issue' ? (
        <Modal title="Xuất kho" onClose={() => setAction(null)}><IssueForm product={action.product} onCancel={() => setAction(null)} onDone={finishAction} /></Modal>
      ) : null}
      {action?.type === 'adjust' ? (
        <Modal title="Điều chỉnh tồn kho" onClose={() => setAction(null)}><AdjustForm product={action.product} canViewCost={canViewCost} onCancel={() => setAction(null)} onDone={finishAction} /></Modal>
      ) : null}
    </div>
  )
}

function SerialsTab({ initialTarget }: { initialTarget?: QrResolved }) {
  const [rows, setRows] = useState<InventoryUnitRow[]>([])
  const [products, setProducts] = useState<Map<string, ProductRow>>(new Map())
  const [search, setSearch] = useState(initialTarget?.resource_type === 'INVENTORY_UNIT' ? initialTarget.resource_id ?? '' : '')
  const [status, setStatus] = useState<'ALL' | 'IN_STOCK' | 'OUT'>('ALL')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data: units, error: unitError } = await supabase.from('inventory_units').select('*').order('updated_at', { ascending: false }).limit(750)
      if (unitError) throw unitError
      setRows(units)
      const ids = [...new Set(units.map((item) => item.product_id))]
      if (ids.length === 0) setProducts(new Map())
      else {
        const { data: productRows, error: productError } = await supabase.from('products').select('*').in('id', ids)
        if (productError) throw productError
        setProducts(new Map(productRows.map((item) => [item.id, item])))
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tải được danh sách Serial.')
    } finally { setLoading(false) }
  }, [])

  useEffect(() => { void load() }, [load])
  useEffect(() => { if (initialTarget?.resource_type === 'INVENTORY_UNIT' && initialTarget.resource_id) setSearch(initialTarget.resource_id) }, [initialTarget])

  const filtered = useMemo(() => {
    const query = normalize(search)
    return rows.filter((row) => {
      if (status !== 'ALL' && row.status !== status) return false
      if (!query) return true
      const product = products.get(row.product_id)
      return [row.id, row.serial_number, row.asset_tag ?? '', row.location ?? '', product?.sku ?? '', product?.name ?? '', product?.brand ?? '', product?.model ?? '']
        .join(' ')
        .toLocaleLowerCase('vi-VN')
        .includes(query)
    })
  }, [products, rows, search, status])

  return (
    <div className="space-y-4">
      <div className="flex flex-col gap-3 rounded-2xl border border-slate-800 bg-slate-900 p-4 md:flex-row">
        <input className="min-w-0 flex-1 rounded-xl border border-slate-700 bg-slate-950 px-4 py-2 outline-none focus:border-cyan-500" placeholder="Tìm Serial, SKU, tên sản phẩm, vị trí…" value={search} onChange={(e) => setSearch(e.target.value)} />
        <select className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={status} onChange={(e) => setStatus(e.target.value as typeof status)}>
          <option value="ALL">Tất cả trạng thái</option><option value="IN_STOCK">Trong kho</option><option value="OUT">Đã xuất</option>
        </select>
        <button type="button" onClick={() => void load()} className="rounded-xl border border-slate-700 px-4 py-2 text-sm hover:bg-slate-800">Làm mới</button>
      </div>
      <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900">
        <div className="overflow-x-auto"><table className="w-full min-w-[950px] text-left text-sm">
          <thead className="bg-slate-950/70 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Serial</th><th className="px-4 py-3">Sản phẩm</th><th className="px-4 py-3">Vị trí</th><th className="px-4 py-3">Nhập kho</th><th className="px-4 py-3">Trạng thái</th><th className="px-4 py-3">Xuất lúc</th></tr></thead>
          <tbody>{filtered.map((row) => { const product = products.get(row.product_id); return <tr key={row.id} className="border-t border-slate-800"><td className="px-4 py-3 font-mono text-cyan-300">{row.serial_number}</td><td className="px-4 py-3"><div className="font-medium text-white">{product?.name ?? '—'}</div><div className="font-mono text-xs text-slate-500">{product?.sku ?? row.product_id}</div></td><td className="px-4 py-3">{row.location || '—'}</td><td className="px-4 py-3 text-slate-400">{new Date(row.received_at).toLocaleString('vi-VN')}</td><td className="px-4 py-3"><span className={row.status === 'IN_STOCK' ? 'text-emerald-300' : 'text-slate-400'}>{row.status === 'IN_STOCK' ? 'Trong kho' : 'Đã xuất'}</span></td><td className="px-4 py-3 text-slate-400">{row.issued_at ? new Date(row.issued_at).toLocaleString('vi-VN') : '—'}</td></tr> })}</tbody>
        </table></div>
        {loading ? <p className="p-6 text-center text-slate-500">Đang tải…</p> : null}
        {!loading && filtered.length === 0 ? <p className="p-8 text-center text-slate-500">Không có Serial phù hợp.</p> : null}
      </section>
      <ErrorPanel message={error} />
    </div>
  )
}

function TransactionsTab({ canViewCost }: { canViewCost: boolean }) {
  const [rows, setRows] = useState<InventoryTransactionViewRow[]>([])
  const [products, setProducts] = useState<Map<string, ProductRow>>(new Map())
  const [units, setUnits] = useState<Map<string, InventoryUnitRow>>(new Map())
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true); setError(null)
    try {
      const { data: txRows, error: txError } = await supabase.from('inventory_transactions_view').select('*').order('occurred_at', { ascending: false }).limit(750)
      if (txError) throw txError
      setRows(txRows)
      const productIds = [...new Set(txRows.flatMap((row) => row.product_id ? [row.product_id] : []))]
      const unitIds = [...new Set(txRows.flatMap((row) => row.inventory_unit_id ? [row.inventory_unit_id] : []))]
      if (productIds.length) {
        const { data, error: e } = await supabase.from('products').select('*').in('id', productIds); if (e) throw e; setProducts(new Map(data.map((x) => [x.id, x])))
      } else setProducts(new Map())
      if (unitIds.length) {
        const { data, error: e } = await supabase.from('inventory_units').select('*').in('id', unitIds); if (e) throw e; setUnits(new Map(data.map((x) => [x.id, x])))
      } else setUnits(new Map())
    } catch (err) { setError(err instanceof Error ? err.message : 'Không tải được giao dịch kho.') }
    finally { setLoading(false) }
  }, [])
  useEffect(() => { void load() }, [load])

  const filtered = useMemo(() => {
    const query = normalize(search)
    if (!query) return rows
    return rows.filter((row) => {
      const product = row.product_id ? products.get(row.product_id) : undefined
      const unit = row.inventory_unit_id ? units.get(row.inventory_unit_id) : undefined
      return [row.transaction_type ?? '', product?.sku ?? '', product?.name ?? '', unit?.serial_number ?? '', row.reference_type ?? '', row.note ?? ''].join(' ').toLocaleLowerCase('vi-VN').includes(query)
    })
  }, [products, rows, search, units])

  return <div className="space-y-4">
    <div className="flex gap-3 rounded-2xl border border-slate-800 bg-slate-900 p-4"><input className="min-w-0 flex-1 rounded-xl border border-slate-700 bg-slate-950 px-4 py-2 outline-none focus:border-cyan-500" placeholder="Tìm loại giao dịch, SKU, sản phẩm, Serial, ghi chú…" value={search} onChange={(e) => setSearch(e.target.value)} /><button type="button" onClick={() => void load()} className="rounded-xl border border-slate-700 px-4 py-2 text-sm hover:bg-slate-800">Làm mới</button></div>
    <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900"><div className="overflow-x-auto"><table className="w-full min-w-[1100px] text-left text-sm"><thead className="bg-slate-950/70 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Thời gian</th><th className="px-4 py-3">Loại</th><th className="px-4 py-3">Sản phẩm</th><th className="px-4 py-3">Serial</th><th className="px-4 py-3">SL</th>{canViewCost ? <th className="px-4 py-3">Giá vốn</th> : null}<th className="px-4 py-3">Tham chiếu / Ghi chú</th></tr></thead><tbody>{filtered.map((row) => { const product = row.product_id ? products.get(row.product_id) : undefined; const unit = row.inventory_unit_id ? units.get(row.inventory_unit_id) : undefined; return <tr key={row.id ?? `${row.product_id}-${row.occurred_at}`} className="border-t border-slate-800"><td className="px-4 py-3 text-slate-400">{row.occurred_at ? new Date(row.occurred_at).toLocaleString('vi-VN') : '—'}</td><td className="px-4 py-3 font-medium">{row.transaction_type}</td><td className="px-4 py-3"><div className="text-white">{product?.name ?? '—'}</div><div className="font-mono text-xs text-cyan-400">{product?.sku ?? row.product_id ?? '—'}</div></td><td className="px-4 py-3 font-mono text-xs">{unit?.serial_number ?? '—'}</td><td className="px-4 py-3">{number(row.quantity)}</td>{canViewCost ? <td className="px-4 py-3">{money(row.unit_cost)}</td> : null}<td className="max-w-sm px-4 py-3 text-slate-400"><div>{row.reference_type || '—'}</div><div className="mt-1 truncate text-xs">{row.note || '—'}</div></td></tr> })}</tbody></table></div>{loading ? <p className="p-6 text-center text-slate-500">Đang tải…</p> : null}{!loading && filtered.length === 0 ? <p className="p-8 text-center text-slate-500">Chưa có giao dịch phù hợp.</p> : null}</section>
    <ErrorPanel message={error} />
  </div>
}

function CategoriesTab({ context }: { context: AppUserContext }) {
  const [rows, setRows] = useState<ProductCategoryRow[]>([])
  const [editing, setEditing] = useState<ProductCategoryRow | null>(null)
  const [showCreate, setShowCreate] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const canManage = hasPermission(context, 'product.manage')
  const load = useCallback(async () => {
    const { data, error: queryError } = await supabase.from('product_categories').select('*').order('sort_order').order('name')
    if (queryError) { setError(queryError.message); setRows([]) } else { setError(null); setRows(data) }
  }, [])
  useEffect(() => { void load() }, [load])
  return <div className="space-y-4">
    <div className="flex justify-between rounded-2xl border border-slate-800 bg-slate-900 p-4"><div><h2 className="font-semibold text-white">Danh mục sản phẩm</h2><p className="mt-1 text-sm text-slate-500">Không xóa vật lý; có thể tắt danh mục không còn dùng.</p></div>{canManage ? <button type="button" onClick={() => setShowCreate(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ Danh mục</button> : null}</div>
    <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900"><div className="overflow-x-auto"><table className="w-full min-w-[720px] text-left text-sm"><thead className="bg-slate-950/70 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Tên</th><th className="px-4 py-3">Mô tả</th><th className="px-4 py-3">Thứ tự</th><th className="px-4 py-3">Trạng thái</th><th className="px-4 py-3 text-right">Sửa</th></tr></thead><tbody>{rows.map((row) => <tr key={row.id} className="border-t border-slate-800"><td className="px-4 py-3 font-medium text-white">{row.name}</td><td className="px-4 py-3 text-slate-400">{row.description || '—'}</td><td className="px-4 py-3">{row.sort_order}</td><td className="px-4 py-3">{row.is_active ? 'Đang dùng' : 'Ngừng'}</td><td className="px-4 py-3 text-right">{canManage ? <button type="button" onClick={() => setEditing(row)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs hover:bg-slate-800">Sửa</button> : '—'}</td></tr>)}</tbody></table></div></section>
    <ErrorPanel message={error} />
    {showCreate ? <Modal title="Thêm danh mục" onClose={() => setShowCreate(false)}><CategoryForm onCancel={() => setShowCreate(false)} onSaved={() => { setShowCreate(false); void load() }} /></Modal> : null}
    {editing ? <Modal title="Cập nhật danh mục" onClose={() => setEditing(null)}><CategoryForm initial={editing} onCancel={() => setEditing(null)} onSaved={() => { setEditing(null); void load() }} /></Modal> : null}
  </div>
}

export function InventoryPage({ context, initialTarget, initialAction, onOpenCrm, onOpenSales, onOpenRepair, onOpenChecklist, onOpenWarranty }: { context: AppUserContext; initialTarget?: QrResolved; initialAction?: QrAction; onOpenCrm: () => void; onOpenSales?: () => void; onOpenRepair?: () => void; onOpenChecklist?: () => void; onOpenWarranty?: () => void }) {
  const [tab, setTab] = useState<Tab>(initialTarget?.resource_type === 'INVENTORY_UNIT' ? 'serials' : 'products')
  useEffect(() => {
    if (initialTarget?.resource_type === 'INVENTORY_UNIT') setTab('serials')
    else if (initialTarget?.resource_type === 'PRODUCT') setTab('products')
  }, [initialTarget])
  const canViewProducts = hasPermission(context, 'product.view')
  const canViewInventory = hasPermission(context, 'inventory.view')
  const canViewCost = hasPermission(context, 'cost_price.view')
  const canOpenCrm = hasPermission(context, 'customer.view') || hasPermission(context, 'device.view')

  if (!canViewProducts && !canViewInventory) {
    return <main className="grid min-h-screen place-items-center bg-slate-950 text-slate-200"><div className="rounded-2xl border border-amber-900 bg-amber-950/20 p-6">Vai trò hiện tại không có quyền xem Product/Inventory.</div></main>
  }

  const tabs: Array<{ id: Tab; label: string; visible: boolean }> = [
    { id: 'products', label: 'Sản phẩm & Tồn', visible: canViewProducts && canViewInventory },
    { id: 'serials', label: 'Serial', visible: canViewInventory },
    { id: 'transactions', label: 'Giao dịch kho', visible: canViewInventory },
    { id: 'categories', label: 'Danh mục', visible: canViewProducts },
  ]

  return <main className="min-h-screen bg-slate-950 text-slate-200">
    <header className="border-b border-slate-800 bg-slate-900/90 px-4 py-4 backdrop-blur sm:px-6"><div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4"><div><div className="text-sm font-semibold uppercase tracking-[0.24em] text-cyan-400">HomeTechVN</div><h1 className="mt-1 text-xl font-bold text-white">Sản phẩm & Quản lý kho</h1></div><div className="flex flex-wrap items-center gap-2 text-sm">{canOpenCrm ? <button type="button" onClick={onOpenCrm} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300 hover:bg-cyan-950/40">CRM & Thiết bị</button> : null}{onOpenSales ? <button type="button" onClick={onOpenSales} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300 hover:bg-cyan-950/40">Bán hàng</button> : null}{onOpenRepair ? <button type="button" onClick={onOpenRepair} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300 hover:bg-cyan-950/40">Sửa chữa</button> : null}{onOpenChecklist ? <button type="button" onClick={onOpenChecklist} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300 hover:bg-cyan-950/40">Checklist</button> : null}{onOpenWarranty ? <button type="button" onClick={onOpenWarranty} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300 hover:bg-cyan-950/40">Bảo hành</button> : null}<div className="px-2 text-right"><div className="font-medium text-white">{context.fullName || context.email || 'Người dùng'}</div><div className="text-xs text-slate-500">{context.roleName} · {context.roleCode}</div></div><button type="button" onClick={() => void supabase.auth.signOut()} className="rounded-xl border border-slate-700 px-3 py-2 hover:bg-slate-800">Đăng xuất</button></div></div></header>
    <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6"><nav className="mb-5 flex flex-wrap gap-2">{tabs.filter((item) => item.visible).map((item) => <button key={item.id} type="button" onClick={() => setTab(item.id)} className={`rounded-xl px-4 py-2 text-sm font-medium ${tab === item.id ? 'bg-cyan-500 text-slate-950' : 'border border-slate-700 text-slate-300 hover:bg-slate-800'}`}>{item.label}</button>)}</nav>
      {tab === 'products' && canViewProducts && canViewInventory ? <ProductsTab context={context} initialTarget={initialTarget} initialAction={initialAction} /> : null}
      {tab === 'serials' && canViewInventory ? <SerialsTab initialTarget={initialTarget} /> : null}
      {tab === 'transactions' && canViewInventory ? <TransactionsTab canViewCost={canViewCost} /> : null}
      {tab === 'categories' && canViewProducts ? <CategoriesTab context={context} /> : null}
    </div>
  </main>
}
