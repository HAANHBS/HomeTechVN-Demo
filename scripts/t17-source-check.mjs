import fs from 'node:fs'
import path from 'node:path'
const root=path.resolve(process.cwd())
let failed=false
function fail(m){failed=true;console.error(`[T17 SOURCE FAIL] ${m}`)}
function read(r){return fs.readFileSync(path.join(root,r),'utf8')}
const pkg=JSON.parse(read('package.json')), appPkg=JSON.parse(read('app/package.json'))
const nodeLoader=read('scripts/t17-demo-load.mjs')
const psWrapper=read('scripts/t17-demo-load.ps1')
const verifyPs=read('scripts/t17-verify.ps1')
const resolver=read('scripts/t17-resolve-local-config.mjs')
const psChecker=read('scripts/t17-powershell-static-check.mjs')
const demoSql=read('supabase/t17_demo_data.sql'), assertSql=read('supabase/tests/t17_demo_assert.sql')
const login=read('app/src/features/auth/LoginPage.tsx'), banner=read('app/src/features/demo/DemoModeBanner.tsx'), app=read('app/src/App.tsx'), viteEnv=read('app/src/vite-env.d.ts')
const t15=read('scripts/t15-restore-drill.ps1'), t16=read('scripts/t16-concurrency-check.ps1')
if(pkg.version!=='0.17.14-t17.14')fail(`root version ${pkg.version}`)
if(appPkg.version!=='0.17.14')fail(`app version ${appPkg.version}`)
const migrations=fs.readdirSync(path.join(root,'supabase','migrations')).filter(x=>x.endsWith('.sql')).sort()
if(migrations.length!==36)fail(`expected 36 migrations, found ${migrations.length}`)
if(migrations.some(x=>x.includes('_t17_')))fail('T17 must add zero DB migrations')
for(const token of ['T17 demo loader REFUSES non-local Supabase URL','t17-resolve-local-config.mjs','/auth/v1/signup','/auth/v1/token?grant_type=password','/rest/v1/profiles?id=eq.','/rest/v1/roles?id=eq.','/rest/v1/rpc/dashboard_snapshot','supabase/t17_demo_data.sql','supabase/tests/t17_demo_assert.sql','T17 DEMO AUTH LOGIN CHECK: PASS','T17 DEMO ROLE JWT CHECK: PASS'])if(!nodeLoader.includes(token))fail(`Node demo loader missing: ${token}`)
if(nodeLoader.includes('SERVICE_ROLE_KEY')||nodeLoader.includes('SECRET_KEY')||nodeLoader.includes('ServiceRoleKey'))fail('Node demo loader must not require secret/service-role')
if(/https:\/\/puqvbenyenwemfbsqpfd\.supabase\.co/i.test(nodeLoader))fail('Node loader contains hosted project URL')
if((psWrapper.match(/^\s*function\s+/gmi)||[]).length!==0)fail('t17-demo-load.ps1 must remain a function-free compatibility wrapper')
if(!psWrapper.includes('t17-demo-load.mjs'))fail('PowerShell compatibility wrapper must delegate to Node loader')
if(verifyPs.includes("scripts\\t17-demo-load.ps1")||verifyPs.includes("scripts/t17-demo-load.ps1"))fail('T17 verifier must not execute PowerShell demo loader')
if(!verifyPs.includes("scripts\\t17-demo-load.mjs"))fail('T17 verifier must invoke Node demo loader')
if(!verifyPs.includes("@('supabase','start','-x',$T17ExcludedServices)"))fail('T17 verifier must start the minimal Auth/API integration stack')
if(verifyPs.includes("@('supabase','db','start')"))fail('T17 verifier must not use DB-only start')
if(!verifyPs.includes("'--no-reset'"))fail('T17 verifier must not reset/restart Auth a second time before demo integration')
if(!nodeLoader.includes("runNpxSupabase(['start','-x',t17ExcludedServices]"))fail('Standalone T17 demo loader must start the minimal Auth/API integration stack')
if(nodeLoader.includes("runNpxSupabase(['db','start']"))fail('Standalone T17 demo loader must not use DB-only start')

const expectedT17Exclusions='realtime,storage-api,imgproxy,mailpit,postgres-meta,studio,edge-runtime,logflare,vector,supavisor'
if(!verifyPs.includes(expectedT17Exclusions))fail('T17 verifier minimal-service exclusion list missing or changed')
if(!nodeLoader.includes(expectedT17Exclusions))fail('T17 standalone loader minimal-service exclusion list missing or changed')
for(const required of ['storage-api','studio','logflare','vector']){
  if(!expectedT17Exclusions.split(',').includes(required))fail(`T17 Windows-unhealthy service exclusion missing: ${required}`)
}
if(!verifyPs.includes('T17 CLEAN BASELINE AFTER VERIFY: PASS'))fail('T17 verifier must assert clean final baseline')
if(!verifyPs.includes('Assert-CleanBusinessBaseline'))fail('T17 verifier clean-baseline function missing')
if(!verifyPs.includes("Restore-AppEnvState"))fail('T17 verifier must restore app/.env.local')

if(!psChecker.includes('duplicate function definition'))fail('PowerShell checker missing duplicate-function regression guard')
for(const token of [
  'T17 LOCAL CONFIG RESOLVER SELF TEST: PASS',
  'T17 AUTH READINESS RETRY CONTRACT: PASS',
  "['supabase','status','-o','json']",
  "['supabase','status','-o','env']",
  "['supabase','status']",
  "['ps','--format','{{.Names}}']",
  'DB_URL can',
  'GoTrue is ready',
  'waitForAuth',
  'projectId:config.projectId||null',
])if(!resolver.includes(token))fail(`resolver missing: ${token}`)
if(resolver.includes('supabase_kong_')||resolver.includes('supabase_auth_')||resolver.includes('supabase_rest_'))fail('resolver must not guess container component names')
for(const token of ['T17 DEMO SALE COMPLETED','sale_complete','warranty_create_sale','T17 DEMO REPAIR COMPLETED','repair_complete','warranty_create_repair','service_schedule_create','T17 DEMO LICENSE EXPIRING','reminder_generate','notification_prepare',"'LOCAL_ONLY'"])if(!demoSql.includes(token))fail(`demo SQL missing ${token}`)

const badJwtOrder=/set\s+local\s+role\s+authenticated\s*;\s*select\s+set_config\(\s*'request\.jwt\.claim\.sub'[\s\S]*?from\s+public\.profiles/ig
if(badJwtOrder.test(demoSql))fail('demo SQL must resolve JWT sub before SET LOCAL ROLE authenticated; otherwise profiles RLS hides the user id')
badJwtOrder.lastIndex=0
if(badJwtOrder.test(assertSql))fail('assert SQL must resolve JWT sub before SET LOCAL ROLE authenticated')
const roleBlocks=(demoSql.match(/set\s+local\s+role\s+authenticated\s*;/ig)||[]).length
const jwtAssignments=(demoSql.match(/select\s+set_config\(\s*'request\.jwt\.claim\.sub'/ig)||[]).length
if(roleBlocks!==jwtAssignments)fail(`demo SQL JWT/role block mismatch: roles=${roleBlocks}, jwt=${jwtAssignments}`)
if(roleBlocks!==11)fail(`demo SQL expected 11 authenticated role phases, found ${roleBlocks}`)
for(const token of [
  '[T17 SQL PHASE] ADMIN_CATALOG',
  '[T17 SQL PHASE] SALES_CRM_AND_SALES',
  '[T17 SQL PHASE] CASHIER_PAYMENT',
  '[T17 SQL PHASE] TECH_WARRANTY_CLAIM',
  '[T17 SQL PHASE] TECH_REPAIR_COMPLETED',
  '[T17 SQL PHASE] ADMIN_REMINDER_NOTIFICATION',
  '[T17 SQL PHASE] DATASET_COMPLETE',
  'T17 AUTH/PERMISSION CONTEXT FAIL:',
])if(!demoSql.includes(token))fail(`demo SQL phase/context guard missing: ${token}`)
if(!assertSql.includes('[T17 SQL PHASE] ASSERT_ADMIN_RPC_CONTEXT'))fail('assert SQL Admin role-context phase missing')
if(/private\.current_role_code\s*\(/i.test(demoSql))fail('T17 demo SQL must not call private.current_role_code() from authenticated test context')
if(/private\.current_role_code\s*\(/i.test(assertSql))fail('T17 assert SQL must not call private.current_role_code() from authenticated test context')
const permissionGuards=(demoSql.match(/private\.has_permission\s*\(/ig)||[]).length
if(permissionGuards<11)fail(`T17 demo SQL expected at least 11 supported permission guards, found ${permissionGuards}`)
const privilegedRoleMaps=(demoSql.match(/T17 PRIVILEGED ROLE MAP FAIL:/g)||[]).length
if(privilegedRoleMaps!==11)fail(`T17 demo SQL expected 11 privileged role-map guards, found ${privilegedRoleMaps}`)
if(!assertSql.includes('T17 ASSERT PRIVILEGED ROLE MAP FAIL:'))fail('T17 assert SQL privileged role-map guard missing')
if(!demoSql.includes("'T17 DEMO partial receivable payment'"))fail('T17 receivable fixture must use a real partial payment')
if(!demoSql.includes("'DEMO-AR-001'"))fail('T17 receivable partial-payment reference missing')
if(!demoSql.includes("100000"))fail('T17 receivable partial-payment amount missing')
const receivableConfirm=demoSql.indexOf("note='T17 DEMO RECEIVABLE')")
const cashierPhase=demoSql.indexOf('[T17 SQL PHASE] CASHIER_PAYMENT')
const receivablePartial=demoSql.indexOf("'T17 DEMO partial receivable payment'")
if(receivableConfirm<0||cashierPhase<0||receivablePartial<0||!(receivableConfirm<cashierPhase&&cashierPhase<receivablePartial)){
  fail('T17 receivable order must be created/confirmed by Sales and partially paid by Cashier')
}
for(const token of [
  "status='PAYMENT_PENDING'",
  'paid_amount=100000',
  'balance_due=560000',
  'payment_pending_at is not null',
  "rule_code_snapshot='RECEIVABLE_DUE'",
  'RECEIVABLE_DUE reminder missing',
])if(!assertSql.includes(token))fail(`T17 receivable assertion contract missing: ${token}`)
if(!demoSql.includes('\\o /dev/null')||!assertSql.includes('\\o /dev/null'))fail('T17 SQL must suppress verbose query-result output')

function extractRoleBlock(sql,role){
  const startToken=`set local role ${role};`
  const start=sql.indexOf(startToken)
  if(start<0)return ''
  const end=sql.indexOf('reset role;',start+startToken.length)
  if(end<0)return sql.slice(start)
  return sql.slice(start,end)
}

const anonAssertBlock=extractRoleBlock(assertSql,'anon')
if(!anonAssertBlock)fail('T17 assert SQL anon public-warranty block missing')
for(const forbidden of [
  /\bfrom\s+public\./i,
  /\bjoin\s+public\./i,
  /\binsert\s+into\s+public\./i,
  /\bupdate\s+public\./i,
  /\bdelete\s+from\s+public\./i,
]){
  if(forbidden.test(anonAssertBlock))fail('T17 anon assertion must not access public tables directly; RPC-only contract required')
}
if(!anonAssertBlock.includes('public.warranty_public_lookup(v_token)'))fail('T17 anon assertion must execute public warranty RPC')
if(!assertSql.includes("'t17.public_warranty_token'"))fail('T17 public warranty token must be captured before anon role')
const tokenCapture=assertSql.indexOf("'t17.public_warranty_token'")
const anonSwitch=assertSql.indexOf('set local role anon;')
if(tokenCapture<0||anonSwitch<0||tokenCapture>anonSwitch)fail('T17 public warranty token must be captured before SET LOCAL ROLE anon')
if(!assertSql.includes('[T17 SQL PHASE] ASSERT_ANON_PUBLIC_WARRANTY_RPC'))fail('T17 anon public warranty phase marker missing')

const authAssertBlock=extractRoleBlock(assertSql,'authenticated')
if(!authAssertBlock)fail('T17 assert SQL authenticated RPC block missing')
for(const forbidden of [
  /\bfrom\s+public\.(?:warranties|customers|customer_devices|sales_orders|repair_orders|payments|reminders|notifications)\b/i,
  /\bjoin\s+public\.(?:warranties|customers|customer_devices|sales_orders|repair_orders|payments|reminders|notifications)\b/i,
]){
  if(forbidden.test(authAssertBlock))fail('T17 authenticated assertion RPC block must not bypass intended RPC boundary with business-table reads')
}

for(const [name,text] of [['demoSql',demoSql],['assertSql',assertSql]]){
  for(let i=0;i<text.length;i++){
    if(text.charCodeAt(i)>127)fail(`T17 ${name} must remain ASCII-only for Windows psql transport; non-ASCII at offset ${i}`)
  }
}


if(!nodeLoader.includes("'-v','VERBOSITY=verbose'")||!nodeLoader.includes("'-v','SHOW_CONTEXT=always'")||!nodeLoader.includes("'-b'"))fail('Node SQL runner must preserve detailed psql diagnostics')
if(!nodeLoader.includes("console.log('\\n[T17 DEMO LOAD FAIL]')"))fail('T17 demo failure must print to stdout to avoid PowerShell RemoteException masking')

for(const token of [
  "'reminder_rules_total'",
  "'reminder_rules_system'",
  "'reminder_rules_non_system'",
  "'reminder_rule_codes'",
  "'RECEIVABLE_DUE'",
  "'WARRANTY_30D'",
  "'LOW_STOCK'",
  'T17 system reminder-rule foundation is intact: 12/12.',
]){
  if(!verifyPs.includes(token))fail(`T17 clean-baseline foundation contract missing: ${token}`)
}
if(verifyPs.includes("'reminder_rules', (select count(*) from public.reminder_rules)")){
  fail('T17 must not require system reminder_rules to be zero')
}
if(!verifyPs.includes('$appEnvRestoreCompleted = $false')||
   !verifyPs.includes('$appEnvRestoreCompleted = $true')||
   !verifyPs.includes('-not $restoreAlreadyCompleted')){
  fail('T17 app/.env.local cleanup must be idempotent')
}


for(const token of ['expected 5 active demo profiles','completed sale payment mismatch','completed repair','dashboard_snapshot','report_snapshot','security_audit_snapshot','warranty_public_lookup','ASSERT_ANON_PUBLIC_WARRANTY_RPC','T17 DEMO INTEGRATION CHECKS: PASS'])if(!assertSql.includes(token))fail(`assert SQL missing ${token}`)
if(!login.includes("VITE_HOMETECHVN_DEMO_MODE === 'true'")||!login.includes('VITE_HOMETECHVN_DEMO_ACCOUNTS')||!login.includes('VITE_HOMETECHVN_DEMO_PASSWORD'))fail('login demo env contract incomplete')
if(login.includes('demo.admin@hometechvn.example')||login.includes('HomeTechVN#Demo2026!'))fail('frontend must not hard-code demo credentials')
if(!banner.includes('LOCAL DEMO · KHÔNG DÙNG DỮ LIỆU THẬT')||!app.includes('<DemoModeBanner />'))fail('demo banner contract missing')
if(!viteEnv.includes('VITE_HOMETECHVN_DEMO_ACCOUNTS')||!viteEnv.includes('VITE_HOMETECHVN_DEMO_PASSWORD'))fail('vite demo env types incomplete')
for(const x of ['[IO.Path]::GetRelativePath','[System.IO.Path]::GetRelativePath','pg_terminate_backend','$markerJson'])if(t15.includes(x))fail(`T15 regression reintroduced: ${x}`)
if(/^\s*\|/m.test(t16)||/\$issueCount\s*=\s*\(\s*\r?\n/.test(t16))fail('T16 PowerShell parser regression reintroduced')
if(!failed){console.log('T17 clean Node demo-loader architecture: PASS');console.log('T17 PowerShell duplicate-function regression guard: PASS');console.log('T17 migration/data/privacy contracts: PASS');console.log('T17 DEMO SOURCE CHECK: PASS')}
process.exit(failed?1:0)
