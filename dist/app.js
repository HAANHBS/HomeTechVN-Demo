const copy = {
  dashboard: ['Tổng quan cửa hàng', 'Tình hình kinh doanh và công việc cần xử lý hôm nay.'],
  customers: ['Khách hàng & thiết bị', 'Nhập thử hồ sơ khách hàng trên trình duyệt hiện tại.'],
  inventory: ['Kho hàng', 'Thử nhập sản phẩm và quan sát cảnh báo tồn kho.'],
  sales: ['Bán hàng', 'Tạo đơn bán thử và kiểm tra trạng thái thanh toán.'],
  repairs: ['Sửa chữa', 'Tiếp nhận thiết bị và theo dõi tiến độ sửa chữa thử.'],
  warranty: ['Bảo hành', 'Tạo hồ sơ bảo hành giả định để xem quy trình.'],
  reminders: ['Nhắc việc', 'Tạo công việc thử theo vai trò hiện tại.'],
  reports: ['Báo cáo', 'Số liệu minh họa, không phản ánh hoạt động kinh doanh thực tế.'],
}

const roles = {
  admin: {
    name: 'Quản trị viên', initials: 'AD', summary: 'Toàn quyền trong bản demo',
    modules: Object.keys(copy), write: ['customers', 'inventory', 'sales', 'repairs', 'warranty', 'reminders'],
  },
  manager: {
    name: 'Quản lý', initials: 'QL', summary: 'Xem mọi phân hệ và tạo nghiệp vụ',
    modules: Object.keys(copy), write: ['customers', 'inventory', 'sales', 'repairs', 'warranty', 'reminders'],
  },
  sales: {
    name: 'Bán hàng', initials: 'BH', summary: 'Khách hàng, bán hàng và nhắc việc',
    modules: ['dashboard', 'customers', 'inventory', 'sales', 'warranty', 'reminders', 'reports'],
    write: ['customers', 'sales', 'reminders'],
  },
  technician: {
    name: 'Kỹ thuật viên', initials: 'KT', summary: 'Sửa chữa, bảo hành và nhắc việc',
    modules: ['dashboard', 'customers', 'inventory', 'repairs', 'warranty', 'reminders'],
    write: ['repairs', 'warranty', 'reminders'],
  },
}

const forms = {
  customers: {
    title: 'Thêm khách hàng thử', prefix: 'KH-TEST-',
    fields: [
      { key: 'name', label: 'Tên khách hàng giả định', placeholder: 'Ví dụ: Khách thử 01', required: true },
      { key: 'phone', label: 'Số điện thoại thử', placeholder: '09xx xxx xxx', required: true },
      { key: 'device', label: 'Thiết bị', placeholder: 'Laptop / Máy in / Camera', required: true, wide: true },
    ],
  },
  inventory: {
    title: 'Nhập sản phẩm thử', prefix: 'SP-TEST-',
    fields: [
      { key: 'name', label: 'Tên sản phẩm', placeholder: 'SSD Demo 1TB', required: true },
      { key: 'group', label: 'Nhóm hàng', placeholder: 'Linh kiện', required: true },
      { key: 'quantity', label: 'Số lượng', type: 'number', min: 0, value: 1, required: true },
      { key: 'price', label: 'Giá bán (đồng)', type: 'number', min: 0, value: 100000, required: true },
    ],
  },
  sales: {
    title: 'Tạo đơn bán thử', prefix: 'SO-TEST-',
    fields: [
      { key: 'customer', label: 'Khách hàng giả định', placeholder: 'Khách thử 01', required: true },
      { key: 'product', label: 'Sản phẩm', placeholder: 'Laptop Demo', required: true },
      { key: 'total', label: 'Tổng tiền (đồng)', type: 'number', min: 0, value: 1000000, required: true },
      { key: 'payment', label: 'Thanh toán', type: 'select', options: ['Đủ', 'Đặt cọc', 'Chưa thanh toán'], required: true },
    ],
  },
  repairs: {
    title: 'Tiếp nhận sửa chữa thử', prefix: 'SC-TEST-',
    fields: [
      { key: 'device', label: 'Thiết bị', placeholder: 'Laptop Demo A', required: true },
      { key: 'due', label: 'Ngày hẹn trả', type: 'date', required: true },
      { key: 'issue', label: 'Mô tả lỗi giả định', placeholder: 'Không nhận sạc', required: true, wide: true },
    ],
  },
  warranty: {
    title: 'Tạo bảo hành thử', prefix: 'BH-TEST-',
    fields: [
      { key: 'product', label: 'Sản phẩm', placeholder: 'SSD Demo 512GB', required: true },
      { key: 'customer', label: 'Khách hàng giả định', placeholder: 'Khách thử 01', required: true },
      { key: 'expires', label: 'Ngày hết hạn', type: 'date', required: true, wide: true },
    ],
  },
  reminders: {
    title: 'Tạo nhắc việc thử', prefix: 'NV-TEST-',
    fields: [
      { key: 'title', label: 'Tên công việc', placeholder: 'Gọi xác nhận báo giá', required: true },
      { key: 'due', label: 'Hạn xử lý', type: 'date', required: true },
      { key: 'details', label: 'Nội dung', placeholder: 'Ghi chú công việc thử…', type: 'textarea', required: true, wide: true },
    ],
  },
}

const actionModules = {
  'Tạo đơn mới': 'sales', 'Thêm khách hàng': 'customers', 'Nhập kho': 'inventory',
  'Tạo đơn bán': 'sales', 'Tiếp nhận sửa chữa': 'repairs', 'Tạo bảo hành': 'warranty',
  'Tạo nhắc việc': 'reminders',
}

const storageKey = 'hometechvn-interactive-demo-v2'
const emptyRecords = () => Object.fromEntries(Object.keys(forms).map((key) => [key, []]))

function loadState() {
  try {
    const saved = JSON.parse(localStorage.getItem(storageKey))
    const role = roles[saved?.role] ? saved.role : 'admin'
    const records = emptyRecords()
    Object.keys(records).forEach((key) => { if (Array.isArray(saved?.records?.[key])) records[key] = saved.records[key].slice(0, 50) })
    return { role, records }
  } catch { return { role: 'admin', records: emptyRecords() } }
}

const state = loadState()
const title = document.querySelector('#page-title')
const subtitle = document.querySelector('#page-subtitle')
const search = document.querySelector('#table-search')
const toast = document.querySelector('#toast')
const modal = document.querySelector('#demo-modal')
const form = document.querySelector('#demo-form')
const formFields = document.querySelector('#demo-form-fields')
const roleSelect = document.querySelector('#role-select')
let toastTimer
let currentFormModule = null
let lastFocus = null

function persist() {
  try { localStorage.setItem(storageKey, JSON.stringify(state)) }
  catch { showNotice('Trình duyệt đang chặn lưu cục bộ; bản ghi chỉ tồn tại đến khi tải lại trang.', 'warning') }
}

function showNotice(message, type = 'info') {
  clearTimeout(toastTimer)
  toast.textContent = message
  toast.dataset.type = type
  toast.classList.add('show')
  toastTimer = setTimeout(() => toast.classList.remove('show'), 3600)
}

function canOpen(module) { return roles[state.role].modules.includes(module) }
function canWrite(module) { return roles[state.role].write.includes(module) }

function openModule(module, notifyLocked = true) {
  if (!copy[module]) return
  if (!canOpen(module)) {
    if (notifyLocked) showNotice(`${roles[state.role].name} không có quyền mở phân hệ ${copy[module][0]}.`, 'warning')
    return
  }
  document.querySelectorAll('.nav-item').forEach((button) => button.classList.toggle('active', button.dataset.module === module))
  document.querySelectorAll('.module-panel').forEach((panel) => panel.classList.toggle('active', panel.dataset.panel === module))
  title.textContent = copy[module][0]
  subtitle.textContent = copy[module][1]
  search.value = ''
  filterRows('')
  history.replaceState(null, '', `#${module}`)
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

function filterRows(query) {
  const normalized = query.trim().toLocaleLowerCase('vi')
  const panel = document.querySelector('.module-panel.active')
  panel?.querySelectorAll('.searchable-body tr, .searchable-body.reminder-grid > article').forEach((row) => {
    row.classList.toggle('row-hidden', Boolean(normalized) && !row.textContent.toLocaleLowerCase('vi').includes(normalized))
  })
}

function makeCell(value, strong = false) {
  const td = document.createElement('td')
  const target = strong ? document.createElement('strong') : td
  target.textContent = String(value)
  if (strong) td.append(target)
  return td
}

function statusCell(label, kind = 'waiting') {
  const td = document.createElement('td')
  const badge = document.createElement('span')
  badge.className = `status ${kind}`
  badge.textContent = label
  td.append(badge)
  return td
}

function viDate(value) {
  if (!value) return 'Chưa đặt'
  const parsed = new Date(`${value}T00:00:00`)
  return Number.isNaN(parsed.getTime()) ? value : parsed.toLocaleDateString('vi-VN')
}

function money(value) { return `${Number(value || 0).toLocaleString('vi-VN')} ₫` }

function tableRow(module, record) {
  const tr = document.createElement('tr')
  tr.className = 'user-row'
  tr.dataset.userRecord = 'true'
  const cells = {
    customers: [makeCell(record.code), makeCell(record.name, true), makeCell(record.phone), makeCell(record.device), makeCell(record.created)],
    inventory: [makeCell(record.code), makeCell(record.name, true), makeCell(record.group), makeCell(record.quantity), makeCell(money(record.price)), statusCell(Number(record.quantity) < 5 ? 'Sắp hết' : 'Ổn định', Number(record.quantity) < 5 ? 'danger' : 'done')],
    sales: [makeCell(record.code), makeCell(record.customer), makeCell(record.product), makeCell(money(record.total)), statusCell(record.payment, record.payment === 'Đủ' ? 'done' : 'waiting')],
    repairs: [makeCell(record.code), makeCell(record.device), makeCell(record.issue), makeCell(viDate(record.due)), statusCell('Đã tiếp nhận', 'progress')],
    warranty: [makeCell(record.code), makeCell(record.product), makeCell(record.customer), makeCell(viDate(record.expires)), statusCell('Còn hạn', 'done')],
  }
  cells[module]?.forEach((cell) => tr.append(cell))
  return tr
}

function reminderCard(record) {
  const article = document.createElement('article')
  article.className = 'reminder-item user-row'
  article.dataset.userRecord = 'true'
  const icon = document.createElement('span')
  icon.className = 'task-icon cyan'
  icon.textContent = '✓'
  const content = document.createElement('div')
  const heading = document.createElement('strong')
  const description = document.createElement('p')
  const meta = document.createElement('small')
  heading.textContent = record.title
  description.textContent = record.details
  meta.textContent = `Bản ghi thử · ${viDate(record.due)}`
  content.append(heading, description, meta)
  article.append(icon, content)
  return article
}

function renderRecords() {
  document.querySelectorAll('[data-user-record]').forEach((item) => item.remove())
  Object.entries(state.records).forEach(([module, records]) => {
    const target = document.querySelector(`[data-panel="${module}"] .searchable-body`)
    if (!target) return
    records.forEach((record) => target.prepend(module === 'reminders' ? reminderCard(record) : tableRow(module, record)))
  })
  const count = Object.values(state.records).reduce((sum, records) => sum + records.length, 0)
  document.querySelector('#saved-count').textContent = `${count} bản ghi thử`
}

function applyRole() {
  const role = roles[state.role]
  roleSelect.value = state.role
  document.querySelector('#role-name').textContent = role.name
  document.querySelector('#role-summary').textContent = role.summary
  document.querySelector('#role-info').textContent = role.initials
  document.querySelectorAll('.nav-item').forEach((button) => {
    const allowed = canOpen(button.dataset.module)
    button.classList.toggle('locked', !allowed)
    button.setAttribute('aria-disabled', String(!allowed))
    button.title = allowed ? '' : `Không thuộc quyền ${role.name}`
  })
  document.querySelectorAll('[data-demo-action]').forEach((button) => {
    const module = actionModules[button.dataset.demoAction]
    if (!module) return
    const allowed = canWrite(module)
    button.disabled = !allowed
    button.title = allowed ? '' : `${role.name} không có quyền thực hiện`
  })
  const active = document.querySelector('.module-panel.active')?.dataset.panel || 'dashboard'
  if (!canOpen(active)) openModule('dashboard', false)
}

function addField(field) {
  const wrapper = document.createElement('div')
  wrapper.className = `field${field.wide ? ' wide' : ''}`
  const label = document.createElement('label')
  label.htmlFor = `field-${field.key}`
  label.textContent = field.label
  let input
  if (field.type === 'select') {
    input = document.createElement('select')
    field.options.forEach((value) => {
      const option = document.createElement('option')
      option.value = value
      option.textContent = value
      input.append(option)
    })
  } else if (field.type === 'textarea') {
    input = document.createElement('textarea')
  } else {
    input = document.createElement('input')
    input.type = field.type || 'text'
  }
  input.id = `field-${field.key}`
  input.name = field.key
  input.required = Boolean(field.required)
  if (field.placeholder) input.placeholder = field.placeholder
  if (field.min !== undefined) input.min = field.min
  if (field.value !== undefined) input.value = field.value
  wrapper.append(label, input)
  formFields.append(wrapper)
}

function openForm(module) {
  if (!forms[module] || !canWrite(module)) {
    showNotice(`${roles[state.role].name} không có quyền tạo dữ liệu trong phân hệ này.`, 'warning')
    return
  }
  currentFormModule = module
  lastFocus = document.activeElement
  form.reset()
  formFields.replaceChildren()
  document.querySelector('#modal-title').textContent = forms[module].title
  forms[module].fields.forEach(addField)
  modal.hidden = false
  document.body.classList.add('modal-open')
  requestAnimationFrame(() => formFields.querySelector('input, select, textarea')?.focus())
}

function closeModal() {
  modal.hidden = true
  document.body.classList.remove('modal-open')
  currentFormModule = null
  lastFocus?.focus()
}

function exportReport() {
  if (!canOpen('reports')) return showNotice('Vai trò hiện tại không có quyền xem báo cáo.', 'warning')
  const rows = [['Phân hệ', 'Số bản ghi thử'], ...Object.entries(state.records).map(([module, records]) => [copy[module][0], records.length])]
  const csv = `\uFEFF${rows.map((row) => row.map((value) => `"${String(value).replaceAll('"', '""')}"`).join(',')).join('\n')}`
  const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }))
  const link = document.createElement('a')
  link.href = url
  link.download = 'hometechvn-demo-report.csv'
  link.click()
  URL.revokeObjectURL(url)
  showNotice('Đã xuất báo cáo thử, không chứa dữ liệu thật.')
}

document.querySelectorAll('[data-module]').forEach((button) => button.addEventListener('click', () => openModule(button.dataset.module)))
document.querySelectorAll('[data-module-jump]').forEach((button) => button.addEventListener('click', () => openModule(button.dataset.moduleJump)))
document.querySelectorAll('[data-demo-action]').forEach((button) => {
  button.addEventListener('click', () => button.dataset.demoAction === 'Xuất báo cáo' ? exportReport() : openForm(actionModules[button.dataset.demoAction]))
})
document.querySelectorAll('[data-modal-close]').forEach((button) => button.addEventListener('click', closeModal))

roleSelect.addEventListener('change', (event) => {
  state.role = event.target.value
  persist()
  applyRole()
  showNotice(`Đã chuyển sang vai trò ${roles[state.role].name}.`)
})

document.querySelector('#role-info').addEventListener('click', () => {
  const role = roles[state.role]
  showNotice(`${role.name}: được xem ${role.modules.length} phân hệ và được ghi thử tại ${role.write.length} phân hệ.`)
})

document.querySelector('#reset-demo').addEventListener('click', () => {
  if (!window.confirm('Xóa toàn bộ bản ghi thử trên trình duyệt này và trở về dữ liệu mẫu?')) return
  state.records = emptyRecords()
  persist()
  renderRecords()
  showNotice('Đã khôi phục dữ liệu mẫu.')
})

form.addEventListener('submit', (event) => {
  event.preventDefault()
  if (!currentFormModule || !canWrite(currentFormModule)) return closeModal()
  const module = currentFormModule
  const values = Object.fromEntries(new FormData(form).entries())
  const records = state.records[module]
  const sequence = records.length + 1
  const record = { ...values, code: `${forms[module].prefix}${String(sequence).padStart(3, '0')}`, created: new Date().toLocaleDateString('vi-VN') }
  records.push(record)
  persist()
  renderRecords()
  closeModal()
  openModule(module)
  showNotice(`Đã lưu ${record.code} trên trình duyệt này.`)
})

search.addEventListener('input', (event) => filterRows(event.target.value))
document.addEventListener('keydown', (event) => { if (event.key === 'Escape' && !modal.hidden) closeModal() })

renderRecords()
applyRole()
const requestedModule = location.hash.slice(1)
openModule(copy[requestedModule] && canOpen(requestedModule) ? requestedModule : 'dashboard', false)
