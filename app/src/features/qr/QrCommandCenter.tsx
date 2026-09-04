import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react'
import QRCode from 'qrcode'
import type { AppUserContext } from '../../lib/permissions'
import { hasPermission } from '../../lib/permissions'
import { supabase } from '../../lib/supabase'

export type QrRoute = 'crm'|'inventory'|'sales'|'repair'|'warranty'|'service-license'|'checklist'|'reminders'|'notifications'
export type QrAction = 'CREATE'|'VIEW'|'EDIT'|'PAY'

export type QrResolved = {
  found: boolean
  resource_type?: string
  resource_id?: string | null
  intent?: QrAction
  label?: string
  route?: QrRoute
  allowed_actions?: QrAction[]
  expires_at?: string | null
}

type QrIssued = {
  token: string
  path: string
  resource_type: string
  resource_id: string | null
  intent: QrAction
  label: string
  expires_at: string | null
}

type Detector = { detect(source: HTMLVideoElement): Promise<Array<{ rawValue?: string }>> }
type DetectorConstructor = new (options: { formats: string[] }) => Detector

const resources = [
  ['CUSTOMER','Khách hàng','CUS-000001'], ['DEVICE','Thiết bị','DEV-000001'],
  ['PRODUCT','Sản phẩm','SKU hoặc UUID'], ['INVENTORY_UNIT','Serial kho','Serial / Asset tag'],
  ['SALES_ORDER','Đơn bán','SO-20260904-0001'], ['PAYMENT','Thanh toán','PAY-20260904-0001'],
  ['REPAIR_ORDER','Phiếu sửa','SRV-20260904-0001'], ['WARRANTY','Bảo hành','WAR-000001'],
  ['WARRANTY_CLAIM','Yêu cầu bảo hành','WCL-000001'], ['SERVICE_SCHEDULE','Lịch dịch vụ','UUID'],
  ['SOFTWARE_LICENSE','Bản quyền','LIC-000001'], ['CHECKLIST_RUN','Checklist','UUID'],
  ['REMINDER','Nhắc việc','REM-000001'], ['NOTIFICATION','Thông báo','UUID'],
] as const

const actionLabels: Record<QrAction,string> = { CREATE:'Thêm mới', VIEW:'Xem', EDIT:'Sửa', PAY:'Thanh toán' }

function parseToken(value: string) {
  const trimmed = value.trim().toLowerCase()
  if (/^[0-9a-f]{64}$/.test(trimmed)) return trimmed
  try {
    const url = new URL(trimmed, window.location.origin)
    const queryToken = url.searchParams.get('qr')?.toLowerCase()
    if (queryToken && /^[0-9a-f]{64}$/.test(queryToken)) return queryToken
    const match = url.pathname.match(/\/q\/([0-9a-f]{64})\/?$/i)
    return match?.[1]?.toLowerCase() ?? null
  } catch { return null }
}

export function QrCommandCenter({
  context,
  initialToken,
  onNavigate,
}: {
  context: AppUserContext
  initialToken?: string | null
  onNavigate: (route: QrRoute, target: QrResolved, action: QrAction) => void
}) {
  const [open,setOpen] = useState(Boolean(initialToken))
  const [tab,setTab] = useState<'scan'|'issue'>('scan')
  const [input,setInput] = useState(initialToken ?? '')
  const [resourceType,setResourceType] = useState('CUSTOMER')
  const [intent,setIntent] = useState<QrAction>('VIEW')
  const [reference,setReference] = useState('')
  const [expiry,setExpiry] = useState('')
  const [resolved,setResolved] = useState<QrResolved|null>(null)
  const [issued,setIssued] = useState<QrIssued|null>(null)
  const [image,setImage] = useState<string|null>(null)
  const [error,setError] = useState<string|null>(null)
  const [busy,setBusy] = useState(false)
  const [camera,setCamera] = useState(false)
  const videoRef = useRef<HTMLVideoElement|null>(null)
  const streamRef = useRef<MediaStream|null>(null)
  const scanTimerRef = useRef<number|null>(null)

  const stopCamera = useCallback(() => {
    if (scanTimerRef.current) window.clearTimeout(scanTimerRef.current)
    scanTimerRef.current = null
    streamRef.current?.getTracks().forEach((track) => track.stop())
    streamRef.current = null
    setCamera(false)
  },[])

  const resolveValue = useCallback(async (value: string) => {
    const token = parseToken(value)
    setResolved(null); setError(null)
    if (!token) { setError('QR không đúng định dạng HomeTechVN.'); return }
    setBusy(true)
    try {
      const { data,error: rpcError } = await supabase.rpc('qr_resolve',{ p_token:token })
      if (rpcError) throw rpcError
      const payload = data as QrResolved
      if (!payload?.found) setError('QR không tồn tại, đã hết hạn hoặc đã bị thu hồi.')
      else { setInput(token); setResolved(payload) }
    } catch (err) { setError(err instanceof Error ? err.message : 'Không đọc được QR.') }
    finally { setBusy(false) }
  },[])

  const startCamera = useCallback(async () => {
    setError(null)
    const DetectorClass = (window as unknown as { BarcodeDetector?: DetectorConstructor }).BarcodeDetector
    if (!DetectorClass) { setError('Trình duyệt này chưa hỗ trợ quét QR bằng camera. Hãy dùng Chrome/Edge mới hoặc dán nội dung QR.'); return }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video:{ facingMode:{ ideal:'environment' } },audio:false })
      streamRef.current = stream; setCamera(true)
      await new Promise<void>((resolve) => requestAnimationFrame(() => resolve()))
      if (!videoRef.current) return stopCamera()
      videoRef.current.srcObject = stream
      await videoRef.current.play()
      const detector = new DetectorClass({ formats:['qr_code'] })
      const tick = async () => {
        if (!videoRef.current || !streamRef.current) return
        try {
          const codes = await detector.detect(videoRef.current)
          const value = codes[0]?.rawValue
          if (value) { stopCamera(); await resolveValue(value); return }
        } catch { /* camera frame can be unavailable while warming up */ }
        scanTimerRef.current = window.setTimeout(() => void tick(),350)
      }
      await tick()
    } catch (err) { stopCamera(); setError(err instanceof Error ? err.message : 'Không mở được camera.') }
  },[resolveValue,stopCamera])

  useEffect(() => () => stopCamera(),[stopCamera])
  useEffect(() => { if (initialToken) void resolveValue(initialToken) },[initialToken,resolveValue])
  useEffect(() => { if (resourceType !== 'SALES_ORDER' && intent === 'PAY') setIntent('VIEW') }, [resourceType, intent])

  function close() { stopCamera(); setOpen(false); setError(null); setResolved(null) }

  async function issueCode(event: FormEvent) {
    event.preventDefault(); setError(null); setIssued(null); setImage(null); setBusy(true)
    try {
      const { data,error: rpcError } = await supabase.rpc('qr_issue',{
        p_resource_type:resourceType,
        p_reference:intent==='CREATE' ? null : reference.trim(),
        p_intent:intent,
        p_expires_at:expiry ? new Date(`${expiry}T23:59:59`).toISOString() : null,
      })
      if (rpcError) throw rpcError
      const payload = data as QrIssued
      const url = `${window.location.origin}/?qr=${payload.token}`
      const dataUrl = await QRCode.toDataURL(url,{ width:360,margin:2,errorCorrectionLevel:'M',color:{ dark:'#020617',light:'#ffffff' } })
      setIssued(payload); setImage(dataUrl)
    } catch (err) { setError(err instanceof Error ? err.message : 'Không tạo được QR.') }
    finally { setBusy(false) }
  }

  async function revoke() {
    const token = issued?.token ?? parseToken(input)
    if (!token) return
    setBusy(true); setError(null)
    try {
      const { data,error: rpcError } = await supabase.rpc('qr_revoke',{ p_token:token })
      if (rpcError) throw rpcError
      const result = data as { revoked?: boolean }
      if (!result.revoked) throw new Error('QR đã bị thu hồi hoặc không còn tồn tại.')
      setIssued(null); setImage(null); setResolved(null); setInput('')
    } catch (err) { setError(err instanceof Error ? err.message : 'Không thu hồi được QR.') }
    finally { setBusy(false) }
  }

  function download() {
    if (!image || !issued) return
    const link=document.createElement('a'); link.href=image; link.download=`QR-${issued.label}.png`; link.click()
  }

  const selected = resources.find(([value]) => value===resourceType)
  const canIssue = hasPermission(context,'qr.issue')
  const canRevoke = hasPermission(context,'qr.revoke')

  return <>
    <button type="button" onClick={() => setOpen(true)} className="fixed bottom-5 right-5 z-40 flex items-center gap-2 rounded-2xl bg-cyan-400 px-4 py-3 text-sm font-bold text-slate-950 shadow-2xl shadow-cyan-950/50 hover:bg-cyan-300" aria-label="Mở trung tâm QR">
      <span className="text-lg" aria-hidden="true">▦</span><span>Quét QR</span>
    </button>

    {open ? <div className="fixed inset-0 z-[90] grid place-items-center bg-slate-950/85 p-3 backdrop-blur-sm" onMouseDown={(event) => { if (event.target===event.currentTarget) close() }}>
      <section role="dialog" aria-modal="true" aria-labelledby="qr-title" className="max-h-[94vh] w-full max-w-2xl overflow-y-auto rounded-3xl border border-slate-700 bg-slate-900 shadow-2xl">
        <header className="flex items-start justify-between border-b border-slate-800 p-5">
          <div><div className="text-xs font-semibold uppercase tracking-[.22em] text-cyan-400">HomeTechVN QR</div><h2 id="qr-title" className="mt-1 text-xl font-bold text-white">Thao tác nhanh toàn hệ thống</h2><p className="mt-1 text-sm text-slate-400">QR mở đúng nghiệp vụ nhưng không thay thế quyền tài khoản.</p></div>
          <button type="button" onClick={close} className="rounded-xl border border-slate-700 px-3 py-2 text-slate-300" aria-label="Đóng">✕</button>
        </header>
        <div className="flex gap-2 border-b border-slate-800 px-5 pt-4">
          <button type="button" onClick={() => setTab('scan')} className={`rounded-t-xl px-4 py-2 text-sm ${tab==='scan'?'bg-cyan-950 text-cyan-300':'text-slate-400'}`}>Quét / mở</button>
          {canIssue ? <button type="button" onClick={() => setTab('issue')} className={`rounded-t-xl px-4 py-2 text-sm ${tab==='issue'?'bg-cyan-950 text-cyan-300':'text-slate-400'}`}>Tạo mã QR</button> : null}
        </div>

        <div className="space-y-4 p-5">
          {tab==='scan' ? <>
            <div className="flex flex-col gap-2 sm:flex-row"><input value={input} onChange={(event) => setInput(event.target.value)} placeholder="Dán link hoặc token QR HomeTechVN" className="min-w-0 flex-1 rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm outline-none focus:border-cyan-500"/><button disabled={busy} onClick={() => void resolveValue(input)} className="rounded-xl bg-cyan-500 px-4 py-3 text-sm font-semibold text-slate-950 disabled:opacity-50">{busy?'Đang đọc…':'Mở QR'}</button></div>
            {!camera ? <button type="button" onClick={() => void startCamera()} className="w-full rounded-xl border border-cyan-900 px-4 py-3 text-sm text-cyan-300">Mở camera quét mã</button> : <div className="overflow-hidden rounded-2xl border border-cyan-900 bg-black"><video ref={videoRef} muted playsInline className="aspect-video w-full object-cover"/><button type="button" onClick={stopCamera} className="w-full border-t border-slate-800 px-4 py-2 text-sm text-slate-300">Dừng camera</button></div>}
            {resolved?.found ? <div className="rounded-2xl border border-emerald-900 bg-emerald-950/20 p-4"><div className="text-xs uppercase tracking-wider text-emerald-400">Đã xác thực QR</div><div className="mt-1 font-mono text-lg font-semibold text-white">{resolved.label}</div><div className="mt-1 text-sm text-slate-400">{resolved.resource_type} · Ý định {resolved.intent}</div><div className="mt-4 flex flex-wrap gap-2">{resolved.allowed_actions?.map((action) => <button key={action} type="button" onClick={() => { if (resolved.route) onNavigate(resolved.route,resolved,action); close() }} className={action==='PAY'?'rounded-xl bg-emerald-500 px-4 py-2 text-sm font-semibold text-slate-950':'rounded-xl border border-slate-700 px-4 py-2 text-sm text-white'}>{actionLabels[action]}</button>)}</div>{canRevoke ? <button type="button" onClick={() => void revoke()} className="mt-4 text-xs text-red-300 hover:underline">Thu hồi mã này</button> : null}</div> : null}
          </> : null}

          {tab==='issue' && canIssue ? <form onSubmit={(event) => void issueCode(event)} className="space-y-4">
            <div className="grid gap-3 sm:grid-cols-2"><label className="grid gap-1.5 text-sm text-slate-300">Loại nghiệp vụ<select value={resourceType} onChange={(event) => setResourceType(event.target.value)} className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-3">{resources.map(([value,label]) => <option key={value} value={value}>{label}</option>)}</select></label><label className="grid gap-1.5 text-sm text-slate-300">Hành động<select value={intent} onChange={(event) => setIntent(event.target.value as QrAction)} className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-3"><option value="CREATE">Thêm mới</option><option value="VIEW">Xem</option><option value="EDIT">Sửa</option>{resourceType==='SALES_ORDER'?<option value="PAY">Thanh toán</option>:null}</select></label></div>
            {intent!=='CREATE' ? <label className="grid gap-1.5 text-sm text-slate-300">Mã nghiệp vụ hoặc UUID<input required value={reference} onChange={(event) => setReference(event.target.value)} placeholder={selected?.[2]} className="rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 outline-none focus:border-cyan-500"/></label> : <div className="rounded-xl border border-slate-800 bg-slate-950/50 p-3 text-sm text-slate-400">QR này sẽ mở thẳng luồng “{actionLabels[intent]} {selected?.[1]}”.</div>}
            <label className="grid gap-1.5 text-sm text-slate-300">Ngày hết hạn (không bắt buộc)<input type="date" value={expiry} onChange={(event) => setExpiry(event.target.value)} className="rounded-xl border border-slate-700 bg-slate-950 px-4 py-3"/></label>
            <button disabled={busy} className="w-full rounded-xl bg-cyan-500 px-4 py-3 font-semibold text-slate-950 disabled:opacity-50">{busy?'Đang tạo…':'Tạo QR an toàn'}</button>
            {issued && image ? <div className="rounded-2xl border border-cyan-900 bg-white p-4 text-center"><img src={image} alt={`QR ${issued.label}`} className="mx-auto w-full max-w-[300px]"/><div className="mt-2 font-mono text-sm font-semibold text-slate-900">{issued.label}</div><div className="mt-3 flex justify-center gap-2"><button type="button" onClick={download} className="rounded-xl bg-slate-900 px-4 py-2 text-sm text-white">Tải PNG</button>{canRevoke?<button type="button" onClick={() => void revoke()} className="rounded-xl border border-red-300 px-4 py-2 text-sm text-red-700">Thu hồi</button>:null}</div></div> : null}
          </form> : null}
          {error ? <div className="rounded-xl border border-red-900 bg-red-950/30 p-3 text-sm text-red-200">{error}</div> : null}
          <p className="text-xs leading-5 text-slate-500">Không nhập mật khẩu, khóa bản quyền, dữ liệu thẻ hoặc thông tin bí mật vào QR. Thanh toán QR chỉ mở đơn và form thu tiền; không tự xác nhận chuyển khoản ngân hàng.</p>
        </div>
      </section>
    </div> : null}
  </>
}
