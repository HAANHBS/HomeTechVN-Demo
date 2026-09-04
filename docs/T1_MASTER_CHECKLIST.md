# T1 MASTER CHECKLIST — HomeTechVN

> Quy ước:
> - `[ ]` chưa làm
> - `[x]` đã làm
> - Mỗi mục có yêu cầu ghi chú phải cập nhật `T1_ACCOUNT_CONFIG_REGISTER.md`.
> - Tuyệt đối không ghi password/key/token thật vào tài liệu.

---

## A. Chuẩn bị máy phát triển

| Check | Việc | Giá trị cần ghi | Kết quả |
|---|---|---|---|
| [x] | Xác nhận máy dùng phát triển chính | HAANH-MAYCHU — Windows 10 Pro 10.0.19045 build 19045, 64-bit | PASS |
| [x] | Kiểm tra ổ đĩa còn trống | C: 102.1 GB free; D: 55.77 GB free | PASS |
| [x] | Cài Git | 2.45.1.windows.1 — C:\\Program Files\\Git\\cmd\\git.exe | PASS |
| [x] | Cài Node.js/npm | Node v24.18.0; npm 11.16.0 | PASS |
| [x] | Cài Docker Desktop hoặc runtime tương thích | Docker Desktop 4.88.1; Engine 29.7.2 | PASS |
| [x] | Bật virtualization nếu Docker yêu cầu | Docker Linux engine đã khởi động thành công | PASS |
| [x] | Kiểm tra Docker chạy | Client/Server API 1.55; server linux/amd64 | PASS |
| [x] | Cài Supabase CLI dưới dạng project dependency | `supabase@2.116.0` pinned; T16 dependency-lock gate closes transitive lock debt | PASS |
| [x] | Kiểm tra `npx supabase --version` | 2.116.0 | PASS |
| [x] | Ghi snapshot môi trường | T1_ENV_20260829_185832.txt — 29/08/2026 | PASS |

### Ghi chú A

> **Kết quả kiểm tra 28/08/2026:** Git, Node/npm, Docker Desktop/Engine và Supabase CLI đều chạy. Chưa đóng T1.1 vì output cũ chưa thu thập tên máy, Windows build, RAM, dung lượng ổ đĩa và chưa chứng minh Supabase CLI là dependency của chính project.

- Không cần ghi mật khẩu Windows.
- Nếu phần mềm đã cài sẵn, vẫn ghi version và ngày kiểm tra.

---

## B. Git / mã nguồn

| Check | Việc | Ghi chú cần lưu |
|---|---|---|
| [ ] | Xác định repository HomeTechVN | URL repo |
| [ ] | Xác định private/public | Khuyến nghị Private |
| [ ] | Ghi GitHub account sử dụng | Chỉ email/username, không password |
| [ ] | Bật 2FA cho GitHub | Có/Không |
| [ ] | Kiểm tra `.gitignore` | PASS |
| [ ] | Kiểm tra `.env*` không bị commit | PASS |
| [ ] | Commit T1 source | Commit hash |
| [ ] | Sau nghiệm thu tạo tag | `T1-v1.0` |

---

## C. Tạo/kiểm tra tài khoản Supabase

| Check | Việc | Giá trị cần ghi |
|---|---|---|
| [ ] | Xác định email đăng nhập Supabase | Email |
| [ ] | Ghi ngày tạo tài khoản hoặc ngày kiểm tra | Date |
| [ ] | Bật 2FA nếu tài khoản hỗ trợ | Có/Không |
| [ ] | Ghi phương thức khôi phục tài khoản | Không ghi mã recovery |
| [ ] | Tạo/kiểm tra Organization | Organization name |
| [ ] | Tạo project | Project name |
| [ ] | Ghi Project Ref | Project Ref |
| [ ] | Ghi Region | Region |
| [ ] | Ghi Project URL | `https://<ref>.supabase.co` |
| [ ] | Ghi nơi lưu Database Password | Tên password manager/ổ mã hóa — KHÔNG ghi mật khẩu |
| [ ] | Lấy Publishable Key | Chỉ ghi trạng thái + nơi lấy |
| [ ] | Ghi nơi lưu Secret Key | KHÔNG ghi key |
| [ ] | Kiểm tra billing plan | Free |
| [ ] | Chụp/ghi ngày xác nhận project hoạt động | Date |

### Quy tắc key
- Publishable key: được dùng trong browser/PWA.
- Secret key: backend only, không đưa vào React/Vite.
- Không copy Secret Key vào chat, email, tài liệu, Git.

---

## D. Supabase Local

| Check | Việc | Kết quả |
|---|---|---|
| [ ] | `npm install` | PASS |
| [ ] | `npx supabase init` nếu cần | PASS |
| [ ] | Kiểm tra `supabase/config.toml` | Có |
| [ ] | `npx supabase start` | PASS |
| [ ] | Ghi Studio URL local | URL |
| [ ] | Ghi API URL local | URL |
| [ ] | Không ghi local service-role key vào tài liệu | PASS |
| [ ] | `npx supabase db reset` | PASS |
| [ ] | Migration T1 chạy hết | PASS |
| [ ] | Seed chạy hết | PASS |

---

## E. Database Foundation

| Check | Kiểm tra | PASS |
|---|---|---|
| [ ] | `roles` tồn tại | |
| [ ] | `permissions` tồn tại | |
| [ ] | `role_permissions` tồn tại | |
| [ ] | `profiles` tồn tại | |
| [ ] | `settings` tồn tại | |
| [ ] | `audit_logs` tồn tại | |
| [ ] | `sequence_counters` tồn tại | |
| [ ] | Tất cả bảng public T1 bật RLS | |
| [ ] | Trigger `updated_at` hoạt động | |
| [ ] | Trigger tạo profile từ `auth.users` hoạt động | |
| [ ] | User mới mặc định inactive | |
| [ ] | User mới không tự có Admin | |
| [ ] | Audit trigger hoạt động | |
| [ ] | Simple code generator hoạt động | |
| [ ] | Daily code generator hoạt động | |
| [ ] | Timezone mặc định Asia/Bangkok | |

---

## F. Role / Permission

| Check | Role | PASS |
|---|---|---|
| [ ] | admin | |
| [ ] | manager | |
| [ ] | sales | |
| [ ] | technician | |
| [ ] | cashier | |

| Check | Kiểm tra | PASS |
|---|---|---|
| [ ] | Admin có toàn quyền đã seed | |
| [ ] | Manager không có user.manage | |
| [ ] | Sales không xem giá vốn/lợi nhuận | |
| [ ] | Technician có quyền repair/checklist cần thiết | |
| [ ] | Cashier có payment permission | |
| [ ] | Permission code không trùng | |

---

## G. Auth Remote

| Check | Cấu hình | Ghi chú |
|---|---|---|
| [x] | Tạo Admin đầu tiên | 40439a5d-205a-4707-aec4-0c98410b63ef |
| [x] | Profile tự sinh | PASS |
| [x] | Chạy Bootstrap Admin | PASS |
| [x] | Admin `is_active=true` | PASS |
| [x] | Admin role đúng | PASS |
| [ ] | Login Admin thành công | PASS |
| [~] | Tắt public sign-up sau bootstrap | DEFERRED — thực hiện trước khi public |
| [~] | Tắt anonymous sign-in | DEFERRED — kiểm tra trước khi public |
| [x] | Confirm Email được quyết định và ghi lại | DEV: không khóa cứng; review lại trước public |
| [ ] | Site URL/Redirect URL được ghi lại | URL |
| [ ] | Test user inactive không truy cập nghiệp vụ | PASS |

---

## H. Migrations Remote

| Check | Việc | Kết quả |
|---|---|---|
| [ ] | `supabase login` | PASS |
| [ ] | `supabase link --project-ref ...` | PASS |
| [ ] | Ghi Project Ref đã link | Project Ref |
| [ ] | `supabase db push --dry-run` | PASS |
| [ ] | Review SQL trước push | PASS |
| [ ] | `supabase db push` | PASS |
| [ ] | Không chạy seed demo lên production | PASS |
| [ ] | Verify remote tables | PASS |
| [ ] | Verify remote RLS | PASS |

---

## I. Security

| Check | Kiểm tra | PASS |
|---|---|---|
| [ ] | Không có Secret Key trong source | |
| [ ] | Không có DB Password trong source | |
| [ ] | Không có token trong docs | |
| [ ] | `.env.local`/`.env` bị ignore | |
| [ ] | Publishable Key chỉ có quyền qua RLS | |
| [ ] | RLS bật toàn bộ bảng public T1 | |
| [ ] | `settings.is_sensitive=true` không được chứa `value` | |
| [ ] | User inactive không được cấp permission | |
| [ ] | User không tự sửa role/is_active | |
| [ ] | Audit log không cho client sửa/xóa | |

---

## J. Nghiệm thu

| Check | Tiêu chí | PASS |
|---|---|---|
| [ ] | Chạy `t1_verify.sql` local | |
| [ ] | Chạy verify remote | |
| [ ] | Admin đăng nhập | |
| [ ] | Tạo user thử | |
| [ ] | Profile auto-create | |
| [ ] | User thử inactive | |
| [ ] | Kích hoạt user + gán role test | |
| [ ] | Permission test đúng | |
| [ ] | Audit log có record | |
| [ ] | Generate mã không trùng | |
| [ ] | Sổ cấu hình đã cập nhật | |
| [ ] | Không còn secret trong tài liệu | |
| [ ] | Commit Git | |
| [ ] | Tag `T1-v1.0` | |

**T1 chỉ COMPLETE khi toàn bộ mục J PASS.**
