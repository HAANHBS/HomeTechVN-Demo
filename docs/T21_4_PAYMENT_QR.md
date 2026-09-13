# T21.4 — QR thanh toán theo số tiền còn phải thu

Trạng thái: `COMPLETE`

## Nghiệp vụ

- Nút `QR thanh toán` xuất hiện ở đơn `CONFIRMED` hoặc `PAYMENT_PENDING` khi
  người dùng có quyền `payment.create` và đơn còn tiền phải thu.
- QR lấy chính xác `sales_orders.balance_due`; nhân viên không tự nhập lại số
  tiền nên không thể lệch với giá bán hoặc khoản đã thu trước đó.
- Nội dung chuyển khoản là `HTVN <mã đơn>` để đối chiếu giao dịch.
- Sau khi khách quét, nhân viên phải kiểm tra tiền thực sự vào tài khoản rồi mới
  nhấn `Xác nhận đã nhận đủ ...`. Việc hiển thị/quét QR tuyệt đối không gọi RPC
  ghi nhận thanh toán.

## Cấu hình và quyền

- Admin có `settings.manage` cấu hình mã ngân hàng, số tài khoản, tên người nhận
  một lần; cấu hình dùng chung trên PC, điện thoại và máy tính bảng.
- Thu ngân có `payment.create` chỉ đọc cấu hình đã làm sạch qua RPC.
- `anon` không được gọi RPC; private implementation không cấp EXECUTE trực tiếp.
- Không lưu mật khẩu, OTP, PIN, token hoặc khóa ngân hàng. Thông tin nhận tiền là
  cấu hình không nhạy cảm trong `public.settings`, vẫn được bảo vệ bởi RLS.

## Triển khai

- Migrations #41–#44 là T22 đã triển khai trên production và được hợp nhất lại
  vào mã nguồn trước khi phát hành QR.
- Migration #45: `20260913021403_t21_4_payment_vietqr_config.sql`.
- Migration #46: `20260913021747_t21_4_payment_qr_invoker_hardening.sql` chuyển
  RPC sang `SECURITY INVOKER` và chỉ mở đúng dòng cấu hình qua RLS.
- Migrations #1–#45 giữ nguyên hash và thứ tự production.
- Ảnh QR dùng VietQR `compact2`; trình duyệt cần Internet để tải ảnh.

## Kiểm thử bắt buộc

```text
npm run t21.4:ui-check
npm run t21.4:build-check
npm run t21:verify
```

Admin cần mở một đơn còn phải thu, chọn `QR thanh toán`, nhập đúng thông tin tài
khoản nhận tiền, quét thử bằng ứng dụng ngân hàng và kiểm tra tên người nhận, số
tiền, nội dung trước khi dùng thực tế.
