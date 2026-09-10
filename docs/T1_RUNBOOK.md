# T1 RUNBOOK — Khi cần kiểm tra lại sau này

## Nếu máy mới / cài lại Windows

1. Clone repository.
2. Mở `T1_ACCOUNT_CONFIG_REGISTER.md`.
3. Cài đúng các công cụ đã ghi version.
4. `npm install`
5. Bật Docker.
6. `npx supabase start`
7. `npx supabase db reset`
8. Chạy `t1_verify.sql`.
9. Không cần nhớ cấu hình bằng trí nhớ: đối chiếu Register.

## Nếu quên Supabase project nào

Mở Register, xem:
- Organization
- Project name
- Project Ref
- Project URL
- Region

Không đi tìm project bằng cách mở từng project.

## Nếu cần key

### Frontend
Tìm Publishable Key trong Supabase Dashboard.
Register chỉ ghi trạng thái/nơi lấy.

### Backend
Tìm Secret Key trong nơi quản lý bí mật đã ghi ở Register.
Không copy từ lịch sử chat hoặc Git.

## Nếu người mới tham gia dự án

Bắt buộc đọc theo thứ tự:
1. README.md
2. T1_MASTER_CHECKLIST.md
3. T1_ACCOUNT_CONFIG_REGISTER.md
4. T1_ACCEPTANCE.md

## Nếu migration remote không giống local

Không sửa trực tiếp production trước.

Quy trình:
1. xác nhận Project Ref;
2. kiểm tra Git branch;
3. `supabase db push --dry-run`;
4. review;
5. backup trước thay đổi lớn (khi backup stage đã triển khai);
6. push migration.

Không dùng `db reset --linked` trên production.
