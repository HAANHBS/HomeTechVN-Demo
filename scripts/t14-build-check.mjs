import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
const dist = path.join(root, 'app', 'dist')

function fail(message) {
  console.error(`[T14 BUILD FAIL] ${message}`)
  process.exitCode = 1
}

function read(rel) {
  return fs.readFileSync(path.join(dist, rel), 'utf8')
}

function exists(rel) {
  return fs.existsSync(path.join(dist, rel))
}

function pngSize(rel) {
  const buffer = fs.readFileSync(path.join(dist, rel))
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
  }
}

for (const rel of [
  'index.html',
  'manifest.webmanifest',
  'sw.js',
  'icons/pwa-192x192.png',
  'icons/pwa-512x512.png',
  'icons/pwa-maskable-512x512.png',
  'icons/apple-touch-icon.png',
  '_headers',
]) {
  if (!exists(rel)) fail(`Build missing ${rel}`)
}

if (!exists('manifest.webmanifest') || !exists('sw.js')) process.exit(1)

const manifest = JSON.parse(read('manifest.webmanifest'))
if (manifest.name !== 'HomeTechVN - Quản lý cửa hàng') fail('Manifest name mismatch.')
if (manifest.short_name !== 'HomeTechVN') fail('Manifest short_name mismatch.')
if (manifest.start_url !== '/') fail('Manifest start_url must be /.')
if (manifest.scope !== '/') fail('Manifest scope must be /.')
if (manifest.display !== 'standalone') fail('Manifest display must be standalone.')
if (manifest.prefer_related_applications !== false) fail('Manifest prefer_related_applications must be false.')

const icons = Array.isArray(manifest.icons) ? manifest.icons : []
if (!icons.some((x) => x.sizes === '192x192' && x.type === 'image/png')) fail('Manifest missing 192x192 PNG.')
if (!icons.some((x) => x.sizes === '512x512' && x.type === 'image/png' && x.purpose === 'any')) fail('Manifest missing 512x512 any PNG.')
if (!icons.some((x) => x.sizes === '512x512' && x.type === 'image/png' && x.purpose === 'maskable')) fail('Manifest missing maskable 512 PNG.')

for (const [rel, size] of [
  ['icons/pwa-192x192.png', 192],
  ['icons/pwa-512x512.png', 512],
  ['icons/pwa-maskable-512x512.png', 512],
  ['icons/apple-touch-icon.png', 180],
]) {
  if (!exists(rel)) continue
  const actual = pngSize(rel)
  if (actual.width !== size || actual.height !== size) fail(`${rel} has wrong dimensions.`)
}

const index = read('index.html')
if (!/rel=["']manifest["']/.test(index)) fail('Built index.html does not reference web manifest.')
if (!index.includes('/icons/apple-touch-icon.png')) fail('Built index missing Apple touch icon.')

const sw = read('sw.js')
if (sw.length < 300) fail('Generated sw.js unexpectedly small.')
if (/supabase\.co/i.test(sw)) fail('Generated service worker contains Supabase domain/cache rule.')
if (/BackgroundSyncPlugin/i.test(sw)) fail('Generated service worker includes Background Sync plugin.')
if (/Queue\(/.test(sw) && /workbox-background-sync/i.test(sw)) fail('Generated service worker appears to queue requests.')

const headers = read('_headers')
if (!headers.includes('/sw.js') || !headers.includes('no-cache, no-store')) fail('Built _headers missing SW no-cache rule.')
if (!headers.includes('/w/*') || !headers.includes('no-referrer')) fail('T12 public warranty privacy headers regressed.')

console.log('T14 built manifest installability contract: PASS')
console.log('T14 built service worker generated: PASS')
console.log('T14 built service worker Supabase/background-sync exclusion: PASS')
console.log('T14 built icons/header contract: PASS')
console.log('T14 PWA BUILD CHECK: PASS')
