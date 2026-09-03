const copy = {
  dashboard: ['Tổng quan cửa hàng', 'Tình hình kinh doanh và công việc cần xử lý hôm nay.'],
  customers: ['Khách hàng & thiết bị', 'Theo dõi hồ sơ CRM và lịch sử thiết bị giả định.'],
  inventory: ['Kho hàng', 'Tồn kho và cảnh báo định mức bằng dữ liệu demo.'],
  sales: ['Bán hàng', 'Đơn bán, thanh toán và công nợ hoàn toàn giả định.'],
  repairs: ['Sửa chữa', 'Tiến độ tiếp nhận, báo giá và trả máy demo.'],
  warranty: ['Bảo hành', 'Hồ sơ và thời hạn bảo hành giả định.'],
  reminders: ['Nhắc việc', 'Các công việc ưu tiên được tạo sẵn để minh họa.'],
  reports: ['Báo cáo', 'Số liệu minh họa, không phản ánh hoạt động kinh doanh thực tế.'],
}

const title = document.querySelector('#page-title')
const subtitle = document.querySelector('#page-subtitle')
const search = document.querySelector('#table-search')
const toast = document.querySelector('#toast')
let toastTimer

function openModule(module) {
  if (!copy[module]) return
  document.querySelectorAll('.nav-item').forEach((button) => {
    button.classList.toggle('active', button.dataset.module === module)
  })
  document.querySelectorAll('.module-panel').forEach((panel) => {
    panel.classList.toggle('active', panel.dataset.panel === module)
  })
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
    row.classList.toggle('row-hidden', normalized && !row.textContent.toLocaleLowerCase('vi').includes(normalized))
  })
}

function showDemoNotice(action) {
  clearTimeout(toastTimer)
  toast.textContent = `${action}: bản demo chỉ xem, không ghi hoặc gửi dữ liệu.`
  toast.classList.add('show')
  toastTimer = setTimeout(() => toast.classList.remove('show'), 3200)
}

document.querySelectorAll('[data-module]').forEach((button) => {
  button.addEventListener('click', () => openModule(button.dataset.module))
})

document.querySelectorAll('[data-module-jump]').forEach((button) => {
  button.addEventListener('click', () => openModule(button.dataset.moduleJump))
})

document.querySelectorAll('[data-demo-action]').forEach((button) => {
  button.addEventListener('click', () => showDemoNotice(button.dataset.demoAction))
})

search.addEventListener('input', (event) => filterRows(event.target.value))

const initialModule = location.hash.slice(1)
openModule(copy[initialModule] ? initialModule : 'dashboard')
