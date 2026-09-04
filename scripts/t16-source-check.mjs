import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())

function fail(message) {
  console.error(`[T16 SOURCE FAIL] ${message}`)
  process.exitCode = 1
}

function read(rel) {
  return fs.readFileSync(path.join(root, rel), 'utf8')
}

const pkg = JSON.parse(read('package.json'))
const appPkg = JSON.parse(read('app/package.json'))
const app = read('app/src/App.tsx')
const dash = read('app/src/features/dashboard/DashboardPage.tsx')
const audit = read('app/src/features/audit/AuditPage.tsx')
const types = read('app/src/lib/database.types.ts')
const m34 = read('supabase/migrations/20260831104002_t16_security_audit_core_hardening.sql')
const m35 = read('supabase/migrations/20260831104029_t16_audit_search_and_security_snapshot.sql')
const m36 = read('supabase/migrations/20260831105049_t16_audit_actor_history_independence.sql')
const debt = read('docs/T1_T15_DEBT_REGISTER.md')
const prePublic = read('docs/PRE_PUBLIC_AUTH_SECURITY.md')
const bootstrap = read('docs/T1_BOOTSTRAP_FIRST_ADMIN.sql')
const t15Restore = read('scripts/t15-restore-drill.ps1')
const lockScript = read('scripts/t16-dependency-lock.ps1')
const concurrency = read('scripts/t16-concurrency-check.ps1')

if (pkg.version !== '0.16.1-t16.1') fail(`Unexpected root version ${pkg.version}`)
if (appPkg.version !== '0.16.1') fail(`Unexpected app version ${appPkg.version}`)

const migrations = fs.readdirSync(path.join(root, 'supabase', 'migrations'))
  .filter((x) => x.endsWith('.sql')).sort()
if (migrations.length !== 36) fail(`Expected 36 migrations, found ${migrations.length}`)
if (migrations.at(-3) !== '20260831104002_t16_security_audit_core_hardening.sql') fail('T16 migration #34 mismatch.')
if (migrations.at(-2) !== '20260831104029_t16_audit_search_and_security_snapshot.sql') fail('T16 migration #35 mismatch.')
if (migrations.at(-1) !== '20260831105049_t16_audit_actor_history_independence.sql') fail('T16 migration #36 mismatch.')

for (const token of [
  'sequence_counters_no_direct_access',
  'revoke all on table private.sequence_counters',
  'set search_path = \'\'',
  'audit_logs_reject_mutation',
  'trg_audit_logs_no_update_delete',
  'trg_audit_logs_no_truncate',
  'revoke insert, update, delete, truncate',
]) {
  if (!m34.includes(token)) fail(`T16 core migration missing: ${token}`)
}

for (const token of [
  'drop constraint if exists audit_logs_actor_user_id_fkey',
  'Immutable historical Auth user UUID',
]) {
  if (!m36.includes(token)) fail(`T16 actor-history migration missing: ${token}`)
}

for (const token of [
  'private.audit_search_impl',
  'public.audit_search',
  'p_limit integer default 100',
  'Audit limit must be between 1 and 200',
  'Audit date range must not exceed 366 days',
  'private.security_audit_snapshot_impl',
  'public.security_audit_snapshot',
  'service_role_direct_table_privilege',
]) {
  if (!m35.includes(token)) fail(`T16 audit API migration missing: ${token}`)
}

if (!app.includes("hasPermission(authState.context, 'audit.view')")) fail('App missing audit.view route gate.')
if (!app.includes("module === 'audit' && canOpenAudit")) fail('App missing Audit route.')
if (!dash.includes("key: 'audit'") || !dash.includes("short: 'Audit'")) fail('Dashboard missing Audit navigation.')
if (!types.includes('audit_search: {') || !types.includes('security_audit_snapshot: {')) fail('database.types missing T16 RPCs.')

for (const token of [
  "supabase.rpc('audit_search'",
  "supabase.rpc('security_audit_snapshot'",
  'overflow-x-auto',
  'min-w-[1000px]',
  'grid grid-cols-2',
  'sm:grid-cols-3',
  'xl:grid-cols-6',
  'max-w-7xl',
  'Leaked Password Protection',
  'append_only_guards',
]) {
  if (!audit.includes(token)) fail(`AuditPage missing token: ${token}`)
}
if (/\.from\(\s*['"]/.test(audit)) fail('AuditPage must use bounded RPCs, not direct table reads.')

for (const forbidden of [
  'SUPABASE_SERVICE_ROLE_KEY',
  'sb_secret_',
  'TELEGRAM_BOT_TOKEN',
  'ZALO_ACCESS_TOKEN',
  'EMAIL_API_KEY',
]) {
  if (audit.includes(forbidden)) fail(`Audit frontend contains forbidden secret token: ${forbidden}`)
}

for (const token of [
  'D07',
  'D08',
  'PLAN LIMITATION',
  'EXTERNAL CREDENTIAL LIMITATION',
  'ACCEPTED INFO',
  'FIXED in T15 v1.3',
]) {
  if (!debt.includes(token)) fail(`Debt register missing disposition: ${token}`)
}

if (!prePublic.includes('Pro+')) fail('Pre-public Auth checklist missing Pro+ leaked-password plan gate.')
if (bootstrap.includes('TODO')) fail('T1 bootstrap helper still contains stale TODO.')

for (const forbidden of ['[IO.Path]::GetRelativePath','[System.IO.Path]::GetRelativePath','pg_terminate_backend','$markerJson']) {
  if (t15Restore.includes(forbidden)) fail(`Resolved T15 regression reintroduced: ${forbidden}`)
}

for (const token of [
  "'root'",
  "'app'",
  "'worker'",
  "'install','--package-lock-only'",
  "'ci','--no-audit','--no-fund'",
  'T16 DEPENDENCY LOCK CHECK: PASS',
  'T16_DEPENDENCY_LOCKS_',
]) {
  if (!lockScript.includes(token)) fail(`Dependency-lock gate missing: ${token}`)
}

if (/^\s*\|/m.test(concurrency)) {
  fail('PowerShell parser regression: t16-concurrency-check.ps1 contains a line-leading pipeline operator.')
}
if (/\$issueCount\s*=\s*\(\s*\r?\n/.test(concurrency)) {
  fail('PowerShell parser regression: old multiline issueCount expression returned.')
}
if (!concurrency.includes('$issueCountLines = @(Invoke-DockerSql -Sql $issueCountSql)')) {
  fail('PowerShell parser-safe issueCount query block missing.')
}

for (const token of [
  '16 simultaneous sequence calls',
  'public.inventory_issue',
  'Insufficient stock',
  'exactly one transaction succeeded',
  'T16 CONCURRENCY CHECK: PASS',
]) {
  if (!concurrency.includes(token)) fail(`Concurrency gate missing: ${token}`)
}

if (!process.exitCode) {
  console.log('T16 T1-T15 debt register/source reconciliation: PASS')
  console.log('T16 sequence least-privilege source contract: PASS')
  console.log('T16 append-only audit source contract: PASS')
  console.log('T16 bounded audit RPC + responsive UI contract: PASS')
  console.log('T16 dependency-lock/concurrency gate contract: PASS')
  console.log('T16 SECURITY SOURCE CHECK: PASS')
}
