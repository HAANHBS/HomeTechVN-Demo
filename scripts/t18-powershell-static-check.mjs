import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
const manifestPath = path.join(root, 'scripts', 't18-powershell-managed.json')
let failed = false

function fail(file, message) {
  failed = true
  console.error(`[T18 PS STATIC FAIL] ${file}: ${message}`)
}

if (!fs.existsSync(manifestPath)) {
  console.error('[T18 PS STATIC FAIL] scripts/t18-powershell-managed.json: missing managed-source manifest')
  process.exit(1)
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'))
const files = Array.isArray(manifest.files) ? manifest.files : []
if (!files.length) {
  console.error('[T18 PS STATIC FAIL] managed-source manifest contains no PowerShell files')
  process.exit(1)
}

function checkBalance(file, text) {
  const stack = []
  let mode = 'code'
  let blockComment = false
  let hereString = null
  const lines = text.split(/\r?\n/)

  for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    const line = lines[lineIndex]
    if (hereString) {
      if (line.trim() === `${hereString}@`) hereString = null
      continue
    }
    if (!blockComment && /^\s*@(["'])\s*$/.test(line)) {
      hereString = line.trim()[1]
      continue
    }

    for (let index = 0; index < line.length; index++) {
      const char = line[index]
      const next = line[index + 1]
      if (blockComment) {
        if (char === '#' && next === '>') { blockComment = false; index++ }
        continue
      }
      if (mode === 'single') {
        if (char === "'" && next === "'") { index++; continue }
        if (char === "'") mode = 'code'
        continue
      }
      if (mode === 'double') {
        if (char === '`') { index++; continue }
        if (char === '"') mode = 'code'
        continue
      }
      if (char === '<' && next === '#') { blockComment = true; index++; continue }
      if (char === '#') break
      if (char === "'") { mode = 'single'; continue }
      if (char === '"') { mode = 'double'; continue }
      if ('({['.includes(char)) { stack.push([char, lineIndex + 1, index + 1]); continue }
      if (')}]'.includes(char)) {
        const wanted = { ')': '(', '}': '{', ']': '[' }[char]
        const found = stack.pop()
        if (!found || found[0] !== wanted) {
          fail(file, `unbalanced ${char} at ${lineIndex + 1}:${index + 1}`)
          return
        }
      }
    }
  }

  if (mode !== 'code') fail(file, `unterminated ${mode} string`)
  if (blockComment) fail(file, 'unterminated block comment')
  if (hereString) fail(file, 'unterminated here-string')
  if (stack.length) {
    const item = stack[stack.length - 1]
    fail(file, `unclosed ${item[0]} from ${item[1]}:${item[2]}`)
  }
}

const seen = new Set()
for (const relative of files) {
  if (typeof relative !== 'string' || !relative.toLowerCase().endsWith('.ps1')) {
    fail(String(relative), 'managed manifest entry is not a .ps1 path')
    continue
  }
  const key = relative.toLowerCase()
  if (seen.has(key)) {
    fail(relative, 'duplicate managed manifest entry')
    continue
  }
  seen.add(key)

  const file = path.join(root, ...relative.split('/'))
  if (!fs.existsSync(file) || !fs.statSync(file).isFile()) {
    fail(relative, 'managed PowerShell source file is missing')
    continue
  }

  const bytes = fs.readFileSync(file)
  if (!(bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF)) {
    fail(relative, 'missing UTF-8 BOM required for Windows PowerShell 5.1')
  }
  const text = bytes.toString('utf8').replace(/^\uFEFF/, '')
  const nonAscii = [...text].find((char) => char.charCodeAt(0) > 127)
  if (nonAscii) fail(relative, `non-ASCII source character U+${nonAscii.charCodeAt(0).toString(16).toUpperCase()}`)
  if (text.includes('\t')) fail(relative, 'literal TAB character is prohibited')
  if (/^\s*\|/m.test(text)) fail(relative, 'line-leading pipeline operator is prohibited for PS5.1 compatibility')
  if (/^\s*\$[A-Za-z_][A-Za-z0-9_]*\s*\+\s*[^\r\n]+,\s*$/m.test(text)) {
    fail(relative, 'comma-terminated concatenation can collapse array entries in PowerShell 5.1')
  }

  const functionNames = [...text.matchAll(/^\s*function\s+([A-Za-z0-9_-]+)\s*\{/gmi)]
    .map((match) => match[1].toLowerCase())
  const functionSet = new Set()
  for (const name of functionNames) {
    if (functionSet.has(name)) fail(relative, `duplicate function definition: ${name}`)
    functionSet.add(name)
  }
  checkBalance(relative, text)
}

const ignoredDirectories = new Set(['.git', 'node_modules', 'dist', 'snapshots', '.wrangler'])
function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.isDirectory() && ignoredDirectories.has(entry.name)) continue
    const full = path.join(directory, entry.name)
    if (entry.isDirectory()) walk(full)
    else if (entry.name.toLowerCase().endsWith('.ps1')) {
      const relative = path.relative(root, full).split(path.sep).join('/')
      if (!seen.has(relative.toLowerCase())) fail(relative, 'shipped project PowerShell file is not managed')
    }
  }
}
walk(root)

if (!failed) {
  console.log(`T18 POWERSHELL GLOBAL STATIC CHECK: PASS (${files.length} managed files, no unmanaged project scripts)`)
}
process.exit(failed ? 1 : 0)
