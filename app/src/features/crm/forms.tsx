import { useEffect, useMemo, useState } from 'react'
import type { FormEvent, ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { supabase } from '../../lib/supabase'
import type {
  CustomerRow,
  DeviceRow,
  NoteRow,
} from '../../lib/database.types'

const inputClass =
  'mt-1 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none focus:border-cyan-500'
const labelClass = 'block text-sm font-medium text-slate-300'

function toNullable(value: string): string | null {
  const trimmed = value.trim()
  return trimmed === '' ? null : trimmed
}

export function Modal({
  title,
  onClose,
  children,
}: {
  title: string
  onClose: () => void
  children: ReactNode
}) {
  const content = (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/70 p-4 sm:p-8">
      <section
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onSubmit={(event) => event.stopPropagation()}
        className="w-full max-w-3xl rounded-2xl border border-slate-700 bg-slate-900 shadow-2xl"
      >
        <header className="flex items-center justify-between border-b border-slate-800 px-5 py-4">
          <h2 className="font-semibold text-slate-100">{title}</h2>
          <button
            type="button"
            className="rounded-lg px-3 py-1 text-slate-400 hover:bg-slate-800 hover:text-white"
            onClick={onClose}
          >
            Đóng
          </button>
        </header>
        <div className="p-5">{children}</div>
      </section>
    </div>
  )

  return typeof document === 'undefined' ? content : createPortal(content, document.body)
}

export function CustomerForm({
  initial,
  onSaved,
  onCancel,
}: {
  initial?: CustomerRow | null
  onSaved: (customer: CustomerRow) => void
  onCancel: () => void
}) {
  const [fullName, setFullName] = useState(initial?.full_name ?? '')
  const [customerType, setCustomerType] = useState(initial?.customer_type ?? 'INDIVIDUAL')
  const [phone, setPhone] = useState(initial?.phone ?? '')
  const [email, setEmail] = useState(initial?.email ?? '')
  const [zalo, setZalo] = useState(initial?.zalo ?? '')
  const [zaloSameAsPhone, setZaloSameAsPhone] = useState(Boolean(initial?.phone && initial.phone === initial.zalo))
  const [address, setAddress] = useState(initial?.address ?? '')
  const [taxCode, setTaxCode] = useState(initial?.tax_code ?? '')
  const [birthday, setBirthday] = useState(initial?.birthday ?? '')
  const [status, setStatus] = useState(initial?.status ?? 'ACTIVE')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)

    const payload = {
      full_name: fullName.trim(),
      customer_type: customerType,
      phone: toNullable(phone),
      email: toNullable(email),
      zalo: toNullable(zaloSameAsPhone ? phone : zalo),
      address: toNullable(address),
      tax_code: toNullable(taxCode),
      birthday: toNullable(birthday),
      status,
    }

    try {
      if (initial) {
        const { data, error: updateError } = await supabase
          .from('customers')
          .update(payload)
          .eq('id', initial.id)
          .select('*')
          .single()
        if (updateError) throw updateError
        onSaved(data)
      } else {
        const { data, error: insertError } = await supabase
          .from('customers')
          .insert(payload)
          .select('*')
          .single()
        if (insertError) throw insertError
        onSaved(data)
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không lưu được khách hàng.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className="space-y-4" onSubmit={handleSubmit}>
      <div className="grid gap-4 md:grid-cols-2">
        <label className={labelClass}>
          Họ tên / Tên đơn vị *
          <input className={inputClass} value={fullName} onChange={(e) => setFullName(e.target.value)} required />
        </label>
        <label className={labelClass}>
          Loại khách
          <select className={inputClass} value={customerType} onChange={(e) => setCustomerType(e.target.value)}>
            <option value="INDIVIDUAL">Cá nhân</option>
            <option value="BUSINESS">Doanh nghiệp</option>
          </select>
        </label>
        <label className={labelClass}>
          Điện thoại
          <input className={inputClass} value={phone} onChange={(e) => {
            setPhone(e.target.value)
            if (zaloSameAsPhone) setZalo(e.target.value)
          }} />
        </label>
        <label className={labelClass}>
          Email
          <input className={inputClass} type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label className={labelClass}>
          Zalo
          <input className={inputClass} value={zaloSameAsPhone ? phone : zalo} disabled={zaloSameAsPhone} onChange={(e) => setZalo(e.target.value)} />
        </label>
        <label className="flex items-center gap-2 text-sm text-slate-300 md:col-span-2">
          <input
            type="checkbox"
            checked={zaloSameAsPhone}
            onChange={(event) => {
              setZaloSameAsPhone(event.target.checked)
              if (event.target.checked) setZalo(phone)
            }}
          />
          Số Zalo giống số điện thoại
        </label>
        <label className={labelClass}>
          Mã số thuế
          <input className={inputClass} value={taxCode} onChange={(e) => setTaxCode(e.target.value)} />
        </label>
        <label className={labelClass}>
          Ngày sinh
          <input className={inputClass} type="date" value={birthday} onChange={(e) => setBirthday(e.target.value)} />
        </label>
        <label className={labelClass}>
          Trạng thái
          <select className={inputClass} value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="ACTIVE">Đang hoạt động</option>
            <option value="INACTIVE">Ngừng hoạt động</option>
          </select>
        </label>
      </div>
      <label className={labelClass}>
        Địa chỉ
        <textarea className={inputClass} rows={3} value={address} onChange={(e) => setAddress(e.target.value)} />
      </label>
      <div className="flex justify-end gap-3">
        <button type="button" className="rounded-xl border border-slate-700 px-4 py-2" onClick={onCancel}>
          Hủy
        </button>
        <button type="submit" disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-60">
          {busy ? 'Đang lưu…' : initial ? 'Cập nhật' : 'Tạo khách hàng'}
        </button>
      </div>
      {error ? <p role="alert" aria-live="assertive" className="rounded-xl bg-red-950/50 px-3 py-2 text-sm text-red-200">{error}</p> : null}
    </form>
  )
}

export function DeviceForm({
  customerId,
  deviceTypes,
  initial,
  onSaved,
  onCancel,
}: {
  customerId: string
  deviceTypes: string[]
  initial?: DeviceRow | null
  onSaved: (device: DeviceRow) => void
  onCancel: () => void
}) {
  const [deviceType, setDeviceType] = useState(initial?.device_type ?? deviceTypes[0] ?? 'Other')
  const [brand, setBrand] = useState(initial?.brand ?? '')
  const [model, setModel] = useState(initial?.model ?? '')
  const [serial, setSerial] = useState(initial?.serial_number ?? '')
  const [assetTag, setAssetTag] = useState(initial?.asset_tag ?? '')
  const [color, setColor] = useState(initial?.color ?? '')
  const [conditionNotes, setConditionNotes] = useState(initial?.condition_notes ?? '')
  const [purchaseDate, setPurchaseDate] = useState(initial?.purchase_date ?? '')
  const [status, setStatus] = useState(initial?.status ?? 'ACTIVE')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!initial && deviceTypes.length > 0 && !deviceTypes.includes(deviceType)) {
      setDeviceType(deviceTypes[0])
    }
  }, [deviceTypes, deviceType, initial])

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)

    const payload = {
      customer_id: customerId,
      device_type: deviceType,
      brand: toNullable(brand),
      model: toNullable(model),
      serial_number: toNullable(serial),
      asset_tag: toNullable(assetTag),
      color: toNullable(color),
      condition_notes: toNullable(conditionNotes),
      purchase_date: toNullable(purchaseDate),
      status,
    }

    try {
      if (initial) {
        const { data, error: updateError } = await supabase
          .from('customer_devices')
          .update(payload)
          .eq('id', initial.id)
          .select('*')
          .single()
        if (updateError) throw updateError
        onSaved(data)
      } else {
        const { data, error: insertError } = await supabase
          .from('customer_devices')
          .insert(payload)
          .select('*')
          .single()
        if (insertError) throw insertError
        onSaved(data)
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không lưu được thiết bị.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className="space-y-4" onSubmit={handleSubmit}>
      <div className="grid gap-4 md:grid-cols-2">
        <label className={labelClass}>
          Loại thiết bị *
          <select className={inputClass} value={deviceType} onChange={(e) => setDeviceType(e.target.value)} required>
            {deviceTypes.map((type) => (
              <option key={type} value={type}>{type}</option>
            ))}
          </select>
        </label>
        <label className={labelClass}>
          Hãng
          <input className={inputClass} value={brand} onChange={(e) => setBrand(e.target.value)} />
        </label>
        <label className={labelClass}>
          Model
          <input className={inputClass} value={model} onChange={(e) => setModel(e.target.value)} />
        </label>
        <label className={labelClass}>
          Serial
          <input className={inputClass} value={serial} onChange={(e) => setSerial(e.target.value)} />
        </label>
        <label className={labelClass}>
          Asset tag
          <input className={inputClass} value={assetTag} onChange={(e) => setAssetTag(e.target.value)} />
        </label>
        <label className={labelClass}>
          Màu
          <input className={inputClass} value={color} onChange={(e) => setColor(e.target.value)} />
        </label>
        <label className={labelClass}>
          Ngày mua
          <input className={inputClass} type="date" value={purchaseDate} onChange={(e) => setPurchaseDate(e.target.value)} />
        </label>
        <label className={labelClass}>
          Trạng thái
          <select className={inputClass} value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="ACTIVE">Đang sử dụng</option>
            <option value="INACTIVE">Ngừng sử dụng</option>
          </select>
        </label>
      </div>
      <label className={labelClass}>
        Tình trạng / Ghi chú thiết bị
        <textarea className={inputClass} rows={3} value={conditionNotes} onChange={(e) => setConditionNotes(e.target.value)} />
      </label>
      <div className="flex justify-end gap-3">
        <button type="button" className="rounded-xl border border-slate-700 px-4 py-2" onClick={onCancel}>Hủy</button>
        <button type="submit" disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-60">
          {busy ? 'Đang lưu…' : initial ? 'Cập nhật thiết bị' : 'Thêm thiết bị'}
        </button>
      </div>
      {error ? <p role="alert" aria-live="assertive" className="rounded-xl bg-red-950/50 px-3 py-2 text-sm text-red-200">{error}</p> : null}
    </form>
  )
}

export function NoteForm({
  customerId,
  initial,
  onSaved,
  onCancel,
}: {
  customerId: string
  initial?: NoteRow | null
  onSaved: (note: NoteRow) => void
  onCancel: () => void
}) {
  const [noteType, setNoteType] = useState(initial?.note_type ?? 'GENERAL')
  const [content, setContent] = useState(initial?.content ?? '')
  const [isPinned, setIsPinned] = useState(initial?.is_pinned ?? false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)

    const payload = {
      customer_id: customerId,
      note_type: noteType,
      content: content.trim(),
      is_pinned: isPinned,
    }

    try {
      if (initial) {
        const { data, error: updateError } = await supabase
          .from('customer_notes')
          .update(payload)
          .eq('id', initial.id)
          .select('*')
          .single()
        if (updateError) throw updateError
        onSaved(data)
      } else {
        const { data, error: insertError } = await supabase
          .from('customer_notes')
          .insert(payload)
          .select('*')
          .single()
        if (insertError) throw insertError
        onSaved(data)
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không lưu được ghi chú.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className="space-y-4" onSubmit={handleSubmit}>
      <div className="grid gap-4 md:grid-cols-2">
        <label className={labelClass}>
          Loại ghi chú
          <select className={inputClass} value={noteType} onChange={(e) => setNoteType(e.target.value)}>
            <option value="GENERAL">Chung</option>
            <option value="IMPORTANT">Quan trọng</option>
            <option value="CONTACT">Liên hệ</option>
            <option value="SERVICE">Dịch vụ</option>
          </select>
        </label>
        <label className="flex items-center gap-2 self-end pb-2 text-sm text-slate-300">
          <input type="checkbox" checked={isPinned} onChange={(e) => setIsPinned(e.target.checked)} />
          Ghim ghi chú
        </label>
      </div>
      <label className={labelClass}>
        Nội dung *
        <textarea className={inputClass} rows={5} value={content} onChange={(e) => setContent(e.target.value)} required />
      </label>
      <div className="flex justify-end gap-3">
        <button type="button" className="rounded-xl border border-slate-700 px-4 py-2" onClick={onCancel}>Hủy</button>
        <button type="submit" disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-60">
          {busy ? 'Đang lưu…' : initial ? 'Cập nhật ghi chú' : 'Thêm ghi chú'}
        </button>
      </div>
      {error ? <p role="alert" aria-live="assertive" className="rounded-xl bg-red-950/50 px-3 py-2 text-sm text-red-200">{error}</p> : null}
    </form>
  )
}

const fallbackDeviceTypes = [
  'Laptop',
  'PC',
  'Monitor',
  'Printer',
  'Camera',
  'NVR/DVR',
  'Router',
  'Switch',
  'UPS',
  'Disk',
  'Phone',
  'Other',
]

function normalizeSearch(value: string) {
  return value.trim().toLocaleLowerCase('vi-VN')
}

function customerMatches(customer: CustomerRow, query: string) {
  if (!query) return true
  const digits = query.replace(/\D/g, '')
  const haystack = [
    customer.customer_code,
    customer.full_name,
    customer.phone ?? '',
    customer.phone_normalized ?? '',
    customer.email ?? '',
    customer.zalo ?? '',
  ].join(' ').toLocaleLowerCase('vi-VN')

  return haystack.includes(query) || (digits.length >= 3 && (customer.phone_normalized ?? '').includes(digits))
}

function deviceMatches(device: DeviceRow, query: string) {
  if (!query) return true
  return [device.device_code, device.device_type, device.brand ?? '', device.model ?? '', device.serial_number ?? '', device.asset_tag ?? '']
    .join(' ')
    .toLocaleLowerCase('vi-VN')
    .includes(query)
}

function withSelectedFirst<T extends { id: string }>(rows: T[], selected: T | undefined) {
  if (!selected || rows.some((row) => row.id === selected.id)) return rows
  return [selected, ...rows]
}

export function CustomerQuickPicker({
  customers,
  value,
  onChange,
  canCreate = false,
  required = true,
  label = 'Khách hàng',
}: {
  customers: CustomerRow[]
  value: string
  onChange: (customerId: string) => void
  canCreate?: boolean
  required?: boolean
  label?: string
}) {
  const [rows, setRows] = useState(customers)
  const [search, setSearch] = useState('')
  const [showCreate, setShowCreate] = useState(false)

  useEffect(() => {
    setRows((current) => {
      const merged = new Map(current.map((row) => [row.id, row]))
      customers.forEach((row) => merged.set(row.id, row))
      return [...merged.values()]
    })
  }, [customers])

  const query = normalizeSearch(search)
  const selected = rows.find((row) => row.id === value)
  const matches = withSelectedFirst(rows.filter((row) => row.status === 'ACTIVE' && customerMatches(row, query)), selected)

  return <div className="space-y-2 rounded-2xl border border-slate-800 bg-slate-950/40 p-3">
    <div className="flex flex-wrap items-center justify-between gap-2">
      <span className="text-sm font-semibold text-slate-200">{label}{required ? ' *' : ''}</span>
      {canCreate ? <button type="button" onClick={() => setShowCreate(true)} className="rounded-lg border border-cyan-800 px-3 py-1.5 text-xs font-semibold text-cyan-300 hover:bg-cyan-950/40">+ Thêm khách hàng mới</button> : null}
    </div>
    <input
      type="search"
      aria-label={`Tìm ${label.toLocaleLowerCase('vi-VN')}`}
      className="w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm outline-none focus:border-cyan-500"
      placeholder="Tìm tên, mã khách, điện thoại, Zalo hoặc email…"
      value={search}
      onChange={(event) => setSearch(event.target.value)}
    />
    <select
      aria-label={`Chọn ${label.toLocaleLowerCase('vi-VN')}`}
      required={required}
      className="w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
      value={value}
      onChange={(event) => onChange(event.target.value)}
    >
      <option value="">— Chọn khách hàng —</option>
      {matches.map((customer) => <option key={customer.id} value={customer.id}>{customer.customer_code} · {customer.full_name} · {customer.phone || customer.zalo || 'chưa có liên hệ'}</option>)}
    </select>
    {query && matches.length === 0 ? <p className="text-xs text-amber-300">Không tìm thấy khách phù hợp. Có thể tạo ngay mà không rời biểu mẫu.</p> : null}

    {showCreate ? <Modal title="Thêm nhanh khách hàng" onClose={() => setShowCreate(false)}>
      <CustomerForm
        onCancel={() => setShowCreate(false)}
        onSaved={(customer) => {
          setRows((current) => [customer, ...current.filter((row) => row.id !== customer.id)])
          onChange(customer.id)
          setSearch('')
          setShowCreate(false)
        }}
      />
    </Modal> : null}
  </div>
}

export function CustomerDeviceQuickPicker({
  customers,
  devices,
  customerId,
  deviceId,
  onCustomerChange,
  onDeviceChange,
  canCreateCustomer = false,
  canCreateDevice = false,
  deviceRequired = false,
}: {
  customers: CustomerRow[]
  devices: DeviceRow[]
  customerId: string
  deviceId: string
  onCustomerChange: (customerId: string) => void
  onDeviceChange: (deviceId: string) => void
  canCreateCustomer?: boolean
  canCreateDevice?: boolean
  deviceRequired?: boolean
}) {
  const [localDevices, setLocalDevices] = useState(devices)
  const [deviceSearch, setDeviceSearch] = useState('')
  const [showCreateDevice, setShowCreateDevice] = useState(false)
  const [deviceTypes, setDeviceTypes] = useState(fallbackDeviceTypes)

  useEffect(() => {
    setLocalDevices((current) => {
      const merged = new Map(current.map((row) => [row.id, row]))
      devices.forEach((row) => merged.set(row.id, row))
      return [...merged.values()]
    })
  }, [devices])

  useEffect(() => {
    const selectedDevice = localDevices.find((device) => device.id === deviceId)
    if (selectedDevice && selectedDevice.customer_id !== customerId) onDeviceChange('')
  }, [customerId, deviceId, localDevices, onDeviceChange])

  useEffect(() => {
    if (!canCreateDevice) return
    let cancelled = false
    void supabase.from('settings').select('value').eq('key', 'crm.device_types').maybeSingle().then(({ data, error }) => {
      if (cancelled || error || !Array.isArray(data?.value)) return
      const values = data.value.filter((item): item is string => typeof item === 'string' && item.trim().length > 0)
      if (values.length > 0) setDeviceTypes(values)
    })
    return () => { cancelled = true }
  }, [canCreateDevice])

  const query = normalizeSearch(deviceSearch)
  const selected = localDevices.find((row) => row.id === deviceId && row.customer_id === customerId)
  const customerDevices = withSelectedFirst(
    localDevices.filter((row) => row.customer_id === customerId && row.status === 'ACTIVE' && deviceMatches(row, query)),
    selected,
  )

  return <div className="space-y-3">
    <CustomerQuickPicker
      customers={customers}
      value={customerId}
      onChange={(nextCustomerId) => {
        onCustomerChange(nextCustomerId)
        onDeviceChange('')
        setDeviceSearch('')
      }}
      canCreate={canCreateCustomer}
    />

    <div className="space-y-2 rounded-2xl border border-slate-800 bg-slate-950/40 p-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="text-sm font-semibold text-slate-200">Thiết bị{deviceRequired ? ' *' : ' (tùy chọn)'}</span>
        {canCreateDevice && customerId ? <button type="button" onClick={() => setShowCreateDevice(true)} className="rounded-lg border border-cyan-800 px-3 py-1.5 text-xs font-semibold text-cyan-300 hover:bg-cyan-950/40">+ Thêm thiết bị mới</button> : null}
      </div>
      <input
        type="search"
        aria-label="Tìm thiết bị của khách hàng"
        disabled={!customerId}
        className="w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm outline-none focus:border-cyan-500 disabled:opacity-50"
        placeholder="Tìm mã thiết bị, serial, hãng, model…"
        value={deviceSearch}
        onChange={(event) => setDeviceSearch(event.target.value)}
      />
      <select
        aria-label="Chọn thiết bị"
        required={deviceRequired}
        disabled={!customerId}
        className="w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm disabled:opacity-50"
        value={deviceId}
        onChange={(event) => onDeviceChange(event.target.value)}
      >
        <option value="">{deviceRequired ? '— Chọn thiết bị —' : '— Không gắn thiết bị —'}</option>
        {customerDevices.map((device) => <option key={device.id} value={device.id}>{device.device_code} · {device.device_type} · {[device.brand, device.model, device.serial_number].filter(Boolean).join(' · ') || 'chưa có model/serial'}</option>)}
      </select>
      {customerId && query && customerDevices.length === 0 ? <p className="text-xs text-amber-300">Không tìm thấy thiết bị phù hợp của khách này.</p> : null}
      {customerId && !query && localDevices.every((device) => device.customer_id !== customerId || device.status !== 'ACTIVE') ? <p className="text-xs text-amber-300">Khách hàng chưa có thiết bị đang sử dụng. Hãy thêm thiết bị trước khi tiếp tục.</p> : null}

      {showCreateDevice && customerId ? <Modal title="Thêm nhanh thiết bị" onClose={() => setShowCreateDevice(false)}>
        <DeviceForm
          customerId={customerId}
          deviceTypes={deviceTypes}
          onCancel={() => setShowCreateDevice(false)}
          onSaved={(device) => {
            setLocalDevices((current) => [device, ...current.filter((row) => row.id !== device.id)])
            onDeviceChange(device.id)
            setDeviceSearch('')
            setShowCreateDevice(false)
          }}
        />
      </Modal> : null}
    </div>
  </div>
}
