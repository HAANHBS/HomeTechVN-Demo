# HomeTechVN Public Demo

Bản sandbox tương tác mô phỏng giao diện quản lý cửa hàng HomeTechVN.

## Phạm vi

- Tổng quan, khách hàng, kho hàng, bán hàng, sửa chữa, bảo hành, nhắc việc và báo cáo.
- Mọi tên, số điện thoại, mã đơn và số liệu đều là dữ liệu giả định.
- Có thể chuyển giữa vai trò Quản trị viên, Quản lý, Bán hàng và Kỹ thuật viên.
- Có thể nhập thử khách hàng, kho, đơn bán, sửa chữa, bảo hành và nhắc việc.
- Bản ghi thử chỉ lưu trong `localStorage` của trình duyệt và có thể khôi phục bằng một nút.
- Không kết nối Supabase, không có tài khoản đăng nhập và không gửi dữ liệu lên máy chủ.

## Chạy cục bộ

Phục vụ thư mục `dist` bằng một HTTP static server bất kỳ rồi mở `index.html`.

## An toàn

Repository không chứa `.env`, API key, service-role key, mật khẩu, dữ liệu khách
hàng hoặc dữ liệu kinh doanh thực tế.
