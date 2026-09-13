import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
let failed = false

function fail(message) {
  failed = true
  console.error(`[T21.4 UI FAIL] ${message}`)
}
function read(relative) {
  const file = path.join(root,...relative.split('/'))
  if (!fs.existsSync(file)) { fail(`missing ${relative}`); return '' }
  return fs.readFileSync(file,'utf8').replace(/^\uFEFF/,'')
}
function hash(relative) {
  return crypto.createHash('sha256').update(fs.readFileSync(path.join(root,...relative.split('/')))).digest('hex')
}
function requireTokens(relative,tokens) {
  const source = read(relative)
  for (const token of tokens) if (!source.includes(token)) fail(`${relative} missing contract: ${token}`)
  return source
}

const t17 = read('docs/T17_FINAL_INTEGRITY.txt')
const locked = new Map([...t17.matchAll(/^([a-f0-9]{64})  (supabase\/migrations\/[^\r\n]+)$/gm)].map((match) => [match[2],match[1]]))
if (locked.size !== 36) fail(`expected 36 T1-T17 locked migrations, found ${locked.size}`)
for (const [relative,digest] of locked) if (hash(relative) !== digest) fail(`locked migration changed: ${relative}`)
const additionalLocked = new Map([
  ['supabase/migrations/20260904014416_t19_universal_qr_operations.sql','6b6a3d2c9acd88cbdd8809fa9af5349d883f7b4b947974406d30991d90faaee6'],
  ['supabase/migrations/20260904154351_t20_private_cost_rls_hardening.sql','36ee28782e869769e05e8fe3ed2240184e724885f18d718e53d234cc4b21c721'],
  ['supabase/migrations/20260909052415_t20_operational_logic_integrity.sql','d23f2a90b5050f04d34d112ab4d10c9d7b4500aed187bb0a11a380c6c2ae2847'],
  ['supabase/migrations/20260909053211_t20_rpc_surface_and_qr_index_hardening.sql','49cd60a5bd9c7db5569d2d36c7143168d191854338b98c71b93fab70d78162b0'],
  ['supabase/migrations/20260910145644_t22_auto_repair_warranty.sql','d6d12d65be7f832b06a1d28f2bb47f27db2fb95f26021b52481be8f718bd7383'],
  ['supabase/migrations/20260910153258_t22_integrity_rpc_surface_hardening.sql','ad3b54d5e1c4c5dfa99f18e8ce875834b76d29ac60593aa89aee848677e44bd0'],
  ['supabase/migrations/20260910153627_t22_remove_manual_repair_warranty_rpc.sql','a49c14c781b2e531bc65a23bfcb5dae3728f7e128dfd46e4429b536ee6ed4942'],
  ['supabase/migrations/20260910155015_t22_remove_manual_sale_warranty_rpc.sql','acf0e8aa16d93a95c37e40371d95d3b96f46cd0f6d148eb5a5a3ec6e9045816c'],
  ['supabase/migrations/20260913021403_t21_4_payment_vietqr_config.sql','f8826287edd7bdc37065e9b93d0cb737e471408407b2e1f086375dcaab1cc2c9'],
])
for (const [relative,digest] of additionalLocked) if (hash(relative) !== digest) fail(`locked migration changed: ${relative}`)

const migrations = fs.readdirSync(path.join(root,'supabase','migrations')).filter((name) => name.endsWith('.sql')).sort()
if (migrations.length !== 46) fail(`expected production #1-#45 plus T21.4 hardening #46, found ${migrations.length}`)
for (const [index,name] of [
  [40,'20260910145644_t22_auto_repair_warranty.sql'],
  [41,'20260910153258_t22_integrity_rpc_surface_hardening.sql'],
  [42,'20260910153627_t22_remove_manual_repair_warranty_rpc.sql'],
  [43,'20260910155015_t22_remove_manual_sale_warranty_rpc.sql'],
  [44,'20260913021403_t21_4_payment_vietqr_config.sql'],
  [45,'20260913021747_t21_4_payment_qr_invoker_hardening.sql'],
]) if (migrations[index] !== name) fail(`unexpected migration #${index + 1}: ${migrations[index]}`)

const sql = requireTokens('supabase/migrations/20260913021403_t21_4_payment_vietqr_config.sql',[
  "'payment.vietqr.config'",
  "private.has_permission('payment.create')",
  "private.has_permission('settings.manage')",
  'security definer',
  "set search_path=''",
  'public.payment_qr_config_get()',
  'public.payment_qr_configure(',
  'from public,anon,authenticated',
  'to authenticated',
  "'enabled',false",
  "'template','compact2'",
])
const hardening = requireTokens('supabase/migrations/20260913021747_t21_4_payment_qr_invoker_hardening.sql',[
  'create policy settings_payment_qr_select',
  "key='payment.vietqr.config'",
  "private.has_permission('payment.create')",
  'security invoker',
  'drop function if exists private.payment_qr_configure_impl',
  'drop function if exists private.payment_qr_config_get_impl',
  'from public,anon,authenticated',
  'to authenticated',
])
if (/password|otp|pin|service[_-]?role|secret[_-]?key/i.test((sql+hardening).replace(/non-secret/gi,''))) fail('payment QR migrations must not contain or request banking secrets')

const qr = requireTokens('app/src/features/sales/PaymentQr.tsx',[
  "supabase.rpc('payment_qr_config_get')",
  "supabase.rpc('payment_qr_configure'",
  'https://img.vietqr.io/image/',
  'amount:String(roundedAmount)',
  'addInfo:transferContent',
  'accountName:config.account_name',
  "`HTVN ${orderCode}`",
  'referrerPolicy="no-referrer"',
  'QR chỉ điền sẵn yêu cầu chuyển khoản.',
  'Chỉ xác nhận thu tiền sau khi đã kiểm tra tiền thực sự vào tài khoản.',
])
if (qr.includes('sale_record_payment')) fail('rendering a payment QR must never record or confirm payment')

requireTokens('app/src/features/sales/forms.tsx',[
  "initialMethod = 'CASH'",
  "method === 'BANK_TRANSFER'",
  '<PaymentQr amount={amount} orderCode={order.order_code} canManageSettings={canManageSettings} />',
  'Xác nhận đã nhận đủ',
])
requireTokens('app/src/features/sales/SalesPage.tsx',[
  "'payment-qr'",
  '>QR thanh toán</button>',
  "initialMethod={modal === 'payment-qr' ? 'BANK_TRANSFER' : 'CASH'}",
  "hasPermission(context, 'settings.manage')",
])
requireTokens('app/src/features/repair/RepairPage.tsx',[
  "['READY','RETURNED'].includes(order.status)",
  'paymentQrAmount=Number(order.final_amount||order.approved_amount||0)',
  '<PaymentQr amount={paymentQrAmount} orderCode={order.repair_code} canManageSettings={canManageSettings}/>',
  'QR thanh toán {money(paymentQrAmount)}',
])
requireTokens('app/src/lib/database.types.ts',['payment_qr_config_get:','payment_qr_configure:'])

const rootPackage = JSON.parse(read('package.json'))
const appPackage = JSON.parse(read('app/package.json'))
if (rootPackage.version !== '0.21.4-t21.4') fail('root version must be 0.21.4-t21.4')
if (appPackage.version !== '0.21.4') fail('app version must be 0.21.4')

if (!failed) {
  console.log('T21.4 PRODUCTION MIGRATIONS #1-#45 ALIGNED: PASS')
  console.log('T21.4 SECURITY INVOKER HARDENING #46: PASS')
  console.log('T21.4 PAYMENT QR CONFIG/RBAC CONTRACT: PASS')
  console.log('T21.4 EXACT BALANCE + ORDER REFERENCE QR: PASS')
  console.log('T21.4 REPAIR HANDOVER QR AMOUNT: PASS')
  console.log('T21.4 NO AUTOMATIC PAYMENT CONFIRMATION: PASS')
}

process.exit(failed ? 1 : 0)
