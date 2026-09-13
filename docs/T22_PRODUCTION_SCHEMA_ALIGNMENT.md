# T22 — Production schema alignment

Ngày đối chiếu: 2026-09-13

Supabase production đã có bốn migration T22 nhưng GitHub `main` tại T21.3 chưa
chứa các tệp tương ứng. Trước khi thêm QR thanh toán, mã nguồn đã được đồng bộ
đúng các migration production sau:

1. `#41 20260910145644_t22_auto_repair_warranty.sql`
2. `#42 20260910153258_t22_integrity_rpc_surface_hardening.sql`
3. `#43 20260910153627_t22_remove_manual_repair_warranty_rpc.sql`
4. `#44 20260910155015_t22_remove_manual_sale_warranty_rpc.sql`

Giao diện tạo bảo hành thủ công đã bị loại bỏ vì hai RPC tương ứng không còn
tồn tại trên production. Bảo hành được sinh tự động theo nghiệp vụ nguồn. QR
thanh toán bắt đầu ở migration #45 và hardening ở #46, không chiếm hoặc ghi đè lịch sử T22.
