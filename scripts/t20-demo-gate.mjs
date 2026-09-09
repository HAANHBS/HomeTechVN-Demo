import fs from 'node:fs'
import path from 'node:path'
import { spawnSync } from 'node:child_process'

const root=path.resolve(process.cwd())
const node=process.execPath
const npm=process.platform==='win32'?'npm.cmd':'npm'

function run(command,args){
  const result=spawnSync(command,args,{cwd:root,stdio:'inherit',shell:false,windowsHide:true})
  if(result.error)throw result.error
  if(result.status!==0)throw new Error(`Command failed (${result.status}): ${command} ${args.join(' ')}`)
}

const acceptance=fs.readFileSync(path.join(root,'supabase','tests','t20_demo_acceptance.sql'),'utf8')
if(!/\bbegin;[\s\S]*\brollback;[\s\S]*T20 AUTOMATED FAKE-DATA ACCEPTANCE: PASS/i.test(acceptance)){
  throw new Error('T20 fake-data acceptance must be transactional and self-rolling-back')
}
if(!acceptance.includes("value->>'mode'='HOSTED_DEMO'")||!acceptance.includes("contains_real_customer_data")){
  throw new Error('T20 fake-data safety gate is missing')
}

run(node,[path.join('scripts','t20-source-check.mjs')])
run(node,[path.join('scripts','t20-logic-check.mjs')])
run(npm,['--prefix','app','run','build'])
run(node,[path.join('scripts','t18-build-check.mjs')])
run(npm,['--prefix','worker','run','check'])

console.log('T20 AUTOMATED DEMO SOURCE/BUILD GATE: PASS')
console.log('T20 PC ACCEPTANCE REQUIRED: NO')
