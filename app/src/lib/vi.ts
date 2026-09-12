const statusLabels: Record<string, string> = {
  ACTIVE: 'Đang hoạt động',
  INACTIVE: 'Ngừng hoạt động',
  DRAFT: 'Đơn nháp',
  CONFIRMED: 'Đã xác nhận',
  PAYMENT_PENDING: 'Chờ thanh toán',
  PAID: 'Đã thanh toán',
  DELIVERED: 'Đã bàn giao',
  COMPLETED: 'Hoàn tất',
  CANCELLED: 'Đã hủy',
  PENDING: 'Đang chờ',
  SENT: 'Đã gửi',
  FAILED: 'Gửi lỗi',
  READ: 'Đã đọc',
  UNREAD: 'Chưa đọc',
  DUE: 'Đến hạn',
  ACKNOWLEDGED: 'Đã tiếp nhận',
  RESOLVED: 'Đã xử lý',
  OPEN: 'Đang mở',
  RECEIVED: 'Đã tiếp nhận',
  DIAGNOSING: 'Đang chẩn đoán',
  WAITING_APPROVAL: 'Chờ duyệt',
  APPROVED: 'Đã duyệt',
  WAITING_PART: 'Chờ linh kiện',
  REPAIRING: 'Đang sửa chữa',
  QC: 'Đang kiểm tra chất lượng',
  READY: 'Sẵn sàng trả máy',
  RETURNED: 'Đã trả máy',
  WARRANTY_TRANSFER: 'Chuyển bảo hành',
  EXPIRED: 'Đã hết hạn',
  SUSPENDED: 'Tạm dừng',
  PAUSED: 'Tạm dừng',
  IN_STOCK: 'Đang trong kho',
  RESERVED: 'Đã giữ hàng',
  SOLD: 'Đã bán',
  INSTALLED: 'Đã lắp đặt',
  DEFECTIVE: 'Lỗi',
  NEW: 'Mới tiếp nhận',
  CHECKING: 'Đang kiểm tra',
  QUOTED: 'Đã báo giá',
  AWAITING_CUSTOMER: 'Chờ khách hàng',
  CUSTOMER_REJECTED: 'Khách hàng từ chối',
  REJECTED: 'Đã từ chối',
  NO_FIX: 'Không sửa được',
  CLOSED: 'Đã đóng',
  PLANNED: 'Dự kiến',
  ISSUED: 'Đã xuất kho',
  PROCESSING: 'Đang xử lý',
  RETRYING: 'Đang gửi lại',
  SNOOZED: 'Đã tạm hoãn',
  VOID: 'Đã vô hiệu',
  IN_SERVICE: 'Đang sử dụng',
}

const priorityLabels: Record<string, string> = {
  LOW: 'Thấp',
  NORMAL: 'Bình thường',
  HIGH: 'Cao',
  URGENT: 'Khẩn cấp',
}

export function viStatus(value: string | null | undefined) {
  if (!value) return '—'
  return statusLabels[value] ?? value
}

export function viPriority(value: string | null | undefined) {
  if (!value) return '—'
  return priorityLabels[value] ?? value
}

export function viRole(code: string | null | undefined, fallback?: string | null) {
  const labels: Record<string, string> = {
    admin: 'Quản trị viên',
    manager: 'Quản lý',
    sales: 'Nhân viên bán hàng',
    technician: 'Kỹ thuật viên',
    cashier: 'Thu ngân',
  }
  return code ? labels[code] ?? fallback ?? code : fallback ?? 'Chưa gán vai trò'
}

export function viPaymentMethod(value: string | null | undefined) {
  if (!value) return '—'
  const labels: Record<string, string> = {
    CASH: 'Tiền mặt',
    BANK_TRANSFER: 'Chuyển khoản',
    CARD: 'Thẻ',
    EWALLET: 'Ví điện tử',
    OTHER: 'Khác',
  }
  return labels[value] ?? value
}

export function viBillingModel(value: string | null | undefined) {
  if (!value) return '—'
  return value === 'SUBSCRIPTION' ? 'Định kỳ' : value === 'ONE_TIME' ? 'Một lần' : value
}

export function viIntervalUnit(value: string | null | undefined) {
  if (!value) return '—'
  const labels: Record<string, string> = { DAYS: 'ngày', MONTHS: 'tháng', YEARS: 'năm' }
  return labels[value] ?? value
}

export function viChannel(value: string | null | undefined) {
  if (!value) return '—'
  const labels: Record<string, string> = {
    IN_APP: 'Trong ứng dụng',
    EMAIL: 'Email',
    TELEGRAM: 'Telegram',
    ZALO: 'Zalo',
  }
  return labels[value] ?? value
}
