import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react'
import QRCode from 'qrcode'
import type {
  AppUserContext,
} from '../../lib/permissions'
import { hasPermission } from '../../lib/permissions'
import type {
  WarrantyClaimRow,
  WarrantyClaimSummaryRow,
  WarrantyStatusHistoryRow,
  WarrantySummaryRow,
} from '../../lib/database.types'
import { supabase } from '../../lib/supabase'
import { viStatus } from '../../lib/vi'
import { Modal } from '../crm/forms'
import type { QrAction, QrResolved } from '../qr/QrCommandCenter'

type Tab = 'warranties' | 'claims'

type WarrantyScanMatch = {
  warranty_id: string
  warranty_code: string
  effective_status: string
  eligible_for_claim: boolean
  has_open_claim: boolean
  start_date: string
  end_date: string
  days_remaining: number
  coverage: string
  source_type: string
  source_code: string | null
  order_code: string | null
  sku: string | null
  product_name: string | null
  serial_number: string | null
  asset_tag: string | null
  customer_name: string
  phone: string | null
  latest_claim_code: string | null
  latest_claim_status: string | null
}

type WarrantyScanTarget = {
  target_type?: string
  status?: string
  serial_number?: string | null
  asset_tag?: string | null
  inventory_status?: string | null
  product_name?: string | null
  sku?: string | null
  order_code?: string | null
  order_status?: string | null
  customer_name?: string | null
}

type WarrantyScanResult = {
  found: boolean
  has_warranty: boolean
  eligible_for_claim: boolean
  status: string
  lookup_type: string
  result_count: number
  matches: WarrantyScanMatch[]
  target?: WarrantyScanTarget | null
}

type BarcodeDetectorLike = { detect(source: HTMLVideoElement): Promise<Array<{ rawValue?: string }>> }
type BarcodeDetectorConstructor = new (options: { formats: string[] }) => BarcodeDetectorLike

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
  return message ? <div role="alert" aria-live="assertive" className="rounded-xl border border-red-900 bg-red-950/30 p-4 text-sm text-red-200">{message}</div> : null
}

const scanStatusLabels: Record<string,string> = {
  ACTIVE: 'CÒN BẢO HÀNH',
  EXPIRED: 'HẾT BẢO HÀNH',
  VOID: 'BẢO HÀNH ĐÃ HỦY',
  PENDING: 'CHƯA ĐẾN NGÀY HIỆU LỰC',
  MULTIPLE: 'TÌM THẤY NHIỀU BẢO HÀNH',
  NOT_SOLD: 'SẢN PHẨM CHƯA BÁN',
  SALE_NOT_DELIVERED: 'ĐƠN CHƯA BÀN GIAO',
  NO_WARRANTY_POLICY: 'SẢN PHẨM KHÔNG CÓ CHÍNH SÁCH BẢO HÀNH',
  NOT_REGISTERED: 'THIẾU HỒ SƠ BẢO HÀNH',
  NOT_FOUND: 'KHÔNG TÌM THẤY SẢN PHẨM',
}

function WarrantyScanner({ onOpenWarranty }: { onOpenWarranty: (id: string) => void }) {
  const [input,setInput] = useState('')
  const [result,setResult] = useState<WarrantyScanResult|null>(null)
  const [busy,setBusy] = useState(false)
  const [error,setError] = useState<string|null>(null)
  const [camera,setCamera] = useState(false)
  const videoRef = useRef<HTMLVideoElement|null>(null)
  const streamRef = useRef<MediaStream|null>(null)
  const timerRef = useRef<number|null>(null)

  const stopCamera = useCallback(() => {
    if (timerRef.current) window.clearTimeout(timerRef.current)
    timerRef.current=null
    streamRef.current?.getTracks().forEach((track) => track.stop())
    streamRef.current=null
    setCamera(false)
  },[])

  const scan = useCallback(async (value: string) => {
    const query=value.trim()
    setResult(null);setError(null)
    if (!query) { setError('Nhập Serial, Asset Tag, mã đơn, mã bảo hành hoặc quét QR.'); return }
    setBusy(true)
    try {
      const { data,error: rpcError } = await supabase.rpc('warranty_scan_product',{p_query:query})
      if (rpcError) throw rpcError
      const payload=data as WarrantyScanResult
      setInput(query);setResult(payload)
      if (!payload?.found) setError('Không tìm thấy Serial, mã đơn hoặc mã bảo hành tương ứng.')
    } catch(err) {
      setError(err instanceof Error?err.message:'Không kiểm tra được bảo hành.')
    } finally { setBusy(false) }
  },[])

  const startCamera = useCallback(async () => {
    setError(null)
    const Detector=(window as unknown as { BarcodeDetector?: BarcodeDetectorConstructor }).BarcodeDetector
    if (!Detector) { setError('Trình duyệt chưa hỗ trợ quét bằng camera. Hãy dùng Chrome/Edge mới hoặc nhập mã thủ công.'); return }
    try {
      const stream=await navigator.mediaDevices.getUserMedia({video:{facingMode:{ideal:'environment'}},audio:false})
      streamRef.current=stream;setCamera(true)
      await new Promise<void>((resolve)=>requestAnimationFrame(()=>resolve()))
      if (!videoRef.current) return stopCamera()
      videoRef.current.srcObject=stream
      await videoRef.current.play()
      const detector=new Detector({formats:['qr_code','code_128','code_39','ean_13','ean_8']})
      const tick=async()=>{
        if (!videoRef.current||!streamRef.current) return
        try {
          const value=(await detector.detect(videoRef.current))[0]?.rawValue
          if (value) { stopCamera();await scan(value);return }
        } catch { /* camera frame may still be warming up */ }
        timerRef.current=window.setTimeout(()=>void tick(),350)
      }
      await tick()
    } catch(err) { stopCamera();setError(err instanceof Error?err.message:'Không mở được camera.') }
  },[scan,stopCamera])

  useEffect(()=>()=>stopCamera(),[stopCamera])

  const label=result?scanStatusLabels[result.status]??result.status:''
  const positive=result?.status==='ACTIVE'||result?.status==='MULTIPLE'
  return <section className="rounded-2xl border border-cyan-900/70 bg-cyan-950/10 p-4 sm:p-5">
    <div className="flex flex-wrap items-start justify-between gap-3">
      <div><div className="text-xs font-semibold uppercase tracking-[.2em] text-cyan-400">Kiểm tra bảo hành tức thời</div><h2 className="mt-1 text-lg font-bold text-white">Quét sản phẩm đã bán</h2><p className="mt-1 text-sm text-slate-400">Nhận Serial, Asset Tag, mã đơn, mã bảo hành, QR tem bảo hành hoặc QR nội bộ.</p></div>
      <span className="rounded-lg border border-slate-700 px-2.5 py-1 text-xs text-slate-400">Có kiểm tra quyền truy cập</span>
    </div>
    <div className="mt-4 flex flex-col gap-2 lg:flex-row">
      <input value={input} onChange={(event)=>setInput(event.target.value)} onKeyDown={(event)=>{if(event.key==='Enter'){event.preventDefault();void scan(input)}}} placeholder="Ví dụ: DEMO-T20-SN-001 hoặc WAR-…" className="min-w-0 flex-1 rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 outline-none focus:border-cyan-500" />
      <button type="button" disabled={busy} onClick={()=>void scan(input)} className="rounded-xl bg-cyan-500 px-5 py-3 font-semibold text-slate-950 disabled:opacity-50">{busy?'Đang đối chiếu…':'Kiểm tra bảo hành'}</button>
      {!camera?<button type="button" onClick={()=>void startCamera()} className="rounded-xl border border-cyan-800 px-5 py-3 text-cyan-300">Mở camera</button>:<button type="button" onClick={stopCamera} className="rounded-xl border border-red-900 px-5 py-3 text-red-300">Dừng camera</button>}
    </div>
    {camera?<div className="mt-3 overflow-hidden rounded-2xl border border-cyan-900 bg-black"><video ref={videoRef} muted playsInline className="aspect-video w-full object-cover" /></div>:null}
    <div className="mt-3"><ErrorPanel message={error} /></div>
    {result?.found?<div className={`mt-4 rounded-2xl border p-4 ${positive?'border-emerald-800 bg-emerald-950/25':'border-amber-800 bg-amber-950/20'}`}>
      <div className="flex flex-wrap items-center justify-between gap-2"><div className={`text-sm font-bold ${positive?'text-emerald-300':'text-amber-300'}`}>{label}</div><div className="text-xs text-slate-500">Nguồn nhận dạng: {result.lookup_type}</div></div>
      {result.has_warranty?<div className="mt-3 grid gap-3 lg:grid-cols-2">{result.matches.map((match)=><article key={match.warranty_id} className="rounded-xl border border-slate-700 bg-slate-950/60 p-3 text-sm">
        <div className="flex items-start justify-between gap-3"><div><div className="font-mono font-semibold text-cyan-300">{match.warranty_code}</div><div className="mt-1 font-medium text-white">{match.product_name??'Sản phẩm'}</div></div><span className={`rounded-lg px-2 py-1 text-xs font-semibold ${statusClass(match.effective_status)}`}>{scanStatusLabels[match.effective_status]??match.effective_status}</span></div>
        <div className="mt-3 space-y-1 text-slate-400"><div>Số sê-ri: <span className="font-mono text-slate-200">{match.serial_number??'—'}</span></div><div>Khách: <span className="text-slate-200">{match.customer_name}</span>{match.phone ? <span className="text-slate-400"> · {match.phone}</span> : null}</div><div>Đơn/nguồn: <span className="font-mono text-slate-200">{match.source_code??'—'}</span></div><div>Hiệu lực: {dateOnly(match.start_date)} → {dateOnly(match.end_date)}{match.effective_status==='ACTIVE'?` · còn ${match.days_remaining} ngày`:''}</div>{match.has_open_claim?<div className="text-amber-300">Đang có yêu cầu {match.latest_claim_code??''} · {viStatus(match.latest_claim_status)}</div>:null}</div>
        <button type="button" onClick={()=>onOpenWarranty(match.warranty_id)} className="mt-3 rounded-lg border border-cyan-800 px-3 py-2 text-xs font-semibold text-cyan-300">Mở hồ sơ bảo hành</button>
      </article>)}</div>:<div className="mt-3 text-sm text-slate-300"><div>{result.target?.product_name??result.target?.target_type} {result.target?.serial_number?<span className="font-mono text-cyan-300">· {result.target.serial_number}</span>:null}</div><div className="mt-1 text-slate-500">{result.target?.order_code?`Đơn ${result.target.order_code} · ${result.target.order_status}`:'Không có đơn đã bàn giao khớp với mã này.'}</div></div>}
    </div>:null}
  </section>
}

function escapeHtml(value: string) {
  return value.replace(/[&<>'"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[char] ?? char)
}

export function WarrantyQrCard({ row, onClose }: { row: WarrantySummaryRow; onClose: () => void }) {
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
    <div className="flex flex-wrap justify-end gap-2">
      <button type="button" onClick={onClose} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button>
      <button type="button" onClick={() => void copyLink()} className="rounded-xl border border-cyan-900 px-4 py-2 text-cyan-300">Sao chép link</button>
      {dataUrl ? <a href={dataUrl} download={`${row.warranty_code || 'warranty'}-qr.png`} className="inline-flex min-h-11 items-center rounded-xl border border-slate-700 px-4 py-2 text-sm">Tải QR PNG</a> : null}
      <button type="button" disabled={!dataUrl} onClick={printLabel} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-50">In tem QR</button>
    </div>
    <ErrorPanel message={error} />
  </div>
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
    } catch (err) { setError(err instanceof Error ? err.message : 'Không tiếp nhận được yêu cầu bảo hành.') }
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
    <div className="flex justify-end gap-2"><button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button><button disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950">Tiếp nhận yêu cầu</button></div>
    <ErrorPanel message={error} />
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
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-4"><div className="text-xs text-slate-500">Yêu cầu bảo hành</div><div className="mt-1 text-xl font-bold">{row.claim_count ?? 0}</div></div>
    </div>
    <section className="rounded-2xl border border-slate-800 bg-slate-900 p-4 text-sm">
      <div><span className="text-slate-500">Sản phẩm/thiết bị:</span> {row.product_name_snapshot || [row.device_type,row.brand,row.model].filter(Boolean).join(' ') || '—'}</div>
      <div className="mt-2"><span className="text-slate-500">Số sê-ri:</span> <span className="font-mono text-cyan-300">{row.serial_snapshot || row.device_serial || '—'}</span></div>
      <div className="mt-2"><span className="text-slate-500">Phạm vi:</span> {row.coverage}</div>
      {row.note ? <div className="mt-2"><span className="text-slate-500">Ghi chú:</span> {row.note}</div> : null}
      {row.void_reason ? <div className="mt-2 text-red-300">VOID: {row.void_reason}</div> : null}
      {canManage && row.lookup_token ? <div className="mt-3 rounded-xl border border-cyan-950 bg-cyan-950/20 p-3"><div className="text-xs font-semibold text-cyan-300">Tra cứu công khai đã bật</div><div className="mt-1 text-xs text-slate-500">/w/&lt;opaque-token&gt; · không hiển thị token thô trong chi tiết thường.</div></div> : null}
    </section>
    <div className="flex flex-wrap gap-2">
      {canManage && row.lookup_token ? <button onClick={() => setShowQr(true)} className="rounded-xl border border-cyan-800 px-4 py-2 text-sm font-semibold text-cyan-300">QR tra cứu</button> : null}
      {canManage && row.effective_status === 'ACTIVE' ? <button onClick={() => setShowClaim(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ Yêu cầu bảo hành</button> : null}
      {canManage && row.status !== 'VOID' ? <button onClick={() => void voidWarranty()} className="rounded-xl border border-red-900 px-4 py-2 text-sm text-red-300">Vô hiệu hóa</button> : null}
    </div>
    <ErrorPanel message={error} />
    <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900"><div className="border-b border-slate-800 px-4 py-3 font-semibold">Lịch sử yêu cầu bảo hành</div><div className="overflow-x-auto"><table className="w-full min-w-[800px] text-left text-sm"><thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Yêu cầu</th><th className="px-4 py-3">Lỗi</th><th className="px-4 py-3">Trạng thái</th><th className="px-4 py-3">Tiếp nhận</th><th className="px-4 py-3 text-right">Mở</th></tr></thead><tbody>{ownClaims.map((c) => c.id ? <tr key={c.id} className="border-t border-slate-800"><td className="px-4 py-3 font-mono text-cyan-300">{c.claim_code}</td><td className="px-4 py-3">{c.issue_description}</td><td className="px-4 py-3"><span title={c.status ?? undefined} className={`rounded-lg px-2 py-1 text-xs ${statusClass(c.status)}`}>{viStatus(c.status)}</span></td><td className="px-4 py-3 text-slate-400">{dateTime(c.received_at)}</td><td className="px-4 py-3 text-right"><button onClick={() => onOpenClaim(c.id!)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs">Chi tiết</button></td></tr> : null)}</tbody></table></div>{ownClaims.length === 0 ? <p className="p-6 text-center text-slate-500">Chưa có yêu cầu bảo hành.</p> : null}</section>
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
    <ErrorPanel message={error} />
    <section className="grid gap-3 md:grid-cols-2 rounded-2xl border border-slate-800 bg-slate-900 p-4 text-sm"><div><span className="text-slate-500">Tình trạng nhận:</span> {claim.intake_condition ?? '—'}</div><div><span className="text-slate-500">Yêu cầu:</span> {claim.customer_request ?? '—'}</div><div><span className="text-slate-500">Quyết định:</span> {claim.decision_note ?? '—'}</div><div><span className="text-slate-500">Xử lý:</span> {claim.service_note ?? '—'}</div><div><span className="text-slate-500">Kết quả:</span> {claim.resolution ?? '—'}</div><div><span className="text-slate-500">QC:</span> {claim.qc_passed == null ? '—' : claim.qc_passed ? 'PASS' : 'FAIL'} · {claim.qc_note ?? ''}</div></section>
    <section className="rounded-2xl border border-slate-800 bg-slate-900 p-4"><h3 className="mb-3 font-semibold">Lịch sử trạng thái</h3><div className="space-y-2">{history.map((h) => <div key={h.id} className="rounded-xl border border-slate-800 bg-slate-950/50 p-3 text-sm"><span className="font-mono text-cyan-300">{h.from_status ? viStatus(h.from_status) : 'Khởi tạo'} → {viStatus(h.to_status)}</span><span className="ml-3 text-slate-500">{dateTime(h.changed_at)}</span>{h.note ? <div className="mt-1 text-slate-400">{h.note}</div> : null}</div>)}</div></section>
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
  const [tab,setTab] = useState<Tab>(initialTarget?.resource_type === 'WARRANTY_CLAIM' ? 'claims' : 'warranties')
  const [warranties,setWarranties] = useState<WarrantySummaryRow[]>([])
  const [claims,setClaims] = useState<WarrantyClaimSummaryRow[]>([])
  const [search,setSearch] = useState('')
  const [warrantyId,setWarrantyId] = useState<string|null>(initialTarget?.resource_type === 'WARRANTY' ? initialTarget.resource_id ?? null : null)
  const [claimId,setClaimId] = useState<string|null>(initialTarget?.resource_type === 'WARRANTY_CLAIM' ? initialTarget.resource_id ?? null : null)
  const [error,setError] = useState<string|null>(null)

  const load = useCallback(async () => {
    setError(null)
    try {
      const [w,c] = await Promise.all([
        supabase.from('warranty_summary').select('*').order('created_at',{ascending:false}).limit(1000),
        supabase.from('warranty_claim_summary').select('*').order('created_at',{ascending:false}).limit(1000),
      ])
      if(w.error) throw w.error
      if(c.error) throw c.error
      setWarranties(w.data); setClaims(c.data)
    } catch(err) { setError(err instanceof Error?err.message:'Không tải được Warranty.') }
  },[])
  useEffect(() => { void load() },[load])
  useEffect(() => {
    if (initialTarget?.resource_type === 'WARRANTY') {
      setTab('warranties')
      if (initialTarget.resource_id) setWarrantyId(initialTarget.resource_id)
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
    <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
      {claimId ? <ClaimDetail claimId={claimId} context={context} onBack={() => setClaimId(null)} onChanged={() => void load()} /> : selectedWarranty ? <WarrantyDetail row={selectedWarranty} context={context} claims={claims} onBack={() => setWarrantyId(null)} onOpenClaim={setClaimId} onChanged={() => void load()} /> : <div className="space-y-5">
        <WarrantyScanner onOpenWarranty={(id)=>{setTab('warranties');setWarrantyId(id)}} />
        <div className="rounded-2xl border border-cyan-900 bg-cyan-950/20 p-4 text-sm text-cyan-100"><strong>Bảo hành được tạo tự động theo nghiệp vụ nguồn.</strong><div className="mt-1 text-cyan-200/80">Đơn bán sinh bảo hành khi bàn giao; phiếu sửa sinh bảo hành công sửa và từng linh kiện đủ chính sách. Không cần lập lại hồ sơ tại màn hình này.</div></div>
        <div className="flex flex-col gap-3 rounded-2xl border border-slate-800 bg-slate-900 p-4 lg:flex-row"><div className="flex gap-2"><button onClick={() => setTab('warranties')} className={`rounded-xl px-4 py-2 text-sm ${tab==='warranties'?'bg-cyan-500 font-semibold text-slate-950':'border border-slate-700'}`}>Bảo hành</button><button onClick={() => setTab('claims')} className={`rounded-xl px-4 py-2 text-sm ${tab==='claims'?'bg-cyan-500 font-semibold text-slate-950':'border border-slate-700'}`}>Yêu cầu xử lý</button></div><input className="min-w-0 flex-1 rounded-xl border border-slate-700 bg-slate-950 px-4 py-2" placeholder="Tìm mã, khách, điện thoại, số sê-ri, trạng thái…" value={search} onChange={(e)=>setSearch(e.target.value)} /><button onClick={() => { setSearch(''); void load() }} className="rounded-xl border border-slate-700 px-4 py-2 text-sm">Đặt lại</button></div>
        {tab==='warranties'?<section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900"><div className="overflow-x-auto"><table className="w-full min-w-[1100px] text-left text-sm"><thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Bảo hành</th><th className="px-4 py-3">Khách</th><th className="px-4 py-3">Sản phẩm / số sê-ri</th><th className="px-4 py-3">Nguồn</th><th className="px-4 py-3">Hiệu lực</th><th className="px-4 py-3">Yêu cầu</th><th className="px-4 py-3 text-right">Mở</th></tr></thead><tbody>{filteredW.map((w)=>w.id?<tr key={w.id} className="border-t border-slate-800"><td className="px-4 py-3 font-mono text-cyan-300">{w.warranty_code}</td><td className="px-4 py-3"><div className="text-white">{w.customer_name}</div><div className="text-xs text-slate-500">{w.customer_code} · {w.phone||'—'}</div></td><td className="px-4 py-3"><div>{w.product_name_snapshot||[w.device_type,w.brand,w.model].filter(Boolean).join(' ')||'—'}</div><div className="font-mono text-xs text-slate-500">{w.serial_snapshot||w.device_serial||'—'}</div></td><td className="px-4 py-3">{w.source_type}</td><td className="px-4 py-3"><span title={w.effective_status ?? undefined} className={`rounded-lg px-2 py-1 text-xs ${statusClass(w.effective_status)}`}>{viStatus(w.effective_status)}</span><div className="mt-1 text-xs text-slate-500">{dateOnly(w.start_date)} → {dateOnly(w.end_date)}</div></td><td className="px-4 py-3">{w.claim_count??0} · {viStatus(w.latest_claim_status)}</td><td className="px-4 py-3 text-right"><button onClick={()=>setWarrantyId(w.id!)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs">Chi tiết</button></td></tr>:null)}</tbody></table></div>{filteredW.length===0?<p className="p-8 text-center text-slate-500">Chưa có bảo hành.</p>:null}</section>:<section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900"><div className="overflow-x-auto"><table className="w-full min-w-[1000px] text-left text-sm"><thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Yêu cầu</th><th className="px-4 py-3">Bảo hành</th><th className="px-4 py-3">Khách</th><th className="px-4 py-3">Lỗi</th><th className="px-4 py-3">Trạng thái</th><th className="px-4 py-3">Tiếp nhận</th><th className="px-4 py-3 text-right">Mở</th></tr></thead><tbody>{filteredC.map((c)=>c.id?<tr key={c.id} className="border-t border-slate-800"><td className="px-4 py-3 font-mono text-cyan-300">{c.claim_code}</td><td className="px-4 py-3 font-mono text-xs">{c.warranty_code}</td><td className="px-4 py-3">{c.customer_name}<div className="text-xs text-slate-500">{c.phone||'—'}</div></td><td className="px-4 py-3">{c.issue_description}</td><td className="px-4 py-3"><span title={c.status ?? undefined} className={`rounded-lg px-2 py-1 text-xs ${statusClass(c.status)}`}>{viStatus(c.status)}</span></td><td className="px-4 py-3 text-slate-400">{dateTime(c.received_at)}</td><td className="px-4 py-3 text-right"><button onClick={()=>setClaimId(c.id!)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs">Chi tiết</button></td></tr>:null)}</tbody></table></div>{filteredC.length===0?<p className="p-8 text-center text-slate-500">Chưa có yêu cầu bảo hành.</p>:null}</section>}
        <ErrorPanel message={error} />
      </div>}
    </div>
  </main>
}
