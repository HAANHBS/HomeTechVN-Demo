# T1 ACCEPTANCE — HomeTechVN

## Điều kiện PASS

### 1. Local reproducibility
```powershell
npm install
npx supabase start
npx supabase db reset
```

Kết quả: không lỗi migration/seed.

### 2. Core tables
Phải có:
- profiles
- roles
- permissions
- role_permissions
- settings
- audit_logs
- sequence_counters

### 3. Auth
- Tạo Auth user -> tự tạo `profiles`.
- Profile mới `is_active=false`.
- Profile mới không có role.
- Bootstrap Admin -> active + role admin.
- Inactive user không được `has_permission()`.

### 4. RLS
RLS phải bật cho mọi bảng public T1.

### 5. Security
- Không có secret trong repository.
- Secret Key không dùng trong browser.
- Profile không tự nâng quyền.
- Audit log không sửa/xóa trực tiếp từ authenticated client.

### 6. Role
5 role:
- admin
- manager
- sales
- technician
- cashier

### 7. Generator
Trong transaction test:
- `next_simple_code('customer','CUS',6)` tạo dạng `CUS-000001`.
- `next_daily_code('repair','SRV',date)` tạo dạng `SRV-YYMMDD-0001`.
- Hai lần gọi liên tiếp không trùng.

### 8. Sổ cấu hình
`T1_ACCOUNT_CONFIG_REGISTER.md` phải được điền các trường:
- môi trường;
- tài khoản;
- Project Ref;
- Region;
- URL;
- nơi lưu secret;
- Auth settings;
- migration result;
- lỗi/cách sửa.

## Kết luận

```text
T1 COMPLETE chỉ khi:
LOCAL PASS
REMOTE PASS
AUTH PASS
RLS PASS
ROLE PASS
AUDIT PASS
SEQUENCE PASS
CONFIG REGISTER UPDATED
NO SECRET LEAK
```
