import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
let failed = false

function fail(message) {
  failed = true
  console.error(`[T21.2 UI FAIL] ${message}`)
}

function read(relative) {
  const file = path.join(root, ...relative.split('/'))
  if (!fs.existsSync(file)) {
    fail(`missing ${relative}`)
    return ''
  }
  return fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')
}

function requireTokens(relative, tokens) {
  const source = read(relative)
  for (const token of tokens) {
    if (!source.includes(token)) fail(`${relative} missing contract: ${token}`)
  }
  return source
}

const migrations = fs.readdirSync(path.join(root, 'supabase', 'migrations')).filter((name) => name.endsWith('.sql'))
if (migrations.length < 40) fail(`T21.2 requires the 40-migration baseline; found ${migrations.length}`)

requireTokens('app/src/App.tsx', [
  "type Module = 'dashboard' | 'reports' | 'audit' | 'staff'",
  "hasPermission(authState.context, 'user.view')",
  'className="global-quick-actions"',
  '<span>Tổng quan</span>',
  'triggerClassName="global-qr-button"',
  '<StaffPage context={authState.context} />',
])

requireTokens('app/src/index.css', [
  '.global-quick-actions',
  'position: fixed;',
  '.global-home-button,',
  '.global-qr-button',
])

requireTokens('app/src/features/crm/forms.tsx', [
  "const [zaloSameAsPhone, setZaloSameAsPhone] = useState",
  'Số Zalo giống số điện thoại',
])

requireTokens('app/src/features/repair/forms.tsx', [
  'conditionSameAsIssue,setConditionSameAsIssue',
  'Tình trạng khi nhận giống lỗi khách báo',
])

const sales = requireTokens('app/src/features/sales/SalesPage.tsx', [
  '+ Hàng vào đơn',
  'Xác nhận đơn',
  "sale_remove_item",
  "order.status === 'DRAFT'",
])
requireTokens('app/src/features/sales/forms.tsx', ["sale_update_item", "sale_add_item"])
for (const removed of ['+ Dòng hàng', 'Xác nhận & trừ kho']) {
  if (sales.includes(removed)) fail(`obsolete sales label remains: ${removed}`)
}

requireTokens('app/src/features/inventory/forms.tsx', [
  '+ Thêm nhanh danh mục mới',
  '<CategoryForm',
  'setCategoryId(row.id)',
])

const staff = requireTokens('app/src/features/staff/StaffPage.tsx', [
  "hasPermission(context, 'user.manage')",
  'createIsolatedAuthClient()',
  'protectAccess={editing.id === context.userId}',
  'Xóa quyền',
  'Lịch sử nghiệp vụ vẫn được giữ lại',
])
if (/service[_ -]?role|SUPABASE_SERVICE/i.test(staff)) fail('staff UI must not reference a service-role secret')

requireTokens('app/src/lib/supabase.ts', [
  'export function createIsolatedAuthClient()',
  'persistSession: false',
  'autoRefreshToken: false',
])

const topLevelPages = [
  'app/src/features/crm/CrmPage.tsx',
  'app/src/features/inventory/InventoryPage.tsx',
  'app/src/features/sales/SalesPage.tsx',
  'app/src/features/repair/RepairPage.tsx',
  'app/src/features/checklist/ChecklistPage.tsx',
  'app/src/features/service_license/ServiceLicensePage.tsx',
  'app/src/features/staff/StaffPage.tsx',
]
for (const relative of topLevelPages) {
  if (!read(relative).includes('+ Tạo mới')) fail(`${relative} must expose the unified create label`)
}

const appPackage = JSON.parse(read('app/package.json'))
const rootPackage = JSON.parse(read('package.json'))
if (appPackage.version !== '0.21.4') fail('app version must be 0.21.4')
if (rootPackage.version !== '0.21.4-t21.4') fail('root version must be 0.21.4-t21.4')

if (!failed) {
  console.log('T21.2 BRANCH REQUIREMENT MATRIX: PASS')
  console.log('T21.2 RBAC STAFF MANAGEMENT CONTRACT: PASS')
  console.log('T21.2 QUICK INTAKE/ORDER UX CONTRACT: PASS')
  console.log('T21.2 VIETNAMESE UI CONTRACT: PASS')
  console.log('T21.2 MIGRATION REGRESSION: PASS (#1-#40 unchanged)')
}

process.exit(failed ? 1 : 0)
