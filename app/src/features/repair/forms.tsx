import { useEffect, useMemo, useState, type FormEvent } from 'react'
import type { CustomerRow, DeviceRow, InventoryUnitRow, ProductInventorySummaryRow, RepairOrderRow } from '../../lib/database.types'
import { supabase } from '../../lib/supabase'
import { CustomerDeviceQuickPicker } from '../crm/forms'

const inputClass = 'mt-1 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none focus:border-cyan-500'
const labelClass = 'block text-sm font-medium text-slate-300'

function parseNumber(value: string) {
  const n = Number(value)
  return Number.isFinite(n) ? n : 0
}
function formatMoney(value: number) {
  return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND', maximumFractionDigits: 0 }).format(value)
}
function ErrorBox({ message }: { message: string | null }) {
  return message ? <p role="alert" aria-live="assertive" className="rounded-xl border border-red-900 bg-red-950/30 p-3 text-sm text-red-200">{message}</p> : null
}
function Actions({ busy, onCancel, label }: { busy: boolean; onCancel: () => void; label: string }) {
  return <div className="flex justify-end gap-2 pt-2"><button type="button" onClick={onCancel} className="rounded-xl border border-slate-700 px-4 py-2 text-sm">Đóng</button><button disabled={busy} className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950 disabled:opacity-50">{busy ? 'Đang xử lý…' : label}</button></div>
}

export function CreateRepairForm({ customers, devices, canCreateCustomer, canCreateDevice, onCancel, onCreated }: { customers: CustomerRow[]; devices: DeviceRow[]; canCreateCustomer: boolean; canCreateDevice: boolean; onCancel: () => void; onCreated: (id: string) => void }) {
  const [customerId,setCustomerId]=useState(customers[0]?.id ?? '')
  const [deviceId,setDeviceId]=useState('')
  const [issue,setIssue]=useState('')
  const [condition,setCondition]=useState('')
  const [conditionSameAsIssue,setConditionSameAsIssue]=useState(false)
  const [accessories,setAccessories]=useState('')
  const [request,setRequest]=useState('')
  const [priority,setPriority]=useState('NORMAL')
  const [note,setNote]=useState('')
  const [busy,setBusy]=useState(false); const [error,setError]=useState<string|null>(null)
  async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setError(null);try{if(!customerId)throw new Error('Hãy chọn hoặc thêm nhanh khách hàng.');if(!deviceId)throw new Error('Hãy chọn hoặc thêm nhanh thiết bị trước khi tiếp nhận.');const {data,error:rpcError}=await supabase.rpc('repair_create',{p_customer_id:customerId,p_customer_device_id:deviceId,p_reported_issue:issue.trim(),p_intake_condition:(conditionSameAsIssue?issue:condition).trim()||undefined,p_accessories_received:accessories.split(/[,\n]/).map(x=>x.trim()).filter(Boolean),p_customer_request:request.trim()||undefined,p_priority:priority,p_intake_note:note.trim()||undefined});if(rpcError)throw rpcError;const id=typeof data==='object'&&data&&!Array.isArray(data)?String((data as Record<string,unknown>).id??''):'';if(!id)throw new Error('Hệ thống không trả về mã phiếu sửa chữa.');onCreated(id)}catch(err){setError(err instanceof Error?err.message:'Không tạo được phiếu sửa chữa.')}finally{setBusy(false)}}
  return <form className="space-y-4" onSubmit={submit}>
    <CustomerDeviceQuickPicker customers={customers} devices={devices} customerId={customerId} deviceId={deviceId} onCustomerChange={setCustomerId} onDeviceChange={setDeviceId} canCreateCustomer={canCreateCustomer} canCreateDevice={canCreateDevice} deviceRequired />
    <div className="grid gap-4 md:grid-cols-2">
      <label className={labelClass}>Mức ưu tiên<select className={inputClass} value={priority} onChange={e=>setPriority(e.target.value)}><option value="NORMAL">Bình thường</option><option value="HIGH">Cao</option><option value="URGENT">Khẩn cấp</option></select></label>
      <label className={labelClass}>Phụ kiện nhận kèm<input className={inputClass} value={accessories} onChange={e=>setAccessories(e.target.value)} placeholder="Sạc, túi, chuột…" /></label>
    </div>
    <label className={labelClass}>Lỗi khách báo *<textarea required className={inputClass} rows={3} value={issue} onChange={e=>{setIssue(e.target.value);if(conditionSameAsIssue)setCondition(e.target.value)}} /></label>
    <label className="flex items-center gap-2 text-sm text-slate-300"><input type="checkbox" checked={conditionSameAsIssue} onChange={e=>{setConditionSameAsIssue(e.target.checked);if(e.target.checked)setCondition(issue)}} />Tình trạng khi nhận giống lỗi khách báo</label>
    <label className={labelClass}>Tình trạng khi nhận<textarea className={inputClass} rows={2} value={conditionSameAsIssue?issue:condition} disabled={conditionSameAsIssue} onChange={e=>setCondition(e.target.value)} /></label>
    <label className={labelClass}>Yêu cầu khách hàng<textarea className={inputClass} rows={2} value={request} onChange={e=>setRequest(e.target.value)} /></label>
    <label className={labelClass}>Ghi chú tiếp nhận<textarea className={inputClass} rows={2} value={note} onChange={e=>setNote(e.target.value)} /></label>
    <Actions busy={busy} onCancel={onCancel} label="Tạo phiếu sửa chữa" /><ErrorBox message={error}/>
  </form>
}

export function DiagnosticForm({ orderId,onCancel,onDone }:{orderId:string;onCancel:()=>void;onDone:()=>void}){
 const [symptom,setSymptom]=useState('');const[findings,setFindings]=useState('');const[conclusion,setConclusion]=useState('');const[recommendation,setRecommendation]=useState('');const[busy,setBusy]=useState(false);const[error,setError]=useState<string|null>(null)
 async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setError(null);try{const {error:rpcError}=await supabase.rpc('repair_add_diagnostic',{p_order_id:orderId,p_symptom:symptom.trim(),p_findings:findings.trim(),p_conclusion:conclusion.trim()||undefined,p_recommendation:recommendation.trim()||undefined});if(rpcError)throw rpcError;onDone()}catch(err){setError(err instanceof Error?err.message:'Không lưu được chẩn đoán.')}finally{setBusy(false)}}
 return <form className="space-y-4" onSubmit={submit}><label className={labelClass}>Triệu chứng<textarea className={inputClass} rows={2} value={symptom} onChange={e=>setSymptom(e.target.value)}/></label><label className={labelClass}>Kết quả kiểm tra *<textarea required className={inputClass} rows={3} value={findings} onChange={e=>setFindings(e.target.value)}/></label><label className={labelClass}>Kết luận<textarea className={inputClass} rows={2} value={conclusion} onChange={e=>setConclusion(e.target.value)}/></label><label className={labelClass}>Đề xuất xử lý<textarea className={inputClass} rows={2} value={recommendation} onChange={e=>setRecommendation(e.target.value)}/></label><Actions busy={busy} onCancel={onCancel} label="Lưu chẩn đoán"/><ErrorBox message={error}/></form>
}

export function QuoteForm({ orderId,onCancel,onDone }:{orderId:string;onCancel:()=>void;onDone:()=>void}){
 const[labor,setLabor]=useState('');const[parts,setParts]=useState('');const[discount,setDiscount]=useState('');const[warrantyMonths,setWarrantyMonths]=useState('3');const[validUntil,setValidUntil]=useState('');const[note,setNote]=useState('');const[busy,setBusy]=useState(false);const[error,setError]=useState<string|null>(null)
 const laborAmount=parseNumber(labor),partsAmount=parseNumber(parts),discountAmount=parseNumber(discount)
 const subtotal=laborAmount+partsAmount
 const total=Math.max(subtotal-discountAmount,0)
 async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setError(null);try{const months=Math.trunc(parseNumber(warrantyMonths));if(laborAmount<0||partsAmount<0||discountAmount<0)throw new Error('Các khoản tiền không được âm.');if(laborAmount===0&&partsAmount===0)throw new Error('Hãy nhập ít nhất tiền công hoặc tiền linh kiện.');if(discountAmount>subtotal)throw new Error('Giảm giá không được lớn hơn tiền công cộng tiền linh kiện.');if(months<1||months>120)throw new Error('Thời hạn bảo hành phải từ 1 đến 120 tháng.');const {error:rpcError}=await supabase.rpc('repair_create_quote_v2',{p_order_id:orderId,p_labor_amount:laborAmount,p_parts_amount:partsAmount,p_discount_amount:discountAmount,p_warranty_months:months,p_valid_until:validUntil||undefined,p_note:note.trim()||undefined});if(rpcError)throw rpcError;onDone()}catch(err){setError(err instanceof Error?err.message:'Không tạo được báo giá.')}finally{setBusy(false)}}
 return <form className="space-y-4" onSubmit={submit}>
  <p className="rounded-xl border border-cyan-950 bg-cyan-950/20 p-3 text-sm text-slate-300">Chỉ nhập khoản thực tế có phát sinh. Ô để trống được tính là 0 ₫.</p>
  <div className="grid gap-4 md:grid-cols-3">
   <label className={labelClass}>Tiền công (VNĐ)<input type="number" inputMode="numeric" min="0" step="1" placeholder="Để trống nếu không có" className={inputClass} value={labor} onWheel={e=>e.currentTarget.blur()} onChange={e=>setLabor(e.target.value)}/></label>
   <label className={labelClass}>Tiền linh kiện (VNĐ)<input type="number" inputMode="numeric" min="0" step="1" placeholder="Để trống nếu không có" className={inputClass} value={parts} onWheel={e=>e.currentTarget.blur()} onChange={e=>setParts(e.target.value)}/></label>
   <label className={labelClass}>Giảm giá (VNĐ)<input type="number" inputMode="numeric" min="0" step="1" max={subtotal||undefined} placeholder="Để trống nếu không giảm" className={inputClass} value={discount} onWheel={e=>e.currentTarget.blur()} onChange={e=>setDiscount(e.target.value)}/></label>
  </div>
  <div className="grid gap-2 rounded-2xl border border-slate-700 bg-slate-950/70 p-4 text-sm sm:grid-cols-4">
   <div><div className="text-slate-500">Tiền công</div><div className="mt-1 font-semibold text-slate-100">{formatMoney(laborAmount)}</div></div>
   <div><div className="text-slate-500">Tiền linh kiện</div><div className="mt-1 font-semibold text-slate-100">{formatMoney(partsAmount)}</div></div>
   <div><div className="text-slate-500">Giảm giá</div><div className="mt-1 font-semibold text-amber-300">− {formatMoney(discountAmount)}</div></div>
   <div><div className="text-slate-500">Khách thanh toán</div><div className="mt-1 text-lg font-bold text-emerald-300">{formatMoney(total)}</div></div>
  </div>
  <div className="grid gap-4 sm:grid-cols-2"><label className={labelClass}>Bảo hành sửa chữa (tháng)<input type="number" min="1" max="120" step="1" className={inputClass} value={warrantyMonths} onChange={e=>setWarrantyMonths(e.target.value)}/><span className="mt-1 block text-xs text-slate-500">Áp dụng cho bảo hành công sửa chữa sau khi hoàn tất phiếu.</span></label><label className={labelClass}>Hiệu lực báo giá đến<input type="date" className={inputClass} value={validUntil} onChange={e=>setValidUntil(e.target.value)}/></label></div>
  <label className={labelClass}>Ghi chú<textarea className={inputClass} rows={2} value={note} onChange={e=>setNote(e.target.value)}/></label>
  <Actions busy={busy} onCancel={onCancel} label="Lưu báo giá"/><ErrorBox message={error}/>
 </form>
}

export function PartForm({ orderId,products,onCancel,onDone }:{orderId:string;products:ProductInventorySummaryRow[];onCancel:()=>void;onDone:()=>void}){
 const[productId,setProductId]=useState(products[0]?.product_id??'');const product=useMemo(()=>products.find(p=>p.product_id===productId),[productId,products]);const[quantity,setQuantity]=useState('1');const[price,setPrice]=useState(String(product?.sale_price??0));const[units,setUnits]=useState<InventoryUnitRow[]>([]);const[selectedUnits,setSelectedUnits]=useState<string[]>([]);const[note,setNote]=useState('');const[busy,setBusy]=useState(false);const[error,setError]=useState<string|null>(null)
 useEffect(()=>setPrice(String(product?.sale_price??0)),[product?.sale_price,productId])
 useEffect(()=>{let cancel=false;async function load(){if(!product?.track_serial||!productId){setUnits([]);return}const{data,error:q}=await supabase.from('inventory_units').select('*').eq('product_id',productId).eq('status','IN_STOCK').order('serial_number');if(!cancel){if(q)setError(q.message);else setUnits(data)}}void load();return()=>{cancel=true}},[product?.track_serial,productId])
 async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setError(null);try{const qty=parseNumber(quantity);if(product?.track_serial&&selectedUnits.length!==Math.trunc(qty))throw new Error(`Cần chọn đúng ${Math.trunc(qty)} Serial.`);const{error:rpcError}=await supabase.rpc('repair_plan_part',{p_order_id:orderId,p_product_id:productId,p_quantity:qty,p_unit_price:parseNumber(price),p_inventory_unit_ids:product?.track_serial?selectedUnits:[],p_note:note.trim()||undefined});if(rpcError)throw rpcError;onDone()}catch(err){setError(err instanceof Error?err.message:'Không lập được vật tư.')}finally{setBusy(false)}}
 return <form className="space-y-4" onSubmit={submit}><label className={labelClass}>Sản phẩm<select className={inputClass} value={productId} onChange={e=>{setProductId(e.target.value);setSelectedUnits([])}}>{products.filter(p=>p.product_id).map(p=><option key={p.product_id!} value={p.product_id!}>{p.sku} · {p.name} · tồn {p.stock_qty??0}</option>)}</select></label><div className="grid gap-4 md:grid-cols-2"><label className={labelClass}>Số lượng<input type="number" min="0.001" step={product?.track_serial?'1':'0.001'} className={inputClass} value={quantity} onChange={e=>setQuantity(e.target.value)}/></label><label className={labelClass}>Giá tính khách (VNĐ)<input type="number" inputMode="numeric" min="0" step="1" className={inputClass} value={price} onWheel={e=>e.currentTarget.blur()} onChange={e=>setPrice(e.target.value)}/></label></div>{product?.track_serial?<div><div className="mb-2 text-sm font-medium">Serial ({selectedUnits.length}/{Math.max(0,Math.trunc(parseNumber(quantity)))})</div><div className="max-h-52 overflow-y-auto rounded-xl border border-slate-800 bg-slate-950 p-2">{units.map(u=><label key={u.id} className="flex items-center gap-2 rounded-lg px-2 py-1.5 text-sm hover:bg-slate-900"><input type="checkbox" checked={selectedUnits.includes(u.id)} onChange={e=>setSelectedUnits(prev=>e.target.checked?[...prev,u.id]:prev.filter(id=>id!==u.id))}/><span className="font-mono text-cyan-300">{u.serial_number}</span></label>)}</div></div>:null}<label className={labelClass}>Ghi chú<input className={inputClass} value={note} onChange={e=>setNote(e.target.value)}/></label><Actions busy={busy} onCancel={onCancel} label="Lập vật tư"/><ErrorBox message={error}/></form>
}

export function QCForm({order,onCancel,onDone}:{order:RepairOrderRow;onCancel:()=>void;onDone:()=>void}){
 const[passed,setPassed]=useState(true);const[findings,setFindings]=useState('');const[conclusion,setConclusion]=useState('');const[busy,setBusy]=useState(false);const[error,setError]=useState<string|null>(null)
 async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setError(null);try{const{error:rpcError}=await supabase.rpc('repair_record_qc',{p_order_id:order.id,p_passed:passed,p_findings:findings.trim(),p_conclusion:conclusion.trim()||undefined});if(rpcError)throw rpcError;onDone()}catch(err){setError(err instanceof Error?err.message:'Không lưu được QC.')}finally{setBusy(false)}}
 return <form className="space-y-4" onSubmit={submit}><label className={labelClass}>Kết quả<select className={inputClass} value={passed?'PASS':'FAIL'} onChange={e=>setPassed(e.target.value==='PASS')}><option value="PASS">PASS → READY</option><option value="FAIL">FAIL → REPAIRING</option></select></label><label className={labelClass}>Nội dung kiểm tra *<textarea required className={inputClass} rows={3} value={findings} onChange={e=>setFindings(e.target.value)}/></label><label className={labelClass}>Kết luận<textarea className={inputClass} rows={2} value={conclusion} onChange={e=>setConclusion(e.target.value)}/></label><Actions busy={busy} onCancel={onCancel} label="Ghi kết quả QC"/><ErrorBox message={error}/></form>
}

export function TextActionForm({placeholder,label,onCancel,onSubmit}:{placeholder:string;label:string;onCancel:()=>void;onSubmit:(text:string)=>Promise<void>}){
 const[text,setText]=useState('');const[busy,setBusy]=useState(false);const[error,setError]=useState<string|null>(null)
 async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setError(null);try{await onSubmit(text.trim());onCancel()}catch(err){setError(err instanceof Error?err.message:`Không thể ${label}.`)}finally{setBusy(false)}}
 return <form className="space-y-4" onSubmit={submit}><textarea autoFocus required className={inputClass} rows={4} placeholder={placeholder} value={text} onChange={e=>setText(e.target.value)}/><Actions busy={busy} onCancel={onCancel} label={label}/><ErrorBox message={error}/></form>
}
