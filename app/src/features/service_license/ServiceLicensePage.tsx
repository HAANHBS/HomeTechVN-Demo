import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react'
import type {
  CustomerRow,
  DeviceRow,
  ServiceRow,
  ServiceScheduleSummaryRow,
  SoftwareLicenseSummaryRow,
  SoftwareProductRow,
} from '../../lib/database.types'
import { hasPermission, type AppUserContext } from '../../lib/permissions'
import { supabase } from '../../lib/supabase'
import { Modal } from '../crm/forms'
import type { QrAction, QrResolved } from '../qr/QrCommandCenter'

type Tab = 'schedules' | 'services' | 'licenses' | 'software'

function money(value: number | null | undefined) {
  return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND', maximumFractionDigits: 0 }).format(value ?? 0)
}

function date(value: string | null | undefined) {
  return value ? new Date(`${value}T00:00:00`).toLocaleDateString('vi-VN') : '—'
}

function dateTime(value: string | null | undefined) {
  return value ? new Date(value).toLocaleString('vi-VN') : '—'
}

function todayIso() {
  return new Date().toISOString().slice(0, 10)
}

function ErrorPanel({ message }: { message: string | null }) {
  if (!message) return null
  return <div className="rounded-xl border border-red-900 bg-red-950/30 p-4 text-sm text-red-200">{message}</div>
}

function statusClass(status: string | null | undefined) {
  if (status === 'ACTIVE') return 'bg-emerald-950 text-emerald-300'
  if (status === 'PAUSED' || status === 'SUSPENDED') return 'bg-amber-950 text-amber-300'
  if (status === 'COMPLETED') return 'bg-cyan-950 text-cyan-300'
  if (status === 'EXPIRED') return 'bg-slate-800 text-slate-300'
  if (status === 'CANCELLED') return 'bg-red-950 text-red-300'
  return 'bg-slate-800 text-slate-300'
}

function parseNumber(value: string, fallback = 0) {
  const n = Number(value)
  return Number.isFinite(n) ? n : fallback
}

function ServiceForm({
  initial,
  onCancel,
  onDone,
}: {
  initial?: ServiceRow
  onCancel: () => void
  onDone: () => void
}) {
  const [name, setName] = useState(initial?.name ?? '')
  const [category, setCategory] = useState(initial?.category ?? 'MAINTENANCE')
  const [description, setDescription] = useState(initial?.description ?? '')
  const [intervalCount, setIntervalCount] = useState(String(initial?.default_interval_count ?? 1))
  const [intervalUnit, setIntervalUnit] = useState(initial?.default_interval_unit ?? 'MONTHS')
  const [price, setPrice] = useState(String(initial?.default_price ?? 0))
  const [warrantyMonths, setWarrantyMonths] = useState(String(initial?.warranty_months ?? 0))
  const [isActive, setIsActive] = useState(initial?.is_active ?? true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)
    try {
      if (initial) {
        const { error: rpcError } = await supabase.rpc('service_update', {
          p_service_id: initial.id,
          p_name: name.trim(),
          p_category: category,
          p_description: description.trim(),
          p_interval_count: Math.max(1, Math.trunc(parseNumber(intervalCount, 1))),
          p_interval_unit: intervalUnit,
          p_default_price: Math.max(0, parseNumber(price)),
          p_warranty_months: Math.max(0, Math.trunc(parseNumber(warrantyMonths))),
          p_is_active: isActive,
        })
        if (rpcError) throw rpcError
      } else {
        const { error: rpcError } = await supabase.rpc('service_create', {
          p_name: name.trim(),
          p_category: category,
          p_description: description.trim() || undefined,
          p_interval_count: Math.max(1, Math.trunc(parseNumber(intervalCount, 1))),
          p_interval_unit: intervalUnit,
          p_default_price: Math.max(0, parseNumber(price)),
          p_warranty_months: Math.max(0, Math.trunc(parseNumber(warrantyMonths))),
        })
        if (rpcError) throw rpcError
      }
      onDone()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không lưu được dịch vụ.')
    } finally {
      setBusy(false)
    }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <label className="block text-sm font-medium">Tên dịch vụ
      <input required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={name} onChange={(e) => setName(e.target.value)} />
    </label>
    <div className="grid gap-4 sm:grid-cols-2">
      <label className="text-sm font-medium">Nhóm
        <select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={category} onChange={(e) => setCategory(e.target.value)}>
          <option value="MAINTENANCE">Bảo trì</option>
          <option value="SUBSCRIPTION">Thuê bao</option>
          <option value="MANAGED_SERVICE">Dịch vụ quản trị</option>
          <option value="OTHER">Khác</option>
        </select>
      </label>
      <label className="text-sm font-medium">Giá mặc định
        <input type="number" min="0" step="1000" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={price} onChange={(e) => setPrice(e.target.value)} />
      </label>
      <label className="text-sm font-medium">Chu kỳ
        <div className="mt-2 flex gap-2">
          <input type="number" min="1" className="w-24 rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={intervalCount} onChange={(e) => setIntervalCount(e.target.value)} />
          <select className="min-w-0 flex-1 rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={intervalUnit} onChange={(e) => setIntervalUnit(e.target.value)}>
            <option value="DAYS">Ngày</option>
            <option value="MONTHS">Tháng</option>
            <option value="YEARS">Năm</option>
          </select>
        </div>
      </label>
      <label className="text-sm font-medium">Bảo hành sau dịch vụ (tháng)
        <input type="number" min="0" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={warrantyMonths} onChange={(e) => setWarrantyMonths(e.target.value)} />
      </label>
    </div>
    <label className="block text-sm font-medium">Mô tả
      <textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={description} onChange={(e) => setDescription(e.target.value)} />
    </label>
    {initial ? <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} /> Đang hoạt động</label> : null}
    <ErrorPanel message={error} />
    <div className="flex justify-end gap-2">
      <button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button>
      <button disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-50">{busy ? 'Đang lưu…' : 'Lưu dịch vụ'}</button>
    </div>
  </form>
}

function ScheduleForm({
  services,
  customers,
  devices,
  onCancel,
  onDone,
}: {
  services: ServiceRow[]
  customers: CustomerRow[]
  devices: DeviceRow[]
  onCancel: () => void
  onDone: () => void
}) {
  const activeServices = services.filter((x) => x.is_active)
  const [serviceId, setServiceId] = useState(activeServices[0]?.id ?? '')
  const [customerId, setCustomerId] = useState(customers[0]?.id ?? '')
  const [deviceId, setDeviceId] = useState('')
  const service = useMemo(() => activeServices.find((x) => x.id === serviceId), [activeServices, serviceId])
  const customerDevices = useMemo(() => devices.filter((d) => d.customer_id === customerId && d.status === 'ACTIVE'), [devices, customerId])
  const [startDate, setStartDate] = useState(todayIso())
  const [nextDue, setNextDue] = useState(todayIso())
  const [endDate, setEndDate] = useState('')
  const [count, setCount] = useState('1')
  const [unit, setUnit] = useState('MONTHS')
  const [price, setPrice] = useState('0')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!service) return
    setCount(String(service.default_interval_count))
    setUnit(service.default_interval_unit)
    setPrice(String(service.default_price))
  }, [service?.id])

  useEffect(() => {
    if (!customerDevices.some((d) => d.id === deviceId)) setDeviceId('')
  }, [customerId, customerDevices, deviceId])

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)
    try {
      const { error: rpcError } = await supabase.rpc('service_schedule_create', {
        p_service_id: serviceId,
        p_customer_id: customerId,
        p_customer_device_id: deviceId || undefined,
        p_start_date: startDate,
        p_next_due_date: nextDue,
        p_interval_count: Math.max(1, Math.trunc(parseNumber(count, 1))),
        p_interval_unit: unit,
        p_price: Math.max(0, parseNumber(price)),
        p_end_date: endDate || undefined,
        p_note: note.trim() || undefined,
      })
      if (rpcError) throw rpcError
      onDone()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tạo được lịch dịch vụ.')
    } finally {
      setBusy(false)
    }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <label className="block text-sm font-medium">Dịch vụ
      <select required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={serviceId} onChange={(e) => setServiceId(e.target.value)}>
        {activeServices.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
      </select>
    </label>
    <label className="block text-sm font-medium">Khách hàng
      <select required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={customerId} onChange={(e) => setCustomerId(e.target.value)}>
        {customers.map((c) => <option key={c.id} value={c.id}>{c.customer_code} · {c.full_name}</option>)}
      </select>
    </label>
    <label className="block text-sm font-medium">Thiết bị (tùy chọn)
      <select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={deviceId} onChange={(e) => setDeviceId(e.target.value)}>
        <option value="">— Không gắn thiết bị —</option>
        {customerDevices.map((d) => <option key={d.id} value={d.id}>{d.device_code} · {d.device_type} {d.brand ?? ''} {d.model ?? ''}</option>)}
      </select>
    </label>
    <div className="grid gap-4 sm:grid-cols-3">
      <label className="text-sm font-medium">Ngày bắt đầu<input required type="date" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={startDate} onChange={(e) => setStartDate(e.target.value)} /></label>
      <label className="text-sm font-medium">Lần đến hạn đầu<input required type="date" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={nextDue} onChange={(e) => setNextDue(e.target.value)} /></label>
      <label className="text-sm font-medium">Ngày kết thúc<input type="date" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={endDate} onChange={(e) => setEndDate(e.target.value)} /></label>
    </div>
    <div className="grid gap-4 sm:grid-cols-3">
      <label className="text-sm font-medium">Số chu kỳ<input type="number" min="1" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={count} onChange={(e) => setCount(e.target.value)} /></label>
      <label className="text-sm font-medium">Đơn vị<select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={unit} onChange={(e) => setUnit(e.target.value)}><option value="DAYS">Ngày</option><option value="MONTHS">Tháng</option><option value="YEARS">Năm</option></select></label>
      <label className="text-sm font-medium">Giá<input type="number" min="0" step="1000" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={price} onChange={(e) => setPrice(e.target.value)} /></label>
    </div>
    <label className="block text-sm font-medium">Ghi chú<textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={note} onChange={(e) => setNote(e.target.value)} /></label>
    <ErrorPanel message={error} />
    <div className="flex justify-end gap-2">
      <button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button>
      <button disabled={busy || !serviceId || !customerId} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-50">{busy ? 'Đang tạo…' : 'Tạo lịch'}</button>
    </div>
  </form>
}

function SoftwareProductForm({
  initial,
  onCancel,
  onDone,
}: {
  initial?: SoftwareProductRow
  onCancel: () => void
  onDone: () => void
}) {
  const [category, setCategory] = useState(initial?.category ?? 'M365')
  const [vendor, setVendor] = useState(initial?.vendor ?? '')
  const [name, setName] = useState(initial?.name ?? '')
  const [edition, setEdition] = useState(initial?.edition ?? '')
  const [billing, setBilling] = useState(initial?.billing_model ?? 'SUBSCRIPTION')
  const [term, setTerm] = useState(String(initial?.default_term_months ?? 12))
  const [description, setDescription] = useState(initial?.description ?? '')
  const [active, setActive] = useState(initial?.is_active ?? true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)
    const termMonths = billing === 'SUBSCRIPTION' ? Math.max(1, Math.trunc(parseNumber(term, 12))) : (term.trim() ? Math.max(1, Math.trunc(parseNumber(term, 1))) : 0)
    try {
      if (initial) {
        const { error: rpcError } = await supabase.rpc('software_product_update', {
          p_product_id: initial.id,
          p_category: category,
          p_vendor: vendor.trim(),
          p_name: name.trim(),
          p_edition: edition.trim(),
          p_billing_model: billing,
          p_default_term_months: termMonths,
          p_description: description.trim(),
          p_is_active: active,
        })
        if (rpcError) throw rpcError
      } else {
        const args = {
          p_category: category,
          p_vendor: vendor.trim(),
          p_name: name.trim(),
          p_edition: edition.trim() || undefined,
          p_billing_model: billing,
          p_default_term_months: termMonths || undefined,
          p_description: description.trim() || undefined,
        }
        const { error: rpcError } = await supabase.rpc('software_product_create', args)
        if (rpcError) throw rpcError
      }
      onDone()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không lưu được sản phẩm phần mềm.')
    } finally {
      setBusy(false)
    }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <div className="grid gap-4 sm:grid-cols-2">
      <label className="text-sm font-medium">Nhóm<select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={category} onChange={(e) => setCategory(e.target.value)}>{['WINDOWS','OFFICE','M365','ANTIVIRUS','CAMERA_CLOUD','HOSTING','DOMAIN','BACKUP','ACCOUNTING','OTHER'].map((x) => <option key={x}>{x}</option>)}</select></label>
      <label className="text-sm font-medium">Nhà cung cấp<input className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={vendor} onChange={(e) => setVendor(e.target.value)} /></label>
      <label className="text-sm font-medium">Tên sản phẩm<input required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={name} onChange={(e) => setName(e.target.value)} /></label>
      <label className="text-sm font-medium">Edition<input className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={edition} onChange={(e) => setEdition(e.target.value)} /></label>
      <label className="text-sm font-medium">Mô hình<select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={billing} onChange={(e) => setBilling(e.target.value)}><option value="SUBSCRIPTION">Subscription</option><option value="ONE_TIME">One-time</option></select></label>
      <label className="text-sm font-medium">Thời hạn mặc định (tháng)<input type="number" min="1" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={term} onChange={(e) => setTerm(e.target.value)} /></label>
    </div>
    <label className="block text-sm font-medium">Mô tả<textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={description} onChange={(e) => setDescription(e.target.value)} /></label>
    {initial ? <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} /> Đang hoạt động</label> : null}
    <ErrorPanel message={error} />
    <div className="flex justify-end gap-2"><button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button><button disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950">{busy ? 'Đang lưu…' : 'Lưu sản phẩm'}</button></div>
  </form>
}

function LicenseForm({
  products,
  customers,
  devices,
  onCancel,
  onDone,
}: {
  products: SoftwareProductRow[]
  customers: CustomerRow[]
  devices: DeviceRow[]
  onCancel: () => void
  onDone: () => void
}) {
  const activeProducts = products.filter((x) => x.is_active)
  const [productId, setProductId] = useState(activeProducts[0]?.id ?? '')
  const [customerId, setCustomerId] = useState(customers[0]?.id ?? '')
  const [deviceId, setDeviceId] = useState('')
  const customerDevices = useMemo(() => devices.filter((d) => d.customer_id === customerId && d.status === 'ACTIVE'), [devices, customerId])
  const [startDate, setStartDate] = useState(todayIso())
  const [endDate, setEndDate] = useState('')
  const [seats, setSeats] = useState('1')
  const [account, setAccount] = useState('')
  const [secretRef, setSecretRef] = useState('')
  const [autoRenew, setAutoRenew] = useState(false)
  const [cost, setCost] = useState('0')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)
    try {
      const { error: rpcError } = await supabase.rpc('software_license_create', {
        p_software_product_id: productId,
        p_customer_id: customerId,
        p_customer_device_id: deviceId || undefined,
        p_start_date: startDate,
        p_end_date: endDate || undefined,
        p_seats: Math.max(1, Math.trunc(parseNumber(seats, 1))),
        p_account_identifier: account.trim() || undefined,
        p_secret_ref: secretRef.trim() || undefined,
        p_auto_renew: autoRenew,
        p_renewal_cost: Math.max(0, parseNumber(cost)),
        p_note: note.trim() || undefined,
      })
      if (rpcError) throw rpcError
      onDone()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tạo được License.')
    } finally {
      setBusy(false)
    }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <label className="block text-sm font-medium">Sản phẩm phần mềm<select required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={productId} onChange={(e) => setProductId(e.target.value)}>{activeProducts.map((p) => <option key={p.id} value={p.id}>{p.vendor ? `${p.vendor} · ` : ''}{p.name} {p.edition ?? ''}</option>)}</select></label>
    <label className="block text-sm font-medium">Khách hàng<select required className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={customerId} onChange={(e) => setCustomerId(e.target.value)}>{customers.map((c) => <option key={c.id} value={c.id}>{c.customer_code} · {c.full_name}</option>)}</select></label>
    <label className="block text-sm font-medium">Thiết bị<select className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={deviceId} onChange={(e) => setDeviceId(e.target.value)}><option value="">— Không gắn thiết bị —</option>{customerDevices.map((d) => <option key={d.id} value={d.id}>{d.device_code} · {d.device_type} {d.brand ?? ''} {d.model ?? ''}</option>)}</select></label>
    <div className="grid gap-4 sm:grid-cols-3">
      <label className="text-sm font-medium">Bắt đầu<input required type="date" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={startDate} onChange={(e) => setStartDate(e.target.value)} /></label>
      <label className="text-sm font-medium">Kết thúc<input type="date" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={endDate} onChange={(e) => setEndDate(e.target.value)} /></label>
      <label className="text-sm font-medium">Seats<input type="number" min="1" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={seats} onChange={(e) => setSeats(e.target.value)} /></label>
    </div>
    <label className="block text-sm font-medium">Tài khoản/identifier<input className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={account} onChange={(e) => setAccount(e.target.value)} placeholder="user@example.com" /></label>
    <label className="block text-sm font-medium">Secret reference URI
      <input className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 font-mono text-sm" value={secretRef} onChange={(e) => setSecretRef(e.target.value)} placeholder="vault://hometechvn/licenses/..." />
      <span className="mt-1 block text-xs text-amber-300">Không dán product key, license key hoặc mật khẩu vào đây. Chỉ lưu URI tham chiếu tới kho bí mật.</span>
    </label>
    <div className="grid gap-4 sm:grid-cols-2">
      <label className="text-sm font-medium">Chi phí gia hạn<input type="number" min="0" step="1000" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={cost} onChange={(e) => setCost(e.target.value)} /></label>
      <label className="mt-7 flex items-center gap-2 text-sm"><input type="checkbox" checked={autoRenew} onChange={(e) => setAutoRenew(e.target.checked)} /> Tự động gia hạn</label>
    </div>
    <label className="block text-sm font-medium">Ghi chú<textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={note} onChange={(e) => setNote(e.target.value)} /></label>
    <ErrorPanel message={error} />
    <div className="flex justify-end gap-2"><button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button><button disabled={busy || !productId || !customerId} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950">{busy ? 'Đang tạo…' : 'Tạo License'}</button></div>
  </form>
}

function ScheduleEditForm({
  row,
  onCancel,
  onDone,
}: {
  row: ServiceScheduleSummaryRow
  onCancel: () => void
  onDone: () => void
}) {
  const [nextDue, setNextDue] = useState(row.next_due_date ?? todayIso())
  const [count, setCount] = useState(String(row.interval_count ?? 1))
  const [unit, setUnit] = useState(row.interval_unit ?? 'MONTHS')
  const [price, setPrice] = useState(String(row.price ?? 0))
  const [endDate, setEndDate] = useState(row.end_date ?? '')
  const [note, setNote] = useState(row.note ?? '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!row.id) return
    setBusy(true)
    setError(null)
    try {
      const { error: rpcError } = await supabase.rpc('service_schedule_update', {
        p_schedule_id: row.id,
        p_next_due_date: nextDue,
        p_interval_count: Math.max(1, Math.trunc(parseNumber(count, 1))),
        p_interval_unit: unit,
        p_price: Math.max(0, parseNumber(price)),
        p_end_date: endDate || undefined,
        p_note: note.trim() || undefined,
      })
      if (rpcError) throw rpcError
      onDone()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không cập nhật được lịch dịch vụ.')
    } finally {
      setBusy(false)
    }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <div className="rounded-xl border border-slate-800 bg-slate-950/50 p-3 text-sm">
      <strong>{row.service_name}</strong> · {row.customer_name}
    </div>
    <div className="grid gap-4 sm:grid-cols-2">
      <label className="text-sm font-medium">Đến hạn tiếp theo<input required type="date" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={nextDue} onChange={(e) => setNextDue(e.target.value)} /></label>
      <label className="text-sm font-medium">Ngày kết thúc<input type="date" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={endDate} onChange={(e) => setEndDate(e.target.value)} /></label>
      <label className="text-sm font-medium">Chu kỳ<div className="mt-2 flex gap-2"><input type="number" min="1" className="w-24 rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={count} onChange={(e) => setCount(e.target.value)} /><select className="min-w-0 flex-1 rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={unit} onChange={(e) => setUnit(e.target.value)}><option value="DAYS">Ngày</option><option value="MONTHS">Tháng</option><option value="YEARS">Năm</option></select></div></label>
      <label className="text-sm font-medium">Giá<input type="number" min="0" step="1000" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={price} onChange={(e) => setPrice(e.target.value)} /></label>
    </div>
    <label className="block text-sm font-medium">Ghi chú<textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={note} onChange={(e) => setNote(e.target.value)} /></label>
    <ErrorPanel message={error} />
    <div className="flex justify-end gap-2"><button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button><button disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950">{busy ? 'Đang lưu…' : 'Lưu lịch'}</button></div>
  </form>
}

function LicenseEditForm({
  row,
  onCancel,
  onDone,
}: {
  row: SoftwareLicenseSummaryRow
  onCancel: () => void
  onDone: () => void
}) {
  const [seats, setSeats] = useState(String(row.seats ?? 1))
  const [account, setAccount] = useState(row.account_identifier ?? '')
  const [secretRef, setSecretRef] = useState(row.secret_ref ?? '')
  const [autoRenew, setAutoRenew] = useState(Boolean(row.auto_renew))
  const [cost, setCost] = useState(String(row.renewal_cost ?? 0))
  const [note, setNote] = useState(row.note ?? '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!row.id) return
    setBusy(true)
    setError(null)
    try {
      const { error: rpcError } = await supabase.rpc('software_license_update', {
        p_license_id: row.id,
        p_seats: Math.max(1, Math.trunc(parseNumber(seats, 1))),
        p_account_identifier: account.trim(),
        p_secret_ref: secretRef.trim(),
        p_auto_renew: autoRenew,
        p_renewal_cost: Math.max(0, parseNumber(cost)),
        p_note: note.trim() || undefined,
      })
      if (rpcError) throw rpcError
      onDone()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không cập nhật được License.')
    } finally {
      setBusy(false)
    }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <div className="rounded-xl border border-slate-800 bg-slate-950/50 p-3 text-sm">
      <strong className="font-mono text-cyan-300">{row.license_code}</strong> · {row.product_name} · {row.customer_name}
    </div>
    <div className="grid gap-4 sm:grid-cols-2">
      <label className="text-sm font-medium">Seats<input type="number" min="1" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={seats} onChange={(e) => setSeats(e.target.value)} /></label>
      <label className="text-sm font-medium">Chi phí gia hạn<input type="number" min="0" step="1000" className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={cost} onChange={(e) => setCost(e.target.value)} /></label>
    </div>
    <label className="block text-sm font-medium">Tài khoản/identifier<input className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={account} onChange={(e) => setAccount(e.target.value)} /></label>
    <label className="block text-sm font-medium">Secret reference URI
      <input className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 font-mono text-sm" value={secretRef} onChange={(e) => setSecretRef(e.target.value)} placeholder="vault://hometechvn/licenses/..." />
      <span className="mt-1 block text-xs text-amber-300">Không nhập key hoặc mật khẩu thật. Chỉ nhập URI tham chiếu tới kho bí mật.</span>
    </label>
    <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={autoRenew} onChange={(e) => setAutoRenew(e.target.checked)} /> Tự động gia hạn</label>
    <label className="block text-sm font-medium">Ghi chú<textarea className="mt-2 min-h-20 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={note} onChange={(e) => setNote(e.target.value)} /></label>
    <ErrorPanel message={error} />
    <div className="flex justify-end gap-2"><button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Đóng</button><button disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950">{busy ? 'Đang lưu…' : 'Lưu License'}</button></div>
  </form>
}

export function ServiceLicensePage({
  context,
  initialTarget,
  initialAction,
  onOpenCrm,
  onOpenWarranty,
}: {
  context: AppUserContext
  initialTarget?: QrResolved
  initialAction?: QrAction
  onOpenCrm?: () => void
  onOpenWarranty?: () => void
}) {
  const canViewService = hasPermission(context, 'service.view')
  const canManageService = hasPermission(context, 'service.manage')
  const canViewLicense = hasPermission(context, 'license.view')
  const canManageLicense = hasPermission(context, 'license.manage')
  const canManageWarranty = hasPermission(context, 'warranty.manage')

  const initialTab: Tab = initialTarget?.resource_type === 'SOFTWARE_LICENSE' ? 'licenses' : canViewService ? 'schedules' : 'licenses'
  const [tab, setTab] = useState<Tab>(initialTab)
  const [services, setServices] = useState<ServiceRow[]>([])
  const [schedules, setSchedules] = useState<ServiceScheduleSummaryRow[]>([])
  const [products, setProducts] = useState<SoftwareProductRow[]>([])
  const [licenses, setLicenses] = useState<SoftwareLicenseSummaryRow[]>([])
  const [customers, setCustomers] = useState<CustomerRow[]>([])
  const [devices, setDevices] = useState<DeviceRow[]>([])
  const [showService, setShowService] = useState(false)
  const [editingService, setEditingService] = useState<ServiceRow | null>(null)
  const [showSchedule, setShowSchedule] = useState(false)
  const [editingSchedule, setEditingSchedule] = useState<ServiceScheduleSummaryRow | null>(null)
  const [showProduct, setShowProduct] = useState(false)
  const [editingProduct, setEditingProduct] = useState<SoftwareProductRow | null>(null)
  const [showLicense, setShowLicense] = useState(false)
  const [editingLicense, setEditingLicense] = useState<SoftwareLicenseSummaryRow | null>(null)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setError(null)
    try {
      const tasks: PromiseLike<{ error: { message: string } | null; data: unknown }>[] = []
      if (canViewService) {
        tasks.push(supabase.from('services').select('*').order('name'))
        tasks.push(supabase.from('service_schedule_summary').select('*').order('next_due_date'))
      }
      if (canViewLicense) {
        tasks.push(supabase.from('software_products').select('*').order('name'))
        tasks.push(supabase.from('software_license_summary').select('*').order('end_date', { ascending: true, nullsFirst: false }))
      }
      if (canManageService || canManageLicense) {
        tasks.push(supabase.from('customers').select('*').eq('status', 'ACTIVE').order('full_name').limit(1000))
        tasks.push(supabase.from('customer_devices').select('*').eq('status', 'ACTIVE').order('device_code').limit(1500))
      }
      const results = await Promise.all(tasks)
      const firstError = results.find((x) => x.error)?.error
      if (firstError) throw new Error(firstError.message)

      let i = 0
      if (canViewService) {
        setServices(results[i++].data as ServiceRow[])
        setSchedules(results[i++].data as ServiceScheduleSummaryRow[])
      }
      if (canViewLicense) {
        setProducts(results[i++].data as SoftwareProductRow[])
        setLicenses(results[i++].data as SoftwareLicenseSummaryRow[])
      }
      if (canManageService || canManageLicense) {
        setCustomers(results[i++].data as CustomerRow[])
        setDevices(results[i++].data as DeviceRow[])
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tải được dữ liệu T8.')
    }
  }, [canManageLicense, canManageService, canViewLicense, canViewService])

  useEffect(() => { void load() }, [load])
  useEffect(() => {
    if (initialTarget?.resource_type === 'SERVICE_SCHEDULE') {
      setTab('schedules')
      if (initialAction === 'CREATE') setShowSchedule(true)
      if (initialAction === 'EDIT' && initialTarget.resource_id) {
        const row=schedules.find((item) => item.id === initialTarget.resource_id)
        if (row) setEditingSchedule(row)
      }
    } else if (initialTarget?.resource_type === 'SOFTWARE_LICENSE') {
      setTab('licenses')
      if (initialAction === 'CREATE') setShowLicense(true)
      if (initialAction === 'EDIT' && initialTarget.resource_id) {
        const row=licenses.find((item) => item.id === initialTarget.resource_id)
        if (row) setEditingLicense(row)
      }
    }
  }, [initialTarget, initialAction, schedules, licenses])

  async function scheduleStatus(id: string, status: 'ACTIVE' | 'PAUSED' | 'CANCELLED') {
    const note = status === 'CANCELLED' ? window.prompt('Lý do hủy lịch dịch vụ:') : undefined
    if (status === 'CANCELLED' && !note?.trim()) return
    const { error: rpcError } = await supabase.rpc('service_schedule_set_status', { p_schedule_id: id, p_status: status, p_note: note?.trim() || undefined })
    if (rpcError) setError(rpcError.message); else await load()
  }

  async function completeSchedule(id: string) {
    const note = window.prompt('Ghi chú lần thực hiện dịch vụ:') ?? ''
    const { error: rpcError } = await supabase.rpc('service_schedule_complete', { p_schedule_id: id, p_note: note.trim() || undefined })
    if (rpcError) setError(rpcError.message); else await load()
  }

  async function createServiceWarranty(row: ServiceScheduleSummaryRow) {
    const service = services.find((x) => x.id === row.service_id)
    const defaultMonths = service?.warranty_months ?? 0
    const raw = window.prompt('Số tháng bảo hành cho lần dịch vụ gần nhất:', String(defaultMonths || 3))
    if (!raw) return
    const months = Math.max(1, Math.trunc(parseNumber(raw, defaultMonths || 3)))
    const { error: rpcError } = await supabase.rpc('warranty_create_service', {
      p_schedule_id: row.id!,
      p_warranty_months: months,
      p_coverage: `Bảo hành dịch vụ: ${row.service_name ?? ''}`,
    })
    if (rpcError) setError(rpcError.message)
    else {
      window.alert('Đã tạo bảo hành cho lần dịch vụ gần nhất.')
      await load()
    }
  }

  async function renewLicense(row: SoftwareLicenseSummaryRow) {
    const raw = window.prompt('Gia hạn thêm bao nhiêu tháng?', '12')
    if (!raw || !row.id) return
    const months = Math.max(1, Math.trunc(parseNumber(raw, 12)))
    const { error: rpcError } = await supabase.rpc('software_license_renew', { p_license_id: row.id, p_term_months: months })
    if (rpcError) setError(rpcError.message); else await load()
  }

  async function licenseStatus(row: SoftwareLicenseSummaryRow, status: 'ACTIVE' | 'SUSPENDED' | 'EXPIRED' | 'CANCELLED') {
    if (!row.id) return
    const reason = status === 'CANCELLED' ? window.prompt('Lý do hủy License:') : undefined
    if (status === 'CANCELLED' && !reason?.trim()) return
    const { error: rpcError } = await supabase.rpc('software_license_set_status', { p_license_id: row.id, p_status: status, p_reason: reason?.trim() || undefined })
    if (rpcError) setError(rpcError.message); else await load()
  }

  if (!canViewService && !canViewLicense) {
    return <main className="grid min-h-screen place-items-center bg-slate-950 text-slate-200"><div className="rounded-2xl border border-amber-900 p-6">Vai trò hiện tại không có quyền Dịch vụ/License.</div></main>
  }

  return <main className="min-h-screen bg-slate-950 text-slate-200">
    <header className="border-b border-slate-800 bg-slate-900/90 px-4 py-4 sm:px-6">
      <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4">
        <div><div className="text-sm font-semibold uppercase tracking-[0.24em] text-cyan-400">HomeTechVN</div><h1 className="mt-1 text-xl font-bold text-white">Dịch vụ định kỳ & Software License</h1></div>
        <div className="flex flex-wrap items-center gap-2 text-sm">
          {onOpenCrm ? <button onClick={onOpenCrm} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">CRM</button> : null}
          {onOpenWarranty ? <button onClick={onOpenWarranty} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300">Bảo hành</button> : null}
          <div className="px-2 text-right"><div className="font-medium text-white">{context.fullName || context.email || 'Người dùng'}</div><div className="text-xs text-slate-500">{context.roleName} · {context.roleCode}</div></div>
          <button onClick={() => void supabase.auth.signOut()} className="rounded-xl border border-slate-700 px-3 py-2">Đăng xuất</button>
        </div>
      </div>
    </header>

    <div className="mx-auto max-w-7xl space-y-5 px-4 py-6 sm:px-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap gap-2">
          {canViewService ? <button onClick={() => setTab('schedules')} className={`rounded-xl px-4 py-2 text-sm ${tab === 'schedules' ? 'bg-cyan-500 font-semibold text-slate-950' : 'border border-slate-700'}`}>Lịch dịch vụ</button> : null}
          {canViewService ? <button onClick={() => setTab('services')} className={`rounded-xl px-4 py-2 text-sm ${tab === 'services' ? 'bg-cyan-500 font-semibold text-slate-950' : 'border border-slate-700'}`}>Danh mục dịch vụ</button> : null}
          {canViewLicense ? <button onClick={() => setTab('licenses')} className={`rounded-xl px-4 py-2 text-sm ${tab === 'licenses' ? 'bg-cyan-500 font-semibold text-slate-950' : 'border border-slate-700'}`}>License</button> : null}
          {canViewLicense ? <button onClick={() => setTab('software')} className={`rounded-xl px-4 py-2 text-sm ${tab === 'software' ? 'bg-cyan-500 font-semibold text-slate-950' : 'border border-slate-700'}`}>Sản phẩm phần mềm</button> : null}
        </div>
        <div className="flex gap-2">
          <button onClick={() => void load()} className="rounded-xl border border-slate-700 px-4 py-2 text-sm">Làm mới</button>
          {tab === 'schedules' && canManageService ? <button onClick={() => setShowSchedule(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ Lịch dịch vụ</button> : null}
          {tab === 'services' && canManageService ? <button onClick={() => setShowService(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ Dịch vụ</button> : null}
          {tab === 'licenses' && canManageLicense ? <button onClick={() => setShowLicense(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ License</button> : null}
          {tab === 'software' && canManageLicense ? <button onClick={() => setShowProduct(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ Sản phẩm</button> : null}
        </div>
      </div>

      {tab === 'schedules' && canViewService ? <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900">
        <div className="overflow-x-auto"><table className="w-full min-w-[1200px] text-left text-sm">
          <thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Dịch vụ</th><th className="px-4 py-3">Khách / Thiết bị</th><th className="px-4 py-3">Chu kỳ</th><th className="px-4 py-3">Đến hạn</th><th className="px-4 py-3">Đã làm</th><th className="px-4 py-3">Giá</th><th className="px-4 py-3">Trạng thái</th><th className="px-4 py-3 text-right">Thao tác</th></tr></thead>
          <tbody>{schedules.map((r) => r.id ? <tr key={r.id} className="border-t border-slate-800"><td className="px-4 py-3"><div className="font-medium text-white">{r.service_name}</div><div className="text-xs text-slate-500">{r.category}</div></td><td className="px-4 py-3"><div>{r.customer_name}</div><div className="text-xs text-slate-500">{r.customer_code} · {r.device_code ?? 'Không gắn thiết bị'}</div></td><td className="px-4 py-3">{r.interval_count} {r.interval_unit}</td><td className="px-4 py-3 font-medium text-amber-300">{date(r.next_due_date)}</td><td className="px-4 py-3">{r.completion_count ?? 0}<div className="text-xs text-slate-500">{dateTime(r.last_completed_at)}</div></td><td className="px-4 py-3">{money(r.price)}</td><td className="px-4 py-3"><span className={`rounded-lg px-2 py-1 text-xs ${statusClass(r.status)}`}>{r.status}</span></td><td className="px-4 py-3 text-right">{canManageService ? <div className="flex flex-wrap justify-end gap-1">{!['CANCELLED','COMPLETED'].includes(r.status ?? '') ? <button onClick={() => setEditingSchedule(r)} className="rounded-lg border border-slate-700 px-2 py-1 text-xs">Sửa</button> : null}{r.status === 'ACTIVE' ? <><button onClick={() => void completeSchedule(r.id!)} className="rounded-lg border border-emerald-800 px-2 py-1 text-xs text-emerald-300">Hoàn thành lần này</button><button onClick={() => void scheduleStatus(r.id!,'PAUSED')} className="rounded-lg border border-amber-800 px-2 py-1 text-xs text-amber-300">Tạm dừng</button></> : null}{r.status === 'PAUSED' ? <button onClick={() => void scheduleStatus(r.id!,'ACTIVE')} className="rounded-lg border border-emerald-800 px-2 py-1 text-xs text-emerald-300">Tiếp tục</button> : null}{r.last_completion_id && canManageWarranty ? <button onClick={() => void createServiceWarranty(r)} className="rounded-lg border border-cyan-800 px-2 py-1 text-xs text-cyan-300">Tạo BH</button> : null}{!['CANCELLED','COMPLETED'].includes(r.status ?? '') ? <button onClick={() => void scheduleStatus(r.id!,'CANCELLED')} className="rounded-lg border border-red-900 px-2 py-1 text-xs text-red-300">Hủy</button> : null}</div> : '—'}</td></tr> : null)}</tbody>
        </table></div>
        {schedules.length === 0 ? <p className="p-8 text-center text-slate-500">Chưa có lịch dịch vụ.</p> : null}
      </section> : null}

      {tab === 'services' && canViewService ? <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900">
        <div className="overflow-x-auto"><table className="w-full min-w-[760px] text-left text-sm"><thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Dịch vụ</th><th className="px-4 py-3">Chu kỳ</th><th className="px-4 py-3">Giá</th><th className="px-4 py-3">Bảo hành</th><th className="px-4 py-3">Trạng thái</th><th className="px-4 py-3 text-right">Sửa</th></tr></thead><tbody>{services.map((s) => <tr key={s.id} className="border-t border-slate-800"><td className="px-4 py-3"><div className="font-medium text-white">{s.name}</div><div className="text-xs text-slate-500">{s.category} · {s.description ?? ''}</div></td><td className="px-4 py-3">{s.default_interval_count} {s.default_interval_unit}</td><td className="px-4 py-3">{money(s.default_price)}</td><td className="px-4 py-3">{s.warranty_months} tháng</td><td className="px-4 py-3">{s.is_active ? <span className="text-emerald-300">ACTIVE</span> : <span className="text-slate-500">INACTIVE</span>}</td><td className="px-4 py-3 text-right">{canManageService ? <button onClick={() => setEditingService(s)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs">Sửa</button> : '—'}</td></tr>)}</tbody></table></div>
      </section> : null}

      {tab === 'licenses' && canViewLicense ? <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900">
        <div className="overflow-x-auto"><table className="w-full min-w-[1250px] text-left text-sm">
          <thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">License</th><th className="px-4 py-3">Sản phẩm</th><th className="px-4 py-3">Khách hàng</th><th className="px-4 py-3">Thời hạn</th><th className="px-4 py-3">Seats</th><th className="px-4 py-3">Secret ref</th><th className="px-4 py-3">Trạng thái</th><th className="px-4 py-3 text-right">Thao tác</th></tr></thead>
          <tbody>{licenses.map((l) => l.id ? <tr key={l.id} className="border-t border-slate-800"><td className="px-4 py-3"><div className="font-mono text-cyan-300">{l.license_code}</div><div className="text-xs text-slate-500">{l.account_identifier ?? '—'}</div></td><td className="px-4 py-3"><div>{l.vendor} {l.product_name}</div><div className="text-xs text-slate-500">{l.category} · {l.edition ?? ''}</div></td><td className="px-4 py-3">{l.customer_name}<div className="text-xs text-slate-500">{l.customer_code} · {l.device_code ?? '—'}</div></td><td className="px-4 py-3">{date(l.start_date)} → {date(l.end_date)}<div className="text-xs text-slate-500">Gia hạn: {money(l.renewal_cost)}</div></td><td className="px-4 py-3">{l.seats}</td><td className="max-w-56 truncate px-4 py-3 font-mono text-xs text-slate-400" title={l.secret_ref ?? ''}>{l.secret_ref ?? '—'}</td><td className="px-4 py-3"><span className={`rounded-lg px-2 py-1 text-xs ${statusClass(l.status)}`}>{l.status}</span></td><td className="px-4 py-3 text-right">{canManageLicense ? <div className="flex flex-wrap justify-end gap-1">{l.status !== 'CANCELLED' ? <button onClick={() => setEditingLicense(l)} className="rounded-lg border border-slate-700 px-2 py-1 text-xs">Sửa</button> : null}{l.status !== 'CANCELLED' ? <button onClick={() => void renewLicense(l)} className="rounded-lg border border-cyan-800 px-2 py-1 text-xs text-cyan-300">Gia hạn</button> : null}{l.status === 'ACTIVE' ? <button onClick={() => void licenseStatus(l,'SUSPENDED')} className="rounded-lg border border-amber-800 px-2 py-1 text-xs text-amber-300">Suspend</button> : null}{l.status === 'SUSPENDED' || l.status === 'EXPIRED' ? <button onClick={() => void licenseStatus(l,'ACTIVE')} className="rounded-lg border border-emerald-800 px-2 py-1 text-xs text-emerald-300">Activate</button> : null}{l.status !== 'CANCELLED' ? <button onClick={() => void licenseStatus(l,'CANCELLED')} className="rounded-lg border border-red-900 px-2 py-1 text-xs text-red-300">Hủy</button> : null}</div> : '—'}</td></tr> : null)}</tbody>
        </table></div>
        {licenses.length === 0 ? <p className="p-8 text-center text-slate-500">Chưa có License.</p> : null}
      </section> : null}

      {tab === 'software' && canViewLicense ? <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900">
        <div className="overflow-x-auto"><table className="w-full min-w-[900px] text-left text-sm"><thead className="bg-slate-950/60 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Sản phẩm</th><th className="px-4 py-3">Nhóm</th><th className="px-4 py-3">Billing</th><th className="px-4 py-3">Term</th><th className="px-4 py-3">Trạng thái</th><th className="px-4 py-3 text-right">Sửa</th></tr></thead><tbody>{products.map((p) => <tr key={p.id} className="border-t border-slate-800"><td className="px-4 py-3"><div className="font-medium text-white">{p.vendor ? `${p.vendor} · ` : ''}{p.name}</div><div className="text-xs text-slate-500">{p.edition ?? ''} · {p.description ?? ''}</div></td><td className="px-4 py-3">{p.category}</td><td className="px-4 py-3">{p.billing_model}</td><td className="px-4 py-3">{p.default_term_months ? `${p.default_term_months} tháng` : '—'}</td><td className="px-4 py-3">{p.is_active ? <span className="text-emerald-300">ACTIVE</span> : <span className="text-slate-500">INACTIVE</span>}</td><td className="px-4 py-3 text-right">{canManageLicense ? <button onClick={() => setEditingProduct(p)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs">Sửa</button> : '—'}</td></tr>)}</tbody></table></div>
      </section> : null}

      <ErrorPanel message={error} />
    </div>

    {showService ? <Modal title="Tạo dịch vụ" onClose={() => setShowService(false)}><ServiceForm onCancel={() => setShowService(false)} onDone={() => { setShowService(false); void load() }} /></Modal> : null}
    {editingService ? <Modal title="Sửa dịch vụ" onClose={() => setEditingService(null)}><ServiceForm initial={editingService} onCancel={() => setEditingService(null)} onDone={() => { setEditingService(null); void load() }} /></Modal> : null}
    {showSchedule ? <Modal title="Tạo lịch dịch vụ" onClose={() => setShowSchedule(false)}><ScheduleForm services={services} customers={customers} devices={devices} onCancel={() => setShowSchedule(false)} onDone={() => { setShowSchedule(false); void load() }} /></Modal> : null}
    {editingSchedule ? <Modal title="Sửa lịch dịch vụ" onClose={() => setEditingSchedule(null)}><ScheduleEditForm row={editingSchedule} onCancel={() => setEditingSchedule(null)} onDone={() => { setEditingSchedule(null); void load() }} /></Modal> : null}
    {showProduct ? <Modal title="Tạo sản phẩm phần mềm" onClose={() => setShowProduct(false)}><SoftwareProductForm onCancel={() => setShowProduct(false)} onDone={() => { setShowProduct(false); void load() }} /></Modal> : null}
    {editingProduct ? <Modal title="Sửa sản phẩm phần mềm" onClose={() => setEditingProduct(null)}><SoftwareProductForm initial={editingProduct} onCancel={() => setEditingProduct(null)} onDone={() => { setEditingProduct(null); void load() }} /></Modal> : null}
    {showLicense ? <Modal title="Tạo License" onClose={() => setShowLicense(false)}><LicenseForm products={products} customers={customers} devices={devices} onCancel={() => setShowLicense(false)} onDone={() => { setShowLicense(false); void load() }} /></Modal> : null}
    {editingLicense ? <Modal title="Sửa License" onClose={() => setEditingLicense(null)}><LicenseEditForm row={editingLicense} onCancel={() => setEditingLicense(null)} onDone={() => { setEditingLicense(null); void load() }} /></Modal> : null}
  </main>
}
