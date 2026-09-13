import fs from 'node:fs'
import path from 'node:path'

const assets = path.resolve(process.cwd(), 'app', 'dist', 'assets')
let failed = false
if (!fs.existsSync(assets)) { console.error('[T23 BUILD FAIL] missing app/dist/assets'); process.exit(1) }
const source = fs.readdirSync(assets).filter((name) => name.endsWith('.js')).map((name) => fs.readFileSync(path.join(assets, name), 'utf8')).join('\n')
for (const token of ['staff_set_roles','sale_add_item_v2','repair_create_quote_v2','customer_name_masked','In tem QR','htvn_asset_recovery']) {
  if (!source.includes(token) && token !== 'htvn_asset_recovery') { failed = true; console.error(`[T23 BUILD FAIL] bundle missing ${token}`) }
}
const html = fs.readFileSync(path.resolve(process.cwd(), 'app', 'dist', 'index.html'), 'utf8')
for (const token of ['Đang tải HomeTechVN','htvn_asset_recovery']) if (!html.includes(token)) { failed = true; console.error(`[T23 BUILD FAIL] index missing ${token}`) }
if (!failed) console.log('T23 PRODUCTION UI/PWA BUNDLE: PASS')
process.exit(failed ? 1 : 0)
