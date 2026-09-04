import { useEffect, useState } from 'react'
import type { FormEvent, ReactNode } from 'react'
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
  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/70 p-4 sm:p-8">
      <section className="w-full max-w-3xl rounded-2xl border border-slate-700 bg-slate-900 shadow-2xl">
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
      zalo: toNullable(zalo),
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
          <input className={inputClass} value={phone} onChange={(e) => setPhone(e.target.value)} />
        </label>
        <label className={labelClass}>
          Email
          <input className={inputClass} type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label className={labelClass}>
          Zalo
          <input className={inputClass} value={zalo} onChange={(e) => setZalo(e.target.value)} />
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
      {error ? <p className="rounded-xl bg-red-950/50 px-3 py-2 text-sm text-red-200">{error}</p> : null}
      <div className="flex justify-end gap-3">
        <button type="button" className="rounded-xl border border-slate-700 px-4 py-2" onClick={onCancel}>
          Hủy
        </button>
        <button type="submit" disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-60">
          {busy ? 'Đang lưu…' : initial ? 'Cập nhật' : 'Tạo khách hàng'}
        </button>
      </div>
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
      {error ? <p className="rounded-xl bg-red-950/50 px-3 py-2 text-sm text-red-200">{error}</p> : null}
      <div className="flex justify-end gap-3">
        <button type="button" className="rounded-xl border border-slate-700 px-4 py-2" onClick={onCancel}>Hủy</button>
        <button type="submit" disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-60">
          {busy ? 'Đang lưu…' : initial ? 'Cập nhật thiết bị' : 'Thêm thiết bị'}
        </button>
      </div>
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
      {error ? <p className="rounded-xl bg-red-950/50 px-3 py-2 text-sm text-red-200">{error}</p> : null}
      <div className="flex justify-end gap-3">
        <button type="button" className="rounded-xl border border-slate-700 px-4 py-2" onClick={onCancel}>Hủy</button>
        <button type="submit" disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-60">
          {busy ? 'Đang lưu…' : initial ? 'Cập nhật ghi chú' : 'Thêm ghi chú'}
        </button>
      </div>
    </form>
  )
}
