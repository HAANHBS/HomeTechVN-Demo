# HomeTechVN — T4 MASTER CHECKLIST

## Phạm vi T4

T4 triển khai Sales với các bảng:
- `sales_orders`
- `sales_order_items`
- `payments`
- `private.sales_order_item_costs`

Và workflow:
`DRAFT → CONFIRMED → PAYMENT_PENDING → PAID → DELIVERED → COMPLETED`

Hủy đơn dùng trạng thái `CANCELLED` và hoàn tồn nếu hàng đã xuất.

## Database

- [x] Mã `SO-YYMMDD-0001` bằng counter T1
- [x] Mã `PAY-YYMMDD-0001`
- [x] Dòng hàng lưu snapshot SKU/tên/giá/bảo hành
- [x] Một sản phẩm chỉ có một dòng trên một đơn
- [x] Serial được chọn trước khi confirm và kiểm tra lại atomic lúc confirm
- [x] Confirm đơn trừ tồn atomically
- [x] Hủy đơn hoàn tồn bulk + serial
- [x] Không cho âm kho
- [x] Snapshot giá vốn lưu private
- [x] Thanh toán partial/full
- [x] Hoàn tiền trước bàn giao
- [x] Không hủy đơn nếu còn tiền chưa hoàn
- [x] `DELIVERED` chỉ sau `PAID`
- [x] `COMPLETED` chỉ sau `DELIVERED`, đã thanh toán đủ và checklist đạt

## Checklist bán hàng

T4 dùng 16 mục cố định. `payment_confirmed` chỉ được payment workflow cập nhật.
Mục Serial trở thành bắt buộc động nếu đơn có sản phẩm `track_serial=true`.

## RLS / quyền

- [x] Authenticated chỉ SELECT các bảng Sales qua RLS
- [x] Không INSERT/UPDATE/DELETE trực tiếp `sales_orders`, `sales_order_items`, `payments`
- [x] Sales: tạo/sửa/xác nhận/bàn giao/complete, không thu tiền/hủy
- [x] Cashier: xem đơn + thu/hoàn tiền, không sửa trạng thái bán hàng
- [x] Technician: xem
- [x] Manager/Admin: đầy đủ, gồm hủy
- [x] Private cost snapshot không đọc được từ authenticated
- [x] `sales_order_summary` là `security_invoker`

## Runtime remote

- [x] Preflight DDL bằng transaction ROLLBACK
- [x] Lifecycle `COMPLETED`
- [x] Completion bị chặn khi checklist thiếu
- [x] Sales bị chặn payment
- [x] Cashier bị chặn delivery
- [x] Hủy đơn hoàn kho
- [x] Refund → cancel
- [x] Serial bán = OUT
- [x] Serial đơn hủy = IN_STOCK
- [x] Test data rollback sạch
- [x] Security Advisor không có lỗi T4 mới
- [x] Performance Advisor không có missing-FK-index T4

## Local / app acceptance

- [ ] `npm run t4:verify` trên Windows
- [ ] `T4 LOCAL REPRODUCIBILITY: PASS`
- [ ] `T4 FINAL CORE CHECKS: PASS`
- [ ] `T4 APP BUILD: PASS`
- [ ] Snapshot lưu trong `docs/snapshots/`

**Không đánh dấu T4 COMPLETE trước khi 3 PASS cuối cùng xuất hiện trên máy Windows.**
