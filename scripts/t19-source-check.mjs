import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'

const root=path.resolve(process.cwd())
let failed=false
function fail(message){failed=true;console.error(`[T19 SOURCE FAIL] ${message}`)}
function read(relative){return fs.readFileSync(path.join(root,...relative.split('/')),'utf8').replace(/^\uFEFF/,'')}
function hash(relative){return crypto.createHash('sha256').update(fs.readFileSync(path.join(root,...relative.split('/')))).digest('hex')}
function requireTokens(relative,tokens){
  if(!fs.existsSync(path.join(root,...relative.split('/')))){fail(`missing ${relative}`);return}
  const text=read(relative)
  for(const token of tokens)if(!text.includes(token))fail(`${relative} missing contract: ${token}`)
}

const manifest=read('docs/T17_FINAL_INTEGRITY.txt')
const expected=new Map([...manifest.matchAll(/^([a-f0-9]{64})  (supabase\/migrations\/[^\r\n]+)$/gm)].map(m=>[m[2],m[1]]))
if(expected.size!==36)fail(`T17 integrity manifest must describe 36 migrations, found ${expected.size}`)
const migrations=fs.readdirSync(path.join(root,'supabase','migrations')).filter(x=>x.endsWith('.sql')).sort()
if(migrations.length!==37)fail(`expected locked #1-#36 plus T19 #37, found ${migrations.length}`)
for(const [relative,digest] of expected){
  if(!fs.existsSync(path.join(root,...relative.split('/'))))fail(`locked migration missing: ${relative}`)
  else if(hash(relative)!==digest)fail(`locked migration changed: ${relative}`)
}
const t19=migrations.filter(x=>/_t19_/i.test(x))
if(t19.length!==1||t19[0]!=='20260904014416_t19_universal_qr_operations.sql')fail(`unexpected T19 migration set: ${t19.join(', ')||'(none)'}`)
if(!failed)console.log('T19 LOCKED MIGRATION REGRESSION: PASS (#1-#36 unchanged; #37 isolated)')

const rootPackage=JSON.parse(read('package.json'))
const appPackage=JSON.parse(read('app/package.json'))
if(rootPackage.version!=='0.19.0-t19.0'||appPackage.version!=='0.19.0')fail('T19 package versions are inconsistent')
for(const name of ['t19:source-check','t19:verify'])if(!rootPackage.scripts?.[name])fail(`missing package script ${name}`)

const migration='supabase/migrations/20260904014416_t19_universal_qr_operations.sql'
requireTokens(migration,[
  'create table private.qr_codes','token_hash bytea not null unique','create table private.qr_action_events',
  'alter table private.qr_codes enable row level security','create policy qr_codes_no_direct_access',
  'create policy qr_action_events_no_direct_access','to public\nusing (false)\nwith check (false)',
  'revoke all on table private.qr_codes,private.qr_action_events from public,anon,authenticated',
  "extensions.digest(v_token,'sha256')",'private.fn_assert_active_or_privileged()',"private.has_permission('qr.issue')",
  "private.has_permission('qr.revoke')",'create or replace function public.qr_issue','create or replace function public.qr_resolve',
  'create or replace function public.qr_revoke','security definer set search_path=\'\'',
  'revoke execute on function private.qr_issue_impl(text,text,text,timestamptz) from public,anon,authenticated',
  'grant execute on function public.qr_resolve(text) to authenticated',
  "if v_code.intent='EDIT'", "if v_code.intent='PAY'",
])
const sql=read(migration)
if(/create table private\.qr_codes[\s\S]*?\btoken\s+text\b/i.test(sql))fail('QR table must not persist a plaintext token')
if(/grant execute on function private\.qr_(?:issue|resolve|revoke)_impl[^;]+to authenticated/i.test(sql))fail('private QR implementation must not be executable by authenticated')
if(/grant (?:select|all)[^;]+private\.qr_codes[^;]+authenticated/i.test(sql))fail('authenticated must not read private QR table')
for(const [table,policy] of [['qr_codes','qr_codes_no_direct_access'],['qr_action_events','qr_action_events_no_direct_access']]){
  const pattern=new RegExp(`create policy\\s+${policy}\\s+on\\s+private\\.${table}\\s+for all\\s+to public\\s+using \\(false\\)\\s+with check \\(false\\)`,'i')
  if(!pattern.test(sql))fail(`${table} must have an explicit deny-all RLS policy`)
}

requireTokens('app/src/features/qr/QrCommandCenter.tsx',[
  "supabase.rpc('qr_resolve'","supabase.rpc('qr_issue'","supabase.rpc('qr_revoke'",'BarcodeDetector',
  'navigator.mediaDevices.getUserMedia','Dán link hoặc token QR HomeTechVN','Không nhập mật khẩu',
  "resourceType==='SALES_ORDER'",'Tạo QR an toàn','Tải PNG',
])
requireTokens('app/src/App.tsx',[
  'QrCommandCenter','readInternalQrToken','handleQrNavigate','window.history.replaceState','Đã mở từ QR',
  'initialTarget={qrHandoff?.target}','initialAction={qrHandoff?.action}',
])
for(const relative of [
  'app/src/features/crm/CrmPage.tsx','app/src/features/sales/SalesPage.tsx','app/src/features/repair/RepairPage.tsx',
  'app/src/features/warranty/WarrantyPage.tsx','app/src/features/checklist/ChecklistPage.tsx',
  'app/src/features/inventory/InventoryPage.tsx','app/src/features/service_license/ServiceLicensePage.tsx',
  'app/src/features/reminders/ReminderPage.tsx','app/src/features/notifications/NotificationPage.tsx',
])requireTokens(relative,['initialTarget','initialAction'])

requireTokens('supabase/seed.sql',["'qr.issue'","'qr.revoke'","where r.code = 'cashier'","where r.code = 'technician'"])

for(const relative of ['app/src/App.tsx','app/src/features/qr/QrCommandCenter.tsx']){
  const text=read(relative)
  if(/service[_-]?role|sb_secret_/i.test(text))fail(`T19 browser source contains server-secret marker: ${relative}`)
}

requireTokens('supabase/tests/t19_verify.sql',['T19 QR DATABASE SECURITY CHECK: PASS','authenticated must not read private QR tokens','anon must not resolve internal QR','T19 security snapshot RLS gap'])
requireTokens('scripts/t19-runtime-verify.mjs',[
  'maxChildBuffer=64*1024*1024','CHILD OUTPUT (last 160 lines)','T19_FAILURE_${stamp}.txt',
  '[REDACTED_JWT]','[REDACTED_SUPABASE_KEY]','Failure snapshot:',
  'safeOutput(stdout)','safeOutput(stderr)','T19_LOCAL_VERIFY_${stamp}.txt','Secrets included: NO',
  'T19 CHILD PROCESS DIAGNOSTICS SELF TEST: PASS','process.exit(7)',
])
requireTokens('scripts/t17-demo-load.mjs',[
  'redactConsole(stdout)','redactConsole(stderr)','[REDACTED_SUPABASE_KEY]','console redaction self-test failed',
])
requireTokens('docs/T19_UNIVERSAL_QR_OPERATIONS.md',['T19 LOCAL REPRODUCIBILITY: PASS','does not claim that a bank transfer succeeded','Raw tokens are never stored'])
requireTokens('docs/T19_STATUS.md',['COMPLETE & LOCKED','Locked migrations #1–#37','no real bank/provider acknowledgement'])
requireTokens('docs/T19_FINAL_ACCEPTANCE.md',['T19 LOCAL REPRODUCIBILITY: PASS','T19 CLEAN BASELINE AFTER VERIFY: PASS','Secrets included in final evidence: NO'])
requireTokens('docs/T19_FINAL_INTEGRITY.txt',['Migration count: 37','Next migration: #38','T19 migration SHA-256:'])

if(!failed){
  console.log('T19 UNIVERSAL QR SECURITY CONTRACT: PASS')
  console.log('T19 QR RESPONSIVE UI CHECK: PASS')
  console.log('T19 SOURCE CHECK: PASS')
}
process.exit(failed?1:0)
