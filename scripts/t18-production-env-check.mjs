import fs from 'node:fs'
import path from 'node:path'
import { pathToFileURL } from 'node:url'

function parseEnv(text) {
  const values = {}
  for (const [index, raw] of text.replace(/^\uFEFF/, '').split(/\r?\n/).entries()) {
    const line = raw.trim()
    if (!line || line.startsWith('#')) continue
    const normalized = line.startsWith('export ') ? line.slice(7).trim() : line
    const match = /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/.exec(normalized)
    if (!match) throw new Error(`invalid env syntax at line ${index + 1}`)
    const key = match[1]
    if (Object.hasOwn(values, key)) throw new Error(`duplicate env key: ${key}`)
    let value = match[2].trim()
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) value = value.slice(1, -1)
    values[key] = value
  }
  return values
}

function decodeJwtPayload(value) {
  const parts = value.split('.')
  if (parts.length !== 3) return null
  try {
    return JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'))
  } catch {
    return null
  }
}

export function validateProductionEnv(values) {
  const errors = []
  const urlText = String(values.VITE_SUPABASE_URL || '').trim()
  const key = String(values.VITE_SUPABASE_PUBLISHABLE_KEY || '').trim()

  if (!urlText) errors.push('VITE_SUPABASE_URL is required')
  else {
    try {
      const url = new URL(urlText)
      const host = url.hostname.toLowerCase()
      if (url.protocol !== 'https:') errors.push('VITE_SUPABASE_URL must use HTTPS')
      if (['localhost', '127.0.0.1', '0.0.0.0', 'host.docker.internal'].includes(host) || host.endsWith('.local')) {
        errors.push('VITE_SUPABASE_URL must not target a local runtime')
      }
      if (url.username || url.password) errors.push('VITE_SUPABASE_URL must not contain credentials')
    } catch {
      errors.push('VITE_SUPABASE_URL is not a valid URL')
    }
  }

  if (!key) errors.push('VITE_SUPABASE_PUBLISHABLE_KEY is required')
  if (/YOUR_|REPLACE|CHANGE[_-]?ME|EXAMPLE|<|>/i.test(`${urlText}\n${key}`)) {
    errors.push('production configuration contains a placeholder')
  }
  if (/^sb_secret_/i.test(key)) errors.push('secret API key must never be used by the browser app')
  if (/service[_-]?role/i.test(key)) errors.push('service-role material must never be used by the browser app')

  if (key && !/^sb_publishable_/i.test(key)) {
    const payload = decodeJwtPayload(key)
    if (!payload || payload.role !== 'anon') {
      errors.push('browser key must be a publishable key or a legacy anon JWT')
    }
  }

  for (const name of Object.keys(values)) {
    if (/^VITE_.*(?:SECRET|SERVICE_ROLE|PRIVATE_KEY|PASSWORD|TOKEN)/i.test(name)) {
      errors.push(`browser-exposed secret-like variable is prohibited: ${name}`)
    }
    if (/^VITE_HOMETECHVN_DEMO_/i.test(name)) {
      errors.push(`demo variable is prohibited in production: ${name}`)
    }
  }

  return [...new Set(errors)]
}

function expectValid(name, values) {
  const errors = validateProductionEnv(values)
  if (errors.length) throw new Error(`${name} unexpectedly failed: ${errors.join('; ')}`)
}

function expectInvalid(name, values, pattern) {
  const errors = validateProductionEnv(values)
  if (!errors.some((error) => pattern.test(error))) {
    throw new Error(`${name} unexpectedly passed or returned the wrong error: ${errors.join('; ')}`)
  }
}

function fakeAnonJwt() {
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url')
  return `${encode({ alg: 'none' })}.${encode({ role: 'anon' })}.signature`
}

function selfTest() {
  const good = {
    VITE_SUPABASE_URL: 'https://project-ref.supabase.co',
    VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_abcdefghijklmnopqrstuvwxyz',
  }
  expectValid('publishable key', good)
  expectValid('legacy anon key', { ...good, VITE_SUPABASE_PUBLISHABLE_KEY: fakeAnonJwt() })
  expectInvalid('HTTP URL', { ...good, VITE_SUPABASE_URL: 'http://project-ref.supabase.co' }, /HTTPS/)
  expectInvalid('local URL', { ...good, VITE_SUPABASE_URL: 'https://localhost:54321' }, /local runtime/)
  expectInvalid('placeholder', { ...good, VITE_SUPABASE_URL: 'https://YOUR_PROJECT.supabase.co' }, /placeholder/)
  expectInvalid('secret key', { ...good, VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_secret_do_not_use' }, /secret API key/)
  expectInvalid('demo variable', { ...good, VITE_HOMETECHVN_DEMO_MODE: 'false' }, /demo variable/)
  expectInvalid('browser password', { ...good, VITE_ADMIN_PASSWORD: 'bad' }, /secret-like/)
  console.log('T18 PRODUCTION ENV VALIDATION SELF TEST: PASS')
}

function runCli() {
  const args = process.argv.slice(2)
  if (args.includes('--self-test')) {
    selfTest()
    return
  }

  const fileIndex = args.indexOf('--file')
  if (fileIndex < 0 || !args[fileIndex + 1]) {
    console.error('Usage: node scripts/t18-production-env-check.mjs --file <env-file> | --self-test')
    process.exitCode = 2
    return
  }

  const file = path.resolve(args[fileIndex + 1])
  if (!fs.existsSync(file)) {
    console.error(`[T18 ENV FAIL] production working-copy config is missing: ${path.relative(process.cwd(), file)}`)
    process.exitCode = 1
    return
  }

  try {
    const values = parseEnv(fs.readFileSync(file, 'utf8'))
    const errors = validateProductionEnv(values)
    if (errors.length) throw new Error(errors.join('; '))
    console.log('T18 RUNTIME CONFIG POLICY: PASS (WORKING COPY)')
    console.log('T18 PRODUCTION CONFIG SAFETY: PASS')
  } catch (error) {
    console.error(`[T18 ENV FAIL] ${error.message}`)
    process.exitCode = 1
  }
}

const entryUrl = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : ''
if (entryUrl === import.meta.url) runCli()
