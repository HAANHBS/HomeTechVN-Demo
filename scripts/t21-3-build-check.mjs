import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
const assets = path.join(root, 'app', 'dist', 'assets')
let failed = false

function fail(message) {
  failed = true
  console.error(`[T21.3 BUILD FAIL] ${message}`)
}

if (!fs.existsSync(assets)) {
  fail('missing app/dist/assets; run the production build first')
} else {
  const bundles = fs.readdirSync(assets).filter((name) => name.endsWith('.js'))
  const source = bundles.map((name) => fs.readFileSync(path.join(assets, name), 'utf8')).join('\n')
  const bytes = Buffer.byteLength(source)

  if (bytes < 300_000) fail(`JavaScript bundle is unexpectedly small (${bytes} bytes)`)
  for (const contract of ['repair_create_quote', 'repair_start_diagnosis', 'repair_record_qc']) {
    if (!source.includes(contract)) fail(`production bundle missing application contract: ${contract}`)
  }
  if (source.includes('VITE_SUPABASE_URL') || source.includes('VITE_SUPABASE_PUBLISHABLE_KEY')) {
    fail('production bundle still contains the missing-Supabase-configuration guard')
  }
}

if (!failed) {
  console.log('T21.3 PRODUCTION BUNDLE COMPLETENESS: PASS')
  console.log('T21.3 SUPABASE BUILD CONFIGURATION: PASS')
}

process.exit(failed ? 1 : 0)
