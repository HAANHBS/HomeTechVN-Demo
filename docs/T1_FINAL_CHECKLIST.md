# HomeTechVN — T1 FINAL CHECKLIST

## A. Remote Supabase — đã kiểm tra trực tiếp

| Check | Hạng mục | Trạng thái |
|---|---|---|
| [x] | Project ACTIVE_HEALTHY | PASS |
| [x] | 3 migration T1 tồn tại | PASS |
| [x] | 5 system roles | PASS |
| [x] | 46 permissions | PASS |
| [x] | Role-permission mapping | PASS |
| [x] | Admin Auth + Profile | PASS |
| [x] | Admin permissions | PASS |
| [x] | RLS core tables | PASS |
| [x] | Fake/non-member UID không thấy profiles/settings | PASS |
| [x] | Admin UID thấy profiles/settings đúng quyền | PASS |
| [x] | Generator CUS | PASS |
| [x] | Generator SRV daily | PASS |
| [x] | Generator test rollback | PASS |
| [x] | Public SECURITY DEFINER RPC warnings đã xử lý | PASS |
| [x] | RLS initPlan performance warnings đã xử lý | PASS |
| [x] | Missing FK indexes đã xử lý | PASS |
| [x] | `sequence_counters` chuyển private schema | PASS |
| [x] | Trigger bảo vệ privilege chuyển SECURITY INVOKER | PASS |

## B. Advisor còn lại — chấp nhận có chủ đích

| Advisor | Quyết định |
|---|---|
| private.sequence_counters: RLS no policy | FIXED T16 — explicit deny-all policy + service_role direct table grants revoked |
| Leaked Password Protection Disabled | PLAN LIMITATION — Supabase feature requires Pro+; current project is Free. Mandatory if plan is upgraded before production. |
| Unused indexes | ACCEPT — database mới chưa có đủ workload để index có usage statistics |

## C. Local source sync

Migration local phải có đúng version:
- `20260829143948_t1_core_foundation.sql`
- `20260829144121_t1_security_hardening.sql`
- `20260829150727_t1_private_security_and_rls_performance.sql`

## D. Một bước cuối trên máy Windows

Chạy tại `D:\HOMETECHVN`:

```powershell
npx supabase db reset
```

Sau đó mở local Studio SQL Editor và chạy:

`supabase/tests/t1_verify.sql`

Nếu hiện:

`T1 FINAL CORE CHECKS: PASS`

thì đánh dấu:

`T1 LOCAL REPRODUCIBILITY = PASS`

## E. Điều kiện đóng T1

- Remote: PASS
- Local db reset: PASS
- t1_verify.sql: PASS
- PRE_PUBLIC security: chưa cần ở DEV
