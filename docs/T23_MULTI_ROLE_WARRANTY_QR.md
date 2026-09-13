# HomeTechVN T23 — đa chức vụ, thời hạn bảo hành và tem QR

## Phạm vi

- Hai nút `Tổng quan` và `Quét QR` nằm trong header cố định, ngay sau khối `HomeTechVN / Tổng quan điều hành / Asia/Bangkok`.
- Một nhân viên có từ 1 đến 5 chức vụ. Quyền hiệu lực là hợp của toàn bộ chức vụ đang hoạt động; `profiles.role_id` được giữ làm chức vụ chính để tương thích dữ liệu cũ.
- Dòng hàng bán cho phép nhập riêng thời hạn bảo hành từ 0 đến 120 tháng.
- Báo giá sửa chữa cho phép nhập thời hạn bảo hành công từ 1 đến 120 tháng. Tiền công, linh kiện và giảm giá vẫn là ba khoản độc lập; ô trống là 0 đồng.
- Sau khi bán hàng được bàn giao hoặc sửa chữa hoàn tất, màn hình chứng từ hiển thị danh sách tem QR bảo hành để in/dán lên từng sản phẩm hoặc thiết bị.
- QR mở trang tra cứu công khai với tên người mua, số điện thoại và Serial đã che. Nhân viên có quyền quét nội bộ thấy đầy đủ thông tin cần cho nghiệp vụ.
- PWA tự nhận bản mới; HTML khởi động có trạng thái tải, nút tải lại và cơ chế tự xóa cache/service worker cũ khi asset không còn tồn tại, tránh màn hình trắng.

## Cơ sở dữ liệu

Migration mới duy nhất:

```text
#47 20260913101000_t23_multi_role_warranty_qr_labels.sql
```

Migration #1–#46 không thay đổi. Migration #47 tạo `profile_roles` có RLS; thêm RPC cập nhật nhiều chức vụ và thời hạn bảo hành; cập nhật kiểm tra kỹ thuật viên kiêm nhiệm; giữ bảo hành linh kiện theo từng sản phẩm; và chỉ trả tên người mua đã che ở tra cứu công khai.

## Kiểm tra

```powershell
cd D:\HOMETECHVN
npm install
npm run app:install
npm run t23:verify
```

Không đưa `service_role`, mật khẩu, token hay khóa bí mật vào frontend hoặc repository.
