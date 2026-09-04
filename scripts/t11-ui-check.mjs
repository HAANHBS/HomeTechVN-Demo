import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
const appSrc = path.join(root, 'app', 'src')

function fail(message) {
  console.error(`[T11 UI FAIL] ${message}`)
  process.exitCode = 1
}

function read(relative) {
  return fs.readFileSync(path.join(root, relative), 'utf8')
}

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name)
    return entry.isDirectory() ? walk(full) : [full]
  })
}

const css = read('app/src/index.css')
for (const token of [
  'min-height: 44px',
  ':focus-visible',
  'touch-action: manipulation',
  '@media (max-width: 640px)',
  '@media (pointer: coarse)',
  '@media (prefers-reduced-motion: reduce)',
  '.global-home-button',
  'env(safe-area-inset-bottom)',
]) {
  if (!css.includes(token)) fail(`index.css missing responsive/accessibility token: ${token}`)
}

const dashboard = read('app/src/features/dashboard/DashboardPage.tsx')
for (const token of [
  'grid grid-cols-2',
  'sm:grid-cols-3',
  'lg:grid-cols-4',
  'overflow-x-auto',
  'sticky top-0',
  "([7, 30, 90] as const)",
  "supabase.rpc('dashboard_snapshot'",
]) {
  if (!dashboard.includes(token)) fail(`Dashboard missing responsive/functional token: ${token}`)
}

const app = read('app/src/App.tsx')
if (!app.includes("useState<Module>('dashboard')")) fail('Dashboard is not the default module.')
if (!app.includes('global-home-button')) fail('Global one-tap Dashboard launcher missing.')

let tableCount = 0
for (const file of walk(appSrc).filter((x) => x.endsWith('.tsx'))) {
  const source = fs.readFileSync(file, 'utf8')
  let index = source.indexOf('<table')
  while (index >= 0) {
    tableCount += 1
    const before = source.slice(Math.max(0, index - 320), index)
    if (!before.includes('overflow-x-auto')) {
      fail(`Table without nearby overflow-x-auto wrapper: ${path.relative(root, file)} @ ${index}`)
    }
    index = source.indexOf('<table', index + 6)
  }
}

if (tableCount < 20) fail(`Unexpectedly low table count: ${tableCount}`)

const forbiddenSmallTarget = /min-h-(?:4|5|6|7|8)\b/
for (const file of walk(appSrc).filter((x) => x.endsWith('.tsx'))) {
  const source = fs.readFileSync(file, 'utf8')
  if (forbiddenSmallTarget.test(source) && file.endsWith('DashboardPage.tsx')) {
    fail('Dashboard contains an explicitly tiny min-height target.')
  }
}

if (!process.exitCode) {
  console.log(`T11 responsive table scan: PASS (${tableCount} tables)`)
  console.log('T11 touch/focus/mobile foundation: PASS')
  console.log('T11 dashboard responsive structure: PASS')
  console.log('T11 RESPONSIVE UI CHECK: PASS')
}
