import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
function fail(message) { console.error(`[T12 UI FAIL] ${message}`); process.exitCode = 1 }
function read(rel) { return fs.readFileSync(path.join(root, rel), 'utf8') }

const app = read('app/src/App.tsx')
const publicPage = read('app/src/features/public_warranty/PublicWarrantyPage.tsx')
const warranty = read('app/src/features/warranty/WarrantyPage.tsx')
const headers = read('app/public/_headers')
const pkg = JSON.parse(read('app/package.json'))

if (!app.includes("path.startsWith('/w/')")) fail('Missing /w/* public route detection.')
if (!app.includes('return <PublicWarrantyPage token={publicWarrantyRoute.token} />')) fail('PublicWarrantyPage route missing.')
if (app.indexOf('return <PublicWarrantyPage') > app.indexOf("if (authState.status === 'loading')")) fail('Public warranty route is behind auth/loading UI.')
if (!publicPage.includes("supabase.rpc('warranty_public_lookup'")) fail('Public page must use warranty_public_lookup RPC.')
if (/\.from\(\s*['"](?:warranties|customers|warranty_claims)['"]/.test(publicPage)) fail('Public page directly queries protected tables.')
for (const token of ['max-w-2xl','sm:grid-cols-2','min-h-screen','serial_masked','phone_masked']) {
  if (!publicPage.includes(token)) fail(`Public page missing responsive/privacy token: ${token}`)
}
if (!warranty.includes("import QRCode from 'qrcode'")) fail('Warranty module missing pinned QR generator.')
if (!warranty.includes('QRCode.toDataURL(publicUrl')) fail('QR generation flow missing.')
if (!warranty.includes('Tải QR PNG') || !warranty.includes('In tem QR') || !warranty.includes('Sao chép link')) fail('QR operator actions incomplete.')
if (pkg.dependencies?.qrcode !== '1.5.4') fail('qrcode must be pinned to 1.5.4.')
if (pkg.devDependencies?.['@types/qrcode'] !== '1.5.6') fail('@types/qrcode must be pinned to 1.5.6.')
for (const token of ['X-Robots-Tag: noindex, nofollow, noarchive','Referrer-Policy: no-referrer','Cache-Control: no-store','/w/*']) {
  if (!headers.includes(token)) fail(`Cloudflare public route header missing: ${token}`)
}
if (fs.existsSync(path.join(root, 'app/public/404.html'))) fail('Top-level 404.html would disable Cloudflare Pages SPA fallback.')

if (!process.exitCode) {
  console.log('T12 public route before auth gate: PASS')
  console.log('T12 anonymous RPC-only privacy scan: PASS')
  console.log('T12 QR generate/copy/download/print: PASS')
  console.log('T12 Cloudflare noindex/no-referrer headers: PASS')
  console.log('T12 RESPONSIVE PUBLIC UI CHECK: PASS')
}
