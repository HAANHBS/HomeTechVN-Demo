import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
const manifestPath = path.join(root, 'scripts', 't17-powershell-managed.json')
let failed = false

function fail(file, msg) {
  failed = true
  console.error(`[T17 PS STATIC FAIL] ${file}: ${msg}`)
}

if (!fs.existsSync(manifestPath)) {
  console.error('[T17 PS STATIC FAIL] scripts/t17-powershell-managed.json: missing managed-source manifest')
  process.exit(1)
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'))
const files = Array.isArray(manifest.files) ? manifest.files : []
if (!files.length) {
  console.error('[T17 PS STATIC FAIL] managed-source manifest contains no PowerShell files')
  process.exit(1)
}

function balance(file, text) {
  const stack = []
  let mode = 'code', block = false, here = null
  const lines = text.split(/\r?\n/)

  for (let li = 0; li < lines.length; li++) {
    const line = lines[li]
    if (here) {
      if (line.trim() === `${here}@`) here = null
      continue
    }
    if (!block && /^\s*@(["'])\s*$/.test(line)) {
      here = line.trim()[1]
      continue
    }

    for (let i = 0; i < line.length; i++) {
      const c = line[i], n = line[i + 1]
      if (block) {
        if (c === '#' && n === '>') { block = false; i++ }
        continue
      }
      if (mode === 'single') {
        if (c === "'" && n === "'") { i++; continue }
        if (c === "'") mode = 'code'
        continue
      }
      if (mode === 'double') {
        if (c === '`') { i++; continue }
        if (c === '"') mode = 'code'
        continue
      }
      if (c === '<' && n === '#') { block = true; i++; continue }
      if (c === '#') break
      if (c === "'") { mode = 'single'; continue }
      if (c === '"') { mode = 'double'; continue }
      if ('({['.includes(c)) { stack.push([c, li + 1, i + 1]); continue }
      if (')}]'.includes(c)) {
        const want = {')':'(', '}':'{', ']':'['}[c]
        const got = stack.pop()
        if (!got || got[0] !== want) {
          fail(file, `unbalanced ${c} at ${li + 1}:${i + 1}`)
          return
        }
      }
    }
  }

  if (mode !== 'code') fail(file, `unterminated ${mode} string`)
  if (block) fail(file, 'unterminated block comment')
  if (here) fail(file, 'unterminated here-string')
  if (stack.length) {
    const x = stack[stack.length - 1]
    fail(file, `unclosed ${x[0]} from ${x[1]}:${x[2]}`)
  }
}

const seen = new Set()
for (const rel of files) {
  if (typeof rel !== 'string' || !rel.toLowerCase().endsWith('.ps1')) {
    fail(String(rel), 'managed manifest entry is not a .ps1 path')
    continue
  }
  if (seen.has(rel.toLowerCase())) {
    fail(rel, 'duplicate managed manifest entry')
    continue
  }
  seen.add(rel.toLowerCase())

  const file = path.join(root, ...rel.split('/'))
  if (!fs.existsSync(file)) {
    fail(rel, 'managed PowerShell source file is missing')
    continue
  }
  const stat = fs.statSync(file)
  if (!stat.isFile()) {
    fail(rel, 'managed path is not a file')
    continue
  }

  const b = fs.readFileSync(file)
  if (!(b[0] === 0xEF && b[1] === 0xBB && b[2] === 0xBF)) {
    fail(rel, 'missing UTF-8 BOM required for Windows PowerShell 5.1')
  }
  const text = b.toString('utf8').replace(/^\uFEFF/, '')
  const nonAscii = [...text].find(c => c.charCodeAt(0) > 127)
  if (nonAscii) fail(rel, `non-ASCII source character U+${nonAscii.charCodeAt(0).toString(16).toUpperCase()}`)
  if (text.includes('\t')) fail(rel, 'literal TAB character is prohibited; use spaces and explicit backslash path separators')
  const fnNames=[...text.matchAll(/^\s*function\s+([A-Za-z0-9_-]+)\s*\{/gmi)].map(m=>m[1].toLowerCase())
  const fnSeen=new Set()
  for(const name of fnNames){
    if(fnSeen.has(name))fail(rel,`duplicate function definition: ${name}`)
    fnSeen.add(name)
  }
  if (/^\s*\|/m.test(text)) fail(rel, 'line-leading pipeline operator is prohibited for PS5.1 compatibility')
  balance(rel, text)
}

// Informational only: leftovers/vendor files are deliberately outside source ownership.
let ignored = 0
function walkForIgnored(dir) {
  for (const entry of fs.readdirSync(dir, {withFileTypes:true})) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      if (entry.name === '.git') continue
      walkForIgnored(full)
    } else if (entry.name.toLowerCase().endsWith('.ps1')) {
      const rel = path.relative(root, full).split(path.sep).join('/')
      if (!seen.has(rel.toLowerCase())) ignored++
    }
  }
}
walkForIgnored(root)

if (!failed) {
  console.log(`T17 PowerShell managed-source scope: PASS (${files.length} managed files; ${ignored} unmanaged/vendor .ps1 ignored)`)
  console.log(`T17 POWERSHELL GLOBAL STATIC CHECK: PASS (${files.length} managed files, UTF-8 BOM + ASCII + lexical balance)`)
}
process.exit(failed ? 1 : 0)
