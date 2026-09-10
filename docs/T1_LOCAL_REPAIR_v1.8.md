# HomeTechVN T1 — Local Repair v1.8

## Lỗi v1.7

`spawnSync npx.cmd EINVAL`

Nguyên nhân: wrapper Node.js gọi trực tiếp `npx.cmd` bằng `spawnSync` trên Windows.
Đây là lỗi wrapper, không phải Supabase.

## Sửa v1.8

- Bỏ wrapper Node trên Windows.
- `npm run t1:repair` gọi trực tiếp Windows PowerShell.
- PowerShell resolve `npx.cmd` trước `npx`.
- Chính PowerShell thực thi `npx.cmd supabase ...`, giống môi trường đã chạy thành công trên máy HomeTechVN.
- Script tự:
  1. init nếu thiếu `config.toml`;
  2. backup migration legacy;
  3. chặn migration lạ;
  4. stop local stack;
  5. start local stack;
  6. reset local DB;
  7. tự chạy SQL verify bằng `docker exec ... psql`;
  8. chạy `supabase status`;
  9. ghi snapshot.

## Chạy

```powershell
cd D:\HOMETECHVN
npm run t1:repair
```

Không cần chạy `supabase start` hoặc `db reset` thủ công trước.
