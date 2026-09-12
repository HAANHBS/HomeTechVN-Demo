# T21.3 — Repair quote and guided continuation

Status: `COMPLETE`

T21.3 sửa luồng thao tác phiếu sửa chữa ở giao diện. Database formula và state
machine hiện có được giữ nguyên; migrations #1–#40 không đổi và #41 vẫn dành
cho T22.

## Báo giá sửa chữa

- Tiền công, tiền linh kiện và giảm giá là ba khoản độc lập.
- Có thể chỉ nhập tiền công, chỉ nhập tiền linh kiện hoặc nhập cả hai.
- Ô không phát sinh để trống và được gửi lên RPC bằng `0`.
- Bước nhập là 1 VNĐ thay vì 1.000 VNĐ; cuộn chuột không làm đổi số đang nhập.
- Giao diện xem trước từng khoản và tổng khách phải thanh toán.
- Chặn cả tiền công và linh kiện cùng bằng 0.
- Chặn giảm giá lớn hơn tiền công cộng tiền linh kiện.

Ví dụ khóa hồi quy: công `100.000`, linh kiện để trống, giảm giá để trống thì
tổng báo giá phải là `100.000`, không phải `101.000`.

## Tiếp tục thực hiện

Nút chính duy nhất tự chọn bước tiếp theo từ trạng thái và dữ liệu của phiếu:

1. Tiếp nhận → bắt đầu chẩn đoán.
2. Đang chẩn đoán → nhập chẩn đoán → lập báo giá.
3. Đã lập báo giá → gửi báo giá.
4. Chờ khách → chọn đồng ý hoặc từ chối.
5. Đã duyệt/chờ linh kiện → xuất đủ vật tư nếu có → bắt đầu sửa chữa.
6. Đang sửa → QC → ghi kết quả QC.
7. Sẵn sàng → xác nhận trả thiết bị → hoàn tất.
8. Đã chuyển bảo hành → nhận lại và chẩn đoán tiếp.

Nút bị khóa kèm lý do khi thiếu quyền hoặc thiếu điều kiện. Các nhánh ngoại lệ
vẫn là thao tác riêng để tránh chọn nhầm: chờ linh kiện, không sửa được, chuyển
bảo hành và hủy phiếu.

## Checklist nghiệm thu

- [x] Công thức database không thay đổi.
- [x] Migrations #1–#40 không thay đổi; #41 chưa sử dụng.
- [x] Kiểm trường hợp chỉ có 100.000 tiền công.
- [x] Kiểm trường hợp chỉ có tiền linh kiện.
- [x] Kiểm trường hợp có công + linh kiện − giảm giá.
- [x] Kiểm nút tiếp tục theo trạng thái và RBAC.
- [x] Chuẩn hóa nhãn ngoại lệ sang tiếng Việt.
- [x] Kiểm bundle production có đầy đủ ứng dụng và cấu hình Supabase công khai.

Sau khi build production, `npm run t21.3:build-check` sẽ từ chối bundle thiếu
`VITE_SUPABASE_URL` hoặc `VITE_SUPABASE_PUBLISHABLE_KEY`, kể cả khi Vite trả
exit code 0.
