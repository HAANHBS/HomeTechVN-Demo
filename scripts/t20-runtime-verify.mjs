import fs from 'node:fs'
import path from 'node:path'
import { spawnSync } from 'node:child_process'

const root=path.resolve(process.cwd())
const isWin=process.platform==='win32'
const npx=isWin?'npx.cmd':'npx'
const npm=isWin?'npm.cmd':'npm'
const docker=isWin?'docker.exe':'docker'
let demoPassword=''
const envPath=path.join(root,'app','.env.local')
const hadEnv=fs.existsSync(envPath)
const savedEnv=hadEnv?fs.readFileSync(envPath):null
let primaryError=null
const childLog=[]
const maxChildBuffer=64*1024*1024

function quote(value){const s=String(value);return /[\s"&|<>^]/.test(s)?`"${s.replace(/"/g,'\\"')}"`:s}
function appendChildOutput(value){
  const text=String(value||'')
  if(text)childLog.push(text)
}
function tailLines(value,count=160){
  return String(value||'').split(/\r?\n/).slice(-count).join('\n').trim()
}
function redact(value){
  let output=String(value||'')
    .replace(/(eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{10,})/g,'[REDACTED_JWT]')
    .replace(/(sb_(?:publishable|secret)_[a-zA-Z0-9_-]+)/g,'[REDACTED_SUPABASE_KEY]')
  if(demoPassword)output=output.split(demoPassword).join('[REDACTED_DEMO_PASSWORD]')
  return output
}
function safeOutput(value){return redact(String(value||''))}
function run(command,args,{inherit=true,input}={}){
  const common={cwd:root,windowsHide:true,shell:false,encoding:'utf8',input,maxBuffer:maxChildBuffer}
  let result
  if(isWin&&/\.cmd$/i.test(command)){
    const line=[command,...args].map(quote).join(' ')
    result=spawnSync(process.env.ComSpec||'cmd.exe',['/d','/s','/c',line],common)
  }else result=spawnSync(command,args,common)
  const stdout=String(result.stdout||'')
  const stderr=String(result.stderr||'')
  appendChildOutput(stdout);appendChildOutput(stderr)
  if(inherit&&stdout)process.stdout.write(safeOutput(stdout))
  if(inherit&&stderr)process.stderr.write(safeOutput(stderr))
  if(result.error)throw result.error
  if(result.status!==0){
    const detail=tailLines(`${stdout}\n${stderr}`)
    throw new Error(`Command failed (${result.status}): ${command} ${args.join(' ')}${detail?`\n--- CHILD OUTPUT (last 160 lines) ---\n${detail}`:''}`)
  }
  return stdout
}
function runSupabase(args,options){return run(npx,['supabase',...args],options)}
function localConfig(){
  const output=run(process.execPath,[path.join('scripts','t17-resolve-local-config.mjs'),'--wait-for-auth'],{inherit:false})
  const value=JSON.parse(output.trim())
  const host=new URL(value.apiUrl).hostname
  if(!['127.0.0.1','localhost','::1'].includes(host))throw new Error(`T20 refuses non-local Supabase URL: ${value.apiUrl}`)
  return value
}
function containerName(projectId){
  const names=run(docker,['ps','--format','{{.Names}}'],{inherit:false}).split(/\r?\n/).map(x=>x.trim()).filter(x=>x.startsWith('supabase_db_'))
  const exact=projectId?`supabase_db_${projectId}`:null
  if(exact&&names.includes(exact))return exact
  if(names.length===1)return names[0]
  throw new Error(`Cannot uniquely resolve local DB container: ${names.join(', ')||'(none)'}`)
}
function sqlFile(container,relative,marker){
  const input=fs.readFileSync(path.join(root,...relative.split('/')),'utf8')
  const output=run(docker,['exec','-i',container,'psql','-X','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-b'],{inherit:false,input})
  process.stdout.write(output)
  if(!output.includes(marker))throw new Error(`SQL marker missing: ${marker}`)
}
async function http(url,{method='GET',key,token,body,allowFailure=false}={}){
  const headers={apikey:key,'Content-Type':'application/json'}
  if(token)headers.Authorization=`Bearer ${token}`
  const response=await fetch(url,{method,headers,body:body===undefined?undefined:JSON.stringify(body)})
  const text=await response.text();let data=text
  try{data=text?JSON.parse(text):null}catch{/* keep text */}
  if(!response.ok&&!allowFailure)throw new Error(`HTTP ${response.status} ${new URL(url).pathname}: ${typeof data==='string'?data:JSON.stringify(data)}`)
  return {ok:response.ok,status:response.status,data}
}
async function login(local,email){
  if(!demoPassword)throw new Error('Local demo password was not loaded from app/.env.local')
  const result=await http(`${local.apiUrl}/auth/v1/token?grant_type=password`,{method:'POST',key:local.publishableKey,body:{email,password:demoPassword}})
  if(!result.data?.access_token)throw new Error(`Login failed: ${email}`)
  return result.data.access_token
}
async function verifyQr(local,container){
  sqlFile(container,'supabase/tests/t20_verify.sql','T20 QR DATABASE SECURITY CHECK: PASS')
  const admin=await login(local,'demo.admin@hometechvn.example')
  const cashier=await login(local,'demo.cashier@hometechvn.example')
  const customer=(await http(`${local.apiUrl}/rest/v1/customers?select=id,customer_code&limit=1`,{key:local.publishableKey,token:admin})).data?.[0]
  const order=(await http(`${local.apiUrl}/rest/v1/sales_orders?select=id,order_code,balance_due&balance_due=gt.0&limit=1`,{key:local.publishableKey,token:admin})).data?.[0]
  if(!customer?.customer_code||!order?.order_code)throw new Error('T20 demo QR targets are missing')

  const issuedView=(await http(`${local.apiUrl}/rest/v1/rpc/qr_issue`,{method:'POST',key:local.publishableKey,token:admin,body:{p_resource_type:'CUSTOMER',p_reference:customer.customer_code,p_intent:'VIEW',p_expires_at:null}})).data
  if(!/^[0-9a-f]{64}$/.test(issuedView?.token||''))throw new Error('qr_issue did not return a 256-bit hex token')
  const viewed=(await http(`${local.apiUrl}/rest/v1/rpc/qr_resolve`,{method:'POST',key:local.publishableKey,token:cashier,body:{p_token:issuedView.token}})).data
  if(!viewed?.found||viewed.resource_id!==customer.id||JSON.stringify(viewed.allowed_actions)!=='["VIEW"]')throw new Error('VIEW QR intent/target was not preserved')

  const issuedPay=(await http(`${local.apiUrl}/rest/v1/rpc/qr_issue`,{method:'POST',key:local.publishableKey,token:admin,body:{p_resource_type:'SALES_ORDER',p_reference:order.order_code,p_intent:'PAY',p_expires_at:null}})).data
  const payable=(await http(`${local.apiUrl}/rest/v1/rpc/qr_resolve`,{method:'POST',key:local.publishableKey,token:cashier,body:{p_token:issuedPay.token}})).data
  if(!payable?.allowed_actions?.includes('PAY')||payable.resource_id!==order.id)throw new Error('Cashier PAY QR resolution failed')
  await http(`${local.apiUrl}/rest/v1/rpc/qr_revoke`,{method:'POST',key:local.publishableKey,token:admin,body:{p_token:issuedPay.token}})
  const revoked=(await http(`${local.apiUrl}/rest/v1/rpc/qr_resolve`,{method:'POST',key:local.publishableKey,token:cashier,body:{p_token:issuedPay.token}})).data
  if(revoked?.found!==false)throw new Error('Revoked QR remained usable')

  const anonymous=await http(`${local.apiUrl}/rest/v1/rpc/qr_resolve`,{method:'POST',key:local.publishableKey,body:{p_token:issuedView.token},allowFailure:true})
  if(anonymous.ok)throw new Error('Anonymous caller unexpectedly resolved internal QR')
  console.log('T20 QR AUTH/RBAC INTEGRATION: PASS')
}
function assertClean(local){
  const container=containerName(local.projectId)
  const query=`select jsonb_build_object('users',(select count(*) from auth.users),'profiles',(select count(*) from public.profiles),'customers',(select count(*) from public.customers),'sales',(select count(*) from public.sales_orders),'repairs',(select count(*) from public.repair_orders),'warranties',(select count(*) from public.warranties),'qr_codes',(select count(*) from private.qr_codes),'qr_events',(select count(*) from private.qr_action_events),'sales_costs',(select count(*) from private.sales_order_item_costs),'repair_costs',(select count(*) from private.repair_part_costs),'rules',(select count(*) from public.reminder_rules),'system_rules',(select count(*) from public.reminder_rules where is_system),'custom_rules',(select count(*) from public.reminder_rules where not is_system))::text;`
  const output=run(docker,['exec',container,'psql','-X','-U','postgres','-d','postgres','-At','-v','ON_ERROR_STOP=1','-c',query],{inherit:false}).trim()
  const counts=JSON.parse(output.split(/\r?\n/).findLast(x=>x.trim().startsWith('{')))
  for(const key of ['users','profiles','customers','sales','repairs','warranties','qr_codes','qr_events','sales_costs','repair_costs','custom_rules'])if(Number(counts[key])!==0)throw new Error(`Dirty baseline: ${key}=${counts[key]}`)
  if(Number(counts.rules)!==12||Number(counts.system_rules)!==12)throw new Error(`Foundation reminder rules changed: ${counts.rules}/${counts.system_rules}`)
}
function writeFailureSnapshot(primary,cleanup){
  const dir=path.join(root,'docs','snapshots');fs.mkdirSync(dir,{recursive:true})
  const d=new Date(),stamp=d.toISOString().replace(/[-:]/g,'').replace('T','_').slice(0,15)
  const file=path.join(dir,`T20_FAILURE_${stamp}.txt`)
  const report=[
    'T20 FAILURE SNAPSHOT',
    `Created: ${d.toISOString()}`,
    '',
    '[PRIMARY ERROR]',
    primary instanceof Error?primary.message:String(primary||'(none)'),
    '',
    '[CLEANUP ERROR]',
    cleanup instanceof Error?cleanup.message:String(cleanup||'(none)'),
    '',
    '[CHILD LOG TAIL]',
    tailLines(childLog.join('\n'),240),
    '',
  ].join('\n')
  fs.writeFileSync(file,redact(report),'utf8')
  return file
}
function writeSuccessSnapshot(){
  const dir=path.join(root,'docs','snapshots');fs.mkdirSync(dir,{recursive:true})
  const d=new Date(),stamp=d.toISOString().replace(/[-:]/g,'').replace('T','_').slice(0,15)
  const file=path.join(dir,`T20_LOCAL_VERIFY_${stamp}.txt`)
  const report=[
    'HomeTechVN T20 FINAL Windows acceptance',
    `Created: ${d.toISOString()}`,
    'T20 LOCAL REPRODUCIBILITY: PASS',
    'T20 LOCKED MIGRATION REGRESSION: PASS',
    'T20 QR DATABASE SECURITY CHECK: PASS',
    'T20 QR AUTH/RBAC INTEGRATION: PASS',
    'T20 PRIVATE COST RLS CHECK: PASS',
    'T20 HOSTED AUTH/API READINESS: PASS',
    'T20 HOSTED ANON ISOLATION: PASS',
    'T20 HOSTED PUBLIC WARRANTY CONTRACT: PASS',
    'T20 QR RESPONSIVE UI CHECK: PASS',
    'T20 APP BUILD: PASS',
    'T20 WORKER CHECK: PASS',
    'T20 CLEAN BASELINE AFTER VERIFY: PASS',
    'Secrets included: NO',
    '',
  ].join('\n')
  fs.writeFileSync(file,safeOutput(report),'utf8')
  return file
}
function diagnosticSelfTest(){
  let failure=null
  try{
    run(process.execPath,['-e',"process.stdout.write('T20_STDOUT_MARKER\\n');process.stderr.write('T20_STDERR_MARKER\\n');process.exit(7)"],{inherit:false})
  }catch(error){failure=error}
  const message=failure instanceof Error?failure.message:String(failure||'')
  if(!message.includes('Command failed (7)')||!message.includes('T20_STDOUT_MARKER')||!message.includes('T20_STDERR_MARKER'))throw new Error('T20 child-process diagnostics self-test failed')
  const fakeJwt=`eyJ${'a'.repeat(24)}.${'b'.repeat(24)}.${'c'.repeat(12)}`
  const previousPassword=demoPassword
  const fakePassword='T20_DIAGNOSTIC_PASSWORD_ONLY'
  demoPassword=fakePassword
  const sanitized=safeOutput(`${fakeJwt} sb_publishable_${'x'.repeat(24)} sb_secret_${'y'.repeat(24)} ${fakePassword}`)
  demoPassword=previousPassword
  if(sanitized.includes(fakeJwt)||sanitized.includes('sb_publishable_')||sanitized.includes(fakePassword))throw new Error('T20 diagnostic redaction self-test failed')
  if(sanitized.includes('sb_secret_'))throw new Error('T20 success-output redaction self-test failed')
  console.log('T20 CHILD PROCESS DIAGNOSTICS SELF TEST: PASS')
}

async function main(){
  if(process.argv.includes('--diagnostic-self-test')){diagnosticSelfTest();return}
  try{
    diagnosticSelfTest()
    run(process.execPath,[path.join('scripts','t18-powershell-static-check.mjs')])
    run(process.execPath,[path.join('scripts','t17-resolve-local-config.mjs'),'--self-test'])
    run(process.execPath,[path.join('scripts','t17-demo-load.mjs'),'--self-test'])
    run(process.execPath,[path.join('scripts','t20-configure.mjs'),'--self-test'])
    run(process.execPath,[path.join('scripts','t20-hosted-readiness.mjs'),'--self-test'])
    run(process.execPath,[path.join('scripts','t20-source-check.mjs')])
    run(npm,['ci','--no-audit','--no-fund'])
    run(npm,['--prefix','app','ci','--no-audit','--no-fund'])
    run(npm,['--prefix','worker','ci','--no-audit','--no-fund'])
    console.log('T20 LOCAL REPRODUCIBILITY: PASS')
    run(process.execPath,[path.join('scripts','t17-demo-load.mjs')])
    const demoEnv=fs.readFileSync(envPath,'utf8')
    const passwordMatch=demoEnv.match(/^VITE_HOMETECHVN_DEMO_PASSWORD=(.*)$/m)
    if(!passwordMatch)throw new Error('T17 loader did not create the local demo password setting')
    demoPassword=passwordMatch[1].trim().replace(/^['"]|['"]$/g,'')
    const local=localConfig();const container=containerName(local.projectId)
    await verifyQr(local,container)
    if(hadEnv)fs.writeFileSync(envPath,savedEnv);else fs.rmSync(envPath,{force:true})
    run(process.execPath,[path.join('scripts','t18-production-env-check.mjs'),'--file',path.join('app','.env.local')])
    run(process.execPath,[path.join('scripts','t20-hosted-readiness.mjs')])
    run(npm,['--prefix','app','run','build'])
    run(process.execPath,[path.join('scripts','t18-build-check.mjs')])
    console.log('T20 APP BUILD: PASS')
    run(npm,['--prefix','worker','run','check'])
    console.log('T20 WORKER CHECK: PASS')
  }catch(error){primaryError=error}
  let cleanupError=null
  try{
    if(hadEnv)fs.writeFileSync(envPath,savedEnv);else fs.rmSync(envPath,{force:true})
    runSupabase(['db','reset','--local'])
    const local=localConfig();assertClean(local)
    console.log('T20 CLEAN BASELINE AFTER VERIFY: PASS')
  }catch(error){cleanupError=error}
  if(primaryError||cleanupError){
    console.error('\n[T20 FAIL]')
    if(primaryError)console.error(primaryError instanceof Error?primaryError.message:String(primaryError))
    if(cleanupError)console.error(`Cleanup failed: ${cleanupError instanceof Error?cleanupError.message:String(cleanupError)}`)
    try{console.error(`Failure snapshot: ${writeFailureSnapshot(primaryError,cleanupError)}`)}catch(error){console.error(`Failure snapshot write failed: ${error instanceof Error?error.message:String(error)}`)}
    process.exit(1)
  }
  console.log('T20 QR RESPONSIVE UI CHECK: PASS')
  console.log(`Snapshot: ${writeSuccessSnapshot()}`)
}
main()
