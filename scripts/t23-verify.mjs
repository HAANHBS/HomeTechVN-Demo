import path from 'node:path'
import { spawnSync } from 'node:child_process'

const root = path.resolve(process.cwd())
const node = process.execPath
function run(command, args, cwd = root) {
  const result = spawnSync(command, args, { cwd, stdio: 'inherit', shell: false, windowsHide: true })
  if (result.error) throw result.error
  if (result.status !== 0) throw new Error(`Command failed (${result.status}): ${command} ${args.join(' ')}`)
}
for (const script of ['t21-ui-check.mjs','t21-2-ui-check.mjs','t21-3-ui-check.mjs','t21-4-ui-check.mjs','t20-logic-check.mjs','t23-ui-check.mjs']) run(node, [path.join('scripts', script)])
run(node, [path.join('app','node_modules','typescript','bin','tsc'), '-b', 'app'])
run(node, [path.join('node_modules','vite','bin','vite.js'), 'build'], path.join(root, 'app'))
for (const script of ['t18-build-check.mjs','t21-3-build-check.mjs','t21-4-build-check.mjs','t23-build-check.mjs']) run(node, [path.join('scripts', script)])
run(node, ['--check', path.join('worker','src','index.js')])
console.log('T23 FULL SOURCE/TYPE/PWA/WORKER REGRESSION: PASS')
