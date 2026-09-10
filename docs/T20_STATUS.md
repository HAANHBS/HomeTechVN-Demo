# T20.2 status

```text
Stage: T20.2 — Operational Logic + Hosted Fake-Data Acceptance
Status: COMPLETE & LOCKED
Date: 2026-09-09
Hosted migrations: #1–#40 applied and hash-locked
Next migration: #41
PC acceptance required: NO
GitHub source merge: 09cabc831e7a2fb45fa03b5aa7ff8dab4f951a1c
Sites production version: 4 — succeeded
```

Nghiệm thu chính thức từ T20.2 chạy tự động trên Supabase hosted chuyên dùng cho
dữ liệu giả. Bộ test tự rollback, không phụ thuộc máy Windows của người dùng.

Các gate hosted đã PASS:

- từ chối thu thiếu/thừa qua luồng thu đủ;
- thu đúng số còn lại và đối chiếu sổ thanh toán;
- từ chối trùng mã giao dịch;
- thu một phần chỉ qua RPC riêng và bắt buộc có lý do;
- chặn bàn giao/sửa chữa khi thiếu bước trước;
- tự tạo bảo hành lúc bàn giao và quét được serial/QR/mã bảo hành/mã đơn;
- Demo Admin có toàn bộ quyền RBAC, không mở quyền ghi cho `anon`;
- kiểm toàn hệ thống không có lệch tổng tiền, sổ thu, serial, tồn kho, bảo hành,
  quy trình sửa chữa hoặc quyền Admin.

Hai RPC nghiệp vụ cần thiết cho frontend dùng `SECURITY DEFINER` có chủ đích:
`sale_record_partial_payment` và `warranty_scan_product`. Cả hai bắt buộc Auth,
kiểm permission phía server, đặt `search_path=''`, và không cho browser gọi trực
tiếp implementation trong schema `private`.

Production demo:
`https://hometechvn-demo.maytinhhaanhbs.chatgpt.site` (owner-only).
