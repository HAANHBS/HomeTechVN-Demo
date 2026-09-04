import { useCallback, useEffect, useState } from 'react'
import { supabase } from '../../lib/supabase'

type PublicClaim = {
  status: string
  received_at: string | null
  ready_at: string | null
  returned_at: string | null
  closed_at: string | null
}

type PublicWarrantyPayload = {
  found: boolean
  warranty_code?: string
  status?: 'ACTIVE' | 'EXPIRED' | 'VOID'
  start_date?: string
  end_date?: string
  days_remaining?: number | null
  coverage?: string
  product?: string | null
  serial_masked?: string | null
  phone_masked?: string | null
  latest_claim?: PublicClaim | null
}

function dateOnly(value: string | null | undefined) {
  if (!value) return '—'
  return new Date(`${value}T00:00:00`).toLocaleDateString('vi-VN')
}

function dateTime(value: string | null | undefined) {
  return value ? new Date(value).toLocaleString('vi-VN') : '—'
}

function statusClass(status: string | undefined) {
  if (status === 'ACTIVE') return 'border-emerald-800 bg-emerald-950/40 text-emerald-300'
  if (status === 'EXPIRED') return 'border-amber-800 bg-amber-950/40 text-amber-300'
  if (status === 'VOID') return 'border-red-900 bg-red-950/40 text-red-300'
  return 'border-slate-700 bg-slate-900 text-slate-300'
}

function statusLabel(status: string | undefined) {
  if (status === 'ACTIVE') return 'Còn hiệu lực'
  if (status === 'EXPIRED') return 'Đã hết hạn'
  if (status === 'VOID') return 'Không còn hiệu lực'
  return status ?? 'Không xác định'
}

function claimLabel(status: string | undefined) {
  const map: Record<string, string> = {
    RECEIVED: 'Đã tiếp nhận',
    CHECKING: 'Đang kiểm tra',
    APPROVED: 'Đã duyệt',
    REJECTED: 'Từ chối',
    IN_SERVICE: 'Đang xử lý',
    QC: 'Đang kiểm tra chất lượng',
    READY: 'Sẵn sàng trả khách',
    RETURNED: 'Đã trả khách',
    CLOSED: 'Đã đóng',
  }
  return status ? map[status] ?? status : 'Chưa có yêu cầu bảo hành'
}

export function PublicWarrantyPage({ token }: { token: string | null }) {
  const [payload, setPayload] = useState<PublicWarrantyPayload | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    setPayload(null)
    try {
      if (!token || !/^[0-9a-f]{64}$/.test(token)) {
        setPayload({ found: false })
        return
      }
      const { data, error: rpcError } = await supabase.rpc('warranty_public_lookup', { p_token: token })
      if (rpcError) throw rpcError
      setPayload((data ?? { found: false }) as PublicWarrantyPayload)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không thể tra cứu bảo hành lúc này.')
    } finally {
      setLoading(false)
    }
  }, [token])

  useEffect(() => {
    document.title = 'Tra cứu bảo hành · HomeTechVN'
    void load()
  }, [load])

  return <main className="min-h-screen bg-slate-950 px-3 py-6 text-slate-200 sm:px-6 sm:py-10">
    <div className="mx-auto w-full max-w-2xl space-y-4">
      <header className="rounded-3xl border border-slate-800 bg-slate-900/90 p-5 text-center shadow-sm sm:p-7">
        <div className="text-xs font-semibold uppercase tracking-[0.28em] text-cyan-400">HomeTechVN</div>
        <h1 className="mt-2 text-2xl font-bold text-white sm:text-3xl">Tra cứu bảo hành</h1>
        <p className="mx-auto mt-2 max-w-lg text-sm leading-6 text-slate-400">Quét QR trên tem bảo hành để kiểm tra hiệu lực và trạng thái xử lý gần nhất.</p>
      </header>

      {loading ? <section className="grid min-h-64 place-items-center rounded-3xl border border-slate-800 bg-slate-900 p-6">
        <div className="text-center"><div className="mx-auto h-10 w-10 animate-spin rounded-full border-4 border-slate-700 border-t-cyan-400"/><p className="mt-4 text-sm text-slate-400">Đang kiểm tra bảo hành…</p></div>
      </section> : null}

      {error ? <section className="rounded-3xl border border-red-900 bg-red-950/30 p-6 text-center">
        <h2 className="font-semibold text-red-300">Không thể tra cứu</h2>
        <p className="mt-2 text-sm leading-6 text-red-200/80">{error}</p>
        <button type="button" onClick={() => void load()} className="mt-4 rounded-xl border border-red-800 px-4 py-2 text-sm text-red-200">Thử lại</button>
      </section> : null}

      {!loading && !error && payload && !payload.found ? <section className="rounded-3xl border border-amber-900 bg-amber-950/20 p-6 text-center sm:p-8">
        <div className="text-4xl" aria-hidden="true">⌕</div>
        <h2 className="mt-3 text-lg font-semibold text-amber-300">Không tìm thấy bảo hành</h2>
        <p className="mt-2 text-sm leading-6 text-slate-400">QR không hợp lệ, đã hết hiệu lực tra cứu hoặc đường dẫn bị thay đổi. Vui lòng liên hệ cửa hàng và cung cấp mã trên hóa đơn/phiếu dịch vụ.</p>
      </section> : null}

      {!loading && !error && payload?.found ? <>
        <section className={`rounded-3xl border p-5 sm:p-7 ${statusClass(payload.status)}`}>
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div><div className="text-xs uppercase tracking-[0.18em] opacity-70">Mã bảo hành</div><div className="mt-1 font-mono text-xl font-bold text-white sm:text-2xl">{payload.warranty_code}</div></div>
            <div className="rounded-2xl border border-current/30 px-4 py-3 text-center"><div className="text-sm font-semibold">{statusLabel(payload.status)}</div>{payload.status === 'ACTIVE' && payload.days_remaining != null ? <div className="mt-1 text-xs opacity-80">Còn {payload.days_remaining} ngày</div> : null}</div>
          </div>
        </section>

        <section className="grid gap-3 sm:grid-cols-2">
          <article className="rounded-2xl border border-slate-800 bg-slate-900 p-4"><div className="text-xs text-slate-500">Bắt đầu</div><div className="mt-1 font-semibold text-white">{dateOnly(payload.start_date)}</div></article>
          <article className="rounded-2xl border border-slate-800 bg-slate-900 p-4"><div className="text-xs text-slate-500">Hết hạn</div><div className="mt-1 font-semibold text-white">{dateOnly(payload.end_date)}</div></article>
        </section>

        <section className="space-y-4 rounded-3xl border border-slate-800 bg-slate-900 p-5 sm:p-6">
          <div><div className="text-xs uppercase tracking-[0.14em] text-slate-500">Sản phẩm / thiết bị</div><div className="mt-1 text-base font-semibold text-white">{payload.product || '—'}</div></div>
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="rounded-xl bg-slate-950/70 p-3"><div className="text-xs text-slate-500">Serial đã ẩn</div><div className="mt-1 font-mono text-sm text-cyan-300">{payload.serial_masked || '—'}</div></div>
            <div className="rounded-xl bg-slate-950/70 p-3"><div className="text-xs text-slate-500">Điện thoại đã ẩn</div><div className="mt-1 font-mono text-sm text-cyan-300">{payload.phone_masked || '—'}</div></div>
          </div>
          <div><div className="text-xs uppercase tracking-[0.14em] text-slate-500">Phạm vi bảo hành</div><div className="mt-1 whitespace-pre-wrap text-sm leading-6 text-slate-300">{payload.coverage || '—'}</div></div>
        </section>

        <section className="rounded-3xl border border-slate-800 bg-slate-900 p-5 sm:p-6">
          <div className="text-xs uppercase tracking-[0.14em] text-slate-500">Yêu cầu bảo hành gần nhất</div>
          <div className="mt-2 text-lg font-semibold text-white">{claimLabel(payload.latest_claim?.status)}</div>
          {payload.latest_claim ? <div className="mt-3 grid gap-2 text-sm text-slate-400 sm:grid-cols-2"><div>Tiếp nhận: <span className="text-slate-300">{dateTime(payload.latest_claim.received_at)}</span></div><div>Sẵn sàng: <span className="text-slate-300">{dateTime(payload.latest_claim.ready_at)}</span></div><div>Đã trả: <span className="text-slate-300">{dateTime(payload.latest_claim.returned_at)}</span></div><div>Đóng: <span className="text-slate-300">{dateTime(payload.latest_claim.closed_at)}</span></div></div> : <p className="mt-2 text-sm text-slate-500">Chưa ghi nhận yêu cầu bảo hành nào.</p>}
        </section>
      </> : null}

      <footer className="px-2 text-center text-xs leading-5 text-slate-600">Trang công khai chỉ hiển thị dữ liệu tối thiểu. Số điện thoại và Serial đã được che để bảo vệ thông tin khách hàng.</footer>
    </div>
  </main>
}
