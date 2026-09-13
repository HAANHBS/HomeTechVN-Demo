import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
let failed = false

function fail(message) {
  failed = true
  console.error(`[T21 UI FAIL] ${message}`)
}

function read(relative) {
  const file = path.join(root, ...relative.split('/'))
  if (!fs.existsSync(file)) {
    fail(`missing ${relative}`)
    return ''
  }
  return fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')
}

function hash(relative) {
  return crypto.createHash('sha256').update(fs.readFileSync(path.join(root, ...relative.split('/')))).digest('hex')
}

function requireTokens(relative, tokens) {
  const source = read(relative)
  for (const token of tokens) {
    if (!source.includes(token)) fail(`${relative} missing contract: ${token}`)
  }
  return source
}

const t17Manifest = read('docs/T17_FINAL_INTEGRITY.txt')
const lockedT1T16 = new Map(
  [...t17Manifest.matchAll(/^([a-f0-9]{64})  (supabase\/migrations\/[^\r\n]+)$/gm)]
    .map((match) => [match[2], match[1]]),
)
if (lockedT1T16.size !== 36) fail(`expected 36 locked T1–T16 migrations, found ${lockedT1T16.size}`)
for (const [relative, digest] of lockedT1T16) {
  if (read(relative) && hash(relative) !== digest) fail(`locked migration changed: ${relative}`)
}

const t19Manifest = read('docs/T19_FINAL_INTEGRITY.txt')
const t19Match = t19Manifest.match(/^([a-f0-9]{64})  (supabase\/migrations\/20260904014416_t19_universal_qr_operations\.sql)$/m)
if (!t19Match || hash(t19Match[2]) !== t19Match[1]) fail('locked T19 migration #37 changed')

for (const [relative, digest] of [
  ['supabase/migrations/20260904154351_t20_private_cost_rls_hardening.sql', '36ee28782e869769e05e8fe3ed2240184e724885f18d718e53d234cc4b21c721'],
  ['supabase/migrations/20260909052415_t20_operational_logic_integrity.sql', 'd23f2a90b5050f04d34d112ab4d10c9d7b4500aed187bb0a11a380c6c2ae2847'],
  ['supabase/migrations/20260909053211_t20_rpc_surface_and_qr_index_hardening.sql', '49cd60a5bd9c7db5569d2d36c7143168d191854338b98c71b93fab70d78162b0'],
]) {
  if (hash(relative) !== digest) fail(`locked T20 migration changed: ${relative}`)
}

const migrations = fs.readdirSync(path.join(root, 'supabase', 'migrations')).filter((name) => name.endsWith('.sql')).sort()
if (migrations.length < 40) fail(`T21.1 requires the 40-migration baseline; found ${migrations.length}`)
if (!failed) console.log('T21 LOCKED MIGRATION REGRESSION: PASS (#1-#40 unchanged)')

const picker = requireTokens('app/src/features/crm/forms.tsx', [
  'export function CustomerQuickPicker',
  'export function CustomerDeviceQuickPicker',
  'Tìm tên, mã khách, điện thoại, Zalo hoặc email…',
  'Tìm mã thiết bị, serial, hãng, model…',
  '+ Thêm khách hàng mới',
  '+ Thêm thiết bị mới',
  "eq('key', 'crm.device_types')",
  'createPortal(content, document.body)',
  'onSubmit={(event) => event.stopPropagation()}',
  'onChange(customer.id)',
  'onDeviceChange(device.id)',
])
if (/device[_ ]?password|access[_ ]?password|p_password/i.test(picker)) fail('quick intake must not capture a device/customer password')

requireTokens('app/src/features/sales/forms.tsx', [
  '<CustomerQuickPicker customers={customers}',
  'Hãy chọn hoặc thêm nhanh khách hàng trước khi tạo đơn.',
])
requireTokens('app/src/features/sales/SalesPage.tsx', [
  "canCreateCustomer={hasPermission(context, 'customer.create')}",
])
requireTokens('app/src/features/repair/forms.tsx', [
  '<CustomerDeviceQuickPicker customers={customers}',
  'Hãy chọn hoặc thêm nhanh thiết bị trước khi tiếp nhận.',
  'deviceRequired',
])
requireTokens('app/src/features/repair/RepairPage.tsx', [
  "canCreateCustomer={hasPermission(context,'customer.create')}",
  "canCreateDevice={hasPermission(context,'device.create')}",
])
requireTokens('supabase/tests/t21_demo_acceptance.sql', [
  "key = 'demo.t20.hosted'",
  "value->>'mode' = 'HOSTED_DEMO'",
  "set local role authenticated",
  "insert into public.customers",
  "insert into public.customer_devices",
  "reset role;\nrollback;",
  'T21 HOSTED QUICK CUSTOMER/DEVICE ACCEPTANCE: PASS',
  'T21 HOSTED FAKE-DATA ROLLBACK: PASS',
])
const serviceLicense = requireTokens('app/src/features/service_license/ServiceLicensePage.tsx', [
  'function ScheduleForm({',
  'function LicenseForm({',
  '<CustomerDeviceQuickPicker customers={customers}',
  "canCreateCustomer={hasPermission(context, 'customer.create')}",
  "canCreateDevice={hasPermission(context, 'device.create')}",
])
if ((serviceLicense.match(/<CustomerDeviceQuickPicker customers=\{customers\}/g) ?? []).length !== 2) {
  fail('service schedule and license must both use the shared customer/device picker')
}

const rootPackage = JSON.parse(read('package.json'))
const appPackage = JSON.parse(read('app/package.json'))
const rootLock = JSON.parse(read('package-lock.json'))
const appLock = JSON.parse(read('app/package-lock.json'))
if (rootPackage.version !== '0.23.0-t23' || rootLock.version !== rootPackage.version || rootLock.packages?.['']?.version !== rootPackage.version) {
  fail('root package/lock version mismatch')
}
if (appPackage.version !== '0.23.0' || appLock.version !== appPackage.version || appLock.packages?.['']?.version !== appPackage.version) {
  fail('app package/lock version mismatch')
}
for (const script of ['t21:ui-check', 't21:verify', 't21.2:ui-check', 't21.3:ui-check']) {
  if (!rootPackage.scripts?.[script]) fail(`missing package script ${script}`)
}

if (!failed) {
  console.log('T21 SHARED CUSTOMER/DEVICE PICKER CONTRACT: PASS')
  console.log('T21 RBAC-GATED QUICK CREATE CONTRACT: PASS')
  console.log('T21 NESTED FORM/MODAL SAFETY CONTRACT: PASS')
  console.log('T21 UI SOURCE CHECK: PASS')
}

process.exit(failed ? 1 : 0)
