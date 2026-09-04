# T1 ACCOUNT & CONFIG REGISTER
## HomeTechVN — Sổ cấu hình hệ thống

> File này dùng để biết **đã cài gì, dùng tài khoản nào, cấu hình nằm ở đâu**.
>
> **CẤM ghi password, Secret Key, database password, recovery code hoặc token thật vào file này.**
> Với thông tin bí mật chỉ ghi: `Nơi lưu: <tên password manager / ổ mã hóa / vị trí quản lý bí mật>`.

---

## 1. Thông tin checkpoint

| Trường | Giá trị |
|---|---|
| Project | HomeTechVN |
| Stage | T1 Database + Auth |
| Version | T1 v1.0 |
| Ngày bắt đầu | 28/08/2026 |
| Ngày nghiệm thu | |
| Người thực hiện | |
| Máy thực hiện chính | |
| Git commit | |
| Git tag | |

---

## 2. Máy phát triển

| Trường | Giá trị |
|---|---|
| Computer name | HAANH-MAYCHU |
| Windows edition/version | Microsoft Windows 10 Pro — 10.0.19045 build 19045 — 64-bit |
| CPU | |
| RAM | 15.91 GB |
| Disk free tại ngày T1 | C: 102.1 GB / 295.15 GB; D: 55.77 GB / 165.51 GB |
| Git version | 2.45.1.windows.1 |
| Node version | v24.18.0 |
| npm version | 11.16.0 |
| Docker version | Docker Engine 29.7.2; Docker Desktop 4.88.1 |
| Supabase CLI version | 2.116.0 |
| Ngày kiểm tra | 28/08/2026 |
| Ghi chú lỗi/cách xử lý | Docker client/server hoạt động; context desktop-linux. Cần bổ sung Computer name, Windows edition/version/build, RAM và Disk free trước khi đóng T1.1. |

---

## 3. GitHub

| Trường | Giá trị |
|---|---|
| GitHub username | |
| Email dùng GitHub | |
| Repository URL | |
| Repository visibility | Private / Public |
| 2FA | ON / OFF |
| Ngày kiểm tra | |
| Nơi lưu thông tin khôi phục | |
| Ghi chú | |

---

## 4. Supabase Account

| Trường | Giá trị |
|---|---|
| Email đăng nhập Supabase | |
| Organization | maytinhhaanhbs@gmail.com's Org |
| 2FA | ON / OFF |
| Recovery method | |
| Nơi lưu recovery code | KHÔNG ghi code |
| Ngày tạo/kiểm tra | |
| Ghi chú | |

---

## 5. Supabase Project

| Trường | Giá trị |
|---|---|
| Project name | HomeTechVN |
| Project Ref | puqvbenyenwemfbsqpfd |
| Region | ap-southeast-1 |
| Plan | Free |
| Project URL | https://puqvbenyenwemfbsqpfd.supabase.co |
| Database host | db.puqvbenyenwemfbsqpfd.supabase.co |
| Database port | |
| Database name | postgres |
| Database user | postgres |
| Nơi lưu Database Password | |
| Ngày tạo | 29/08/2026 |
| Ghi chú | |

---

## 6. API Keys

| Thành phần | Giá trị được phép ghi |
|---|---|
| Publishable Key | Đã tạo và đang hoạt động |
| Publishable Key dùng ở | Frontend/PWA |
| Secret Key | Connector hiện không cung cấp quyền đọc secret key |
| Nơi lưu Secret Key | PENDING — sẽ lưu bằng module khởi tạo/cấu hình hệ thống ở giai đoạn sau |
| Legacy anon key còn dùng? | NO/YES |
| Legacy service_role còn dùng? | NO/YES |
| Ngày kiểm tra key | |
| Ghi chú rotate key | |

---

## 7. Environment Variables

| Biến | Scope | Giá trị/ghi chú |
|---|---|---|
| `VITE_SUPABASE_URL` | Frontend | Project URL |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | Frontend | Publishable key |
| `SUPABASE_SECRET_KEY` | Backend only | Chỉ ghi nơi lưu |
| `APP_TIMEZONE` | App | Asia/Bangkok |
| `APP_ENV` | App | local / dev / production |

### Vị trí file thực tế
| File | Có commit? | Ghi chú |
|---|---|---|
| `.env.example` | YES | Không có secret |
| `.env.local` | NO | Local developer |
| Worker secrets | NO | Tạo ở backend khi tới giai đoạn Worker |

---

## 8. Auth Configuration

| Cấu hình | Giá trị |
|---|---|
| Allow new users to sign up | DEV: giữ nguyên/cho phép; review trước public |
| Allow anonymous sign-ins | DEV: không dùng trong app; review cấu hình trước public |
| Email signup | |
| Confirm Email | DEV: không khóa cứng; review trước public |
| Site URL | |
| Redirect URLs | |
| Admin User UUID | 40439a5d-205a-4707-aec4-0c98410b63ef |
| Admin email | hometechvn@outlook.com |
| Admin role | admin |
| Admin activated at | 29/08/2026 |
| Ghi chú | Profile auto-created: PASS; is_active=true; role=admin; permission verification PASS; audit INSERT/UPDATE PASS |

---

## 9. Supabase Local

| Trường | Giá trị |
|---|---|
| Local API URL | Chưa tạo local stack |
| Local Studio URL | |
| Local DB URL | **Không ghi password nếu có** |
| `supabase init` date | |
| `supabase start` PASS | |
| `supabase db reset` PASS | |
| Migration count | |
| Seed PASS | |
| Verify PASS | |
| Ghi chú lỗi | |

---

## 10. Migration Remote

| Trường | Giá trị |
|---|---|
| Linked Project Ref | |
| Link date | |
| Dry-run result | |
| Push date | |
| Migration version | |
| Verify remote result | |
| Ghi chú lỗi/cách sửa | |

---

## 11. Security Record

| Check | Trạng thái |
|---|---|
| Secret không nằm trong Git | |
| DB password không nằm trong Git | |
| `.env.local` ignored | |
| RLS enabled | |
| Public signup disabled sau bootstrap | |
| Anonymous sign-in disabled | |
| User mới inactive | |
| Role không tự gán | |
| Audit enabled | |

---

## 12. Nhật ký lỗi/cách xử lý

| Ngày | Bước | Lỗi | Nguyên nhân | Cách sửa | Kết quả |
|---|---|---|---|---|---|
| | | | | | |

---

## 13. Nhật ký thay đổi cấu hình

| Ngày | Thành phần | Giá trị cũ | Giá trị mới | Lý do | Người thực hiện |
|---|---|---|---|---|---|
| | | | | | |

---

## 14. Nơi lưu thông tin nhạy cảm

| Loại | Nơi lưu | Người có quyền |
|---|---|---|
| Supabase password | | |
| Database password | | |
| Supabase Secret Key | | |
| GitHub recovery | | |
| Backup encryption key | Chưa triển khai T1 | |
