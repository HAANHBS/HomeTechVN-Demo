# HomeTechVN — T1 Status

## T1.1 Environment Check — 28/08/2026

### PASS
- Git 2.45.1.windows.1
- Node.js v24.18.0
- npm 11.16.0
- Docker Engine 29.7.2
- Docker Desktop 4.88.1
- Docker Linux engine chạy thành công
- Supabase CLI 2.116.0
- npx 11.16.0

### Chưa đóng T1.1
Cần script mới ghi thêm:
- Computer name
- Windows edition/version/build
- RAM
- Disk free
- `npm ls supabase --depth=0`

### Lệnh chạy
```powershell
.\scripts\check-prerequisites.ps1
```

Snapshot tự lưu vào `docs/snapshots/` và thư mục này không commit Git.

## T1.1 update — 29/08/2026
- Machine: HAANH-MAYCHU
- Windows 10 Pro 10.0.19045 build 19045, 64-bit
- RAM: 15.91 GB
- Disk: C free 102.1 GB; D free 55.77 GB
- Supabase CLI project dependency: PASS — root pins `supabase@2.116.0`; T16 dependency-lock gate makes transitive resolution reproducible.
- `check-prerequisites.ps1` replaced with v1.2 implementation that does not use Start-Process for npm/npx.


## T1.2 Supabase Project — 29/08/2026

### PASS
- Project HomeTechVN đang ACTIVE_HEALTHY
- Organization: maytinhhaanhbs@gmail.com's Org
- Plan: Free
- Region: ap-southeast-1
- Project Ref: puqvbenyenwemfbsqpfd
- Project URL: https://puqvbenyenwemfbsqpfd.supabase.co
- Database host: db.puqvbenyenwemfbsqpfd.supabase.co
- PostgreSQL 17.6.1.166
- T1 core migration: PASS
- T1 seed: PASS
- 7 core tables: PASS
- 5 roles: PASS
- 46 permissions: PASS
- 145 role-permission mappings: PASS
- RLS: PASS trên 7/7 bảng
- Security hardening: PASS

### PENDING
- Auth user/admin bootstrap: auth.users = 0
- Auth toggles: connector hiện không có action chỉnh signup/anonymous/email confirm
- Secret Key/recovery codes: connector không expose giá trị
- Security advisor còn cảnh báo có chủ đích cho các SECURITY DEFINER helper; cần refactor trước production


## T1.2 Auth Bootstrap — 29/08/2026

### PASS
- Auth user detected: hometechvn@outlook.com
- Email verified: PASS
- Profile auto-create trigger: PASS
- Initial profile inactive/no-role behavior: PASS
- Admin activation: PASS
- Admin role assignment: PASS
- `current_role_code()` = admin
- `is_admin()` = true
- `has_permission('user.manage')` = true
- `has_permission('role.manage')` = true
- `has_permission('settings.manage')` = true
- `has_permission('audit.view')` = true
- Audit profile INSERT: PASS
- Audit profile UPDATE: PASS

### Remaining before T1 COMPLETE
- Review/configure Auth toggles (public signup, anonymous sign-in, email confirmation) in Dashboard because current connector does not expose write actions for these settings.
- Final local/remote source migration synchronization and final security advisor review.


## T1 Auth Configuration Decision — DEV MODE — 29/08/2026

Quyết định dự án:
- Không khóa public signup trong giai đoạn phát triển nội bộ.
- Không coi Auth production hardening là blocker của T1.
- Hệ thống vẫn bảo vệ nghiệp vụ bằng:
  - profile mới mặc định `is_active = false`;
  - profile mới không có role;
  - RLS bật trên toàn bộ bảng T1;
  - chỉ Admin mới được kích hoạt/gán role.
- Trước khi public hệ thống phải chạy checklist `PRE_PUBLIC_AUTH_SECURITY`.

Lý do:
- Hiện chỉ có một người phát triển/test.
- Việc bật/tắt signup/confirm email/anonymous sign-in có thể cấu hình lại về sau.
- Không cần làm phức tạp luồng DEV sớm.

Trạng thái:
- Auth hardening production: DEFERRED TO PRE-PUBLIC.
- T1 không bị chặn bởi mục này.


## T1.3 Migration Sync + Security/Performance — 29/08/2026

### REMOTE PASS
- Remote migration history: 3/3 synchronized versions
- Private security schema: PASS
- Public SECURITY DEFINER RPC exposure: FIXED
- RLS initPlan performance warnings: FIXED
- FK indexes: FIXED
- Admin RLS simulation: PASS
- Unauthorized/fake UID RLS simulation: PASS
- Code generators: PASS + rollback
- Security Advisor remaining items are documented/accepted for DEV
- Performance Advisor remaining items are unused-index informational notices only

### LOCAL SOURCE
- Migration filenames now match remote history.
- `t1_verify.sql` updated for final private/public schema.
- Final local `npx supabase db reset` still needs to be run on HAANH-MAYCHU because ChatGPT cannot execute on the user's D: drive.

T1 Remote Foundation: COMPLETE.
T1 Local Reproducibility was subsequently accepted on Windows; this historical blocker is CLOSED.


## T1 local wrapper fix — v1.8

- v1.7 Node spawnSync wrapper: REJECTED on Windows (`npx.cmd EINVAL`).
- v1.8 Windows PowerShell runner: current implementation.
- Broken Node runner renamed `.DISABLED`.
- `npm run t1:repair` now launches PowerShell directly.


## T1 local port conflict fix — v1.9

Windows runtime confirmed:
- all 3 T1 migrations: applied successfully
- seed.sql: applied successfully
- failure occurs only when Inbucket tries to publish TCP 54324

v1.9:
- detects bindability of `[inbucket].port`
- auto-moves Inbucket web UI to a free port >=54330
- never kills unrelated process using 54324
- backs up config.toml before changing it


## T1 local DB-only correction — v2.0

- v1.9 `[inbucket]` config assumption: REJECTED.
- Official CLI DB-only command selected: `supabase db start`.
- T1 verifier no longer starts auxiliary local services.
- Port 54324/Mailpit cannot block T1 database reproducibility.


## T1 verifier correction — v2.1

Runtime evidence from HAANH-MAYCHU:
- local project_id = HOMETECHVN
- database container = running
- local db reset had completed before verify
- PostgreSQL emitted `NOTICE: T1 FINAL CORE CHECKS: PASS`
- v2.0 wrapper incorrectly treated NOTICE/stderr as terminating error

v2.1:
- fixes native psql stderr handling
- requires psql exit code 0 AND PASS marker
- adds non-destructive `npm run t1:finalize`


# T1 FINAL ACCEPTANCE — 29/08/2026

## STATUS

**T1 — DATABASE + AUTH: COMPLETE**

Runtime acceptance evidence from Windows machine:

```text
T1 LOCAL REPRODUCIBILITY: PASS
T1 FINAL CORE CHECKS: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T1_LOCAL_VERIFY_20260829_231834.txt
```

## Accepted runtime checks

- Windows local Supabase CLI environment: PASS
- Local database container running: PASS
- Migration replay: PASS
- Seed replay: PASS
- RLS core verification: PASS
- Roles/permissions verification: PASS
- Code generator verification: PASS
- Local reproducibility from migrations + seed: PASS
- Remote Supabase T1 foundation: PASS
- Admin bootstrap: PASS
- Security hardening: PASS
- Performance fixes: PASS

## Deferred by design

These are not T1 blockers during DEV:
- Production Auth lockdown
- Leaked password protection
- Final SMTP/auth production configuration
- Public deployment hardening

These items remain tracked in:
`docs/PRE_PUBLIC_AUTH_SECURITY.md`

## Checkpoint rule satisfied

Code -> Test -> Checklist -> Fix -> Acceptance -> Checkpoint backup

T1 is now locked as the baseline for T2.
