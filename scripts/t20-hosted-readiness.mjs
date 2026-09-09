import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
const envPath = path.join(root, 'app', '.env.local')

function parseEnv(text) {
  const values = {}
  for (const raw of String(text).split(/\r?\n/)) {
    const line = raw.trim()
    if (!line || line.startsWith('#')) continue
    const at = line.indexOf('=')
    if (at < 1) continue
    let value = line.slice(at + 1).trim()
    if (
      value.length >= 2
      && ((value.startsWith('"') && value.endsWith('"'))
        || (value.startsWith("'") && value.endsWith("'")))
    ) value = value.slice(1, -1)
    values[line.slice(0, at).trim()] = value
  }
  return values
}

function validate(values) {
  const urlText = String(values.VITE_SUPABASE_URL || '').trim()
  const key = String(values.VITE_SUPABASE_PUBLISHABLE_KEY || '').trim()
  if (!urlText || !key) throw new Error('Hosted URL/publishable key is missing')
  const url = new URL(urlText)
  if (url.protocol !== 'https:') throw new Error('Hosted Supabase URL must use HTTPS')
  if (['localhost', '127.0.0.1', '::1'].includes(url.hostname)) {
    throw new Error('T20 hosted readiness refuses a local Supabase URL')
  }
  if (!url.hostname.endsWith('.supabase.co')) {
    throw new Error('T20 hosted readiness requires a Supabase project URL')
  }
  if (!/^sb_publishable_[A-Za-z0-9_-]{20,}$/.test(key) && key.split('.').length !== 3) {
    throw new Error('Browser key must be a publishable key or legacy anon JWT')
  }
  if (/^sb_secret_/i.test(key) || /service[_-]?role/i.test(key)) {
    throw new Error('Secret/service-role key is forbidden in the browser app')
  }
  if (values.VITE_HOMETECHVN_HOSTED_DEMO !== 'true') {
    throw new Error('VITE_HOMETECHVN_HOSTED_DEMO=true is required')
  }
  for (const name of Object.keys(values)) {
    if (/^VITE_HOMETECHVN_DEMO_(?:ACCOUNTS|PASSWORD|MODE)$/i.test(name)) {
      throw new Error(`Local demo variable is forbidden in hosted T20: ${name}`)
    }
  }
  return { apiUrl: url.origin, publishableKey: key }
}

async function request(apiUrl, publishableKey, pathname, body) {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), 15000)
  try {
    const response = await fetch(`${apiUrl}${pathname}`, {
      method: body === undefined ? 'GET' : 'POST',
      headers: {
        apikey: publishableKey,
        'Content-Type': 'application/json',
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: controller.signal,
    })
    const text = await response.text()
    let data = text
    try { data = text ? JSON.parse(text) : null } catch { /* retain text */ }
    return { ok: response.ok, status: response.status, data }
  } finally {
    clearTimeout(timeout)
  }
}

function selfTest() {
  const good = {
    VITE_SUPABASE_URL: 'https://project-ref.supabase.co',
    VITE_SUPABASE_PUBLISHABLE_KEY: `sb_publishable_${'x'.repeat(24)}`,
    VITE_HOMETECHVN_HOSTED_DEMO: 'true',
  }
  validate(good)
  for (const bad of [
    { ...good, VITE_SUPABASE_URL: 'http://127.0.0.1:54321' },
    { ...good, VITE_SUPABASE_PUBLISHABLE_KEY: `sb_secret_${'x'.repeat(24)}` },
    { ...good, VITE_HOMETECHVN_DEMO_PASSWORD: 'forbidden' },
  ]) {
    let blocked = false
    try { validate(bad) } catch { blocked = true }
    if (!blocked) throw new Error('T20 hosted readiness self-test missed unsafe config')
  }
  console.log('T20 HOSTED READINESS SELF TEST: PASS')
}

async function main() {
  if (process.argv.includes('--self-test')) {
    selfTest()
    return
  }
  if (!fs.existsSync(envPath)) throw new Error('app/.env.local is required for hosted verification')
  const config = validate(parseEnv(fs.readFileSync(envPath, 'utf8')))

  const health = await request(config.apiUrl, config.publishableKey, '/auth/v1/health')
  if (!health.ok) throw new Error(`Hosted Auth health failed with HTTP ${health.status}`)

  const anonymousQr = await request(
    config.apiUrl,
    config.publishableKey,
    '/rest/v1/rpc/qr_resolve',
    { p_token: '0'.repeat(64) },
  )
  if (anonymousQr.ok) throw new Error('Anonymous caller unexpectedly executed internal QR resolver')

  const publicWarranty = await request(
    config.apiUrl,
    config.publishableKey,
    '/rest/v1/rpc/warranty_public_lookup',
    { p_token: '0'.repeat(64) },
  )
  if (!publicWarranty.ok) {
    throw new Error(`Public warranty RPC failed with HTTP ${publicWarranty.status}`)
  }
  if (publicWarranty.data?.found !== false) {
    throw new Error('Invalid public warranty token must return found=false')
  }

  const anonymousSettings = await request(
    config.apiUrl,
    config.publishableKey,
    '/rest/v1/settings?select=key&limit=1',
  )
  if (anonymousSettings.ok && Array.isArray(anonymousSettings.data) && anonymousSettings.data.length > 0) {
    throw new Error('Anonymous caller unexpectedly read application settings')
  }

  console.log('T20 HOSTED AUTH/API READINESS: PASS')
  console.log('T20 HOSTED ANON ISOLATION: PASS')
  console.log('T20 HOSTED PUBLIC WARRANTY CONTRACT: PASS')
}

main().catch((error) => {
  console.error(`[T20 HOSTED FAIL] ${error instanceof Error ? error.message : String(error)}`)
  process.exit(1)
})
