import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react'
import { hasPermission, type AppUserContext } from '../../lib/permissions'
import { createIsolatedAuthClient, supabase } from '../../lib/supabase'
import { viRole } from '../../lib/vi'
import { Modal } from '../crm/forms'

type StaffRow = {
  id: string
  email: string | null
  full_name: string | null
  phone: string | null
  role_id: string | null
  role_ids: string[]
  is_active: boolean
  last_login_at: string | null
  created_at: string
  updated_at: string
}

type RoleRow = {
  id: string
  code: string
  name: string
  is_active: boolean
}

const inputClass = 'mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm outline-none focus:border-cyan-500 disabled:opacity-50'

function dateTime(value: string | null) {
  return value ? new Date(value).toLocaleString('vi-VN') : 'Chưa đăng nhập'
}

function StaffForm({
  roles,
  initial,
  onCancel,
  onSaved,
  protectAccess,
}: {
  roles: RoleRow[]
  initial?: StaffRow
  onCancel: () => void
  onSaved: () => void
  protectAccess?: boolean
}) {
  const [email, setEmail] = useState(initial?.email ?? '')
  const [fullName, setFullName] = useState(initial?.full_name ?? '')
  const [phone, setPhone] = useState(initial?.phone ?? '')
  const defaultRoleId = initial?.role_id ?? roles.find((role) => role.code !== 'admin')?.id ?? roles[0]?.id ?? ''
  const [roleIds, setRoleIds] = useState<string[]>(initial?.role_ids?.length ? initial.role_ids : (defaultRoleId ? [defaultRoleId] : []))
  const [password, setPassword] = useState('')
  const [active, setActive] = useState(initial?.is_active ?? true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function updateProfile(userId: string, updateRoles: boolean) {
    const { error: updateError } = await supabase.from('profiles').update({
      full_name: fullName.trim(),
      phone: phone.trim() || null,
      is_active: active,
    }).eq('id', userId)
    if (updateError) throw updateError
    if (updateRoles) {
      const { error: roleError } = await supabase.rpc('staff_set_roles', {
        p_profile_id: userId,
        p_role_ids: roleIds,
      })
      if (roleError) throw roleError
    }
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError(null)
    try {
      if (roleIds.length === 0) throw new Error('Hãy chọn ít nhất một chức vụ cho nhân viên.')
      if (initial) {
        await updateProfile(initial.id, !protectAccess)
      } else {
        if (password.length < 8) throw new Error('Mật khẩu tạm phải có ít nhất 8 ký tự.')
        const isolated = createIsolatedAuthClient()
        const { data, error: signupError } = await isolated.auth.signUp({
          email: email.trim(),
          password,
          options: { data: { full_name: fullName.trim() } },
        })
        if (signupError) throw signupError
        if (!data.user?.id) throw new Error('Không tạo được tài khoản xác thực cho nhân viên.')
        await updateProfile(data.user.id, true)
        await isolated.auth.signOut()
      }
      onSaved()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không lưu được nhân viên.')
    } finally {
      setBusy(false)
    }
  }

  return <form className="space-y-4" onSubmit={submit}>
    <div className="grid gap-4 sm:grid-cols-2">
      <label className="text-sm font-medium">Họ tên *<input required className={inputClass} value={fullName} onChange={(event) => setFullName(event.target.value)} /></label>
      <label className="text-sm font-medium">Số điện thoại<input className={inputClass} value={phone} onChange={(event) => setPhone(event.target.value)} /></label>
      <label className="text-sm font-medium">Email đăng nhập *<input required type="email" disabled={Boolean(initial)} className={inputClass} value={email} onChange={(event) => setEmail(event.target.value)} /></label>
      {!initial ? <label className="text-sm font-medium">Mật khẩu tạm *<input required minLength={8} type="password" autoComplete="new-password" className={inputClass} value={password} onChange={(event) => setPassword(event.target.value)} /></label> : null}
      <fieldset className="rounded-xl border border-slate-700 bg-slate-950/60 p-3 sm:col-span-2">
        <legend className="px-1 text-sm font-medium">Chức vụ đảm trách *</legend>
        <p className="mb-2 text-xs text-slate-500">Có thể chọn nhiều chức vụ; quyền làm việc là tổng quyền của các chức vụ đã chọn.</p>
        <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
          {roles.filter((role) => role.is_active || roleIds.includes(role.id)).map((role) => <label key={role.id} className="flex items-center gap-2 rounded-lg border border-slate-800 px-3 py-2 text-sm"><input type="checkbox" disabled={protectAccess} checked={roleIds.includes(role.id)} onChange={(event) => setRoleIds((current) => event.target.checked ? [...current,role.id] : current.filter((id) => id !== role.id))} />{viRole(role.code, role.name)}</label>)}
        </div>
      </fieldset>
      <label className="mt-7 flex items-center gap-2 text-sm"><input type="checkbox" disabled={protectAccess} checked={active} onChange={(event) => setActive(event.target.checked)} />Cho phép đăng nhập và làm việc</label>
    </div>
    {!initial ? <p className="rounded-xl border border-amber-900/60 bg-amber-950/20 p-3 text-xs leading-5 text-amber-200">Tài khoản được tạo bằng khóa công khai an toàn, sau đó chỉ quản trị viên mới được gán vai trò và kích hoạt. Hệ thống không dùng hoặc lộ khóa quản trị bí mật.</p> : null}
    {error ? <div role="alert" className="rounded-xl border border-red-900 bg-red-950/30 p-3 text-sm text-red-200">{error}</div> : null}
    <div className="flex justify-end gap-2"><button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2">Hủy</button><button disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 font-semibold text-slate-950 disabled:opacity-50">{busy ? 'Đang lưu…' : initial ? 'Cập nhật nhân viên' : 'Thêm nhân viên'}</button></div>
  </form>
}

export function StaffPage({ context }: { context: AppUserContext }) {
  const canManage = hasPermission(context, 'user.manage')
  const [staff, setStaff] = useState<StaffRow[]>([])
  const [roles, setRoles] = useState<RoleRow[]>([])
  const [search, setSearch] = useState('')
  const [roleFilter, setRoleFilter] = useState('ALL')
  const [activeFilter, setActiveFilter] = useState('ALL')
  const [showCreate, setShowCreate] = useState(false)
  const [editing, setEditing] = useState<StaffRow | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [profilesResult, rolesResult, assignmentsResult] = await Promise.all([
        supabase.from('profiles').select('id,email,full_name,phone,role_id,is_active,last_login_at,created_at,updated_at').order('created_at', { ascending: false }).limit(500),
        supabase.from('roles').select('id,code,name,is_active').order('name'),
        supabase.from('profile_roles').select('profile_id,role_id'),
      ])
      if (profilesResult.error) throw profilesResult.error
      if (rolesResult.error) throw rolesResult.error
      if (assignmentsResult.error) throw assignmentsResult.error
      const assignments = new Map<string,string[]>()
      for (const item of assignmentsResult.data) assignments.set(item.profile_id,[...(assignments.get(item.profile_id) ?? []),item.role_id])
      setStaff(profilesResult.data.map((profile) => ({ ...profile, role_ids: assignments.get(profile.id) ?? (profile.role_id ? [profile.role_id] : []) })))
      setRoles(rolesResult.data)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tải được danh sách nhân viên.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { void load() }, [load])
  const roleById = useMemo(() => new Map(roles.map((role) => [role.id, role])), [roles])
  const filtered = useMemo(() => {
    const query = search.trim().toLocaleLowerCase('vi-VN')
    return staff.filter((row) => {
      if (roleFilter !== 'ALL' && !row.role_ids.includes(roleFilter)) return false
      if (activeFilter === 'ACTIVE' && !row.is_active) return false
      if (activeFilter === 'INACTIVE' && row.is_active) return false
      if (!query) return true
      const assignedRoles = row.role_ids.map((id) => roleById.get(id)).filter(Boolean)
      return [row.full_name ?? '', row.email ?? '', row.phone ?? '', ...assignedRoles.flatMap((role) => [role?.name ?? '',role?.code ?? ''])].join(' ').toLocaleLowerCase('vi-VN').includes(query)
    })
  }, [activeFilter, roleById, roleFilter, search, staff])

  async function deactivate(row: StaffRow) {
    if (!canManage) {
      setError('Bạn không có quyền thay đổi tài khoản nhân viên.')
      return
    }
    if (row.id === context.userId) {
      setError('Không thể tự xóa quyền truy cập của tài khoản đang đăng nhập.')
      return
    }
    if (!window.confirm(`Xóa quyền truy cập của ${row.full_name || row.email || 'nhân viên này'}? Lịch sử nghiệp vụ vẫn được giữ lại.`)) return
    const { error: updateError } = await supabase.from('profiles').update({ is_active: false }).eq('id', row.id)
    if (updateError) setError(updateError.message)
    else await load()
  }

  return <main className="min-h-screen bg-slate-950 text-slate-200">
    <div className="mx-auto max-w-7xl space-y-4 px-4 py-6 pb-24 sm:px-6">
      <section className="flex flex-col gap-3 rounded-2xl border border-slate-800 bg-slate-900 p-4 lg:flex-row">
        <input type="search" className="min-w-0 flex-1 rounded-xl border border-slate-700 bg-slate-950 px-4 py-2" placeholder="Tìm tên, email, số điện thoại hoặc vai trò…" value={search} onChange={(event) => setSearch(event.target.value)} />
        <select className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={roleFilter} onChange={(event) => setRoleFilter(event.target.value)}><option value="ALL">Tất cả vai trò</option>{roles.map((role) => <option key={role.id} value={role.id}>{viRole(role.code, role.name)}</option>)}</select>
        <select className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2" value={activeFilter} onChange={(event) => setActiveFilter(event.target.value)}><option value="ALL">Tất cả trạng thái</option><option value="ACTIVE">Đang hoạt động</option><option value="INACTIVE">Đã khóa</option></select>
        <button type="button" onClick={() => { setSearch(''); setRoleFilter('ALL'); setActiveFilter('ALL') }} className="rounded-xl border border-slate-700 px-4 py-2 text-sm">Đặt lại</button>
        {canManage ? <button type="button" onClick={() => setShowCreate(true)} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950">+ Tạo mới</button> : null}
      </section>
      <p className="text-xs leading-5 text-slate-500">“Xóa” trong hệ thống là khóa quyền truy cập, không xóa vật lý tài khoản để bảo toàn nhật ký và người thực hiện trên chứng từ.</p>
      {error ? <div role="alert" className="rounded-xl border border-red-900 bg-red-950/30 p-4 text-sm text-red-200">{error}</div> : null}
      <section className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900"><div className="overflow-x-auto"><table className="w-full min-w-[920px] text-left text-sm"><thead className="bg-slate-950/70 text-xs uppercase text-slate-500"><tr><th className="px-4 py-3">Nhân viên</th><th className="px-4 py-3">Liên hệ</th><th className="px-4 py-3">Chức vụ</th><th className="px-4 py-3">Trạng thái</th><th className="px-4 py-3">Đăng nhập gần nhất</th><th className="px-4 py-3 text-right">Thao tác</th></tr></thead><tbody>{filtered.map((row) => { const assignedRoles = row.role_ids.map((id) => roleById.get(id)).filter((role): role is RoleRow => Boolean(role)); return <tr key={row.id} className="border-t border-slate-800"><td className="px-4 py-3"><div className="font-medium text-white">{row.full_name || 'Chưa cập nhật họ tên'}</div><div className="text-xs text-slate-500">{row.id === context.userId ? 'Tài khoản đang dùng' : row.id.slice(0, 8)}</div></td><td className="px-4 py-3"><div>{row.email || '—'}</div><div className="text-xs text-slate-500">{row.phone || '—'}</div></td><td className="px-4 py-3"><div className="flex max-w-80 flex-wrap gap-1">{assignedRoles.map((role) => <span key={role.id} className="rounded-lg border border-cyan-950 bg-cyan-950/30 px-2 py-1 text-xs text-cyan-200">{viRole(role.code, role.name)}</span>)}</div></td><td className="px-4 py-3"><span className={row.is_active ? 'rounded-lg bg-emerald-950 px-2 py-1 text-xs text-emerald-300' : 'rounded-lg bg-slate-800 px-2 py-1 text-xs text-slate-400'}>{row.is_active ? 'Đang hoạt động' : 'Đã khóa'}</span></td><td className="px-4 py-3 text-slate-400">{dateTime(row.last_login_at)}</td><td className="px-4 py-3 text-right">{canManage ? <div className="flex justify-end gap-1"><button type="button" onClick={() => setEditing(row)} className="rounded-lg border border-slate-700 px-3 py-1 text-xs">Sửa</button>{row.is_active && row.id !== context.userId ? <button type="button" onClick={() => void deactivate(row)} className="rounded-lg border border-red-900 px-3 py-1 text-xs text-red-300">Xóa quyền</button> : null}</div> : '—'}</td></tr> })}</tbody></table></div>{loading ? <p className="p-6 text-center text-slate-500">Đang tải…</p> : null}{!loading && filtered.length === 0 ? <p className="p-8 text-center text-slate-500">Không có nhân viên phù hợp.</p> : null}</section>
    </div>
    {showCreate ? <Modal title="Thêm nhân viên" onClose={() => setShowCreate(false)}><StaffForm roles={roles} onCancel={() => setShowCreate(false)} onSaved={() => { setShowCreate(false); void load() }} /></Modal> : null}
    {editing ? <Modal title="Sửa nhân viên" onClose={() => setEditing(null)}><StaffForm roles={roles} initial={editing} protectAccess={editing.id === context.userId} onCancel={() => setEditing(null)} onSaved={() => { setEditing(null); void load() }} /></Modal> : null}
  </main>
}
