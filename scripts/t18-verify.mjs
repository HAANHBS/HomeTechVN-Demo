import { spawnSync } from 'node:child_process'
import path from 'node:path'

const root = process.cwd()
function run(command, args) {
  const result = spawnSync(command, args, { cwd: root, stdio: 'inherit', shell: false })
  if (result.error) {
    console.error(result.error.message)
    process.exit(1)
  }
  if (result.status !== 0) process.exit(result.status ?? 1)
}

run(process.execPath, [path.join('scripts', 't18-powershell-static-check.mjs')])
run(process.execPath, [path.join('scripts', 't18-source-check.mjs')])
run(process.execPath, [path.join('scripts', 't18-configure.mjs'), '--self-test'])
run(process.execPath, [path.join('scripts', 't18-production-env-check.mjs'), '--self-test'])
run(process.execPath, [path.join('scripts', 't18-worker-self-test.mjs')])
run(process.execPath, [path.join('scripts', 't18-package-policy-self-test.mjs')])
run('powershell.exe', [
  '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(root, 'scripts', 't18-verify.ps1'),
])
