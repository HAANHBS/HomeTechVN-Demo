# T21.2 — Tổng hợp yêu cầu liên nhánh

Ngày tổng hợp: 2026-09-11  
Baseline: T21.1, commit `ec75dff`  
Phạm vi: UI và Auth client; không có migration mới. Migrations #1–#40 giữ nguyên, #41 vẫn để trống cho T22.

## Ma trận hoàn thành

| Yêu cầu | Trạng thái | Cách triển khai và kiểm soát |
|---|---|---|
| `Tổng quan` và `Quét QR` ở đầu màn hình, cạnh nhau | Hoàn thành | Thanh điều hướng nhanh cố định, dùng chung cho mọi phân hệ; `Tổng quan` chỉ hiện khi có `dashboard.view`. |
| Zalo giống số điện thoại | Hoàn thành | Checkbox đồng bộ tức thời, khóa ô Zalo khi bật và lưu đúng số điện thoại. |
| Đổi `+ Dòng hàng` thành `+ Hàng vào đơn` | Hoàn thành | Nhãn mới chỉ xuất hiện khi đơn còn nháp và người dùng có quyền cập nhật. |
| Đổi `Xác nhận & trừ kho` thành `Xác nhận đơn` | Hoàn thành | Vẫn gọi RPC nghiệp vụ cũ; diễn giải rõ hệ thống tự trừ kho khi xác nhận. |
| Sửa/xóa/đổi số lượng hàng của đơn nháp | Hoàn thành | Giữ `sale_item_update` và `sale_item_remove`; thao tác bị ẩn khi đơn rời trạng thái `DRAFT`. |
| Tình trạng nhận máy giống lỗi khách báo | Hoàn thành | Checkbox đồng bộ nội dung và giữ khả năng tách hai mô tả khi cần. |
| Thêm nhanh danh mục khi tạo sản phẩm | Hoàn thành | Mở form danh mục lồng an toàn, tự thêm vào danh sách và tự chọn danh mục vừa tạo. |
| Thêm/sửa/xóa quyền nhân viên để thử vai trò | Hoàn thành | `user.view` chỉ xem; `user.manage` mới được ghi. “Xóa” là khóa truy cập để bảo toàn audit; chặn tự khóa/tự đổi vai trò. |
| Không dùng secret/service role ở frontend | Hoàn thành | Tạo Auth user bằng Supabase client cô lập và publishable key; phiên quản trị hiện tại không bị thay thế. |
| Một nhãn tạo chính theo phân hệ | Hoàn thành | Các màn hình chính chuẩn hóa về `+ Tạo mới`; hành động theo dòng/trạng thái vẫn giữ riêng. |
| Đặt lại bộ lọc và trạng thái rỗng | Hoàn thành | Các danh sách có tìm/lọc cung cấp `Đặt lại`; trạng thái rỗng có thông điệp rõ. |
| Chuẩn hóa giao diện tiếng Việt | Hoàn thành trong phạm vi UI vận hành | Trạng thái, mức ưu tiên, phương thức thanh toán, thông báo, bảo hành, bản quyền và danh sách kiểm tra dùng bộ ánh xạ chung. Mã kỹ thuật trong dữ liệu vẫn giữ nguyên để tra cứu/audit. |

## Quyết định bảo mật

- Không thêm `service_role`, DB password hoặc secret vào app.
- Không nới RLS/GRANT và không sửa migration đã khóa để làm UI hoạt động.
- Tài khoản nhân viên bị “xóa” bằng `is_active=false`; không xóa Auth user vật lý vì chứng từ và audit còn tham chiếu người tạo.
- Tài khoản hiện tại không thể tự thay đổi vai trò hoặc tự vô hiệu hóa từ giao diện.
- Việc tạo tài khoản phụ dùng Auth client không lưu session. Nếu dự án tắt public sign-up, cần chuyển thao tác tạo Auth user sang Edge Function/server có kiểm soát ở mốc sau; tuyệt đối không đưa khóa bí mật vào trình duyệt.

## Cổng nghiệm thu tự động

```text
npm run t21.2:ui-check
npm run t21:verify
```

Hai cổng bắt buộc kiểm migration bất biến, hợp đồng UI liên nhánh, TypeScript/Vite/PWA build, logic T20 và cú pháp worker.

## Ngoài phạm vi T21.2

- T22: policy engine bảo hành theo sản phẩm/danh mục/dịch vụ; migration #41.
- T23: điều phối sau bán idempotent.
- T24: báo giá bán, đổi/trả, nhà cung cấp, phiếu nhập.
- T25: trung tâm cần xử lý.

Các mốc trên không được đánh dấu hoàn thành trong bản tích hợp này.
