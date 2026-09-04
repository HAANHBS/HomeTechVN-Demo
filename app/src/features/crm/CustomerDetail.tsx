import { useCallback, useEffect, useMemo, useState } from 'react'
import type { AppUserContext } from '../../lib/permissions'
import { hasPermission } from '../../lib/permissions'
import { supabase } from '../../lib/supabase'
import type { CustomerRow, DeviceRow, NoteRow } from '../../lib/database.types'
import { CustomerForm, DeviceForm, Modal, NoteForm } from './forms'

const defaultDeviceTypes = [
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

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(value))
}

function TextValue({ label, value }: { label: string; value: string | null | undefined }) {
  return (
    <div>
      <dt className="text-xs uppercase tracking-wide text-slate-500">{label}</dt>
      <dd className="mt-1 text-sm text-slate-200">{value || '—'}</dd>
    </div>
  )
}

export function CustomerDetail({
  customerId,
  context,
  onBack,
}: {
  customerId: string
  context: AppUserContext
  onBack: () => void
}) {
  const [customer, setCustomer] = useState<CustomerRow | null>(null)
  const [devices, setDevices] = useState<DeviceRow[]>([])
  const [notes, setNotes] = useState<NoteRow[]>([])
  const [deviceTypes, setDeviceTypes] = useState<string[]>(defaultDeviceTypes)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [editCustomer, setEditCustomer] = useState(false)
  const [editDevice, setEditDevice] = useState<DeviceRow | null | 'new'>(null)
  const [editNote, setEditNote] = useState<NoteRow | null | 'new'>(null)

  const canUpdateCustomer = hasPermission(context, 'customer.update')
  const canCreateDevice = hasPermission(context, 'device.create')
  const canUpdateDevice = hasPermission(context, 'device.update')

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)

    try {
      const [customerResult, devicesResult, notesResult, typesResult] = await Promise.all([
        supabase.from('customers').select('*').eq('id', customerId).single(),
        supabase
          .from('customer_devices')
          .select('*')
          .eq('customer_id', customerId)
          .order('updated_at', { ascending: false }),
        supabase
          .from('customer_notes')
          .select('*')
          .eq('customer_id', customerId)
          .order('is_pinned', { ascending: false })
          .order('updated_at', { ascending: false }),
        supabase.from('settings').select('value').eq('key', 'crm.device_types').maybeSingle(),
      ])

      if (customerResult.error) throw customerResult.error
      if (devicesResult.error) throw devicesResult.error
      if (notesResult.error) throw notesResult.error

      setCustomer(customerResult.data)
      setDevices(devicesResult.data)
      setNotes(notesResult.data)

      if (!typesResult.error && Array.isArray(typesResult.data?.value)) {
        const values = typesResult.data.value.filter((item): item is string => typeof item === 'string')
        if (values.length > 0) setDeviceTypes(values)
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tải được hồ sơ khách hàng.')
    } finally {
      setLoading(false)
    }
  }, [customerId])

  useEffect(() => {
    void load()
  }, [load])

  const activeDevices = useMemo(() => devices.filter((device) => device.status === 'ACTIVE').length, [devices])

  if (loading) {
    return <div className="rounded-2xl border border-slate-800 bg-slate-900 p-6">Đang tải hồ sơ…</div>
  }

  if (error || !customer) {
    return (
      <div className="rounded-2xl border border-red-900 bg-red-950/20 p-6">
        <p className="text-red-200">{error ?? 'Không tìm thấy khách hàng.'}</p>
        <button className="mt-4 rounded-xl border border-slate-700 px-4 py-2" onClick={onBack}>Quay lại</button>
      </div>
    )
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <button type="button" onClick={onBack} className="rounded-xl border border-slate-700 px-3 py-2 text-sm hover:bg-slate-800">
          ← Danh sách khách hàng
        </button>
        {canUpdateCustomer ? (
          <button type="button" onClick={() => setEditCustomer(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">
            Sửa khách hàng
          </button>
        ) : null}
      </div>

      <section className="rounded-2xl border border-slate-800 bg-slate-900 p-5">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p className="font-mono text-sm text-cyan-400">{customer.customer_code}</p>
            <h2 className="mt-1 text-2xl font-bold text-white">{customer.full_name}</h2>
            <p className="mt-1 text-sm text-slate-400">
              {customer.customer_type === 'BUSINESS' ? 'Doanh nghiệp' : 'Cá nhân'} · {customer.status === 'ACTIVE' ? 'Đang hoạt động' : 'Ngừng hoạt động'}
            </p>
          </div>
          <div className="rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-center">
            <div className="text-2xl font-bold text-white">{devices.length}</div>
            <div className="text-xs text-slate-500">Thiết bị · {activeDevices} active</div>
          </div>
        </div>

        <dl className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <TextValue label="Điện thoại" value={customer.phone} />
          <TextValue label="Email" value={customer.email} />
          <TextValue label="Zalo" value={customer.zalo} />
          <TextValue label="Mã số thuế" value={customer.tax_code} />
          <TextValue label="Ngày sinh" value={customer.birthday} />
          <div className="sm:col-span-2 lg:col-span-3"><TextValue label="Địa chỉ" value={customer.address} /></div>
        </dl>
      </section>

      <section className="rounded-2xl border border-slate-800 bg-slate-900 p-5">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h3 className="text-lg font-semibold text-white">Thiết bị khách hàng</h3>
            <p className="text-sm text-slate-500">Serial không ép UNIQUE để không chặn dữ liệu thực tế.</p>
          </div>
          {canCreateDevice ? (
            <button type="button" onClick={() => setEditDevice('new')} className="rounded-xl bg-cyan-500 px-3 py-2 text-sm font-semibold text-slate-950">
              + Thiết bị
            </button>
          ) : null}
        </div>

        <div className="mt-4 overflow-x-auto">
          <table className="w-full min-w-[760px] text-left text-sm">
            <thead className="text-xs uppercase text-slate-500">
              <tr className="border-b border-slate-800">
                <th className="py-3 pr-4">Mã</th>
                <th className="py-3 pr-4">Loại</th>
                <th className="py-3 pr-4">Hãng / Model</th>
                <th className="py-3 pr-4">Serial</th>
                <th className="py-3 pr-4">Trạng thái</th>
                <th className="py-3 text-right">Thao tác</th>
              </tr>
            </thead>
            <tbody>
              {devices.map((device) => (
                <tr key={device.id} className="border-b border-slate-800/70">
                  <td className="py-3 pr-4 font-mono text-cyan-300">{device.device_code}</td>
                  <td className="py-3 pr-4">{device.device_type}</td>
                  <td className="py-3 pr-4">{[device.brand, device.model].filter(Boolean).join(' ') || '—'}</td>
                  <td className="py-3 pr-4 font-mono text-xs">{device.serial_number || '—'}</td>
                  <td className="py-3 pr-4">{device.status === 'ACTIVE' ? 'Đang dùng' : 'Ngừng dùng'}</td>
                  <td className="py-3 text-right">
                    {canUpdateDevice ? (
                      <button type="button" onClick={() => setEditDevice(device)} className="rounded-lg border border-slate-700 px-2 py-1 text-xs hover:bg-slate-800">
                        Sửa
                      </button>
                    ) : null}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {devices.length === 0 ? <p className="py-8 text-center text-sm text-slate-500">Chưa có thiết bị.</p> : null}
        </div>
      </section>

      <section className="rounded-2xl border border-slate-800 bg-slate-900 p-5">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h3 className="text-lg font-semibold text-white">Ghi chú CRM</h3>
            <p className="text-sm text-slate-500">Ghi lại liên hệ, lưu ý và lịch sử trao đổi.</p>
          </div>
          {canUpdateCustomer ? (
            <button type="button" onClick={() => setEditNote('new')} className="rounded-xl border border-cyan-700 px-3 py-2 text-sm text-cyan-300 hover:bg-cyan-950/30">
              + Ghi chú
            </button>
          ) : null}
        </div>

        <div className="mt-4 space-y-3">
          {notes.map((note) => (
            <article key={note.id} className="rounded-xl border border-slate-800 bg-slate-950/70 p-4">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  {note.is_pinned ? <span title="Đã ghim">📌</span> : null}
                  <span className="rounded-full bg-slate-800 px-2 py-1 text-xs text-slate-300">{note.note_type}</span>
                  <span className="text-xs text-slate-500">{formatDateTime(note.updated_at)}</span>
                </div>
                {canUpdateCustomer ? (
                  <button type="button" onClick={() => setEditNote(note)} className="text-xs text-cyan-400 hover:text-cyan-300">Sửa</button>
                ) : null}
              </div>
              <p className="mt-3 whitespace-pre-wrap text-sm leading-6 text-slate-200">{note.content}</p>
            </article>
          ))}
          {notes.length === 0 ? <p className="py-6 text-center text-sm text-slate-500">Chưa có ghi chú.</p> : null}
        </div>
      </section>

      {editCustomer ? (
        <Modal title="Cập nhật khách hàng" onClose={() => setEditCustomer(false)}>
          <CustomerForm
            initial={customer}
            onCancel={() => setEditCustomer(false)}
            onSaved={(saved) => {
              setCustomer(saved)
              setEditCustomer(false)
            }}
          />
        </Modal>
      ) : null}

      {editDevice ? (
        <Modal title={editDevice === 'new' ? 'Thêm thiết bị' : `Sửa ${editDevice.device_code}`} onClose={() => setEditDevice(null)}>
          <DeviceForm
            customerId={customer.id}
            deviceTypes={deviceTypes}
            initial={editDevice === 'new' ? null : editDevice}
            onCancel={() => setEditDevice(null)}
            onSaved={() => {
              setEditDevice(null)
              void load()
            }}
          />
        </Modal>
      ) : null}

      {editNote ? (
        <Modal title={editNote === 'new' ? 'Thêm ghi chú' : 'Cập nhật ghi chú'} onClose={() => setEditNote(null)}>
          <NoteForm
            customerId={customer.id}
            initial={editNote === 'new' ? null : editNote}
            onCancel={() => setEditNote(null)}
            onSaved={() => {
              setEditNote(null)
              void load()
            }}
          />
        </Modal>
      ) : null}
    </div>
  )
}
