# T21–T25 — Lộ trình tinh gọn vận hành liên thông

Nguồn đề xuất: `goiyhethong.txt` do chủ dự án cung cấp ngày 2026-09-10.

Baseline: T20.2 `COMPLETE & LOCKED`; migrations #1–#40 bất biến. Production đã có T22 migrations #41–#44; T21.4 dùng migration #45 cho cấu hình QR thanh toán. Từ T20.2 trở đi chỉ nghiệm thu tự động trên hosted demo dùng dữ liệu hoàn toàn giả định, không yêu cầu nghiệm thu PC.

## Quyết định áp dụng

| Nhóm đề xuất | Quyết định | Cách áp dụng an toàn |
|---|---|---|
| Một nút tạo chính trên mỗi màn hình | Áp dụng ở T21.2 | Menu hành động theo quyền; giữ thao tác theo dòng vì phụ thuộc trạng thái bản ghi |
| Tìm/thêm nhanh khách hàng và thiết bị | Áp dụng trước ở T21.1 | Thành phần dùng chung, tự chọn bản ghi vừa tạo, không rời form |
| Bộ lọc trạng thái/thời gian/khách/nguồn | Áp dụng ở T21.2 | Bộ lọc thu gọn, có trạng thái rỗng và đặt lại |
| Chính sách bảo hành mặc định theo sản phẩm/nhóm | Áp dụng ở T22 | Cấu hình có hiệu lực theo thời gian, snapshot vào dòng bán để không đổi lịch sử |
| Bảo hành sửa chữa tách linh kiện/công | Áp dụng ở T22 | Hai phạm vi độc lập; không sửa bảo hành bán hàng đã phát hành |
| Chuỗi sau bán tạo warranty/license/service/reminder | Áp dụng ở T23 | Xem trước + xác nhận; một transaction; idempotency key; không tự thu tiền |
| Quote, đổi trả, nhà cung cấp/phiếu nhập | Tách sang T24 | Đây là chứng từ và luồng tồn kho mới, không nhồi vào T21/T22 |
| Trung tâm cần xử lý và thông báo | Áp dụng ở T25 | Tận dụng engine reminder/notification hiện có, bổ sung tab/lọc/lưu trữ |

## Nội dung không áp dụng nguyên trạng

1. Không lưu mật khẩu máy, tài khoản khách hoặc license key dạng rõ. Chỉ lưu `secret_ref` tới kho bí mật; biểu mẫu tiếp nhận không có trường mật khẩu.
2. Không tự tạo hàng loạt dữ liệu liên quan một cách âm thầm. T23 phải cho xem trước, xác nhận và chạy idempotent trong một transaction.
3. Không đánh đồng hoàn tất đơn với đã thanh toán. Sổ thanh toán và tổng đơn T20.2 tiếp tục là nguồn sự thật; thu một phần vẫn là luồng riêng có lý do công nợ.
4. Không gộp catalog phần mềm vào tồn kho vật lý. Hai catalog tiếp tục tách biệt nhưng có thể cùng xuất hiện trong luồng sau bán.
5. Không ẩn thao tác chuyển trạng thái quan trọng trong menu chung. Menu chính chỉ gom thao tác tạo; thao tác theo dòng/bước vẫn hiển thị theo trạng thái và prerequisite.

## Các mốc nhỏ

### T21.1 — Shared intake foundation (`COMPLETE`)

- Tìm khách theo mã/tên/điện thoại/Zalo/email ngay trong form.
- Thêm khách mới tại chỗ và tự chọn sau khi lưu.
- Tìm thiết bị theo mã/serial/hãng/model của đúng khách.
- Thêm thiết bị mới tại chỗ và tự chọn sau khi lưu.
- Áp dụng cho tạo đơn bán, tiếp nhận sửa chữa, lịch dịch vụ và license.
- Không có migration; #41 vẫn để trống.

### T21.2 — Unified actions and filters (`COMPLETE`)

- Một nút `+ Tạo mới` theo module, menu được lọc bằng RBAC.
- Bộ lọc thu gọn dùng chung; giữ tìm kiếm nhanh ở hàng đầu.
- Chuẩn hóa trạng thái rỗng, làm mới và đặt lại bộ lọc.
- Hợp nhất phản hồi liên nhánh: điều hướng nhanh Tổng quan/QR, checkbox nhập nhanh, tạo nhanh danh mục, thao tác đơn nháp và quản lý nhân viên theo RBAC.
- Chuẩn hóa nhãn vận hành tiếng Việt; mã kỹ thuật chỉ giữ ở dữ liệu và audit.

### T21.3 — Repair quote and guided continuation (`COMPLETE`)

- Tách tiền công, tiền linh kiện, giảm giá và tổng khách thanh toán trong báo giá sửa chữa.
- Ô không phát sinh để trống và được gửi bằng `0`; bước nhập tiền là 1 VNĐ, không tự nhảy 1.000 VNĐ.
- Chặn báo giá rỗng và chặn giảm giá vượt tiền công cộng tiền linh kiện trước khi gọi RPC.
- Một nút `Tiếp tục thực hiện` tự dẫn đến bước hợp lệ kế tiếp theo trạng thái, dữ liệu và RBAC.
- Các nhánh ngoại lệ vẫn tách riêng: chờ linh kiện, không sửa được, chuyển bảo hành và hủy phiếu.
- Không có migration tại T21.3.

### T21.4 — Exact-balance payment QR (`COMPLETE`)

- QR chuyển khoản lấy đúng số tiền còn phải thu và mã đơn.
- Admin cấu hình tài khoản nhận dùng chung; Thu ngân chỉ đọc theo RBAC.
- QR không tự xác nhận tiền đã vào tài khoản.
- Migrations #45–#46; migrations #1–#44 giữ nguyên hash và đồng bộ với production.

### T22 — Warranty policy engine

- Chính sách bảo hành theo sản phẩm/danh mục/dịch vụ.
- Nút nhanh 7/15 ngày, 1/3 tháng và tùy chỉnh.
- Bảo hành sửa chữa tách linh kiện/công.
- Production đã triển khai migrations #41–#44; verifier chống trùng/phủ sai thời gian.

### T23 — After-sales orchestrator

- Xem trước các bản ghi sẽ tạo từ từng dòng đơn.
- Tạo warranty/license/service schedule/reminder trong một transaction.
- Idempotent khi bấm lại hoặc mạng chập chờn.
- Không ghi payment và không đổi trạng thái tài chính.

### T24 — Chứng từ còn thiếu

- Báo giá bán, đổi/trả hàng, nhà cung cấp, phiếu nhập và điều chỉnh có lý do.
- Mỗi chứng từ có workflow, audit và tác động tồn kho riêng.

### T25 — Attention center

- Lọc hôm nay/quá hạn/7–30 ngày, nhân viên, khách và nguồn.
- Tab chưa đọc/cần xử lý/tất cả/lưu trữ.
- Checklist lỗi có thể tạo task/reminder có liên kết nguồn.
