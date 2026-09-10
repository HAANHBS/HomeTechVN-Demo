# T1 LOCAL REPAIR — v1.7

## Lỗi đã xác định

Local folder còn file migration cũ:

`supabase/migrations/20260828150000_t1_core.sql`

Trong khi T1 v1.6 đã có migration thay thế:

`20260829143948_t1_core_foundation.sql`

Supabase CLI áp **tất cả** migration trong thư mục theo thứ tự. Do hai migration cùng tạo
`trg_roles_updated_at`, migration thứ hai dừng với:

`ERROR: trigger "trg_roles_updated_at" for relation "roles" already exists`

Ngoài ra, `supabase db reset` yêu cầu local stack đã được `supabase start`.

## Cách sửa v1.7

Không xóa tay migration nữa. Chạy:

```powershell
cd D:\HOMETECHVN
npm run t1:repair
```

Script sẽ:

1. kiểm tra/tạo `supabase/config.toml`;
2. tự chuyển migration legacy đã biết ra thư mục backup;
3. xác nhận CHỈ còn đúng 3 migration T1;
4. nếu gặp migration lạ -> DỪNG, không xóa;
5. clean local stack bằng `supabase stop --no-backup`;
6. chạy `supabase start`;
7. chạy `supabase db reset --local`;
8. tự chạy `t1_verify.sql` qua Postgres trong Docker;
9. kiểm tra marker `T1 FINAL CORE CHECKS: PASS`;
10. chạy `supabase status`;
11. lưu snapshot kết quả.

Script chỉ thao tác local Docker/Supabase. Không reset remote.

## 3 migration hợp lệ

- 20260829143948_t1_core_foundation.sql
- 20260829144121_t1_security_hardening.sql
- 20260829150727_t1_private_security_and_rls_performance.sql
