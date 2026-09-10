import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
function fail(message) {
  console.error(`[T13 UI FAIL] ${message}`)
  process.exitCode = 1
}
function read(rel) {
  return fs.readFileSync(path.join(root, rel), 'utf8')
}

const app = read('app/src/App.tsx')
const dashboard = read('app/src/features/dashboard/DashboardPage.tsx')
const reports = read('app/src/features/reports/ReportsPage.tsx')
const types = read('app/src/lib/database.types.ts')

if (!app.includes("type Module = 'dashboard' | 'reports'")) fail('Reports module missing from App module union.')
if (!app.includes("hasPermission(authState.context, 'report.view')")) fail('Reports route missing report.view gate.')
if (!app.includes("module === 'reports' && canOpenReports")) fail('Reports route missing.')
if (!app.includes('<ReportsPage context={authState.context} />')) fail('Reports page render missing.')
if (!dashboard.includes("key: 'reports'") || !dashboard.includes("short: 'Báo cáo'")) fail('Dashboard quick navigation missing Reports.')
if (!types.includes('report_snapshot: {')) fail('database.types.ts missing report_snapshot RPC.')

if (!reports.includes("supabase.rpc('report_snapshot'")) fail('Reports must use report_snapshot RPC.')
if (/\.from\(\s*['"]/.test(reports)) fail('Reports must not read tables directly.')
for (const token of [
  '[7, 30, 90, 365]',
  "'DAY' | 'WEEK' | 'MONTH'",
  'Xuất CSV',
  'window.print()',
  'downloadCsv(',
  'Lợi nhuận',
  'cost_coverage_revenue_pct',
  'excluded_revenue_missing_cost',
  'Gross profit đã biết',
  'Không có dữ liệu trong kỳ.',
]) {
  if (!reports.includes(token)) fail(`Reports missing required feature token: ${token}`)
}

for (const token of [
  'grid grid-cols-2',
  'overflow-x-auto',
  'sm:grid-cols-3',
  'lg:grid-cols-4',
  'max-w-7xl',
  'sticky top-0',
]) {
  if (!reports.includes(token)) fail(`Reports missing responsive token: ${token}`)
}

const tableMatches = [...reports.matchAll(/<table\b/g)]
if (tableMatches.length < 5) fail(`Reports expected at least 5 tables, found ${tableMatches.length}.`)
for (const match of tableMatches) {
  const before = reports.slice(Math.max(0, match.index - 280), match.index)
  if (!before.includes('overflow-x-auto')) {
    fail(`Reports table without nearby overflow-x-auto wrapper @ ${match.index}`)
  }
}

for (const forbidden of [
  'SUPABASE_SERVICE_ROLE_KEY',
  'sb_secret_',
  'TELEGRAM_BOT_TOKEN',
  'ZALO_ACCESS_TOKEN',
  'EMAIL_API_KEY',
]) {
  if (reports.includes(forbidden)) fail(`Reports frontend contains forbidden secret token: ${forbidden}`)
}

if (!process.exitCode) {
  console.log(`T13 report tables responsive: PASS (${tableMatches.length} tables)`)
  console.log('T13 report RPC-only data access: PASS')
  console.log('T13 profit coverage / missing-cost warnings: PASS')
  console.log('T13 CSV / print / date range controls: PASS')
  console.log('T13 RESPONSIVE UI CHECK: PASS')
}
