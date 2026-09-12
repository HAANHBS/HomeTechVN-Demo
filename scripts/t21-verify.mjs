import path from 'node:path'
import { spawnSync } from 'node:child_process'

const root = path.resolve(process.cwd())
const node = process.execPath

function run(command, args, cwd = root) {
  const result = spawnSync(command, args, { cwd, stdio: 'inherit', shell: false, windowsHide: true })
  if (result.error) throw result.error
  if (result.status !== 0) throw new Error(`Command failed (${result.status}): ${command} ${args.join(' ')}`)
}

run(node, [path.join('scripts', 't21-ui-check.mjs')])
run(node, [path.join('scripts', 't21-2-ui-check.mjs')])
run(node, [path.join('scripts', 't21-3-ui-check.mjs')])
run(node, [path.join('scripts', 't20-logic-check.mjs')])
run(node, [path.join('app', 'node_modules', 'typescript', 'bin', 'tsc'), '-b', 'app'])
run(node, [path.join('node_modules', 'vite', 'bin', 'vite.js'), 'build'], path.join(root, 'app'))
run(node, [path.join('scripts', 't18-build-check.mjs')])
run(node, [path.join('scripts', 't21-3-build-check.mjs')])
run(node, ['--check', path.join('worker', 'src', 'index.js')])

console.log('T21 APP/PWA BUILD: PASS')
console.log('T21 WORKER REGRESSION: PASS')
console.log('T21 AUTOMATED SOURCE/BUILD DEMO GATE: PASS')
console.log('T21 PC ACCEPTANCE REQUIRED: NO')
