import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react'
import QRCode from 'qrcode'
import type {
  AppUserContext,
} from '../../lib/permissions'
import { hasPermission } from '../../lib/permissions'
import type {
  DeviceRow,
  InventoryUnitRow,
  RepairOrderSummaryRow,
  SalesOrderItemRow,
  SalesOrderSummaryRow,
  WarrantyClaimRow,
  WarrantyClaimSummaryRow,
  WarrantyStatusHistoryRow,
  WarrantySummaryRow,
} from '../../lib/database.types'
import { supabase } from '../../lib/supabase'
import { Modal } from '../crm/forms'
import type { QrAction, QrResolved } from '../qr/QrCommandCenter'

type Tab = 'warranties' | 'claims'

function dateTime(value: string | null | undefined) {
  return value ? new Date(value).toLocaleString('vi-VN') : '—'
}
function dateOnly(value: string | null | undefined) {
  if (!value) return '—'
  return new Date(`${value}T00:00:00`).toLocaleDateString('vi-VN')
}
function statusClass(status: string | null | undefined) {
  if (status === 'ACTIVE' || status === 'CLOSED' || status === 'READY') return 'bg-emerald-950 text-emerald-300'
  if (status === 'VOID' || status === 'REJECTED' || status === 'EXPIRED') return 'bg-red-950 text-red-300'
  if (status === 'QC' || status === 'CHECKING' || status === 'IN_SERVICE') return 'bg-cyan-950 text-cyan-300'
  return 'bg-amber-950 text-amber-300'
}
function ErrorPanel({ message }: { message: string | null }) {
  return message ? <div className="rounded-xl border border-red-900 bg-red-950/30 p-4 text-sm text-red-200">{message}</div> : null
}

function escapeHtml(value: string) {
  return value.replace(/[&<>'"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[char] ?? char)
}

function WarrantyQrCard({ row, onClose }: { row: WarrantySummaryRow; onClose: () => void }) {
  const [dataUrl, setDataUrl] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const publicUrl = row.lookup_token ? `${window.location.origin}/w/${row.lookup_token}` : ''

  useEffect(() => {
    let cancelled = false
    setError(null)
    setDataUrl(null)
    if (!publicUrl) return
    void QRCode.toDataURL(publicUrl, {
      errorCorrectionLevel: 'M',
      margin: 2,
      width: 640,
      color: { dark: '#0f172a', light: '#ffffff' },
    }).then((url) => {
      if (!cancelled) setDataUrl(url)
    }).catch((err: unknown) => {
      if (!cancelled) setError(err instanceof Error ? err.message : 'Không tạo được QR.')
    })
    return () => { cancelled = true }
  }, [publicUrl])

  async function copyLink() {
    if (!publicUrl) return
    try {
      await navigator.clipboard.writeText(publicUrl)
    } catch {
      window.prompt('Sao chép đường dẫn tra cứu:', publicUrl)
    }
  }

  function printLabel() {
    if (!dataUrl || !publicUrl) return
    const popup = window.open('', '_blank', 'width=560,height=760')
    if (!popup) {
      setError('Trình duyệt đang chặn cửa sổ in. Hãy cho phép pop-up rồi thử lại.')
      return
    }
    const product = row.product_name_snapshot || [row.device_type,row.brand,row.model].filter(Boolean).join(' ') || 'Thiết bị'
    popup.document.write(`<!doctype html><html><head><meta charset="utf-8"><title>${escapeHtml(row.warranty_code ?? 'Tem bảo hành')}</title><style>body{font-family:Arial,sans-serif;margin:0;padding:24px;color:#111}.label{width:86mm;max-width:100%;border:1px solid #bbb;border-radius:12px;padding:16px;box-sizing:border-box;text-align:center}.brand{font-size:13px;font-weight:700;letter-spacing:2px}.code{font-family:monospace;font-size:18px;font-weight:700;margin-top:6px}.product{font-size:13px;margin:8px 0;line-height:1.4}.qr{width:58mm;height:58mm;object-fit:contain}.hint{font-size:11px;color:#555;margin-top:6px}.url{font-size:8px;word-break:break-all;color:#777;margin-top:8px}@media print{body{padding:0}.label{border:0}}</style></head><body><div class="label"><div class="brand">HOMETECHVN</div><div class="code">${escapeHtml(row.warranty_code ?? '')}</div><div class="product">${escapeHtml(product)}</div><img class="qr" src="${dataUrl}" alt="QR"><div class="hint">Quét QR để tra cứu bảo hành</div><div class="url">${escapeHtml(publicUrl)}</div></div><script>window.addEventListener('load',()=>setTimeout(()=>window.print(),150));<\/script></body></html>`)
    popup.document.close()
  }

  return <div className="space-y-4">
    <div className="grid gap-5 sm:grid-cols-[260px_1fr] sm:items-center">
      <div className="grid min-h-[260px] place-items-center rounded-2xl bg-white p-3">
        {dataUrl ? <img src={dataUrl} alt={`QR tra cứu ${row.warranty_code}`} className="h-60 w-60 max-w-full" /> : <div className="text-sm text-slate-600">Đang tạo QR…</div>}
      </div>
      <div className="min-w-0 space-y-3">
        <div><div className="text-xs uppercase tracking-[0.14em] text-slate-500">Mã bảo hành</div><div className="mt-1 font-mono text-xl font-bold text-white">{row.warranty_code}</div></div>
        <div><div className="text-xs uppercase tracking-[0.14em] text-slate-500">Đường dẫn công khai</div><div className="mt-1 break-all rounded-xl border border-slate-800 bg-slate-950 p-3 font-mono text-xs text-cyan-300">{publicUrl}</div></div>
        <p className="text-xs leading-5 text-slate-500">QR chứa token ngẫu nhiên 64 ký tự. Trang công khai chỉ trả dữ liệu đã giới hạn và che SĐT/Serial.</p>
      </div>
    </div>
    <ErrorPanel message={error} />
    <div className="flex flex-wrap justify-end gap-2">
      <button type="button" onClick={onClose} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button>
      <button type="button" onClick={() => void copyLink()} className="rounded-xl border border-cyan-900 px-4 py-2 text-cyan-300">Sao chép link</button>
      {dataUrl ? <a href={dataUrl} download={`${row.warranty_code || 'warranty'}-qr.png`} className="inline-flex min-h-11 items-center rounded-xl border border-slate-700 px-4 py-2 text-sm">Tải QR PNG</a> : null}
      <button type="button" disabled={!dataUrl} onClick={printLabel} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-50">In tem QR</button>
    </div>
  </div>
}

function CreateWarrantyForm({
  sales,
  items,
  repairs,
  devices,
  units,
  onCancel,
  onDone,
}: {
  sales: SalesOrderSummaryRow[]
  items: SalesOrderItemRow[]
  repairs: RepairOrderSummaryRow[]
  devices: DeviceRow[]
  units: InventoryUnitRow[]
  onCancel: () => void
  onDone: () => void
}) {
  const eligibleSales = sales.filter((x) => x.id && ['DELIVERED', 'COMPLETED'].includes(x.status ?? ''))
  const eligibleRepairs = repairs.filter((x) => x.id && x.status === 'COMPLETED')
  const [sourceType, setSourceType] = useState<'SALE' | 'REPAIR'>('SALE')
  const [saleOrderId, setSaleOrderId] = useState(eligibleSales[0]?.id ?? '')
  const saleItems = useMemo(() => items.filter((x) => x.sales_order_id === saleOrderId), [items, saleOrderId])
  const [saleItemId, setSaleItemId] = useState(saleItems[0]?.id ?? '')
  const selectedItem = useMemo(() => items.find((x) => x.id === saleItemId), [items, saleItemId])
  const selectedSale = useMemo(() => sales.find((x) => x.id === saleOrderId), [sales, saleOrderId])
  const itemUnits = useMemo(() => units.filter((u) => selectedItem?.inventory_unit_ids.includes(u.id)), [selectedItem, units])
  const [inventoryUnitId, setInventoryUnitId] = useState(itemUnits[0]?.id ?? '')
  const customerDevices = useMemo(() => devices.filter((d) => d.customer_id === selectedSale?.customer_id), [devices, selectedSale?.customer_id])
  const [customerDeviceId, setCustomerDeviceId] = useState('')
  const [repairId, setRepairId] = useState(eligibleRepairs[0]?.id ?? '')
  const [months, setMonths] = useState('12')
  const [startDate, setStartDate] = useState(new Date().toISOString().slice(0, 10))
  const [coverage, setCoverage] = useState('Bảo hành tiêu chuẩn')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const first = items.find((x) => x.sales_order_id === saleOrderId)
    setSaleItemId(first?.id ?? '')
  }, [saleOrderId, items])
  useEffect(() => {
    const next = units.find((u) => selectedItem?.inventory_unit_ids.includes(u.id))
    setInventoryUnitId(next?.id ?? '')
  }, [selectedItem, units])
  useEffect(() => {
    setCustomerDeviceId('')
  }, [saleOrderId])
  useEffect(() => {
    if (sourceType === 'SALE') {
      setMonths(String(selectedItem?.warranty_months || 12))
      setCoverage('Bảo hành tiêu chuẩn')
    } else {
      setMonths('3')
      setCoverage('Bảo hành dịch vụ sửa chữa')
    }
  }, [sourceType, selectedItem?.warranty_months])

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)
    try {
      if (sourceType === 'SALE') {
        if (!saleItemId) throw new Error('Chưa chọn dòng hàng bán.')
        if ((selectedItem?.inventory_unit_ids.length ?? 0) > 0 && !inventoryUnitId) throw new Error('Sản phẩm Serial cần chọn đúng Serial đã bán.')
        const { error: rpcError } = await supabase.rpc('warranty_create_sale', {
          p_sales_order_item_id: saleItemId,
          p_inventory_unit_id: inventoryUnitId || undefined,
          p_customer_device_id: customerDeviceId || undefined,
          p_start_date: startDate,
          p_warranty_months: Math.max(1, Number(months) || 1),
          p_coverage: coverage.trim(),
          p_note: note.trim() || undefined,
        })
        if (rpcError) throw rpcError
      } else {
        if (!repairId) throw new Error('Chưa chọn phiếu sửa chữa COMPLETED.')
        const { error: rpcError } = await supabase.rpc('warranty_create_repair', {
          p_repair_order_id: repairId,
          p_start_date: startDate,
          p_warranty_months: Math.max(1, Number(months) || 1),
          p_coverage: coverage.trim(),
          p_note: note.trim() || undefined,
        })
        if (rpcError) throw rpcError
      }
      onDone()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tạo được bảo hành.')
    } finally {
      setBusy(false)
    }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <div className="grid grid-cols-2 gap-2 rounded-xl border border-slate-800 bg-slate-950 p-1">
      <button type="button" onClick={() => setSourceType('SALE')} className={`rounded-lg px-3 py-2 text-sm ${sourceType === 'SALE' ? 'bg-cyan-500 font-semibold text-slate-950' : ''}`}>Từ đơn bán</button>
      <button type="button" onClick={() => setSourceType('REPAIR')} className={`rounded-lg px-3 py-2 text-sm ${sourceType === 'REPAIR' ? 'bg-cyan-500 font-semibold text-slate-950' : ''}`}>Từ sửa chữa</button>
    </div>

    {sourceType === 'SALE' ? <>
      <label className="block text-sm font-medium">Đơn đã giao
        <select required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={saleOrderId} onChange={(e) => setSaleOrderId(e.target.value)}>
          <option value="">— Chọn đơn —</option>
          {eligibleSales.map((x) => <option key={x.id!} value={x.id!}>{x.order_code} · {x.customer_name} · {x.status}</option>)}
        </select>
      </label>
      <label className="block text-sm font-medium">Dòng hàng
        <select required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={saleItemId} onChange={(e) => setSaleItemId(e.target.value)}>
          <option value="">— Chọn sản phẩm —</option>
          {saleItems.map((x) => <option key={x.id} value={x.id}>{x.sku_snapshot} · {x.product_name_snapshot} · BH {x.warranty_months} tháng</option>)}
        </select>
      </label>
      {(selectedItem?.inventory_unit_ids.length ?? 0) > 0 ? <label className="block text-sm font-medium">Serial đã bán
        <select required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={inventoryUnitId} onChange={(e) => setInventoryUnitId(e.target.value)}>
          <option value="">— Chọn Serial —</option>
          {itemUnits.map((u) => <option key={u.id} value={u.id}>{u.serial_number}</option>)}
        </select>
      </label> : null}
      <label className="block text-sm font-medium">Gắn với thiết bị khách (không bắt buộc)
        <select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={customerDeviceId} onChange={(e) => setCustomerDeviceId(e.target.value)}>
          <option value="">— Không gắn —</option>
          {customerDevices.map((d) => <option key={d.id} value={d.id}>{d.device_code} · {d.device_type} {d.brand ?? ''} {d.model ?? ''} · {d.serial_number ?? '—'}</option>)}
        </select>
      </label>
    </> : <label className="block text-sm font-medium">Phiếu sửa chữa COMPLETED
      <select required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={repairId} onChange={(e) => setRepairId(e.target.value)}>
        <option value="">— Chọn phiếu —</option>
        {eligibleRepairs.map((x) => <option key={x.id!} value={x.id!}>{x.repair_code} · {x.customer_name} · {x.device_type} {x.brand ?? ''} {x.model ?? ''}</option>)}
      </select>
    </label>}

    <div className="grid gap-4 sm:grid-cols-2">
      <label className="text-sm font-medium">Ngày bắt đầu
        <input type="date" required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={startDate} onChange={(e) => setStartDate(e.target.value)} />
      </label>
      <label className="text-sm font-medium">Số tháng
        <input type="number" min="1" max="120" required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={months} onChange={(e) => setMonths(e.target.value)} />
      </label>
    </div>
    <label className="block text-sm font-medium">Phạm vi bảo hành
      <input required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={coverage} onChange={(e) => setCoverage(e.target.value)} />
    </label>
    <label className="block text-sm font-medium">Ghi chú
      <textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={note} onChange={(e) => setNote(e.target.value)} />
    </label>
    <p className="text-xs text-slate-500">Nguồn SERVICE đã được schema hỗ trợ nhưng sẽ kích hoạt ở T8 khi module dịch vụ tồn tại.</p>
    <ErrorPanel message={error} />
    <div className="flex justify-end gap-2">
      <button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button>
      <button disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-50">{busy ? 'Đang tạo…' : 'Tạo bảo hành'}</button>
    </div>
  </form>
}

function CreateClaimForm({ warrantyId, onCancel, onDone }: { warrantyId: string; onCancel: () => void; onDone: () => void }) {
  const [issue, setIssue] = useState('')
  const [condition, setCondition] = useState('')
  const [request, setRequest] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError(null)
    try {
      const { error: rpcError } = await supabase.rpc('warranty_claim_create', {
        p_warranty_id: warrantyId,
        p_issue_description: issue.trim(),
        p_intake_condition: condition.trim() || undefined,
        p_customer_request: request.trim() || undefined,
      })
      if (rpcError) throw rpcError
      onDone()
    } catch (err) { setError(err instanceof Error ? err.message : 'Không tiếp nhận được claim.') }
    finally { setBusy(false) }
  }
  return <form className="space-y-4" onSubmit={submit}>
    <label className="block text-sm font-medium">Lỗi khách báo
      <textarea required className="mt-2 min-h-24 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={issue} onChange={(e) => setIssue(e.target.value)} />
    </label>
    <label className="block text-sm font-medium">Tình trạng tiếp nhận
      <textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={condition} onChange={(e) => setCondition(e.target.value)} />
    </label>
    <label className="block text-sm font-medium">Yêu cầu khách hàng
      <input className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={request} onChange={(e) => setRequest(e.target.value)} />
    </label>
    <ErrorPanel message={error} />
    <div className="flex justify-end gap-2"><button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button><button disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950">Tiếp nhận claim</button></div>
  </form>
}

function WarrantyDetail({ row, context, claims, onBack, onOpenClaim, onChanged }: { row: WarrantySummaryRow; context: AppUserContext; claims: WarrantyClaimSummaryRow[]; onBack: () => void; onOpenClaim: (id: string) => void; onChanged: () => void }) {
  const canManage = hasPermission(context, 'warranty.manage')
  const [showClaim, setShowClaim] = useState(false)
  const [showQr, setShowQr] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const ownClaims = claims.filter((c) => c.warranty_id === row.id)
  async function voidWarranty() {
    if (!row.id) return
    const reason = window.prompt('Lý do VOID bảo hành:')
    if (!reason?.trim()) return
    const { error: rpcError } = await supabase.rpc('warranty_void', { p_warranty_id: row.id, p_reason: reason.trim() })
    if (rpcError) setError(rpcError.message); else onChanged()
  }
  return <div className="space-y-5">
    <div className="flex flex-wrap items-start justify-between gap-4">
      <div><button onClick={onBack} className="text-sm text-cyan-300">← Danh sách bảo hành</button><h2 className="mt-2 font-mono text-2xl font-bold text-white">{row.warranty_code}</h2><p className="text-sm text-slate-500">{row.customer_name} · {row.phone ?? '—'}</p></div>
      <span className={`rounded-xl px-3 py-2 text-sm font-semibold ${statusClass(row.effective_status)}`}>{row.effective_status}</span>
    </div>
    <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-4">
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-4"><div className="text-xs text-slate-500">Nguồn</div><div className="mt-1 font-semibold">{row.source_type}</div></div>
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-4"><div className="text-xs text-slate-500">Bắt đầu</div><div className="mt-1 font-semibold">{dateOnly(row.start_date)}</div></div>
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-4"><div className="text-xs text-slate-500">Hết hạn</div><div className="mt-1 font-semibold">{dateOnly(row.end_date)}</div></div>
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-4"><div className="text-xs text-slate-500">Claims</div><div className="mt-1 text-xl font-bold">{row.claim_count ?? 0}</div></div>
    </div>
    <section className="rounded-2xl border border-slate-800 bg-slate-900 p-4 text-sm">
      <div><span className="text-slate-500">Sản phẩm/thiết bị:</span> {row.product_name_snapshot || [row.device_type,row.brand,row.model].filter(Boolean).join(' ') || '—'}</div>
      <div className="mt-2"><span className="text-slate-500">Serial:</span> <span className="font-mono text-cyan-300">{row.serial_snapshot || row.device_serial || '—'}</span></div>
      <div className="mt-2"><span className="text-slate-500">Phạm vi:</span> {row.coverage}</div>
      {row.note ? <div className="mt-2"><span className="text-slate-500">Ghi chú:</span> {row.note}</div> : null}
      {row.void_reason ? <div className="mt-2 text-red-300">VOID: {row.void_reason}</div> : null}
      {canManage && row.lookup_token ? <div className="mt-3 rounded-xl border border-cyan-950 bg-cyan-950/20 p-3"><div className="text-xs font-semibold text-cyan-300">Tra cứu công khai đã bật</div><div className="mt-1 text-xs text-slate-500">/w/&lt;opaque-token&gt; · không hiển thị token thô trong chi tiết thường.</div></div> : null}
    </section>
    <div className="flex flex-wrap gap-2">
      {canManage && row.lookup_token ? <button onClick={() => setShowQr(true)} className="rounded-xl border border-cyan-800 px-4 py-2 text-sm font-semibold text-cyan-300">QR tra cứu</button> : null}
      {canManage && row.effective_status === 'ACTIVE' ? <button onClick={() => setShowClaim(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ Yêu cầu bảo hành</button> : null}
      {canManage && row.status !== 'VOID' ? <button onClick={() => void voidWarranty()} className="rounded-xl border border-red-900 px-4 py-2 text-sm text-red-300">VOID</button> : null}
    </div>
    <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900"><div className="border-b border-slate-800 px-4 py-3 font-semibold">Lịch sử claim</div><div className="overflow-x-auto"><table className="w-full min-w-[800px] text-left text-sm"><thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Claim</th><th className="px-4 py-3">Lỗi</th><th className="px-4 py-3">Status</th><th className="px-4 py-3">Tiếp nhận</th><th className="px-4 py-3 text-right">Mở</th></tr></thead><tbody>{ownClaims.map((c) => c.id ? <tr key={c.id} className="border-t border-slate-800"><td className="px-4 py-3 font-mono text-cyan-300">{c.claim_code}</td><td className="px-4 py-3">{c.issue_description}</td><td className="px-4 py-3"><span className={`rounded-lg px-2 py-1 text-xs ${statusClass(c.status)}`}>{c.status}</span></td><td className="px-4 py-3 text-slate-400">{dateTime(c.received_at)}</td><td className="px-4 py-3 text-right"><button onClick={() => onOpenClaim(c.id!)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs">Chi tiết</button></td></tr> : null)}</tbody></table></div>{ownClaims.length === 0 ? <p className="p-6 text-center text-slate-500">Chưa có yêu cầu bảo hành.</p> : null}</section>
    <ErrorPanel message={error} />
    {showQr && row.lookup_token ? <Modal title="QR tra cứu bảo hành" onClose={() => setShowQr(false)}><WarrantyQrCard row={row} onClose={() => setShowQr(false)} /></Modal> : null}
    {showClaim && row.id ? <Modal title="Tiếp nhận yêu cầu bảo hành" onClose={() => setShowClaim(false)}><CreateClaimForm warrantyId={row.id} onCancel={() => setShowClaim(false)} onDone={() => { setShowClaim(false); onChanged() }} /></Modal> : null}
  </div>
}

function ClaimDetail({ claimId, context, onBack, onChanged }: { claimId: string; context: AppUserContext; onBack: () => void; onChanged: () => void }) {
  const [claim, setClaim] = useState<WarrantyClaimRow | null>(null)
  const [history, setHistory] = useState<WarrantyStatusHistoryRow[]>([])
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const canManage = hasPermission(context, 'warranty.manage')
  const load = useCallback(async () => {
    setError(null)
    const [c,h] = await Promise.all([
      supabase.from('warranty_claims').select('*').eq('id',claimId).single(),
      supabase.from('warranty_status_history').select('*').eq('warranty_claim_id',claimId).order('changed_at'),
    ])
    if (c.error) { setError(c.error.message); return }
    if (h.error) { setError(h.error.message); return }
    setClaim(c.data); setHistory(h.data)
  },[claimId])
  useEffect(() => { void load() }, [load])

  async function call(action: () => PromiseLike<{ error: { message: string } | null }>) {
    setBusy(true); setError(null)
    try { const { error: rpcError } = await action(); if (rpcError) throw new Error(rpcError.message); await load(); onChanged() }
    catch (err) { setError(err instanceof Error ? err.message : 'Thao tác thất bại.') }
    finally { setBusy(false) }
  }
  if (!claim) return <div className="space-y-4"><button onClick={onBack} className="text-cyan-300">← Quay lại</button><ErrorPanel message={error} /><p className="text-slate-500">Đang tải claim…</p></div>

  const status = claim.status
  return <div className="space-y-5">
    <div className="flex flex-wrap items-start justify-between gap-4"><div><button onClick={onBack} className="text-sm text-cyan-300">← Quay lại</button><h2 className="mt-2 font-mono text-2xl font-bold text-white">{claim.claim_code}</h2><p className="mt-1 text-slate-400">{claim.issue_description}</p></div><span className={`rounded-xl px-3 py-2 text-sm font-semibold ${statusClass(status)}`}>{status}</span></div>
    {canManage ? <div className="flex flex-wrap gap-2 rounded-2xl border border-slate-800 bg-slate-900 p-4">
      {status === 'RECEIVED' ? <button disabled={busy} onClick={() => void call(() => supabase.rpc('warranty_claim_start_checking',{p_claim_id:claim.id,p_note:'Bắt đầu kiểm tra'}))} className="rounded-xl bg-cyan-500 px-3 py-2 text-sm font-semibold text-slate-950">Bắt đầu kiểm tra</button> : null}
      {status === 'CHECKING' ? <><button disabled={busy} onClick={() => { const note=window.prompt('Ghi chú duyệt bảo hành:') ?? ''; void call(() => supabase.rpc('warranty_claim_decide',{p_claim_id:claim.id,p_approved:true,p_note:note||undefined})) }} className="rounded-xl bg-emerald-500 px-3 py-2 text-sm font-semibold text-slate-950">APPROVE</button><button disabled={busy} onClick={() => { const note=window.prompt('Lý do từ chối:'); if(note?.trim()) void call(() => supabase.rpc('warranty_claim_decide',{p_claim_id:claim.id,p_approved:false,p_note:note.trim()})) }} className="rounded-xl border border-red-900 px-3 py-2 text-sm text-red-300">REJECT</button></> : null}
      {status === 'APPROVED' ? <button disabled={busy} onClick={() => { const note=window.prompt('Ghi chú bắt đầu xử lý:') ?? ''; void call(() => supabase.rpc('warranty_claim_start_service',{p_claim_id:claim.id,p_service_note:note||undefined})) }} className="rounded-xl bg-cyan-500 px-3 py-2 text-sm font-semibold text-slate-950">IN_SERVICE</button> : null}
      {status === 'IN_SERVICE' ? <><button disabled={busy} onClick={() => { const note=window.prompt('Nội dung xử lý:',claim.service_note ?? ''); if(note?.trim()) { const resolution=window.prompt('Kết quả/giải pháp:',claim.resolution ?? '') ?? ''; void call(() => supabase.rpc('warranty_claim_update_service',{p_claim_id:claim.id,p_service_note:note.trim(),p_resolution:resolution||undefined})) } }} className="rounded-xl border border-cyan-900 px-3 py-2 text-sm text-cyan-300">Cập nhật xử lý</button><button disabled={busy} onClick={() => void call(() => supabase.rpc('warranty_claim_start_qc',{p_claim_id:claim.id}))} className="rounded-xl bg-violet-500 px-3 py-2 text-sm font-semibold text-white">Chuyển QC</button></> : null}
      {status === 'QC' ? <><button disabled={busy} onClick={() => { const note=window.prompt('QC PASS - ghi chú:'); if(note?.trim()) { const resolution=window.prompt('Kết quả cuối:',claim.resolution ?? '') ?? ''; void call(() => supabase.rpc('warranty_claim_record_qc',{p_claim_id:claim.id,p_passed:true,p_note:note.trim(),p_resolution:resolution||undefined})) } }} className="rounded-xl bg-emerald-500 px-3 py-2 text-sm font-semibold text-slate-950">QC PASS</button><button disabled={busy} onClick={() => { const note=window.prompt('QC FAIL - nguyên nhân:'); if(note?.trim()) void call(() => supabase.rpc('warranty_claim_record_qc',{p_claim_id:claim.id,p_passed:false,p_note:note.trim()})) }} className="rounded-xl border border-red-900 px-3 py-2 text-sm text-red-300">QC FAIL</button></> : null}
      {status === 'READY' ? <button disabled={busy} onClick={() => void call(() => supabase.rpc('warranty_claim_mark_returned',{p_claim_id:claim.id,p_note:'Đã trả khách'}))} className="rounded-xl bg-cyan-500 px-3 py-2 text-sm font-semibold text-slate-950">Đã trả khách</button> : null}
      {status === 'RETURNED' || status === 'REJECTED' ? <button disabled={busy} onClick={() => void call(() => supabase.rpc('warranty_claim_close',{p_claim_id:claim.id,p_note:'Đóng yêu cầu'}))} className="rounded-xl bg-emerald-500 px-3 py-2 text-sm font-semibold text-slate-950">CLOSE</button> : null}
    </div> : null}
    <section className="grid gap-3 md:grid-cols-2 rounded-2xl border border-slate-800 bg-slate-900 p-4 text-sm"><div><span className="text-slate-500">Tình trạng nhận:</span> {claim.intake_condition ?? '—'}</div><div><span className="text-slate-500">Yêu cầu:</span> {claim.customer_request ?? '—'}</div><div><span className="text-slate-500">Quyết định:</span> {claim.decision_note ?? '—'}</div><div><span className="text-slate-500">Xử lý:</span> {claim.service_note ?? '—'}</div><div><span className="text-slate-500">Kết quả:</span> {claim.resolution ?? '—'}</div><div><span className="text-slate-500">QC:</span> {claim.qc_passed == null ? '—' : claim.qc_passed ? 'PASS' : 'FAIL'} · {claim.qc_note ?? ''}</div></section>
    <section className="rounded-2xl border border-slate-800 bg-slate-900 p-4"><h3 className="mb-3 font-semibold">Status history</h3><div className="space-y-2">{history.map((h) => <div key={h.id} className="rounded-xl border border-slate-800 bg-slate-950/50 p-3 text-sm"><span className="font-mono text-cyan-300">{h.from_status ?? 'START'} → {h.to_status}</span><span className="ml-3 text-slate-500">{dateTime(h.changed_at)}</span>{h.note ? <div className="mt-1 text-slate-400">{h.note}</div> : null}</div>)}</div></section>
    <ErrorPanel message={error} />
  </div>
}

export function WarrantyPage({
  context,
  initialTarget,
  initialAction,
  onOpenCrm,
  onOpenInventory,
  onOpenSales,
  onOpenRepair,
  onOpenChecklist,
}: {
  context: AppUserContext
  initialTarget?: QrResolved
  initialAction?: QrAction
  onOpenCrm?: () => void
  onOpenInventory?: () => void
  onOpenSales?: () => void
  onOpenRepair?: () => void
  onOpenChecklist?: () => void
}) {
  const canManage = hasPermission(context,'warranty.manage')
  const [tab,setTab] = useState<Tab>(initialTarget?.resource_type === 'WARRANTY_CLAIM' ? 'claims' : 'warranties')
  const [warranties,setWarranties] = useState<WarrantySummaryRow[]>([])
  const [claims,setClaims] = useState<WarrantyClaimSummaryRow[]>([])
  const [sales,setSales] = useState<SalesOrderSummaryRow[]>([])
  const [saleItems,setSaleItems] = useState<SalesOrderItemRow[]>([])
  const [repairs,setRepairs] = useState<RepairOrderSummaryRow[]>([])
  const [devices,setDevices] = useState<DeviceRow[]>([])
  const [units,setUnits] = useState<InventoryUnitRow[]>([])
  const [search,setSearch] = useState('')
  const [showCreate,setShowCreate] = useState(initialAction === 'CREATE' && initialTarget?.resource_type === 'WARRANTY')
  const [warrantyId,setWarrantyId] = useState<string|null>(initialTarget?.resource_type === 'WARRANTY' ? initialTarget.resource_id ?? null : null)
  const [claimId,setClaimId] = useState<string|null>(initialTarget?.resource_type === 'WARRANTY_CLAIM' ? initialTarget.resource_id ?? null : null)
  const [error,setError] = useState<string|null>(null)

  const load = useCallback(async () => {
    setError(null)
    try {
      const [w,c,s,i,r,d,u] = await Promise.all([
        supabase.from('warranty_summary').select('*').order('created_at',{ascending:false}).limit(1000),
        supabase.from('warranty_claim_summary').select('*').order('created_at',{ascending:false}).limit(1000),
        supabase.from('sales_order_summary').select('*').order('created_at',{ascending:false}).limit(750),
        supabase.from('sales_order_items').select('*').order('created_at',{ascending:false}).limit(1500),
        supabase.from('repair_order_summary').select('*').order('created_at',{ascending:false}).limit(750),
        supabase.from('customer_devices').select('*').eq('status','ACTIVE').order('created_at',{ascending:false}).limit(1500),
        supabase.from('inventory_units').select('*').order('created_at',{ascending:false}).limit(2500),
      ])
      if(w.error) throw w.error
      if(c.error) throw c.error
      // Source lists may be RLS-empty for some warranty viewers; errors should still be surfaced.
      if(s.error) throw s.error
      if(i.error) throw i.error
      if(r.error) throw r.error
      if(d.error) throw d.error
      if(u.error) throw u.error
      setWarranties(w.data); setClaims(c.data); setSales(s.data); setSaleItems(i.data); setRepairs(r.data); setDevices(d.data); setUnits(u.data)
    } catch(err) { setError(err instanceof Error?err.message:'Không tải được Warranty.') }
  },[])
  useEffect(() => { void load() },[load])
  useEffect(() => {
    if (initialTarget?.resource_type === 'WARRANTY') {
      setTab('warranties')
      if (initialTarget.resource_id) setWarrantyId(initialTarget.resource_id)
      if (initialAction === 'CREATE') setShowCreate(true)
    } else if (initialTarget?.resource_type === 'WARRANTY_CLAIM') {
      setTab('claims')
      if (initialTarget.resource_id) setClaimId(initialTarget.resource_id)
    }
  }, [initialTarget, initialAction])

  const q=search.trim().toLocaleLowerCase('vi-VN')
  const filteredW = warranties.filter((w) => !q || [w.warranty_code,w.customer_code,w.customer_name,w.phone,w.product_name_snapshot,w.serial_snapshot,w.device_code,w.device_serial,w.effective_status].join(' ').toLocaleLowerCase('vi-VN').includes(q))
  const filteredC = claims.filter((c) => !q || [c.claim_code,c.warranty_code,c.customer_code,c.customer_name,c.phone,c.issue_description,c.status].join(' ').toLocaleLowerCase('vi-VN').includes(q))
  const selectedWarranty = warranties.find((w) => w.id === warrantyId) ?? null

  if (!hasPermission(context,'warranty.view')) return <main className="grid min-h-screen place-items-center bg-slate-950 text-slate-200"><div className="rounded-2xl border border-amber-900 p-6">Vai trò hiện tại không có quyền xem Warranty.</div></main>

  return <main className="min-h-screen bg-slate-950 text-slate-200">
    <header className="border-b border-slate-800 bg-slate-900/90 px-4 py-4 sm:px-6"><div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4"><div><div className="text-sm font-semibold uppercase tracking-[0.24em] text-cyan-400">HomeTechVN</div><h1 className="mt-1 text-xl font-bold text-white">Bảo hành & Claims</h1></div><div className="flex flex-wrap items-center gap-2 text-sm">{onOpenCrm?<button onClick={onOpenCrm} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">CRM</button>:null}{onOpenInventory?<button onClick={onOpenInventory} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Kho</button>:null}{onOpenSales?<button onClick={onOpenSales} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Bán hàng</button>:null}{onOpenRepair?<button onClick={onOpenRepair} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Sửa chữa</button>:null}{onOpenChecklist?<button onClick={onOpenChecklist} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Checklist</button>:null}<div className="px-2 text-right"><div className="font-medium text-white">{context.fullName||context.email||'Người dùng'}</div><div className="text-xs text-slate-500">{context.roleName} · {context.roleCode}</div></div><button onClick={() => void supabase.auth.signOut()} className="rounded-xl border border-slate-700 px-3 py-2">Đăng xuất</button></div></div></header>
    <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
      {claimId ? <ClaimDetail claimId={claimId} context={context} onBack={() => setClaimId(null)} onChanged={() => void load()} /> : selectedWarranty ? <WarrantyDetail row={selectedWarranty} context={context} claims={claims} onBack={() => setWarrantyId(null)} onOpenClaim={setClaimId} onChanged={() => void load()} /> : <div className="space-y-5">
        <div className="flex flex-col gap-3 rounded-2xl border border-slate-800 bg-slate-900 p-4 lg:flex-row"><div className="flex gap-2"><button onClick={() => setTab('warranties')} className={`rounded-xl px-4 py-2 text-sm ${tab==='warranties'?'bg-cyan-500 font-semibold text-slate-950':'border border-slate-700'}`}>Bảo hành</button><button onClick={() => setTab('claims')} className={`rounded-xl px-4 py-2 text-sm ${tab==='claims'?'bg-cyan-500 font-semibold text-slate-950':'border border-slate-700'}`}>Claims</button></div><input className="min-w-0 flex-1 rounded-xl border border-slate-700 bg-slate-950 px-4 py-2" placeholder="Tìm mã, khách, điện thoại, Serial, trạng thái…" value={search} onChange={(e)=>setSearch(e.target.value)} /><button onClick={() => void load()} className="rounded-xl border border-slate-700 px-4 py-2 text-sm">Làm mới</button>{canManage && tab==='warranties'?<button onClick={() => setShowCreate(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ Bảo hành</button>:null}</div>
        {tab==='warranties'?<section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900"><div className="overflow-x-auto"><table className="w-full min-w-[1100px] text-left text-sm"><thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Warranty</th><th className="px-4 py-3">Khách</th><th className="px-4 py-3">Sản phẩm / Serial</th><th className="px-4 py-3">Nguồn</th><th className="px-4 py-3">Hiệu lực</th><th className="px-4 py-3">Claim</th><th className="px-4 py-3 text-right">Mở</th></tr></thead><tbody>{filteredW.map((w)=>w.id?<tr key={w.id} className="border-t border-slate-800"><td className="px-4 py-3 font-mono text-cyan-300">{w.warranty_code}</td><td className="px-4 py-3"><div className="text-white">{w.customer_name}</div><div className="text-xs text-slate-500">{w.customer_code} · {w.phone||'—'}</div></td><td className="px-4 py-3"><div>{w.product_name_snapshot||[w.device_type,w.brand,w.model].filter(Boolean).join(' ')||'—'}</div><div className="font-mono text-xs text-slate-500">{w.serial_snapshot||w.device_serial||'—'}</div></td><td className="px-4 py-3">{w.source_type}</td><td className="px-4 py-3"><span className={`rounded-lg px-2 py-1 text-xs ${statusClass(w.effective_status)}`}>{w.effective_status}</span><div className="mt-1 text-xs text-slate-500">{dateOnly(w.start_date)} → {dateOnly(w.end_date)}</div></td><td className="px-4 py-3">{w.claim_count??0} · {w.latest_claim_status??'—'}</td><td className="px-4 py-3 text-right"><button onClick={()=>setWarrantyId(w.id!)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs">Chi tiết</button></td></tr>:null)}</tbody></table></div>{filteredW.length===0?<p className="p-8 text-center text-slate-500">Chưa có bảo hành.</p>:null}</section>:<section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900"><div className="overflow-x-auto"><table className="w-full min-w-[1000px] text-left text-sm"><thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Claim</th><th className="px-4 py-3">Warranty</th><th className="px-4 py-3">Khách</th><th className="px-4 py-3">Lỗi</th><th className="px-4 py-3">Status</th><th className="px-4 py-3">Tiếp nhận</th><th className="px-4 py-3 text-right">Mở</th></tr></thead><tbody>{filteredC.map((c)=>c.id?<tr key={c.id} className="border-t border-slate-800"><td className="px-4 py-3 font-mono text-cyan-300">{c.claim_code}</td><td className="px-4 py-3 font-mono text-xs">{c.warranty_code}</td><td className="px-4 py-3">{c.customer_name}<div className="text-xs text-slate-500">{c.phone||'—'}</div></td><td className="px-4 py-3">{c.issue_description}</td><td className="px-4 py-3"><span className={`rounded-lg px-2 py-1 text-xs ${statusClass(c.status)}`}>{c.status}</span></td><td className="px-4 py-3 text-slate-400">{dateTime(c.received_at)}</td><td className="px-4 py-3 text-right"><button onClick={()=>setClaimId(c.id!)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs">Chi tiết</button></td></tr>:null)}</tbody></table></div>{filteredC.length===0?<p className="p-8 text-center text-slate-500">Chưa có claim.</p>:null}</section>}
        <ErrorPanel message={error} />
      </div>}
    </div>
    {showCreate?<Modal title="Tạo bảo hành" onClose={()=>setShowCreate(false)}><CreateWarrantyForm sales={sales} items={saleItems} repairs={repairs} devices={devices} units={units} onCancel={()=>setShowCreate(false)} onDone={()=>{setShowCreate(false);void load()}} /></Modal>:null}
  </main>
}
