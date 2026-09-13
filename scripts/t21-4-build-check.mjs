import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
const assets = path.join(root,'app','dist','assets')
let failed = false

function fail(message) {
  failed = true
  console.error(`[T21.4 BUILD FAIL] ${message}`)
}

if (!fs.existsSync(assets)) fail('missing app/dist/assets; run the production build first')
else {
  const source = fs.readdirSync(assets)
    .filter((name) => name.endsWith('.js'))
    .map((name) => fs.readFileSync(path.join(assets,name),'utf8'))
    .join('\n')
  for (const token of ['payment_qr_config_get','payment_qr_configure','img.vietqr.io/image/']) {
    if (!source.includes(token)) fail(`production bundle missing payment QR contract: ${token}`)
  }
  for (const forbidden of ['TEST RECEIVER','VCB-123456789-compact2']) {
    if (source.includes(forbidden)) fail(`production bundle contains forbidden test/secret marker: ${forbidden}`)
  }
}

if (!failed) console.log('T21.4 PRODUCTION PAYMENT QR BUNDLE: PASS')
process.exit(failed ? 1 : 0)
