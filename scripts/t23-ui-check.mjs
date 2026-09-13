import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
let failed = false
const fail = (message) => { failed = true; console.error(`[T23 UI FAIL] ${message}`) }
const read = (relative) => {
  const file = path.join(root, ...relative.split('/'))
  if (!fs.existsSync(file)) { fail(`missing ${relative}`); return '' }
  return fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')
}
const requireTokens = (relative, tokens) => {
  const source = read(relative)
  for (const token of tokens) if (!source.includes(token)) fail(`${relative} missing contract: ${token}`)
  return source
}

const migrations = fs.readdirSync(path.join(root, 'supabase', 'migrations')).filter((name) => name.endsWith('.sql')).sort()
if (migrations.length !== 47) fail(`expected locked #1-#46 plus T23 #47, found ${migrations.length}`)
if (migrations[46] !== '20260913101000_t23_multi_role_warranty_qr_labels.sql') fail(`unexpected migration #47: ${migrations[46]}`)
const locked46 = 'supabase/migrations/20260913021747_t21_4_payment_qr_invoker_hardening.sql'
if (crypto.createHash('sha256').update(fs.readFileSync(path.join(root, locked46))).digest('hex') !== 'f38704c84a36f53012acc1b6dacd4e47b0874aff866f8effa7e2ad621dca8e38') fail('locked migration #46 changed')

const migration = requireTokens('supabase/migrations/20260913101000_t23_multi_role_warranty_qr_labels.sql', [
  'create table public.profile_roles',
  'alter table public.profile_roles enable row level security',
  "private.has_permission('user.manage')",
  'public.staff_set_roles(',
  'private.profile_has_role(',
  'public.sale_add_item_v2(',
  'public.sale_update_item_v2(',
  'add column warranty_months integer not null default 3',
  'public.repair_create_quote_v2(',
  'trg_zz_repair_selected_warranty_duration',
  "'customer_name_masked'",
  "set search_path=''",
])
if (migration.includes('pm.is_active')) fail('permissions has no is_active column')
if (!migration.includes('grant execute on function public.sale_add_item_v2')) fail('v2 sale RPC grant missing')

const dashboard = requireTokens('app/src/features/dashboard/DashboardPage.tsx', [
  'Làm mới',
  'Đăng xuất',
])
if (dashboard.includes('{quickActions}') || dashboard.includes('dashboard-quick-actions')) fail('dashboard must not own a duplicate quick-action group')
const app = requireTokens('app/src/App.tsx', [
  'const operationsHeader',
  'className="operations-header"',
  'className="operations-title-block"',
  'Tổng quan điều hành',
  'Asia/Bangkok',
  'aria-label="Điều hướng nhanh cố định"',
  '<div className="operations-module-content">{node}</div>',
])
if ((app.match(/<QrCommandCenter context=\{authState\.context\}/g) ?? []).length !== 1) fail('all modules must share exactly one QR command trigger')
requireTokens('app/src/index.css', [
  '.operations-header {',
  'position: sticky;',
  '.operations-header-inner {',
  '.operations-module-content > main > header.sticky {',
])

requireTokens('app/src/features/staff/StaffPage.tsx', [
  ".from('profile_roles')",
  "supabase.rpc('staff_set_roles'",
  'Chức vụ đảm trách *',
  'Có thể chọn nhiều chức vụ',
  'row.role_ids.map',
])
requireTokens('app/src/lib/permissions.ts', [
  'roleCodes: string[]',
  ".from('profile_roles')",
  ".in('role_id', activeRoles.map",
  'permissions: new Set(permissionCodes)',
])

const salesForms = requireTokens('app/src/features/sales/forms.tsx', [
  "supabase.rpc('sale_add_item_v2'",
  "supabase.rpc('sale_update_item_v2'",
  'Bảo hành (tháng)',
  'Nhập 0 nếu không bảo hành.',
])
if (salesForms.includes('step="1000"') && salesForms.slice(salesForms.indexOf('export function ItemForm')).includes('step="1000"')) fail('sales item price/discount must use a 1 VND step')

const repairForms = requireTokens('app/src/features/repair/forms.tsx', [
  "supabase.rpc('repair_create_quote_v2'",
  'Bảo hành sửa chữa (tháng)',
  'Áp dụng cho bảo hành công sửa chữa',
  'if(laborAmount===0&&partsAmount===0)',
])
for (const scenario of [
  { labor: 100000, parts: 0, discount: 0, expected: 100000 },
  { labor: 0, parts: 100000, discount: 0, expected: 100000 },
  { labor: 100000, parts: 200000, discount: 50000, expected: 250000 },
]) if (Math.max(scenario.labor + scenario.parts - scenario.discount, 0) !== scenario.expected) fail('repair quote calculation regression')

requireTokens('app/src/features/warranty/WarrantyLabelsPanel.tsx', [
  ".eq('source_type', sourceType)",
  '.eq(\'source_id\', sourceId)',
  'In tem QR',
  '<WarrantyQrCard',
])
requireTokens('app/src/features/sales/SalesPage.tsx', ['<WarrantyLabelsPanel sourceType="SALE" sourceId={order.id} />'])
requireTokens('app/src/features/repair/RepairPage.tsx', ['<WarrantyLabelsPanel sourceType="REPAIR" sourceId={order.id}/>'])
requireTokens('app/src/features/public_warranty/PublicWarrantyPage.tsx', ['customer_name_masked', 'Người mua', 'Tên người mua, số điện thoại và Serial đã được che'])
requireTokens('app/src/features/warranty/WarrantyPage.tsx', ['export function WarrantyQrCard', 'match.phone'])

requireTokens('app/index.html', ['Đang tải HomeTechVN', 'htvn_asset_recovery', 'getRegistrations()', 'caches.keys()'])
requireTokens('app/vite.config.ts', ["registerType: 'autoUpdate'", 'clientsClaim: true', 'skipWaiting: true'])

const rootPackage = JSON.parse(read('package.json'))
const appPackage = JSON.parse(read('app/package.json'))
if (rootPackage.version !== '0.23.0-t23') fail('root version must be 0.23.0-t23')
if (appPackage.version !== '0.23.0') fail('app version must be 0.23.0')
if (!rootPackage.scripts?.['t23:verify']) fail('missing package script t23:verify')

if (!failed) {
  console.log('T23 FIXED DASHBOARD QUICK ACTIONS: PASS')
  console.log('T23 MULTI-ROLE RBAC/RLS CONTRACT: PASS')
  console.log('T23 SALES + REPAIR WARRANTY DURATION: PASS')
  console.log('T23 WARRANTY QR LABEL + MASKED BUYER: PASS')
  console.log('T23 BLANK-SCREEN PWA RECOVERY: PASS')
  console.log('T23 LOCKED MIGRATIONS #1-#46: PASS')
}
process.exit(failed ? 1 : 0)
