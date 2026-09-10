import fs from 'node:fs'
import path from 'node:path'
import readline from 'node:readline/promises'
import { stdin, stdout } from 'node:process'
import { validateProductionEnv } from './t18-production-env-check.mjs'

const root = path.resolve(process.cwd())
const target = path.join(root, 'app', '.env.local')

function renderEnv(url, key) {
  return [
    '# HomeTechVN local working-copy configuration.',
    '# Browser-safe values only. Never put sb_secret or service_role material here.',
    `VITE_SUPABASE_URL=${url}`,
    `VITE_SUPABASE_PUBLISHABLE_KEY=${key}`,
    '',
  ].join('\r\n')
}

function validateOrThrow(values) {
  const errors = validateProductionEnv(values)
  if (errors.length) throw new Error(errors.join('; '))
}

function writeConfig(url, key) {
  const values = {
    VITE_SUPABASE_URL: String(url || '').trim(),
    VITE_SUPABASE_PUBLISHABLE_KEY: String(key || '').trim(),
  }
  validateOrThrow(values)
  fs.mkdirSync(path.dirname(target), { recursive: true })
  fs.writeFileSync(target, renderEnv(values.VITE_SUPABASE_URL, values.VITE_SUPABASE_PUBLISHABLE_KEY), {
    encoding: 'utf8',
    mode: 0o600,
  })
  return values
}

function selfTest() {
  const good = {
    url: 'https://project-ref.supabase.co',
    key: 'sb_publishable_abcdefghijklmnopqrstuvwxyz',
  }
  validateOrThrow({
    VITE_SUPABASE_URL: good.url,
    VITE_SUPABASE_PUBLISHABLE_KEY: good.key,
  })
  const rendered = renderEnv(good.url, good.key)
  if (!rendered.includes('VITE_SUPABASE_URL=https://project-ref.supabase.co\r\n')) {
    throw new Error('configure renderer did not emit the hosted URL')
  }
  if (!rendered.includes('VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_')) {
    throw new Error('configure renderer did not emit the publishable key')
  }
  for (const bad of [
    { url: 'http://project-ref.supabase.co', key: good.key },
    { url: good.url, key: 'sb_secret_forbidden' },
    { url: 'https://YOUR_PROJECT.supabase.co', key: good.key },
  ]) {
    let rejected = false
    try {
      validateOrThrow({
        VITE_SUPABASE_URL: bad.url,
        VITE_SUPABASE_PUBLISHABLE_KEY: bad.key,
      })
    } catch {
      rejected = true
    }
    if (!rejected) throw new Error('configure self-test accepted unsafe input')
  }
  console.log('T18 CONFIGURE SELF TEST: PASS')
}

async function main() {
  if (process.argv.includes('--self-test')) {
    selfTest()
    return
  }

  if (fs.existsSync(target) && !process.argv.includes('--force')) {
    console.log('app/.env.local already exists; no file was changed.')
    console.log('Run npm run t18:env-check to validate it, or rerun with -- --force to replace it.')
    return
  }

  console.log('HomeTechVN T18 hosted frontend configuration')
  console.log('Use Project URL + Publishable key from Supabase Connect / Settings > API Keys.')
  console.log('A legacy anon key is accepted. Never enter sb_secret or service_role material.')
  const prompt = readline.createInterface({ input: stdin, output: stdout })
  try {
    const url = await prompt.question('VITE_SUPABASE_URL: ')
    const key = await prompt.question('VITE_SUPABASE_PUBLISHABLE_KEY: ')
    writeConfig(url, key)
  } finally {
    prompt.close()
  }

  console.log('T18 HOSTED FRONTEND CONFIG: SAVED')
  console.log('T18 PRODUCTION CONFIG SAFETY: PASS')
  console.log('Saved app/.env.local locally; release packaging will exclude it.')
}

main().catch((error) => {
  console.error(`[T18 CONFIGURE FAIL] ${error.message}`)
  process.exit(1)
})
