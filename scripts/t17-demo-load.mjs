import fs from 'node:fs'
import path from 'node:path'
import { spawnSync } from 'node:child_process'

const root=path.resolve(process.cwd())
const isWin=process.platform==='win32'
const node=process.execPath
const docker=isWin?'docker.exe':'docker'
const npx=isWin?'npx.cmd':'npx'
const t17ExcludedServices='realtime,storage-api,imgproxy,mailpit,postgres-meta,studio,edge-runtime,logflare,vector,supavisor'
const demoPassword='HomeTechVN#Demo2026!'
const maxChildBuffer=64*1024*1024
const demoUsers=[
  {email:'demo.admin@hometechvn.example',fullName:'Demo Admin',role:'admin'},
  {email:'demo.manager@hometechvn.example',fullName:'Demo Manager',role:'manager'},
  {email:'demo.sales@hometechvn.example',fullName:'Demo Sales',role:'sales'},
  {email:'demo.technician@hometechvn.example',fullName:'Demo Technician',role:'technician'},
  {email:'demo.cashier@hometechvn.example',fullName:'Demo Cashier',role:'cashier'},
]

function cmdQuote(value){
  const s=String(value)
  if(!/[\s"&|<>^]/.test(s))return s
  return `"${s.replace(/"/g,'\\"')}"`
}
function redactConsole(value){
  return String(value||'')
    .replace(/(eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{10,})/g,'[REDACTED_JWT]')
    .replace(/(sb_(?:publishable|secret)_[a-zA-Z0-9_-]+)/g,'[REDACTED_SUPABASE_KEY]')
    .replace(/(HomeTechVN#Demo2026!)/g,'[REDACTED_DEMO_PASSWORD]')
}
function run(cmd,args,{inherit=false,input=null}={}){
  const common={cwd:root,windowsHide:true,shell:false,encoding:'utf8',input,maxBuffer:maxChildBuffer}
  let r
  if(isWin && /\.cmd$/i.test(cmd)){
    const comspec=process.env.ComSpec||'cmd.exe'
    const line=[cmd,...args].map(cmdQuote).join(' ')
    r=spawnSync(comspec,['/d','/s','/c',line],common)
  }else{
    r=spawnSync(cmd,args,common)
  }
  const stdout=String(r.stdout||'')
  const stderr=String(r.stderr||'')
  if(inherit&&stdout)process.stdout.write(redactConsole(stdout))
  if(inherit&&stderr)process.stderr.write(redactConsole(stderr))
  if(r.error)throw r.error
  if(r.status!==0){
    const detail=redactConsole([stdout,stderr].filter(Boolean).join('\n').trim())
    throw new Error(`Command failed (${r.status}): ${cmd} ${args.join(' ')}${detail?`\n${detail}`:''}`)
  }
  return {stdout,stderr}
}
function runNpxSupabase(args,{inherit=false}={}){
  return run(npx,['supabase',...args],{inherit})
}
function assertLocalUrl(apiUrl){
  const u=new URL(apiUrl)
  if(!['127.0.0.1','localhost','::1'].includes(u.hostname))throw new Error(`T17 demo loader REFUSES non-local Supabase URL: ${apiUrl}`)
}
function dotenvQuote(value){return `"${String(value).replace(/\\/g,'\\\\').replace(/"/g,'\\"')}"`}
function selfTest(){
  assertLocalUrl('http://127.0.0.1:54321')
  let blocked=false
  try{assertLocalUrl('https://example.supabase.co')}catch{blocked=true}
  if(!blocked)throw new Error('hosted URL safety self-test failed')
  if(dotenvQuote('abc#123')!=='"abc#123"')throw new Error('dotenv quote self-test failed')
  const sanitized=redactConsole(`sb_secret_${'x'.repeat(24)} ${demoPassword}`)
  if(sanitized.includes('sb_secret_')||sanitized.includes(demoPassword))throw new Error('console redaction self-test failed')
  console.log('T17 NODE DEMO LOADER SELF TEST: PASS')
}
function resolveLocalConfig(){
  const resolver=path.join(root,'scripts','t17-resolve-local-config.mjs')
  const r=run(node,[resolver,'--wait-for-auth'])
  let cfg
  try{cfg=JSON.parse(r.stdout.trim())}catch{throw new Error('Local config resolver returned invalid JSON')}
  if(!cfg?.apiUrl||!cfg?.publishableKey)throw new Error('Local config resolver returned incomplete data')
  assertLocalUrl(cfg.apiUrl)
  console.log(`[PASS] Local API/key resolution: ${cfg.apiUrl} / ${cfg.keyKind||'client-key'}`)
  return cfg
}
function resolveDbContainer(projectId){
  const r=run(docker,['ps','--format','{{.Names}}'])
  const names=r.stdout.split(/\r?\n/).map(x=>x.trim()).filter(Boolean)
  if(projectId){
    const exact=`supabase_db_${projectId}`
    if(names.includes(exact))return exact
  }
  const dbNames=names.filter(x=>x.startsWith('supabase_db_'))
  if(dbNames.length===1)return dbNames[0]
  throw new Error(`Could not uniquely resolve local Supabase DB container. Found: ${dbNames.join(', ')||'(none)'}`)
}
function runSqlFile(container,rel,expectedMarker=''){
  const file=path.join(root,...rel.split('/'))
  if(!fs.existsSync(file))throw new Error(`SQL file missing: ${rel}`)
  const sql=fs.readFileSync(file,'utf8')
  const r=run(docker,[
    'exec','-i',container,'psql',
    '-X',
    '-U','postgres',
    '-d','postgres',
    '-v','ON_ERROR_STOP=1',
    '-v','VERBOSITY=verbose',
    '-v','SHOW_CONTEXT=always',
    '-b',
  ],{input:sql})
  if(r.stdout)process.stdout.write(r.stdout)
  if(r.stderr)process.stderr.write(r.stderr)
  const all=`${r.stdout}\n${r.stderr}`
  if(expectedMarker&&!all.includes(expectedMarker))throw new Error(`Expected SQL marker missing: ${expectedMarker}`)
}
async function httpJson(url,{method='GET',key,token,body}={}){
  const headers={'apikey':key,'Content-Type':'application/json'}
  if(token)headers.Authorization=`Bearer ${token}`
  const response=await fetch(url,{method,headers,body:body===undefined?undefined:JSON.stringify(body)})
  const text=await response.text()
  let data=null
  if(text){try{data=JSON.parse(text)}catch{data=text}}
  if(!response.ok)throw new Error(`HTTP ${response.status} ${method} ${new URL(url).pathname}: ${typeof data==='string'?data:JSON.stringify(data)}`)
  return data
}
async function createDemoUser(local,user){
  const data=await httpJson(`${local.apiUrl}/auth/v1/signup`,{method:'POST',key:local.publishableKey,body:{email:user.email,password:demoPassword,data:{full_name:user.fullName,demo_stage:'T17',local_only:true}}})
  const id=data?.user?.id||data?.id
  if(!id)throw new Error(`Local signup did not return user id for ${user.email}`)
  console.log(`[PASS] Local Auth signup created ${user.email}`)
}
async function signInDemoUser(local,user){
  const session=await httpJson(`${local.apiUrl}/auth/v1/token?grant_type=password`,{method:'POST',key:local.publishableKey,body:{email:user.email,password:demoPassword}})
  const accessToken=session?.access_token,userId=session?.user?.id
  if(!accessToken||!userId)throw new Error(`Password sign-in failed for ${user.email}`)
  const profiles=await httpJson(`${local.apiUrl}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}&select=id,email,full_name,is_active,role_id`,{key:local.publishableKey,token:accessToken})
  if(!Array.isArray(profiles)||profiles.length!==1)throw new Error(`JWT self-profile RLS expected 1 row for ${user.email}, got ${Array.isArray(profiles)?profiles.length:'invalid response'}`)
  const profile=profiles[0]
  if(!profile.is_active||!profile.role_id)throw new Error(`Demo profile is inactive or role_id missing for ${user.email}`)
  const roles=await httpJson(`${local.apiUrl}/rest/v1/roles?id=eq.${encodeURIComponent(profile.role_id)}&select=code`,{key:local.publishableKey,token:accessToken})
  if(!Array.isArray(roles)||roles.length!==1)throw new Error(`JWT role metadata expected 1 row for ${user.email}`)
  const actualRole=String(roles[0].code||'').trim()
  if(actualRole!==user.role)throw new Error(`JWT role mismatch for ${user.email}: expected=${user.role}, actual=${actualRole}`)
  console.log(`[PASS] Login + JWT + self-profile RLS + role metadata: ${user.email} => ${actualRole}`)
  return {email:user.email,role:actualRole,userId,accessToken}
}
function writeDemoEnv(local){
  const envPath=path.join(root,'app','.env.local')
  const accounts=demoUsers.map(x=>`${x.fullName}|${x.email}`).join(',')
  const lines=[
    `VITE_SUPABASE_URL=${local.apiUrl}`,
    `VITE_SUPABASE_PUBLISHABLE_KEY=${local.publishableKey}`,
    'VITE_HOMETECHVN_DEMO_MODE=true',
    `VITE_HOMETECHVN_DEMO_ACCOUNTS=${dotenvQuote(accounts)}`,
    `VITE_HOMETECHVN_DEMO_PASSWORD=${dotenvQuote(demoPassword)}`,
    '',
  ]
  fs.writeFileSync(envPath,lines.join('\n'),'utf8')
}
function writeSnapshot(local){
  const dir=path.join(root,'docs','snapshots');fs.mkdirSync(dir,{recursive:true})
  const d=new Date(),stamp=d.toISOString().replace(/[-:]/g,'').replace('T','_').slice(0,15)
  const file=path.join(dir,`T17_DEMO_LOAD_${stamp}.json`)
  const snapshot={stage:'T17',mode:'LOCAL_ONLY',createdAt:d.toISOString(),apiUrl:local.apiUrl,realCustomerData:false,demoAccounts:demoUsers.map(x=>({email:x.email,role:x.role,loginVerified:true})),integrationSql:'PASS',authPasswordSignIn:'PASS',jwtSelfProfileRls:'PASS',jwtRoleMetadata:'PASS',dashboardRpc:'PASS',secretMaterialIncluded:false}
  fs.writeFileSync(file,JSON.stringify(snapshot,null,2)+'\n','utf8')
  return file
}
async function main(){
  if(process.argv.includes('--self-test')){selfTest();return}
  if(process.argv.includes('--preflight')){
    run(node,[path.join(root,'scripts','t17-powershell-static-check.mjs')],{inherit:true})
    run(node,[path.join(root,'scripts','t17-resolve-local-config.mjs'),'--self-test'],{inherit:true})
    run(node,[path.join(root,'scripts','t17-source-check.mjs')],{inherit:true})
  }
  console.log('=== HomeTechVN T17 LOCAL Demo Loader (Node) ===')
  console.log('SAFETY: destructive to LOCAL Supabase only; hosted URLs are refused.')
  console.log('')
  if(!process.argv.includes('--no-reset')){
    runNpxSupabase(['start','-x',t17ExcludedServices],{inherit:true})
    runNpxSupabase(['db','reset','--local'],{inherit:true})
  }
  const local=resolveLocalConfig()
  for(const user of demoUsers)await createDemoUser(local,user)
  const container=resolveDbContainer(local.projectId)
  console.log(`[PASS] Local DB container: ${container}`)
  console.log('\n=== Loading T17 integrated business dataset ===')
  runSqlFile(container,'supabase/t17_demo_data.sql')
  console.log('\n=== Database integration assertions ===')
  runSqlFile(container,'supabase/tests/t17_demo_assert.sql','T17 DEMO INTEGRATION CHECKS: PASS')
  console.log('\n=== Real local Auth sign-in assertions ===')
  const sessions=[]
  for(const user of demoUsers)sessions.push(await signInDemoUser(local,user))
  const admin=sessions.find(x=>x.role==='admin')
  if(!admin)throw new Error('Demo Admin session missing')
  const dashboard=await httpJson(`${local.apiUrl}/rest/v1/rpc/dashboard_snapshot`,{method:'POST',key:local.publishableKey,token:admin.accessToken,body:{p_days:30,p_now:null}})
  if(dashboard===null||dashboard===undefined)throw new Error('Demo Admin dashboard_snapshot via real JWT returned null')
  console.log('[PASS] Demo Admin JWT -> dashboard_snapshot')
  writeDemoEnv(local)
  const snapshotPath=writeSnapshot(local)
  sessions.length=0
  console.log('\n==========================================')
  console.log('T17 DEMO LOAD: PASS')
  console.log('T17 DEMO INTEGRATION CHECKS: PASS')
  console.log('T17 DEMO AUTH LOGIN CHECK: PASS')
  console.log('T17 DEMO ROLE JWT CHECK: PASS')
  console.log('T17 DEMO DASHBOARD RPC CHECK: PASS')
  console.log(`Demo snapshot: ${snapshotPath}`)
  console.log('Demo credentials: ephemeral local-only fixtures; password not printed')
  console.log('==========================================')
}
main().catch(err=>{
  const detail=err instanceof Error?err.message:String(err)
  console.log('\n[T17 DEMO LOAD FAIL]')
  console.log(detail)
  process.exit(1)
})
