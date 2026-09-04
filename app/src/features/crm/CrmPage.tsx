import { useCallback, useEffect, useMemo, useState } from 'react'
import type { AppUserContext } from '../../lib/permissions'
import { hasPermission } from '../../lib/permissions'
import { supabase } from '../../lib/supabase'
import type { CustomerRow, DeviceRow } from '../../lib/database.types'
import { CustomerDetail } from './CustomerDetail'
import { CustomerForm, Modal } from './forms'
import type { QrAction, QrResolved } from '../qr/QrCommandCenter'

type Tab = 'customers' | 'devices'

function normalizeSearch(value: string) {
  return value.trim().toLocaleLowerCase('vi-VN')
}

function CustomerList({
  context,
  onOpen,
  initialCreate = false,
}: {
  context: AppUserContext
  onOpen: (customerId: string) => void
  initialCreate?: boolean
}) {
  const [rows, setRows] = useState<CustomerRow[]>([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [showCreate, setShowCreate] = useState(false)

  useEffect(() => { if (initialCreate) setShowCreate(true) }, [initialCreate])

  const canView = hasPermission(context, 'customer.view')
  const canCreate = hasPermission(context, 'customer.create')

  const load = useCallback(async () => {
    if (!canView) return
    setLoading(true)
    setError(null)

    const { data, error: queryError } = await supabase
      .from('customers')
      .select('*')
      .order('updated_at', { ascending: false })
      .limit(250)

    if (queryError) {
      setError(queryError.message)
      setRows([])
    } else {
      setRows(data)
    }
    setLoading(false)
  }, [canView])

  useEffect(() => {
    void load()
  }, [load])

  const filtered = useMemo(() => {
    const query = normalizeSearch(search)
    if (!query) return rows
    const digits = query.replace(/\D/g, '')

    return rows.filter((row) => {
      const haystack = [
        row.customer_code,
        row.full_name,
        row.phone ?? '',
        row.phone_normalized ?? '',
        row.email ?? '',
        row.zalo ?? '',
        row.address ?? '',
      ]
        .join(' ')
        .toLocaleLowerCase('vi-VN')

      return haystack.includes(query) || (digits.length >= 3 && (row.phone_normalized ?? '').includes(digits))
    })
  }, [rows, search])

  if (!canView) {
    return <div className="rounded-2xl border border-amber-900 bg-amber-950/20 p-6 text-amber-200">Vai trò hiện tại không có quyền customer.view.</div>
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-col gap-3 rounded-2xl border border-slate-800 bg-slate-900 p-4 sm:flex-row sm:items-center">
        <input
          className="min-w-0 flex-1 rounded-xl border border-slate-700 bg-slate-950 px-4 py-2 outline-none focus:border-cyan-500"
          placeholder="Tìm mã khách, tên, SĐT, email, Zalo, địa chỉ…"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
        <div className="flex gap-2">
          <button type="button" onClick={() => void load()} className="rounded-xl border border-slate-700 px-4 py-2 text-sm hover:bg-slate-800">Làm mới</button>
          {canCreate ? (
            <button type="button" onClick={() => setShowCreate(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ Khách hàng</button>
          ) : null}
        </div>
      </div>

      <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[800px] text-left text-sm">
            <thead className="bg-slate-950/70 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">Mã</th>
                <th className="px-4 py-3">Khách hàng</th>
                <th className="px-4 py-3">Điện thoại</th>
                <th className="px-4 py-3">Địa chỉ</th>
                <th className="px-4 py-3">Trạng thái</th>
                <th className="px-4 py-3 text-right">Mở</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((row) => (
                <tr key={row.id} className="border-t border-slate-800 hover:bg-slate-800/40">
                  <td className="px-4 py-3 font-mono text-cyan-300">{row.customer_code}</td>
                  <td className="px-4 py-3">
                    <div className="font-medium text-white">{row.full_name}</div>
                    <div className="text-xs text-slate-500">{row.customer_type === 'BUSINESS' ? 'Doanh nghiệp' : 'Cá nhân'}</div>
                  </td>
                  <td className="px-4 py-3">{row.phone || '—'}</td>
                  <td className="max-w-sm truncate px-4 py-3 text-slate-400">{row.address || '—'}</td>
                  <td className="px-4 py-3">{row.status === 'ACTIVE' ? 'Hoạt động' : 'Ngừng'}</td>
                  <td className="px-4 py-3 text-right">
                    <button type="button" onClick={() => onOpen(row.id)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs hover:bg-slate-800">Chi tiết</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {loading ? <p className="p-6 text-center text-slate-500">Đang tải…</p> : null}
        {!loading && filtered.length === 0 ? <p className="p-8 text-center text-sm text-slate-500">Không có khách hàng phù hợp.</p> : null}
        {error ? <p className="border-t border-red-900 bg-red-950/30 p-4 text-sm text-red-200">{error}</p> : null}
      </section>

      {showCreate ? (
        <Modal title="Thêm khách hàng" onClose={() => setShowCreate(false)}>
          <CustomerForm
            onCancel={() => setShowCreate(false)}
            onSaved={(customer) => {
              setShowCreate(false)
              void load()
              onOpen(customer.id)
            }}
          />
        </Modal>
      ) : null}
    </div>
  )
}

function DeviceList({
  context,
  onOpenCustomer,
}: {
  context: AppUserContext
  onOpenCustomer: (customerId: string) => void
}) {
  const [devices, setDevices] = useState<DeviceRow[]>([])
  const [customers, setCustomers] = useState<Map<string, CustomerRow>>(new Map())
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const canView = hasPermission(context, 'device.view')

  const load = useCallback(async () => {
    if (!canView) return
    setLoading(true)
    setError(null)

    try {
      const { data: deviceRows, error: deviceError } = await supabase
        .from('customer_devices')
        .select('*')
        .order('updated_at', { ascending: false })
        .limit(300)
      if (deviceError) throw deviceError

      setDevices(deviceRows)
      const customerIds = [...new Set(deviceRows.map((row) => row.customer_id))]

      if (customerIds.length === 0) {
        setCustomers(new Map())
      } else {
        const { data: customerRows, error: customerError } = await supabase
          .from('customers')
          .select('*')
          .in('id', customerIds)
        if (customerError) throw customerError
        setCustomers(new Map(customerRows.map((row) => [row.id, row])))
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tải được thiết bị.')
    } finally {
      setLoading(false)
    }
  }, [canView])

  useEffect(() => {
    void load()
  }, [load])

  const filtered = useMemo(() => {
    const query = normalizeSearch(search)
    if (!query) return devices

    return devices.filter((row) => {
      const customer = customers.get(row.customer_id)
      const haystack = [
        row.device_code,
        row.device_type,
        row.brand ?? '',
        row.model ?? '',
        row.serial_number ?? '',
        row.asset_tag ?? '',
        customer?.customer_code ?? '',
        customer?.full_name ?? '',
        customer?.phone ?? '',
      ]
        .join(' ')
        .toLocaleLowerCase('vi-VN')
      return haystack.includes(query)
    })
  }, [customers, devices, search])

  if (!canView) {
    return <div className="rounded-2xl border border-amber-900 bg-amber-950/20 p-6 text-amber-200">Vai trò hiện tại không có quyền device.view.</div>
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-col gap-3 rounded-2xl border border-slate-800 bg-slate-900 p-4 sm:flex-row">
        <input
          className="min-w-0 flex-1 rounded-xl border border-slate-700 bg-slate-950 px-4 py-2 outline-none focus:border-cyan-500"
          placeholder="Tìm mã thiết bị, serial, hãng, model hoặc tên khách…"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
        <button type="button" onClick={() => void load()} className="rounded-xl border border-slate-700 px-4 py-2 text-sm hover:bg-slate-800">Làm mới</button>
      </div>

      <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[900px] text-left text-sm">
            <thead className="bg-slate-950/70 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">Mã thiết bị</th>
                <th className="px-4 py-3">Loại</th>
                <th className="px-4 py-3">Hãng / Model</th>
                <th className="px-4 py-3">Serial</th>
                <th className="px-4 py-3">Khách hàng</th>
                <th className="px-4 py-3 text-right">Mở</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((row) => {
                const customer = customers.get(row.customer_id)
                return (
                  <tr key={row.id} className="border-t border-slate-800 hover:bg-slate-800/40">
                    <td className="px-4 py-3 font-mono text-cyan-300">{row.device_code}</td>
                    <td className="px-4 py-3">{row.device_type}</td>
                    <td className="px-4 py-3">{[row.brand, row.model].filter(Boolean).join(' ') || '—'}</td>
                    <td className="px-4 py-3 font-mono text-xs">{row.serial_number || '—'}</td>
                    <td className="px-4 py-3">
                      <div className="font-medium text-white">{customer?.full_name ?? 'Không đọc được khách'}</div>
                      <div className="text-xs text-slate-500">{customer?.customer_code ?? row.customer_id}</div>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <button type="button" onClick={() => onOpenCustomer(row.customer_id)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs hover:bg-slate-800">Khách hàng</button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
        {loading ? <p className="p-6 text-center text-slate-500">Đang tải…</p> : null}
        {!loading && filtered.length === 0 ? <p className="p-8 text-center text-sm text-slate-500">Không có thiết bị phù hợp.</p> : null}
        {error ? <p className="border-t border-red-900 bg-red-950/30 p-4 text-sm text-red-200">{error}</p> : null}
      </section>
    </div>
  )
}

export function CrmPage({ context, initialTarget, initialAction, onOpenInventory, onOpenSales, onOpenRepair, onOpenChecklist, onOpenWarranty, onOpenServiceLicense, onOpenReminders, onOpenNotifications }: { context: AppUserContext; initialTarget?: QrResolved; initialAction?: QrAction; onOpenInventory?: () => void; onOpenSales?: () => void; onOpenRepair?: () => void; onOpenChecklist?: () => void; onOpenWarranty?: () => void; onOpenServiceLicense?: () => void; onOpenReminders?: () => void; onOpenNotifications?: () => void }) {
  const [tab, setTab] = useState<Tab>('customers')
  const [customerId, setCustomerId] = useState<string | null>(initialTarget?.resource_type === 'CUSTOMER' ? initialTarget.resource_id ?? null : null)

  useEffect(() => {
    if (initialTarget?.resource_type === 'CUSTOMER' && initialTarget.resource_id) {
      setTab('customers')
      setCustomerId(initialTarget.resource_id)
    } else if (initialTarget?.resource_type === 'DEVICE' && initialTarget.resource_id) {
      setTab('devices')
      void supabase.from('customer_devices').select('customer_id').eq('id',initialTarget.resource_id).single()
        .then(({data}) => { if (data?.customer_id) openCustomer(data.customer_id) })
    }
  }, [initialTarget])

  function openCustomer(id: string) {
    setTab('customers')
    setCustomerId(id)
  }

  return (
    <main className="min-h-screen bg-slate-950 text-slate-200">
      <header className="border-b border-slate-800 bg-slate-900/90 px-4 py-4 backdrop-blur sm:px-6">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4">
          <div>
            <div className="text-sm font-semibold uppercase tracking-[0.24em] text-cyan-400">HomeTechVN</div>
            <h1 className="mt-1 text-xl font-bold text-white">CRM & Thiết bị khách hàng</h1>
          </div>
          <div className="flex flex-wrap items-center gap-3 text-sm">
            {onOpenInventory ? (
              <button type="button" onClick={onOpenInventory} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300 hover:bg-cyan-950/40">Kho & Sản phẩm</button>
            ) : null}
            {onOpenSales ? (
              <button type="button" onClick={onOpenSales} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300 hover:bg-cyan-950/40">Bán hàng</button>
            ) : null}
            {onOpenRepair ? (
              <button type="button" onClick={onOpenRepair} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300 hover:bg-cyan-950/40">Sửa chữa</button>
            ) : null}
            {onOpenChecklist ? (
              <button type="button" onClick={onOpenChecklist} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300 hover:bg-cyan-950/40">Checklist</button>
            ) : null}
            {onOpenWarranty ? (
              <button type="button" onClick={onOpenWarranty} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300 hover:bg-cyan-950/40">Bảo hành</button>
            ) : null}
            {onOpenServiceLicense ? (
              <button type="button" onClick={onOpenServiceLicense} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300 hover:bg-cyan-950/40">Dịch vụ & License</button>
            ) : null}
            {onOpenReminders ? (
              <button type="button" onClick={onOpenReminders} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300 hover:bg-cyan-950/40">Nhắc việc</button>
            ) : null}
            {onOpenNotifications ? (
              <button type="button" onClick={onOpenNotifications} className="rounded-xl border border-cyan-900 px-3 py-2 text-cyan-300 hover:bg-cyan-950/40">Thông báo</button>
            ) : null}
            <div className="text-right">
              <div className="font-medium text-white">{context.fullName || context.email || 'Người dùng'}</div>
              <div className="text-xs text-slate-500">{context.roleName} · {context.roleCode}</div>
            </div>
            <button type="button" onClick={() => void supabase.auth.signOut()} className="rounded-xl border border-slate-700 px-3 py-2 hover:bg-slate-800">Đăng xuất</button>
          </div>
        </div>
      </header>

      <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
        {!customerId ? (
          <nav className="mb-5 flex gap-2">
            <button
              type="button"
              onClick={() => setTab('customers')}
              className={`rounded-xl px-4 py-2 text-sm font-medium ${tab === 'customers' ? 'bg-cyan-500 text-slate-950' : 'border border-slate-700 text-slate-300 hover:bg-slate-800'}`}
            >
              Khách hàng
            </button>
            <button
              type="button"
              onClick={() => setTab('devices')}
              className={`rounded-xl px-4 py-2 text-sm font-medium ${tab === 'devices' ? 'bg-cyan-500 text-slate-950' : 'border border-slate-700 text-slate-300 hover:bg-slate-800'}`}
            >
              Thiết bị
            </button>
          </nav>
        ) : null}

        {customerId ? (
          <CustomerDetail customerId={customerId} context={context} onBack={() => setCustomerId(null)} />
        ) : tab === 'customers' ? (
          <CustomerList context={context} onOpen={openCustomer} initialCreate={initialAction === 'CREATE' && initialTarget?.resource_type === 'CUSTOMER'} />
        ) : (
          <DeviceList context={context} onOpenCustomer={openCustomer} />
        )}
      </div>
    </main>
  )
}
