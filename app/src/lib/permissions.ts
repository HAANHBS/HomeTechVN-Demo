import { supabase } from './supabase'

export type AppUserContext = {
  userId: string
  email: string | null
  fullName: string | null
  roleCode: string
  roleName: string
  roleCodes: string[]
  roleNames: string[]
  permissions: Set<string>
}

export async function loadUserContext(userId: string): Promise<AppUserContext> {
  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('id,email,full_name,role_id,is_active')
    .eq('id', userId)
    .single()

  if (profileError) throw profileError
  if (!profile.is_active) throw new Error('Tài khoản chưa được kích hoạt.')
  const { data: assignments, error: assignmentError } = await supabase
    .from('profile_roles')
    .select('role_id')
    .eq('profile_id', userId)

  if (assignmentError) throw assignmentError
  const roleIds = Array.from(new Set([
    ...(profile.role_id ? [profile.role_id] : []),
    ...assignments.map((item) => item.role_id),
  ]))
  if (roleIds.length === 0) throw new Error('Tài khoản chưa được gán chức vụ.')

  const { data: roles, error: roleError } = await supabase
    .from('roles')
    .select('id,code,name,is_active')
    .in('id', roleIds)

  if (roleError) throw roleError
  const activeRoles = roles.filter((role) => role.is_active)
  if (activeRoles.length === 0) throw new Error('Các chức vụ hiện đang bị vô hiệu hóa.')
  const primaryRole = activeRoles.find((role) => role.id === profile.role_id) ?? activeRoles[0]

  const { data: mappings, error: mappingError } = await supabase
    .from('role_permissions')
    .select('permission_id')
    .in('role_id', activeRoles.map((role) => role.id))

  if (mappingError) throw mappingError

  const permissionIds = mappings.map((item) => item.permission_id)
  let permissionCodes: string[] = []

  if (permissionIds.length > 0) {
    const { data: permissions, error: permissionError } = await supabase
      .from('permissions')
      .select('code')
      .in('id', permissionIds)

    if (permissionError) throw permissionError
    permissionCodes = permissions.map((item) => item.code)
  }

  return {
    userId: profile.id,
    email: profile.email,
    fullName: profile.full_name,
    roleCode: primaryRole.code,
    roleName: activeRoles.map((role) => role.name).join(' · '),
    roleCodes: activeRoles.map((role) => role.code),
    roleNames: activeRoles.map((role) => role.name),
    permissions: new Set(permissionCodes),
  }
}

export function hasPermission(context: AppUserContext, code: string): boolean {
  return context.permissions.has(code)
}
