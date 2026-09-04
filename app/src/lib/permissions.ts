import { supabase } from './supabase'

export type AppUserContext = {
  userId: string
  email: string | null
  fullName: string | null
  roleCode: string
  roleName: string
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
  if (!profile.role_id) throw new Error('Tài khoản chưa được gán vai trò.')

  const { data: role, error: roleError } = await supabase
    .from('roles')
    .select('id,code,name,is_active')
    .eq('id', profile.role_id)
    .single()

  if (roleError) throw roleError
  if (!role.is_active) throw new Error('Vai trò hiện đang bị vô hiệu hóa.')

  const { data: mappings, error: mappingError } = await supabase
    .from('role_permissions')
    .select('permission_id')
    .eq('role_id', role.id)

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
    roleCode: role.code,
    roleName: role.name,
    permissions: new Set(permissionCodes),
  }
}

export function hasPermission(context: AppUserContext, code: string): boolean {
  return context.permissions.has(code)
}
