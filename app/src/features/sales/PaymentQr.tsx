import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { supabase } from '../../lib/supabase'

type PaymentQrConfig = {
  enabled: boolean
  bank_id: string
  account_no: string
  account_name: string
  template: 'compact2'
  provider: 'VIETQR'
}

const emptyConfig: PaymentQrConfig = {
  enabled: false,
  bank_id: '',
  account_no: '',
  account_name: '',
  template: 'compact2',
  provider: 'VIETQR',
}

function parseConfig(value: unknown): PaymentQrConfig {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return emptyConfig
  const row = value as Record<string, unknown>
  return {
    enabled: row.enabled === true,
    bank_id: String(row.bank_id ?? '').trim().toUpperCase(),
    account_no: String(row.account_no ?? '').trim().toUpperCase(),
    account_name: String(row.account_name ?? '').trim(),
    template: 'compact2',
    provider: 'VIETQR',
  }
}

function money(value: number) {
  return new Intl.NumberFormat('vi-VN', {
    style: 'currency',
    currency: 'VND',
    maximumFractionDigits: 0,
  }).format(value)
}

export function PaymentQr({
  amount,
  orderCode,
  canManageSettings,
}: {
  amount: number
  orderCode: string
  canManageSettings: boolean
}) {
  const [config,setConfig] = useState<PaymentQrConfig | null>(null)
  const [enabled,setEnabled] = useState(true)
  const [bankId,setBankId] = useState('')
  const [accountNo,setAccountNo] = useState('')
  const [accountName,setAccountName] = useState('')
  const [editing,setEditing] = useState(false)
  const [loading,setLoading] = useState(true)
  const [saving,setSaving] = useState(false)
  const [imageError,setImageError] = useState(false)
  const [error,setError] = useState<string | null>(null)
  const transferContent = useMemo(() => `HTVN ${orderCode}`.replace(/[^A-Za-z0-9 ._-]/g,' ').slice(0,50),[orderCode])

  useEffect(() => {
    let cancelled = false
    async function load() {
      setLoading(true); setError(null)
      const { data,error: rpcError } = await supabase.rpc('payment_qr_config_get')
      if (cancelled) return
      if (rpcError) setError(rpcError.message)
      else {
        const next = parseConfig(data)
        setConfig(next)
        setEnabled(next.enabled)
        setBankId(next.bank_id)
        setAccountNo(next.account_no)
        setAccountName(next.account_name)
        setEditing(canManageSettings && !next.enabled)
      }
      setLoading(false)
    }
    void load()
    return () => { cancelled = true }
  },[canManageSettings])

  const roundedAmount = Math.round(amount)
  const qrUrl = useMemo(() => {
    if (!config?.enabled || roundedAmount <= 0 || !config.bank_id || !config.account_no || !config.account_name) return null
    const base = `https://img.vietqr.io/image/${encodeURIComponent(config.bank_id)}-${encodeURIComponent(config.account_no)}-compact2.png`
    const query = new URLSearchParams({
      amount:String(roundedAmount),
      addInfo:transferContent,
      accountName:config.account_name,
    })
    return `${base}?${query.toString()}`
  },[config,roundedAmount,transferContent])

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setSaving(true); setError(null)
    try {
      const { data,error: rpcError } = await supabase.rpc('payment_qr_configure',{
        p_enabled:enabled,
        p_bank_id:bankId.trim().toUpperCase(),
        p_account_no:accountNo.trim().toUpperCase(),
        p_account_name:accountName.trim(),
      })
      if (rpcError) throw rpcError
      const next = parseConfig(data)
      setConfig(next)
      setEnabled(next.enabled)
      setBankId(next.bank_id)
      setAccountNo(next.account_no)
      setAccountName(next.account_name)
      setEditing(false)
      setImageError(false)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không lưu được cấu hình QR thanh toán.')
    } finally { setSaving(false) }
  }

  async function copyContent() {
    try { await navigator.clipboard.writeText(transferContent) }
    catch { setError('Không sao chép được nội dung chuyển khoản trên trình duyệt này.') }
  }

  if (loading) return <div className="rounded-xl border border-slate-800 bg-slate-950/60 p-4 text-sm text-slate-400">Đang tạo QR theo số tiền còn phải thu…</div>

  return <section className="space-y-4 rounded-2xl border border-cyan-900 bg-cyan-950/10 p-4">
    <div className="flex flex-wrap items-start justify-between gap-3">
      <div><div className="text-xs font-semibold uppercase tracking-[.18em] text-cyan-400">QR chuyển khoản</div><h3 className="mt-1 font-semibold text-white">Khách quét đúng số tiền {money(roundedAmount)}</h3></div>
      {canManageSettings && !editing ? <button type="button" onClick={() => setEditing(true)} className="rounded-xl border border-slate-700 px-3 py-2 text-xs text-slate-300">Cấu hình tài khoản nhận</button> : null}
    </div>

    {editing && canManageSettings ? <form onSubmit={save} className="space-y-3 rounded-xl border border-slate-700 bg-slate-950/70 p-4">
      <label className="flex items-center gap-2 text-sm font-medium"><input type="checkbox" checked={enabled} onChange={(event) => setEnabled(event.target.checked)}/> Kích hoạt QR thanh toán</label>
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="text-sm">Mã ngân hàng
          <input required={enabled} pattern="[A-Za-z0-9]{2,12}" placeholder="VD: MB, VCB, BIDV" className="mt-1.5 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 uppercase" value={bankId} onChange={(event) => setBankId(event.target.value.toUpperCase())}/>
        </label>
        <label className="text-sm">Số tài khoản
          <input required={enabled} pattern="[A-Za-z0-9]{4,24}" inputMode="numeric" autoComplete="off" className="mt-1.5 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={accountNo} onChange={(event) => setAccountNo(event.target.value.replace(/\s/g,''))}/>
        </label>
      </div>
      <label className="block text-sm">Tên người nhận
        <input required={enabled} minLength={2} maxLength={100} autoComplete="off" className="mt-1.5 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 uppercase" value={accountName} onChange={(event) => setAccountName(event.target.value)}/>
      </label>
      <p className="text-xs text-slate-500">Đây là thông tin nhận tiền, không nhập mật khẩu, OTP, mã PIN hoặc khóa bí mật.</p>
      <div className="flex justify-end gap-2"><button type="button" onClick={() => setEditing(false)} className="rounded-xl border border-slate-700 px-3 py-2 text-sm">Đóng</button><button disabled={saving} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950 disabled:opacity-50">{saving?'Đang lưu…':'Lưu cấu hình'}</button></div>
    </form> : null}

    {!editing && qrUrl ? <div className="grid items-center gap-4 sm:grid-cols-[minmax(0,280px)_1fr]">
      <div className="rounded-2xl bg-white p-3">
        {!imageError ? <img key={qrUrl} src={qrUrl} referrerPolicy="no-referrer" onError={() => setImageError(true)} alt={`QR chuyển khoản ${money(roundedAmount)} cho đơn ${orderCode}`} className="mx-auto aspect-square w-full object-contain"/> : <div className="grid aspect-square place-items-center p-4 text-center text-sm text-red-700">Không tải được ảnh VietQR. Hãy kiểm tra Internet hoặc mã ngân hàng.</div>}
      </div>
      <div className="space-y-2 text-sm">
        <div><span className="text-slate-500">Ngân hàng:</span> <strong className="text-white">{config?.bank_id}</strong></div>
        <div><span className="text-slate-500">Số tài khoản:</span> <strong className="font-mono text-white">{config?.account_no}</strong></div>
        <div><span className="text-slate-500">Người nhận:</span> <strong className="text-white">{config?.account_name}</strong></div>
        <div><span className="text-slate-500">Số tiền:</span> <strong className="text-amber-300">{money(roundedAmount)}</strong></div>
        <div><span className="text-slate-500">Nội dung:</span> <strong className="font-mono text-cyan-300">{transferContent}</strong></div>
        <div className="flex flex-wrap gap-2 pt-2"><button type="button" onClick={() => void copyContent()} className="rounded-xl border border-cyan-900 px-3 py-2 text-xs text-cyan-300">Sao chép nội dung</button><a href={qrUrl} target="_blank" rel="noreferrer" className="rounded-xl border border-slate-700 px-3 py-2 text-xs text-slate-300">Mở / tải ảnh QR</a></div>
      </div>
    </div> : null}

    {!editing && !qrUrl ? <div className="rounded-xl border border-amber-900 bg-amber-950/20 p-3 text-sm text-amber-200">{canManageSettings?'Hãy cấu hình và kích hoạt tài khoản nhận tiền để tạo QR.':'QR thanh toán chưa được Admin cấu hình.'}</div> : null}
    {error ? <div role="alert" className="rounded-xl border border-red-900 bg-red-950/30 p-3 text-sm text-red-200">{error}</div> : null}
    <p className="text-xs leading-5 text-amber-200">QR chỉ điền sẵn yêu cầu chuyển khoản. Chỉ xác nhận thu tiền sau khi đã kiểm tra tiền thực sự vào tài khoản.</p>
  </section>
}
