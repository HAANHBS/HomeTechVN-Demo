import { useCallback, useEffect, useState } from 'react'
import type { WarrantySummaryRow } from '../../lib/database.types'
import { supabase } from '../../lib/supabase'
import { Modal } from '../crm/forms'
import { WarrantyQrCard } from './WarrantyPage'

export function WarrantyLabelsPanel({
  sourceType,
  sourceId,
}: {
  sourceType: 'SALE' | 'REPAIR'
  sourceId: string
}) {
  const [rows, setRows] = useState<WarrantySummaryRow[]>([])
  const [selected, setSelected] = useState<WarrantySummaryRow | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    const { data, error: queryError } = await supabase
      .from('warranty_summary')
      .select('*')
      .eq('source_type', sourceType)
      .eq('source_id', sourceId)
      .order('created_at')
    if (queryError) setError(queryError.message)
    else setRows(data)
    setLoading(false)
  }, [sourceId, sourceType])

  useEffect(() => { void load() }, [load])

  return <section className="rounded-2xl border border-cyan-900/70 bg-cyan-950/10 p-4">
    <div className="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h3 className="font-semibold text-white">Tem QR bảo hành</h3>
        <p className="mt-1 text-sm text-slate-400">In và dán từng tem lên sản phẩm. Khách quét lại để xem người mua đã che thông tin và thời hạn bảo hành.</p>
      </div>
      <button type="button" onClick={() => void load()} className="rounded-xl border border-cyan-900 px-3 py-2 text-sm text-cyan-300">Tải lại</button>
    </div>
    {loading ? <p className="mt-4 text-sm text-slate-500">Đang tải tem bảo hành…</p> : null}
    {error ? <p role="alert" className="mt-4 text-sm text-red-300">{error}</p> : null}
    {!loading && !error && rows.length === 0 ? <p className="mt-4 rounded-xl border border-amber-900/60 bg-amber-950/20 p-3 text-sm text-amber-200">Chưa có tem. Tem được tạo tự động sau khi đơn bán đã bàn giao hoặc phiếu sửa chữa hoàn tất.</p> : null}
    {rows.length ? <div className="mt-4 grid gap-3 md:grid-cols-2">{rows.map((row) => <article key={row.id ?? row.warranty_code} className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-800 bg-slate-950/60 p-3">
      <div className="min-w-0"><div className="font-mono font-semibold text-cyan-300">{row.warranty_code}</div><div className="mt-1 truncate text-sm text-white">{row.product_name_snapshot || [row.device_type,row.brand,row.model].filter(Boolean).join(' ') || 'Sản phẩm / thiết bị'}</div><div className="mt-1 text-xs text-slate-500">{row.start_date} → {row.end_date}</div></div>
      <button type="button" disabled={!row.lookup_token} onClick={() => setSelected(row)} className="rounded-xl bg-cyan-500 px-3 py-2 text-sm font-semibold text-slate-950 disabled:opacity-40">In tem QR</button>
    </article>)}</div> : null}
    {selected ? <Modal title="In tem QR bảo hành" onClose={() => setSelected(null)}><WarrantyQrCard row={selected} onClose={() => setSelected(null)} /></Modal> : null}
  </section>
}
