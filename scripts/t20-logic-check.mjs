import fs from 'node:fs'
import path from 'node:path'

const root=path.resolve(process.cwd())
let failed=false

function fail(message){failed=true;console.error(`[T20 LOGIC FAIL] ${message}`)}
function read(relative){
  const file=path.join(root,...relative.split('/'))
  if(!fs.existsSync(file)){fail(`missing ${relative}`);return''}
  return fs.readFileSync(file,'utf8').replace(/^\uFEFF/,'')
}
function requireTokens(relative,tokens){
  const text=read(relative)
  for(const token of tokens)if(!text.includes(token))fail(`${relative} missing contract: ${token}`)
  return text
}
function count(text,pattern){return(text.match(pattern)||[]).length}

const migration=requireTokens('supabase/migrations/20260909052415_t20_operational_logic_integrity.sql',[
  'SALE_TOTAL_MISMATCH',
  'PAYMENT_LEDGER_MISMATCH',
  'PAYMENT_AMOUNT_MUST_MATCH_BALANCE',
  'PARTIAL_PAYMENT_MUST_BE_LESS_THAN_BALANCE',
  'PAYMENT_REFERENCE_DUPLICATE',
  'HANDOVER_PREREQUISITES_INCOMPLETE',
  'REPAIR_PREREQUISITES_INCOMPLETE',
  'WARRANTY_COVERAGE_MISSING',
  'AUTO_SALE_HANDOVER',
  'private.warranty_scan_product_impl',
  'public.warranty_scan_product',
  'ux_payments_method_reference_normalized',
  'deferrable initially deferred',
  'language sql\nvolatile\nsecurity definer',
  'for update',
  'private.sale_payment_ledger_total(p_order_id)',
  "p_amount<>v_balance_due",
  "elem->>'key'<>'customer_delivery_confirmation'",
  'trg_repair_transition_prerequisite_guard',
  'revoke execute on function public.sale_record_partial_payment',
])
if(count(migration,/create constraint trigger trg_(?:sales_items|sales_orders|payments|warranties)_deferred_/g)!==6)fail('expected six deferred sale/payment/warranty consistency triggers')
if(!/create or replace function public\.sale_record_partial_payment[\s\S]*language sql\s+security definer\s+set search_path=''[\s\S]*revoke execute on function private\.sale_record_partial_payment_impl[\s\S]*from public,anon,authenticated;/i.test(migration))fail('partial-payment wrapper/private implementation boundary is unsafe')
if(!/create or replace function public\.warranty_scan_product[\s\S]*security definer[\s\S]*revoke execute on function public\.warranty_scan_product\(text\) from public,anon;[\s\S]*grant execute on function public\.warranty_scan_product\(text\) to authenticated;/i.test(migration))fail('warranty scanner execution surface is unsafe')
if(!failed)console.log('T20 PAYMENT/WORKFLOW DATABASE CONTRACT: PASS')

const demo=read('supabase/t17_demo_data.sql')
if(count(demo,/public\.sale_record_partial_payment\s*\(/g)!==1)fail('T17 must have exactly one explicit partial-payment fixture')
if(count(demo,/public\.sale_record_payment\s*\(/g)!==1)fail('T17 full-payment fixture must keep the normal exact-payment RPC')
const hosted=read('supabase/t20_hosted_demo_data.sql')
if(count(hosted,/public\.sale_record_partial_payment\s*\(/g)!==1)fail('T20 hosted receivable must use explicit partial-payment RPC')
requireTokens('app/src/lib/database.types.ts',[
  'sale_record_partial_payment: {',
  'warranty_scan_product: {',
])

const salesForms=requireTokens('app/src/features/sales/forms.tsx',[
  'readOnly aria-readonly="true"',
  'Khóa theo số còn phải thu để không lệch giá bán.',
  'Math.round(Number(updatedOrder.paid_amount) * 100) !== Math.round(Number(updatedOrder.total_amount) * 100)',
])
if(!salesForms.includes('Thu đủ ${new Intl.NumberFormat')&&!salesForms.includes('Xác nhận đã nhận đủ ${new Intl.NumberFormat'))fail('exact-balance payment action label is missing')
// The exact button label is dynamic in T20.1; reject the old editable amount contract.
if(salesForms.includes('onChange={(e) => setAmount(e.target.value)}'))fail('payment amount remains user-editable')
if(count(salesForms,/<Actions[^>]+\/>\s*<ErrorBox message=\{error\} \/>/g)<5)fail('sales form errors are not consistently below action buttons')

const repairForms=read('app/src/features/repair/forms.tsx')
if(count(repairForms,/<Actions[^>]+\/>\s*<ErrorBox message=\{error\}\/>/g)<6)fail('repair form errors are not consistently below action buttons')
const inventoryForms=read('app/src/features/inventory/forms.tsx')
if(count(inventoryForms,/<FormActions[^>]+\/>\s*<ErrorBox message=\{error\} \/>/g)<5)fail('inventory form errors are not consistently below action buttons')

const salesPage=requireTokens('app/src/features/sales/SalesPage.tsx',[
  'WorkflowGuide title="Quy trình bán hàng và bàn giao"',
  'missingPreHandover.length > 0',
  'missingRequired.length > 0',
  '<ErrorPanel message={error} />\n    <WorkflowGuide',
  'THU NGÂN',
  'BÁN HÀNG / KỸ THUẬT',
])
if(salesPage.indexOf('<ErrorPanel message={error} />\n    <WorkflowGuide')<salesPage.indexOf("order.status === 'PAID'"))fail('sales action error is not below the action buttons')

const repairPage=requireTokens('app/src/features/repair/RepairPage.tsx',[
  'WorkflowGuide title="Quy trình sửa chữa và bàn giao"',
  "pendingParts=parts.filter(p=>p.status==='PLANNED')",
  'KHO',
  'BÀN GIAO',
  '<Err message={error}/>',
  'allowed:canUpdate&&pendingParts.length===0&&hasApprovedQuote',
])
if(!repairPage.includes('</div>\n <Err message={error}/>\n <WorkflowGuide'))fail('repair action error is not directly below the action buttons')

requireTokens('app/src/features/warranty/WarrantyPage.tsx',[
  'Kiểm tra bảo hành tức thời',
  'Quét sản phẩm đã bán',
  "supabase.rpc('warranty_scan_product'",
  "formats:['qr_code','code_128','code_39','ean_13','ean_8']",
  'CÒN BẢO HÀNH',
  'HẾT BẢO HÀNH',
])

for(const relative of [
  'app/src/features/sales/forms.tsx',
  'app/src/features/repair/forms.tsx',
  'app/src/features/inventory/forms.tsx',
  'app/src/features/crm/forms.tsx',
  'app/src/features/checklist/ChecklistPage.tsx',
  'app/src/features/warranty/WarrantyPage.tsx',
  'app/src/features/reminders/ReminderPage.tsx',
  'app/src/features/notifications/NotificationPage.tsx',
  'app/src/features/service_license/ServiceLicensePage.tsx',
  'app/src/features/auth/LoginPage.tsx',
  'app/src/features/qr/QrCommandCenter.tsx',
  'app/src/features/audit/AuditPage.tsx',
  'app/src/features/crm/CrmPage.tsx',
  'app/src/features/crm/CustomerDetail.tsx',
  'app/src/features/public_warranty/PublicWarrantyPage.tsx',
]){
  if(!/role="alert"\s+aria-live="assertive"/.test(read(relative)))fail(`${relative} missing accessible action error announcement`)
}

requireTokens('supabase/tests/t20_verify.sql',[
  'T20 mismatched payment unexpectedly succeeded',
  'T20 handover unexpectedly ignored checklist prerequisites',
  'T20 payment-ledger drift unexpectedly succeeded',
  'T20 PAYMENT LEDGER INTEGRITY CHECK: PASS',
  'T20 WORKFLOW PREREQUISITE CHECK: PASS',
])

requireTokens('supabase/tests/t20_demo_acceptance.sql',[
  'T20 underpayment unexpectedly succeeded',
  'T20 overpayment unexpectedly succeeded',
  'T20 duplicate payment reference unexpectedly succeeded',
  "public.warranty_scan_product('DEMO-T20-SN-002')",
  'T20 automatic warranty was not created at handover',
  'T20 AUTOMATED FAKE-DATA ACCEPTANCE: PASS',
])
requireTokens('supabase/t20_hosted_demo_operational_upgrade.sql',[
  'T20 HOSTED DEMO COMPLETED SERIAL WARRANTY',
  'T20 HOSTED DEMO ACTIVE SERIAL WARRANTY',
  'DEMO-T20-SN-001',
  'private.operational_integrity_snapshot_impl()',
])

const surface=requireTokens('supabase/migrations/20260909053211_t20_rpc_surface_and_qr_index_hardening.sql',[
  'drop function if exists public.warranty_activate_sale(uuid)',
  'drop function if exists public.operational_integrity_snapshot()',
  'idx_qr_codes_created_by',
  'idx_qr_codes_revoked_by',
])
if(!/on private\.qr_codes\(created_by\)[\s\S]*on private\.qr_codes\(revoked_by\)/i.test(surface))fail('QR foreign-key indexes are incomplete')

if(!failed){
  console.log('T20 ACTION ERROR PLACEMENT CHECK: PASS')
  console.log('T20 WORKFLOW GUIDANCE UI CHECK: PASS')
  console.log('T20 LOGIC HARDENING SOURCE CHECK: PASS')
}
process.exit(failed?1:0)
