import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
let failed = false
function fail(message) {
  failed = true
  console.error(`[T18 SOURCE FAIL] ${message}`)
}
function read(relative) {
  return fs.readFileSync(path.join(root, ...relative.split('/')), 'utf8').replace(/^\uFEFF/, '')
}
function hashFile(relative) {
  return crypto.createHash('sha256').update(fs.readFileSync(path.join(root, ...relative.split('/')))).digest('hex')
}

const integrityPath = 'docs/T17_FINAL_INTEGRITY.txt'
const expectedIntegrityHash = '8deddca35fefed24c1aa63f4281f3daf0c443bebf626890c5f081a3feb875300'
if (!fs.existsSync(path.join(root, integrityPath))) fail('T17 FINAL integrity manifest is missing')
else if (hashFile(integrityPath) !== expectedIntegrityHash) fail('T17 FINAL integrity manifest hash changed')
else console.log('T18 T17 FINAL BASELINE HASH: PASS')

const integrity = read(integrityPath)
const manifestEntries = [...integrity.matchAll(/^([a-f0-9]{64})  ([^\r\n]+)$/gm)]
const expectedHashes = new Map()
for (const match of manifestEntries) expectedHashes.set(match[2].replaceAll('\\', '/'), match[1])

const migrations = fs.readdirSync(path.join(root, 'supabase', 'migrations'))
  .filter((name) => name.endsWith('.sql')).sort()
if (migrations.length !== 36) fail(`expected 36 locked migrations, found ${migrations.length}`)
if (migrations.some((name) => /_t18_/i.test(name))) fail('T18 Production Release Gate must add zero migrations')
for (const name of migrations) {
  const relative = `supabase/migrations/${name}`
  const expected = expectedHashes.get(relative)
  if (!expected) fail(`migration absent from T17 FINAL integrity manifest: ${name}`)
  else if (hashFile(relative) !== expected) fail(`locked migration hash changed: ${name}`)
}
if (!failed) {
  console.log('T18 LOCKED MIGRATION HASHES #1-#36: PASS')
  console.log('T18 DB MIGRATIONS: 0 (NEXT #37 RESERVED)')
}

const t18AllowedChanges = new Set(['worker/src/index.js'])
for (const [relative, expected] of expectedHashes) {
  if (!(relative.startsWith('scripts/') || relative.startsWith('app/src/') || relative === 'worker/src/index.js')) continue
  if (t18AllowedChanges.has(relative)) continue
  const full = path.join(root, ...relative.split('/'))
  if (!fs.existsSync(full)) fail(`T17 accepted source is missing: ${relative}`)
  else if (hashFile(relative) !== expected) fail(`T17 accepted source changed outside T18 allowlist: ${relative}`)
}

const pkg = JSON.parse(read('package.json'))
const requiredScripts = [
  't18:source-check', 't18:configure', 't18:configure-self-test',
  't18:env-check', 't18:env-self-test',
  't18:worker-self-test', 't18:build-check', 't18:package-self-test',
  't18:powershell-check', 't18:package', 't18:verify',
]
for (const name of requiredScripts) if (!pkg.scripts?.[name]) fail(`missing package script: ${name}`)
if (pkg.version !== '0.17.14-t17.14') fail('T18 must preserve the accepted T17 application version during the release gate')

const appEnvExample = read('app/.env.example')
const appProductionExample = read('app/.env.production.example')
for (const [name, text] of [['app/.env.example', appEnvExample], ['app/.env.production.example', appProductionExample]]) {
  if (!text.includes('https://YOUR_PROJECT.supabase.co')) fail(`${name} must use a non-live URL placeholder`)
  if (!text.includes('sb_publishable_REPLACE_ME')) fail(`${name} must document a publishable key placeholder`)
  if (/sb_secret_|service[_-]?role/i.test(text)) fail(`${name} must not suggest a browser secret key`)
}

const viteConfig = read('app/vite.config.ts')
if (!/build:\s*\{[\s\S]*?sourcemap:\s*false/.test(viteConfig)) fail('production source maps must be disabled')
if (!viteConfig.includes('chunkSizeWarningLimit: 800')) fail('reviewed production chunk warning limit is missing')

const workerSource = read('worker/src/index.js')
const cronGuard = workerSource.indexOf('env.WORKER_CRON_ENABLED !== "true"')
const waitUntil = workerSource.indexOf('ctx.waitUntil(runPipeline(env)')
if (cronGuard < 0 || waitUntil < 0 || cronGuard > waitUntil) fail('Worker cron-off guard must run before notification pipeline activation')
if (!workerSource.includes('HomeTechVN notification cron skipped: WORKER_CRON_ENABLED is not true')) {
  fail('Worker cron-off audit message is missing')
}

const wrangler = JSON.parse(read('worker/wrangler.jsonc'))
if (wrangler.vars?.WORKER_CRON_ENABLED !== 'false') fail('Worker cron must ship disabled')
if (wrangler.vars?.DRY_RUN !== 'true') fail('Worker must ship in DRY_RUN mode')
console.log('T18 WORKER SAFE-ACTIVATION DEFAULTS: PASS')

const envCheck = read('scripts/t18-production-env-check.mjs')
for (const token of [
  'T18 PRODUCTION ENV VALIDATION SELF TEST: PASS',
  'T18 RUNTIME CONFIG POLICY: PASS (WORKING COPY)',
  'secret API key must never be used by the browser app',
  'demo variable is prohibited in production',
]) if (!envCheck.includes(token)) fail(`production env validator missing contract: ${token}`)

const configure = read('scripts/t18-configure.mjs')
for (const token of [
  'T18 CONFIGURE SELF TEST: PASS',
  'T18 HOSTED FRONTEND CONFIG: SAVED',
  'Never enter sb_secret or service_role material',
  'Saved app/.env.local locally; release packaging will exclude it.',
]) if (!configure.includes(token)) fail(`T18 configure helper missing contract: ${token}`)

const packager = read('scripts/t18-package.ps1')
for (const token of [
  'Should-IncludeFile',
  'WorkingCopyRuntimeConfigAllowed',
  'Get-ArchiveEntries',
  '$requiredRelativePaths',
  '$entry = $prefix + $relativePath',
  "return $leaf -in @('.env.example', '.env.production.example')",
  'Local runtime configuration must not be packaged:',
  'T18 RELEASE PACKAGE SAFETY: PASS',
]) if (!packager.includes(token)) fail(`release packager missing contract: ${token}`)
if (/^\s*\$prefix\s*\+\s*['"][^\r\n]+,\s*$/m.test(packager)) {
  fail('release packager contains the PowerShell comma-expression required-entry regression')
}
if (/Get-ChildItem\s+-LiteralPath\s+\$ProjectRoot\s+-Recurse/i.test(packager)) {
  fail('release packager must enumerate explicit top-level allowlist directories')
}

const verify = read('scripts/t18-verify.ps1')
for (const token of [
  'scripts\\t17-verify.mjs',
  'T17 CLEAN BASELINE AFTER VERIFY: PASS',
  '$envHashBefore', '$envHashAfter',
  'T18 RELEASE PACKAGE SAFETY: PASS',
  'T18 CLEAN BASELINE AFTER VERIFY: PASS',
  'Run npm run t18:configure',
]) if (!verify.includes(token)) fail(`T18 verifier missing contract: ${token}`)
if (!fs.existsSync(path.join(root, 'scripts', 't18-build-check.mjs'))) fail('T18 production build checker is missing')
if (!fs.existsSync(path.join(root, 'scripts', 't18-package-policy-self-test.mjs'))) fail('T18 package-policy self-test is missing')

const requiredDocs = [
  'docs/T18_PRODUCTION_RELEASE_GATE.md',
  'docs/T18_DEPLOYMENT_RUNBOOK.md',
  'docs/T18_ACCOUNT_CONFIG_REGISTER.md',
  'docs/T18_MASTER_CHECKLIST.md',
  'docs/T18_STATUS.md',
  'docs/T18_BUILD_TEST.md',
]
for (const relative of requiredDocs) if (!fs.existsSync(path.join(root, relative))) fail(`missing T18 document: ${relative}`)
if (requiredDocs.every((relative) => fs.existsSync(path.join(root, relative)))) {
  const docsText = requiredDocs.map(read).join('\n')
  for (const token of [
    'app/.env.local', 'WORKER_CRON_ENABLED', 'migration #37',
    'T18 RELEASE PACKAGE SAFETY: PASS', 'CANDIDATE',
  ]) if (!docsText.includes(token)) fail(`T18 documentation contract missing: ${token}`)
  console.log('T18 DOCUMENTATION CONTRACT: PASS')
}

if (!failed) console.log('T18 SOURCE CHECK: PASS')
process.exit(failed ? 1 : 0)
