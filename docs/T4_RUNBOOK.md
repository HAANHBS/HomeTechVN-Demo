# HomeTechVN — T4 RUNBOOK

## Install candidate

Giải nén T4 candidate đè vào thư mục dự án hiện tại:

```text
D:\HOMETECHVN
```

Không xóa `.env.local` đang hoạt động. T4 ZIP không đóng gói file đó.

## Verify

Chạy duy nhất:

```powershell
cd D:\HOMETECHVN
npm run t4:verify
```

Verifier tự thực hiện:
1. kiểm tra chính xác 11 migration T1–T4;
2. `supabase stop --no-backup`;
3. `supabase db start`;
4. `supabase db reset --local`;
5. chạy `supabase/tests/t4_verify.sql`;
6. kiểm tra lifecycle Sales/Payment/Inventory/RLS;
7. `npm --prefix app install --no-audit --no-fund`;
8. `npm --prefix app run build` (`tsc -b && vite build`);
9. ghi snapshot trong `docs/snapshots`.

## Acceptance

Chỉ PASS khi có đủ:

```text
T4 LOCAL REPRODUCIBILITY: PASS
T4 FINAL CORE CHECKS: PASS
T4 APP BUILD: PASS
```

Nếu fail, gửi output từ dòng `=== HomeTechVN T4` đến `[T4 FAIL]`.
