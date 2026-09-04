# HomeTechVN — T2 MASTER CHECKLIST

## Scope

T2 = CRM khách hàng + Thiết bị khách hàng + Ghi chú CRM + giao diện React cơ bản.

## A. Database / Migration

| Check | Hạng mục | Kết quả |
|---|---|---|
| [x] | Không sửa 3 migration T1 đã khóa | PASS |
| [x] | `customers` | PASS remote |
| [x] | `customer_devices` | PASS remote |
| [x] | `customer_notes` | PASS remote |
| [x] | `CUS-000001` generator | PASS + rollback |
| [x] | `DEV-000001` generator | PASS + rollback |
| [x] | SĐT không UNIQUE | PASS |
| [x] | SĐT `+84 ...` -> `0...` | PASS |
| [x] | Email lowercase/trim | PASS |
| [x] | Serial indexed, không UNIQUE | PASS |
| [x] | customer/device code immutable | PASS |
| [x] | Audit INSERT/UPDATE | PASS |
| [x] | `crm.device_types` 12 loại mặc định | PASS |
| [x] | Loại thiết bị cấu hình qua `settings` | PASS |
| [x] | Insert types cho code là optional | PASS |

## B. RLS / Permission

| Check | Hạng mục | Kết quả |
|---|---|---|
| [x] | RLS 3/3 bảng CRM | PASS |
| [x] | `anon` không có table access | PASS |
| [x] | UID không profile thấy 0 row | PASS |
| [x] | UID không profile INSERT bị 42501 | PASS |
| [x] | Admin CRUD T2 theo quyền | PASS |
| [x] | Sales tạo/sửa khách + thiết bị + note | PASS |
| [x] | Technician xem khách, sửa thiết bị | PASS |
| [x] | Technician không sửa khách | PASS (0 rows) |
| [x] | Cashier chỉ xem CRM/device | PASS |
| [x] | Sales/Technician chỉ đọc `crm.device_types`, không mở toàn bộ settings | PASS |

## C. Security / Advisor

| Check | Hạng mục | Kết quả |
|---|---|---|
| [x] | Security Advisor sau T2 | Không có cảnh báo T2 mới |
| [x] | `private.sequence_counters` no-policy | ACCEPT từ T1 |
| [~] | Leaked password protection | DEFERRED PRE-PUBLIC |
| [x] | Performance Advisor | Chỉ unused-index INFO do DB mới |

## D. App T2

| Check | Hạng mục | Kết quả |
|---|---|---|
| [x] | React + TypeScript + Vite + Tailwind source | CREATED |
| [x] | Supabase publishable key frontend only | PASS |
| [x] | Login email/password | IMPLEMENTED |
| [x] | Profile active + role + permissions | IMPLEMENTED |
| [x] | Danh sách/tìm khách hàng | IMPLEMENTED |
| [x] | Thêm/sửa khách hàng | IMPLEMENTED |
| [x] | Hồ sơ khách hàng | IMPLEMENTED |
| [x] | Danh sách/tìm thiết bị | IMPLEMENTED |
| [x] | Thêm/sửa thiết bị theo permission | IMPLEMENTED |
| [x] | Ghi chú CRM thêm/sửa | IMPLEMENTED |
| [x] | Không có chức năng DELETE vật lý | PASS |
| [~] | Production build trong môi trường tạo artifact | BLOCKED BY ENV: npm registry DNS timeout; syntax 10/10 + stub structural typecheck PASS, nhưng chưa được gọi production-build PASS |
| [x] | Windows local DB reset + app install/build | Windows T2 acceptance was completed; T16 regenerates and verifies package locks | PASS |

## E. Acceptance

T2 chỉ được đánh dấu COMPLETE khi:

1. Remote DB/RLS tests PASS.
2. App production build PASS.
3. Windows `npm run t2:verify` trả đủ:
   - `T2 LOCAL REPRODUCIBILITY: PASS`
   - `T2 FINAL CORE CHECKS: PASS`
   - `T2 APP BUILD: PASS`
