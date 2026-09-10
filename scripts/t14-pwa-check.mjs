import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())

function fail(message) {
  console.error(`[T14 PWA FAIL] ${message}`)
  process.exitCode = 1
}

function read(rel) {
  return fs.readFileSync(path.join(root, rel), 'utf8')
}

function pngSize(rel) {
  const buffer = fs.readFileSync(path.join(root, rel))
  if (buffer.length < 24 || buffer.toString('ascii', 1, 4) !== 'PNG') {
    fail(`${rel} is not a valid PNG header`)
    return { width: 0, height: 0 }
  }
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
  }
}

const vite = read('app/vite.config.ts')
const shell = read('app/src/features/pwa/PwaShell.tsx')
const main = read('app/src/main.tsx')
const env = read('app/src/vite-env.d.ts')
const css = read('app/src/index.css')
const html = read('app/index.html')
const headers = read('app/public/_headers')
const pkg = JSON.parse(read('app/package.json'))

if (pkg.devDependencies?.['vite-plugin-pwa'] !== '1.3.0') {
  fail(`vite-plugin-pwa must be pinned to 1.3.0, got ${pkg.devDependencies?.['vite-plugin-pwa']}`)
}

for (const token of [
  "registerType: 'prompt'",
  'injectRegister: null',
  "start_url: '/'",
  "scope: '/'",
  "display: 'standalone'",
  "'window-controls-overlay'",
  "src: '/icons/pwa-192x192.png'",
  "src: '/icons/pwa-512x512.png'",
  "src: '/icons/pwa-maskable-512x512.png'",
  "purpose: 'maskable'",
  'cleanupOutdatedCaches: true',
  'skipWaiting: false',
  'runtimeCaching: []',
]) {
  if (!vite.includes(token)) fail(`vite.config.ts missing PWA token: ${token}`)
}

if (/backgroundSync/i.test(vite)) fail('Background Sync must not be configured in T14.')
if (/supabase/i.test(vite)) fail('Supabase runtime caching must not be configured in vite.config.ts.')

for (const token of [
  "useRegisterSW",
  'beforeinstallprompt',
  'appinstalled',
  'navigator.onLine',
  'registration.update()',
  'updateServiceWorker(true)',
  'pwa-offline-lock',
  'không xếp hàng giao dịch nền',
  'không bán hàng',
]) {
  if (!shell.includes(token)) fail(`PwaShell missing required install/update/offline token: ${token}`)
}

if (!main.includes('<PwaShell>') || !main.includes('</PwaShell>')) {
  fail('PwaShell is not mounted around App.')
}
if (!env.includes('vite-plugin-pwa/react')) fail('vite-env.d.ts missing vite-plugin-pwa/react types.')
if (!env.includes('BeforeInstallPromptEvent')) fail('BeforeInstallPromptEvent typing missing.')

for (const token of [
  '.pwa-install-button',
  '.pwa-toast',
  '.pwa-offline-lock',
  'env(safe-area-inset-bottom)',
  '@media (max-width: 640px)',
  '@media print',
]) {
  if (!css.includes(token)) fail(`index.css missing PWA responsive token: ${token}`)
}

for (const token of [
  'mobile-web-app-capable',
  'apple-mobile-web-app-capable',
  '/icons/apple-touch-icon.png',
  'theme-color',
]) {
  if (!html.includes(token)) fail(`index.html missing PWA metadata: ${token}`)
}

for (const token of [
  '/sw.js',
  'Cache-Control: no-cache, no-store, must-revalidate',
  'Service-Worker-Allowed: /',
  '/manifest.webmanifest',
  '/w/*',
  'Referrer-Policy: no-referrer',
]) {
  if (!headers.includes(token)) fail(`_headers missing required T12/T14 token: ${token}`)
}

for (const [rel, width, height] of [
  ['app/public/icons/pwa-192x192.png', 192, 192],
  ['app/public/icons/pwa-512x512.png', 512, 512],
  ['app/public/icons/pwa-maskable-512x512.png', 512, 512],
  ['app/public/icons/apple-touch-icon.png', 180, 180],
]) {
  const actual = pngSize(rel)
  if (actual.width !== width || actual.height !== height) {
    fail(`${rel} expected ${width}x${height}, got ${actual.width}x${actual.height}`)
  }
}

if (!process.exitCode) {
  console.log('T14 manifest/install source contract: PASS')
  console.log('T14 prompt-update lifecycle: PASS')
  console.log('T14 offline transaction lock: PASS')
  console.log('T14 no Background Sync / no Supabase runtime cache: PASS')
  console.log('T14 icons: PASS (192/512/maskable/Apple)')
  console.log('T14 PWA SOURCE CHECK: PASS')
}
