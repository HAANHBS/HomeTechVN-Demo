# T20.1 — Logic integrity and workflow guidance

Status: `SUPERSEDED BY T20.2 COMPLETE IMPLEMENTATION`  
Date: `2026-09-09`  
Migration: `#39 — 20260909052415_t20_operational_logic_integrity.sql`  
Surface hardening: `#40 — 20260909053211_t20_rpc_surface_and_qr_index_hardening.sql`

## Mục tiêu

1. Luồng thu tiền chuẩn chỉ nhận đúng toàn bộ số còn phải thu.
2. Tổng `payments` trạng thái `COMPLETED` luôn bằng `sales_orders.paid_amount` và không vượt `total_amount`.
3. Thu một phần là RPC riêng, bắt buộc có lý do công nợ; giao diện thu tiền chuẩn không cho sửa số tiền.
4. Bàn giao đơn bán bị chặn nếu tiền hoặc checklist trước bàn giao chưa hoàn tất.
5. Chuyển bước sửa chữa bị chặn nếu thiếu báo giá duyệt, chẩn đoán, xuất vật tư hoặc QC PASS.
6. Lỗi thao tác xuất hiện ngay dưới cụm nút và được công bố bằng `role="alert"`/`aria-live="assertive"`.
7. Giao diện hiển thị quy trình, bước hiện tại, bộ phận chịu trách nhiệm và việc còn thiếu.

## Quy tắc nghiệp vụ chính

| Luồng | Điều kiện bắt buộc |
|---|---|
| Thu đủ đơn bán | Số thu bằng đúng `total_amount - completed payments` |
| Thu một phần | Số thu nhỏ hơn số còn lại và có lý do/cam kết công nợ |
| Bàn giao bán hàng | Trạng thái `PAID`; sổ thanh toán khớp giá bán; checklist trước bàn giao hoàn tất |
| Hoàn tất đơn bán | Đã bàn giao; toàn bộ checklist bắt buộc, gồm xác nhận khách nhận đủ, đã hoàn tất |
| Bắt đầu sửa/QC | Báo giá đã duyệt; không còn vật tư `PLANNED`; trước QC phải có chẩn đoán |
| Trả/hoàn tất sửa chữa | QC phải `PASS` |

## Phạm vi giao diện báo lỗi

Các form và khu vực thao tác của Auth, CRM, Kho, Bán hàng, Sửa chữa, Checklist, Bảo hành, Dịch vụ/License, Reminder, Notification, QR và Audit đều có thông báo lỗi truy cập được. Các form submit đặt lỗi sau cụm nút để người vận hành không phải tìm lại lỗi ở đầu biểu mẫu.

## Nghiệm thu

Nghiệm thu chạy tự động bằng dữ liệu giả trên hosted và source/build gate:

```text
T20 PAYMENT/WORKFLOW DATABASE CONTRACT: PASS
T20 ACTION ERROR PLACEMENT CHECK: PASS
T20 WORKFLOW GUIDANCE UI CHECK: PASS
T20 PAYMENT LEDGER INTEGRITY CHECK: PASS
T20 WORKFLOW PREREQUISITE CHECK: PASS
T20 APP BUILD: PASS
T20 AUTOMATED FAKE-DATA ACCEPTANCE: PASS
T20 PC ACCEPTANCE REQUIRED: NO
```

Test hosted tự rollback. Migration #39–#40 đã được áp và khóa hash.
