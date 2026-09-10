# T21.1 — Shared customer/device intake

Status: `COMPLETE`

T21.1 dùng lại bảng, RLS và quyền của CRM nên không tạo migration. Migrations #1–#40 phải giữ nguyên hash và #41 vẫn còn trống cho T22.

## Phạm vi

- `CustomerQuickPicker`: tìm theo mã, tên, điện thoại, Zalo, email; thêm nhanh; tự chọn khách vừa tạo.
- `CustomerDeviceQuickPicker`: lọc thiết bị theo đúng khách; tìm mã, serial, hãng, model; thêm nhanh; tự chọn thiết bị vừa tạo.
- Form áp dụng: tạo đơn bán, tiếp nhận sửa chữa, tạo lịch dịch vụ, tạo software license.
- Nút thêm nhanh chỉ xuất hiện khi `customer.create` hoặc `device.create` được RBAC cấp.
- Modal dùng portal và chặn submit nổi bọt để form thêm nhanh không vô tình submit form nghiệp vụ cha.
- Không có trường mật khẩu thiết bị, tài khoản hoặc license key dạng rõ.

## Nghiệm thu tự động

```text
T21 LOCKED MIGRATION REGRESSION: PASS
T21 SHARED CUSTOMER/DEVICE PICKER CONTRACT: PASS
T21 RBAC-GATED QUICK CREATE CONTRACT: PASS
T21 NESTED FORM/MODAL SAFETY CONTRACT: PASS
T21 UI SOURCE CHECK: PASS
T21 HOSTED QUICK CUSTOMER/DEVICE ACCEPTANCE: PASS
T21 HOSTED FAKE-DATA ROLLBACK: PASS
T20 PAYMENT/WORKFLOW DATABASE CONTRACT: PASS
T20 ACTION ERROR PLACEMENT CHECK: PASS
T20 WORKFLOW GUIDANCE UI CHECK: PASS
T21 APP/PWA BUILD: PASS
T21 WORKER REGRESSION: PASS
T21 AUTOMATED SOURCE/BUILD DEMO GATE: PASS
T21 PC ACCEPTANCE REQUIRED: NO
```

## Kết quả hosted ngày 2026-09-10

- Site version 5 đã triển khai thành công tại
  `https://hometechvn-demo.maytinhhaanhbs.chatgpt.site`.
- Audience của lớp website là `public`; Auth/RLS/RBAC nghiệp vụ không bị nới.
- Demo safety marker xác nhận `HOSTED_DEMO` và không chứa dữ liệu khách thật.
- Khách hàng và thiết bị T21 giả lập được tạo qua quyền Admin rồi rollback;
  residue sau kiểm thử bằng `0`.
- Operational integrity snapshot trả `ok=true`; tất cả nhóm vi phạm đều bằng
  `0`: tổng đơn, sổ thanh toán, trạng thái thanh toán, trùng tham chiếu, serial,
  trạng thái tồn kho, độ phủ bảo hành, quy trình sửa chữa và quyền Admin.
- Quét serial giả lập trả `found=true`, `has_warranty=true`, `status=ACTIVE`.
