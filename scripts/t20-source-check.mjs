import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
let failed = false

function fail(message) {
  failed = true
  console.error(`[T20 SOURCE FAIL] ${message}`)
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
  return crypto
    .createHash('sha256')
    .update(fs.readFileSync(path.join(root, ...relative.split('/'))))
    .digest('hex')
}
function requireTokens(relative, tokens) {
  const text = read(relative)
  for (const token of tokens) {
    if (!text.includes(token)) fail(`${relative} missing contract: ${token}`)
  }
}

const t17Manifest = read('docs/T17_FINAL_INTEGRITY.txt')
const lockedT1T16 = new Map(
  [...t17Manifest.matchAll(/^([a-f0-9]{64})  (supabase\/migrations\/[^\r\n]+)$/gm)]
    .map((match) => [match[2], match[1]]),
)
if (lockedT1T16.size !== 36) {
  fail(`T17 integrity manifest must describe 36 migrations, found ${lockedT1T16.size}`)
}
for (const [relative, digest] of lockedT1T16) {
  if (read(relative) && hash(relative) !== digest) fail(`locked migration changed: ${relative}`)
}

const t19Manifest = read('docs/T19_FINAL_INTEGRITY.txt')
const t19Match = t19Manifest.match(
  /^([a-f0-9]{64})  (supabase\/migrations\/20260904014416_t19_universal_qr_operations\.sql)$/m,
)
if (!t19Match) fail('T19 locked migration hash is missing from integrity manifest')
else if (read(t19Match[2]) && hash(t19Match[2]) !== t19Match[1]) {
  fail('locked T19 migration #37 changed')
}

const migrations = fs
  .readdirSync(path.join(root, 'supabase', 'migrations'))
  .filter((name) => name.endsWith('.sql'))
  .sort()
if (migrations.length !== 38) {
  fail(`expected locked #1-#37 plus T20 #38, found ${migrations.length}`)
}
const t20Migrations = migrations.filter((name) => /_t20_/i.test(name))
if (
  t20Migrations.length !== 1
  || t20Migrations[0] !== '20260904154351_t20_private_cost_rls_hardening.sql'
) fail(`unexpected T20 migration set: ${t20Migrations.join(', ') || '(none)'}`)
if (!failed) console.log('T20 LOCKED MIGRATION REGRESSION: PASS (#1-#37 unchanged; #38 isolated)')

const migration = 'supabase/migrations/20260904154351_t20_private_cost_rls_hardening.sql'
requireTokens(migration, [
  'alter table private.sales_order_item_costs enable row level security',
  'alter table private.repair_part_costs enable row level security',
  'create policy sales_order_item_costs_no_direct_access',
  'create policy repair_part_costs_no_direct_access',
  'to public\nusing (false)\nwith check (false)',
  'from public, anon, authenticated',
])
const migrationSql = read(migration)
for (const [table, policy] of [
  ['sales_order_item_costs', 'sales_order_item_costs_no_direct_access'],
  ['repair_part_costs', 'repair_part_costs_no_direct_access'],
]) {
  const pattern = new RegExp(
    `create policy\\s+${policy}\\s+on\\s+private\\.${table}\\s+for all\\s+to public\\s+using \\(false\\)\\s+with check \\(false\\)`,
    'i',
  )
  if (!pattern.test(migrationSql)) fail(`${table} deny-all policy is missing or unsafe`)
}
if (!failed) console.log('T20 PRIVATE COST RLS SOURCE CONTRACT: PASS')

const hostedData = read('supabase/t20_hosted_demo_data.sql')
for (const token of [
  'T20 hosted demo refuses a non-empty business database',
  "'contains_real_customer_data',false",
  "'mode','HOSTED_DEMO'",
  "set_config(\n  'request.jwt.claim.sub'",
  'set local role authenticated',
  'reset role;\ncommit;',
]) {
  if (!hostedData.includes(token)) fail(`hosted demo data missing safety contract: ${token}`)
}
if (
  /sb_(?:secret|publishable)_|service[_-]?role|password|@hometechvn\.example/i.test(
    hostedData.replace(/No passwords/i, ''),
  )
) fail('hosted demo data contains credential or local-demo material')
if (hostedData.indexOf("'request.jwt.claim.sub'") > hostedData.indexOf('set local role authenticated')) {
  fail('hosted demo must set JWT subject before SET ROLE')
}
if (!failed) console.log('T20 HOSTED DEMO DATA SAFETY: PASS')

const rootPackage = JSON.parse(read('package.json'))
const appPackage = JSON.parse(read('app/package.json'))
if (rootPackage.version !== '0.20.0-t20.0' || appPackage.version !== '0.20.0') {
  fail('T20 package versions are inconsistent')
}
for (const name of [
  't20:configure',
  't20:hosted-check',
  't20:source-check',
  't20:verify',
]) {
  if (!rootPackage.scripts?.[name]) fail(`missing package script ${name}`)
}

requireTokens('scripts/t20-runtime-verify.mjs', [
  'maxChildBuffer=64*1024*1024',
  'CHILD OUTPUT (last 160 lines)',
  'T20_FAILURE_${stamp}.txt',
  '[REDACTED_JWT]',
  '[REDACTED_SUPABASE_KEY]',
  'T20_LOCAL_VERIFY_${stamp}.txt',
  'T20 CLEAN BASELINE AFTER VERIFY: PASS',
  't20-hosted-readiness.mjs',
])
requireTokens('scripts/t20-hosted-readiness.mjs', [
  'T20 hosted readiness refuses a local Supabase URL',
  'Secret/service-role key is forbidden in the browser app',
  'Anonymous caller unexpectedly executed internal QR resolver',
  'T20 HOSTED PUBLIC WARRANTY CONTRACT: PASS',
])
requireTokens('scripts/t20-configure.mjs', [
  'VITE_HOMETECHVN_HOSTED_DEMO=true',
  'Never put sb_secret or service_role material here',
])
requireTokens('supabase/tests/t20_verify.sql', [
  'T20 QR DATABASE SECURITY CHECK: PASS',
  'T20 PRIVATE COST RLS CHECK: PASS',
  'T20 private cost direct privilege regression',
])
requireTokens('app/src/features/demo/DemoModeBanner.tsx', [
  'VITE_HOMETECHVN_HOSTED_DEMO',
  'HOSTED DEMO · DỮ LIỆU HOÀN TOÀN GIẢ ĐỊNH',
])

for (const relative of [
  'app/src/App.tsx',
  'app/src/features/qr/QrCommandCenter.tsx',
  'app/src/features/demo/DemoModeBanner.tsx',
]) {
  if (/sb_secret_|service[_-]?role/i.test(read(relative))) {
    fail(`browser source contains server-secret marker: ${relative}`)
  }
}

if (!failed) {
  console.log('T20 KNOWN-ERROR REGRESSION CONTRACT: PASS')
  console.log('T20 SOURCE CHECK: PASS')
}
process.exit(failed ? 1 : 0)
