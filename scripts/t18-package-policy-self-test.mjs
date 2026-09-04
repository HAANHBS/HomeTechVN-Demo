import fs from 'node:fs'

const blockedDirectories = new Set([
  '.git', 'node_modules', 'dist', '.temp', '.branches', '.wrangler',
  '.t10-dryrun', 'snapshots', 'legacy_migrations_backup',
  'config_backups', '.backup', 'backup-output',
])

function shouldInclude(relativePath) {
  const relative = relativePath.replaceAll('\\', '/').replace(/^\/+/, '')
  const segments = relative.split('/')
  if (segments.some((segment) => blockedDirectories.has(segment))) return false
  const leaf = segments.at(-1)
  if (/^\.env(?:\..*)?$/.test(leaf)) return ['.env.example', '.env.production.example'].includes(leaf)
  if (/^\.dev\.vars(?:\..*)?$/.test(leaf)) return leaf === '.dev.vars.example'
  if (relative === 'supabase/config.toml') return false
  if (/\.(zip|log|bak|tmp)$/.test(leaf)) return false
  return true
}

const cases = new Map([
  ['package.json', true],
  ['app/src/App.tsx', true],
  ['app/.env.example', true],
  ['app/.env.production.example', true],
  ['worker/.dev.vars.example', true],
  ['app/.env.local', false],
  ['app/.env.production', false],
  ['app/.env.production.local', false],
  ['worker/.dev.vars', false],
  ['supabase/config.toml', false],
  ['app/node_modules/pkg/index.js', false],
  ['app/dist/assets/app.js', false],
  ['docs/snapshots/old.zip', false],
  ['backup-output/full.backup.zip', false],
])

for (const [relative, expected] of cases) {
  const actual = shouldInclude(relative)
  if (actual !== expected) throw new Error(`package policy mismatch for ${relative}: ${actual}`)
}

const powerShell = fs.readFileSync('scripts/t18-package.ps1', 'utf8').replace(/^\uFEFF/, '')
for (const segment of blockedDirectories) {
  if (!powerShell.includes(`'${segment}'`)) throw new Error(`PowerShell package policy missing: ${segment}`)
}
for (const token of ['.env.production.example', '.dev.vars.example', 'supabase/config.toml']) {
  if (!powerShell.includes(token)) throw new Error(`PowerShell package policy missing token: ${token}`)
}

const requiredBlock = /\$requiredRelativePaths\s*=\s*@\(([\s\S]*?)\r?\n\s*\)/.exec(powerShell)
if (!requiredBlock) throw new Error('PowerShell package required-entry block is missing')
const requiredPaths = [...requiredBlock[1].matchAll(/^\s*'([^']+)'\s*$/gm)].map((match) => match[1])
const expectedRequiredPaths = [
  'package.json',
  'app/package.json',
  'scripts/t18-verify.ps1',
  'supabase/migrations/20260831105049_t16_audit_actor_history_independence.sql',
  'worker/src/index.js',
]
if (JSON.stringify(requiredPaths) !== JSON.stringify(expectedRequiredPaths)) {
  throw new Error(`PowerShell required-entry list mismatch: ${requiredPaths.join(', ')}`)
}
if (/^\s*\$prefix\s*\+\s*['"][^\r\n]+,\s*$/m.test(powerShell)) {
  throw new Error('PowerShell comma-expression regression can collapse required ZIP entries')
}
if (!powerShell.includes('$entry = $prefix + $relativePath')) {
  throw new Error('PowerShell must construct one required ZIP entry per foreach iteration')
}

console.log('T18 PACKAGE POLICY SELF TEST: PASS')
