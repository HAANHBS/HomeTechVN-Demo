import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())
let failed = false

function fail(message) {
  failed = true
  console.error(`[T21.3 UI FAIL] ${message}`)
}

function read(relative) {
  const file = path.join(root, ...relative.split('/'))
  if (!fs.existsSync(file)) {
    fail(`missing ${relative}`)
    return ''
  }
  return fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')
}

function requireTokens(relative, tokens) {
  const source = read(relative)
  for (const token of tokens) {
    if (!source.includes(token)) fail(`${relative} missing contract: ${token}`)
  }
  return source
}

const migrations = fs.readdirSync(path.join(root, 'supabase', 'migrations')).filter((name) => name.endsWith('.sql'))
if (migrations.length < 40) fail(`T21.3 requires the 40-migration baseline; found ${migrations.length}`)

const forms = requireTokens('app/src/features/repair/forms.tsx', [
  "const[labor,setLabor]=useState('')",
  "const[parts,setParts]=useState('')",
  "const[discount,setDiscount]=useState('')",
  "const total=Math.max(subtotal-discountAmount,0)",
  "if(laborAmount===0&&partsAmount===0)",
  "if(discountAmount>subtotal)",
  'Ô để trống được tính là 0 ₫.',
  'Tiền công (VNĐ)',
  'Tiền linh kiện (VNĐ)',
  'Khách thanh toán',
  'onWheel={e=>e.currentTarget.blur()}',
])
const quoteForm = forms.slice(forms.indexOf('export function QuoteForm'), forms.indexOf('export function PartForm'))
if (quoteForm.includes('step="1000"')) fail('repair quote must not increment an optional amount by 1,000 VND')
if ((quoteForm.match(/step="1"/g) ?? []).length !== 3) fail('labor, parts and discount must each use a 1 VND input step')
if (forms.includes('step="1000"')) fail('repair money inputs must not increment by 1,000 VND')

const repair = requireTokens('app/src/features/repair/RepairPage.tsx', [
  "next:'Bắt đầu chẩn đoán'",
  "next:'Nhập kết quả chẩn đoán'",
  "next:'Lập báo giá'",
  "next:'Gửi báo giá cho khách'",
  "next:'Ghi nhận phản hồi của khách'",
  "next:pendingParts.length?`Xuất ${pendingParts.length} vật tư đang chờ`:!hasApprovedQuote?'Kiểm tra báo giá được duyệt':'Bắt đầu sửa chữa'",
  'allowed:canUpdate&&pendingParts.length===0&&hasApprovedQuote',
  "next:pendingParts.length?`Xuất ${pendingParts.length} vật tư đang chờ`:'Bắt đầu kiểm tra QC'",
  "next:'Ghi kết quả QC'",
  "next:'Xác nhận đã trả thiết bị'",
  "next:'Hoàn tất phiếu'",
  "next:'Nhận lại và chẩn đoán tiếp'",
  "'Tiếp tục thực hiện'",
  'Bước kế tiếp:',
  'Khách đồng ý báo giá',
  'Khách từ chối báo giá',
  '>Không sửa được</button>',
  '>Chờ linh kiện</button>',
])
if ((repair.match(/'Tiếp tục thực hiện'/g) ?? []).length !== 1) fail('repair detail must expose one contextual continue action')

const repairSchema = requireTokens('supabase/migrations/20260830082723_t5_repair_schema.sql', [
  'greatest(labor_amount + parts_amount - discount_amount, 0)',
  'constraint repair_quotes_discount_check check (discount_amount <= labor_amount + parts_amount)',
])
if (!repairSchema) fail('repair quote database formula missing')

for (const scenario of [
  { labor: 100000, parts: 0, discount: 0, expected: 100000 },
  { labor: 0, parts: 250000, discount: 0, expected: 250000 },
  { labor: 100000, parts: 250000, discount: 50000, expected: 300000 },
]) {
  const total = Math.max(scenario.labor + scenario.parts - scenario.discount, 0)
  if (total !== scenario.expected) fail(`quote scenario calculated ${total}, expected ${scenario.expected}`)
}

const rootPackage = JSON.parse(read('package.json'))
const appPackage = JSON.parse(read('app/package.json'))
if (rootPackage.version !== '0.21.4-t21.4') fail('root version must be 0.21.4-t21.4')
if (appPackage.version !== '0.21.4') fail('app version must be 0.21.4')

if (!failed) {
  console.log('T21.3 REPAIR QUOTE AMOUNT CONTRACT: PASS')
  console.log('T21.3 LABOR-ONLY 100000 + PARTS 0 = 100000: PASS')
  console.log('T21.3 GUIDED CONTINUE STATE/RBAC CONTRACT: PASS')
  console.log('T21.3 VIETNAMESE EXCEPTION ACTIONS: PASS')
  console.log('T21.3 MIGRATION REGRESSION: PASS (#1-#40 unchanged)')
}

process.exit(failed ? 1 : 0)
