import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
const dist = path.join(root, 'app', 'dist')
let failed = false
function fail(message) {
  failed = true
  console.error(`[T18 BUILD FAIL] ${message}`)
}

if (!fs.existsSync(dist)) fail('app/dist is missing')
else {
  const files = []
  function walk(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const full = path.join(directory, entry.name)
      if (entry.isDirectory()) walk(full)
      else files.push(full)
    }
  }
  walk(dist)
  if (files.some((file) => file.endsWith('.map'))) fail('production build contains source maps')
  const scripts = files.filter((file) => file.endsWith('.js'))
    .map((file) => fs.readFileSync(file, 'utf8')).join('\n')
  for (const token of ['LOCAL DEMO', 'demo.admin@hometechvn.example', 'HomeTechVN#Demo2026!']) {
    if (scripts.includes(token)) fail(`production bundle contains demo material: ${token}`)
  }
  if (!files.some((file) => file.endsWith('manifest.webmanifest'))) fail('PWA manifest missing')
  if (!files.some((file) => path.basename(file) === 'sw.js')) fail('service worker missing')
}

if (!failed) {
  console.log('T18 PRODUCTION BUILD DEMO/SOURCEMAP EXCLUSION: PASS')
}
process.exit(failed ? 1 : 0)
