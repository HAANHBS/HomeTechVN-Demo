# HomeTechVN Management — T19 Universal QR Candidate

Current candidate: `0.19.0-t19.0`. T19 adds authenticated QR issue/scan/revoke for 14 business resource types and CREATE / VIEW / EDIT / PAY intents. Migrations #1–#36 remain locked; T19 adds migration #37 only.

Windows acceptance:

```powershell
cd D:\HOMETECHVN
npm run t19:verify
```

See `docs/T19_UNIVERSAL_QR_OPERATIONS.md` and `docs/T19_RUNBOOK.md`. Payment QR is a sandbox workflow opener, not confirmation from a real bank or payment provider.

---

# Historical baseline — T1 v1.0
## Database + Auth Foundation

Mục tiêu T1:
- Thiết lập môi trường phát triển Supabase local.
- Tạo project Supabase remote.
- Tạo Auth foundation.
- Tạo Role / Permission / Profile / Settings / Audit / Sequence foundation.
- Bật RLS ngay từ đầu.
- Có checklist và sổ cấu hình để sau này không phải tìm lại thông tin.
- Có bộ kiểm thử SQL để nghiệm thu T1.
- Chưa triển khai CRM/Device/Sales/Repair ở T1.

## Nguyên tắc bắt buộc

1. Không ghi password, database password, Secret Key hoặc token thật vào Git.
2. Trong checklist chỉ ghi **nơi đang lưu secret**, không ghi secret.
3. Frontend chỉ dùng:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_PUBLISHABLE_KEY`
4. `SUPABASE_SECRET_KEY` chỉ dùng ở backend/Worker/automation an toàn.
5. Tất cả bảng public nghiệp vụ phải bật RLS.
6. Tài khoản nhân viên không tự gán role.
7. User mới tạo mặc định `is_active = false`, Admin phải kích hoạt.
8. Không xóa dữ liệu nghiệp vụ để "sửa sai"; về sau dùng trạng thái/audit.
9. Mỗi bước cài đặt/tạo tài khoản phải ghi vào `docs/T1_ACCOUNT_CONFIG_REGISTER.md`.
10. T1 chỉ được COMPLETE khi chạy đạt `supabase/tests/t1_verify.sql`.

## Thứ tự triển khai

### Bước 1 — Đọc checklist
Mở:
- `docs/T1_MASTER_CHECKLIST.md`
- `docs/T1_ACCOUNT_CONFIG_REGISTER.md`

### Bước 2 — Kiểm tra máy Windows
PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\check-prerequisites.ps1
```

### Bước 3 — Chuẩn bị Supabase CLI
Trong thư mục dự án:

```powershell
npm install
npx supabase --version
```

Supabase CLI cần Docker-compatible runtime để chạy local.

### Bước 4 — Khởi tạo Supabase local
Nếu thư mục `supabase/` chưa có `config.toml`:

```powershell
npx supabase init
```

Sau đó:

```powershell
npx supabase start
```

Lưu URL local và các thông tin không nhạy cảm vào sổ cấu hình.

### Bước 5 — Áp migration local

```powershell
npx supabase db reset
```

Lệnh này:
1. reset database local;
2. chạy migration theo thứ tự;
3. chạy `seed.sql`.

### Bước 6 — Verify local
Mở Supabase Studio local hoặc chạy file:

`supabase/tests/t1_verify.sql`

Tất cả CHECK phải PASS.

### Bước 7 — Tạo Supabase remote project
Thực hiện theo checklist mục C trong `T1_MASTER_CHECKLIST.md`.

Không lưu Database Password hoặc Secret Key vào file tài liệu.

### Bước 8 — Link remote

```powershell
npx supabase login
npx supabase link --project-ref <PROJECT_REF>
npx supabase db push --dry-run
```

Chỉ khi dry-run đúng mới chạy:

```powershell
npx supabase db push
```

Không chạy `db reset --linked` với production.

### Bước 9 — Tạo Admin đầu tiên
1. Supabase Dashboard → Authentication → Users.
2. Tạo user Admin đầu tiên.
3. Copy User UUID.
4. Mở `docs/T1_BOOTSTRAP_FIRST_ADMIN.sql`.
5. Điền UUID vào biến được chỉ dẫn.
6. Chạy SQL.
7. Kiểm tra `profiles.is_active = true` và role `admin`.

### Bước 10 — Khóa Auth production
Sau khi có Admin:
- Tắt public signup.
- Tắt anonymous sign-in.
- User nhân viên được tạo bằng Dashboard Invite/Add User hoặc cơ chế Admin riêng ở giai đoạn sau.
- Ghi trạng thái vào sổ cấu hình.

## File quan trọng

| File | Mục đích |
|---|---|
| `docs/T1_MASTER_CHECKLIST.md` | Checklist thực hiện T1 |
| `docs/T1_ACCOUNT_CONFIG_REGISTER.md` | Sổ ghi tài khoản/cấu hình |
| `docs/T1_BOOTSTRAP_FIRST_ADMIN.sql` | Cấp quyền Admin đầu tiên |
| `docs/T1_ACCEPTANCE.md` | Nghiệm thu T1 |
| `supabase/migrations/..._t1_core.sql` | Schema T1 |
| `supabase/seed.sql` | Role, permission, setting mặc định |
| `supabase/tests/t1_verify.sql` | Bộ kiểm tra |
| `.env.example` | Tên biến môi trường, không chứa secret |
| `scripts/check-prerequisites.ps1` | Kiểm tra môi trường Windows |

## Quy tắc checkpoint

Khi nghiệm thu:

```text
T1 STATUS = COMPLETE
Migration local = PASS
Remote push = PASS
RLS = PASS
Admin login = PASS
Role/Permission = PASS
Audit = PASS
Sequence = PASS
Config register = UPDATED
Secrets = NOT COMMITTED
Git tag = T1-v1.0
```


## T1 v1.6 — Final local verification

Remote Supabase T1 has passed security/RLS/generator checks.

On the Windows development machine:

```powershell
cd D:\HOMETECHVN
npx supabase db reset
```

Then run `supabase/tests/t1_verify.sql` in the local Studio SQL Editor.

Do not mark T1 overall COMPLETE until both commands/tests pass.


## T1 FINAL CHECKPOINT

T1 runtime acceptance completed on 29/08/2026.

```text
T1 LOCAL REPRODUCIBILITY: PASS
T1 FINAL CORE CHECKS: PASS
```

T1 migrations are now LOCKED. T2 must add new migrations only.


## T2 — CRM + Customer Devices

Remote database T2 is implemented and tested. The React CRM app source is included under `app/`.

Final Windows acceptance command:

```powershell
cd D:\HOMETECHVN
npm run t2:verify
```

Do not mark T2 COMPLETE until DB reproducibility, SQL verify, and the real Vite production build all PASS.


## T2 FINAL CHECKPOINT

T2 runtime acceptance completed on 30/08/2026.

```text
T2 LOCAL REPRODUCIBILITY: PASS
T2 FINAL CORE CHECKS: PASS
T2 APP BUILD: PASS
```

T1 and T2 migration chains are now LOCKED.
T3 must add new migrations only.

## T3 — Product + Inventory candidate

T3 adds Product Catalog, stock ledger, serialized units, role-aware cost security and React inventory screens.

Remote database validation is PASS. Final Windows acceptance is intentionally not pre-marked.

Run:

```powershell
cd D:\HOMETECHVN
npm run t3:verify
```

T3 is COMPLETE only after all three runtime markers pass.


## T3 FINAL CHECKPOINT

T3 runtime acceptance completed on 30/08/2026.

```text
T3 LOCAL REPRODUCIBILITY: PASS
T3 FINAL CORE CHECKS: PASS
T3 APP BUILD: PASS
```

T1, T2 and T3 migration chains are now LOCKED.
T4 must add new migrations only.

## T4 — Sales candidate

T4 adds Sales Orders, items, payments, atomic stock issue/reversal, serialized sales, refund handling, 16-item delivery checklist and permission-based Sales UI.

Remote DB lifecycle: PASS. Windows acceptance:

```powershell
npm run t4:verify
```

T4 is not COMPLETE until local DB verification and app production build both PASS.


## T4 FINAL CHECKPOINT

T4 runtime acceptance completed on 30/08/2026.

```text
T4 LOCAL REPRODUCIBILITY: PASS
T4 FINAL CORE CHECKS: PASS
T4 APP BUILD: PASS
```

T1 through T4 migration chains are now LOCKED.
T5 must add new migrations only.


## T5 Repair candidate

T5 adds Repair intake, diagnosis, quotation, parts, QC, status history and special-state workflows.
Run `npm run t5:verify` before T5 is marked COMPLETE.


## T5 FINAL CHECKPOINT

T5 runtime acceptance completed on 30/08/2026.

```text
T5 LOCAL REPRODUCIBILITY: PASS
T5 FINAL CORE CHECKS: PASS
T5 APP BUILD: PASS
```

T1 through T5 migration chains are now LOCKED.
T6 must add new migrations only.


## T6 CANDIDATE CHECKPOINT

T6 implements the reusable Checklist Engine:

- checklist templates and versioned template items
- checklist runs and snapshot run items
- entity-aware RLS and RPC-only mutations
- Sales 16-item system template bridge
- conditional Serial requirement
- system-managed payment confirmation
- refund invalidation / automatic checklist reopening
- template management for Admin/Manager
- checklist execution for authorized operational roles

T1 through T5 migrations remain LOCKED.

T6 is accepted only after Windows returns:

```text
T6 LOCAL REPRODUCIBILITY: PASS
T6 FINAL CORE CHECKS: PASS
T6 APP BUILD: PASS
```


## T6 FINAL CHECKPOINT

T6 runtime acceptance completed on 30/08/2026.

```text
T6 LOCAL REPRODUCIBILITY: PASS
T6 FINAL CORE CHECKS: PASS
T6 APP BUILD: PASS
```

T1 through T6 migration chains are now LOCKED.
T7 must add new migrations only.


## T7 CANDIDATE CHECKPOINT

T7 adds Warranty and Warranty Claims with opaque lookup tokens,
masked server-side public lookup data, claim state-machine/history,
Sale/Repair sources, Warranty Checklist integration and RPC-only writes.

The anonymous `/w/<token>` page remains a T12 responsibility.

T1 through T6 migrations remain LOCKED.

Run:

```powershell
npm run t7:verify
```


## T7 FINAL CHECKPOINT

T7 runtime acceptance completed on 30/08/2026.

```text
T7 LOCAL REPRODUCIBILITY: PASS
T7 FINAL CORE CHECKS: PASS
T7 APP BUILD: PASS
```

T1 through T7 migration chains are now LOCKED.
T8 must add new migrations only.


## T8 CANDIDATE CHECKPOINT

T8 adds recurring Service schedules and Software/License management.

Key rules:
- Service completion creates a unique occurrence id.
- SERVICE-source warranties can be created per completed occurrence.
- License codes use `LIC-000001`.
- No plaintext license key/password is stored.
- `secret_ref` accepts only external URI references.
- T8 table mutations are RPC-only.

T1 through T7 migrations remain LOCKED.

Run:

```powershell
npm run t8:verify
```


## T8 FINAL CHECKPOINT

T8 runtime acceptance completed on 30/08/2026.

```text
T8 LOCAL REPRODUCIBILITY: PASS
T8 FINAL CORE CHECKS: PASS
T8 APP BUILD: PASS
```

T1 through T8 migration chains are now LOCKED.
T9 must add new migrations only.


## T9 CANDIDATE CHECKPOINT

T9 adds the Reminder Engine:

- rule-driven reminder generation
- Warranty / License / Service / Repair / Sales receivable / Low-stock sources
- `REM-000001`
- dedupe and generator reconciliation
- PENDING / DUE / SNOOZED / ACKNOWLEDGED / RESOLVED
- rule disable/condition-clear auto-resolution
- Admin/Manager engine management
- operational-role acknowledgement/snooze
- service-role path for future Cloudflare Worker scheduling

T9 does not send Telegram/email/in-app messages; delivery is T10.

T1 through T8 migrations remain LOCKED.

Run:

```powershell
npm run t9:verify
```


## T9 FINAL CHECKPOINT

```text
T9 LOCAL REPRODUCIBILITY: PASS
T9 FINAL CORE CHECKS: PASS
T9 APP BUILD: PASS
```

T1 through T9 migrations are LOCKED. T10 must add new migrations only.


## T10 CANDIDATE CHECKPOINT

T10 adds Notification delivery on top of T9 Reminder Engine:

- IN_APP
- Telegram staff delivery
- Email customer delivery
- Zalo customer delivery: ZBS_PHONE + OA_UID
- notification outbox and attempt logs
- dedupe / retry / stale-worker recovery
- Cloudflare Worker Cron dispatcher
- secret-reference-only provider configuration

T1 through T9 migrations remain LOCKED.

Windows acceptance:

```powershell
npm run t10:verify
```


## T10 FINAL CHECKPOINT

T10 runtime acceptance completed on 30/08/2026.

```text
T10 LOCAL REPRODUCIBILITY: PASS
T10 FINAL CORE CHECKS: PASS
T10 APP BUILD: PASS
T10 WORKER CHECK: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T10_LOCAL_VERIFY_20260830_213305.txt
```

T1 through T10 migration chains are now LOCKED.
T11 must add new migrations only.


## T11 CANDIDATE CHECKPOINT

T11 adds the permission-aware operational Dashboard and establishes the global
responsive UI/UX standard for PC, tablet and phone.

Key additions:

- Dashboard as authenticated landing page
- 7/30/90-day operational KPI snapshot
- permission-aware aggregate data
- sales trend / repair status / notification quality
- low-stock / repair / reminder attention queues
- one-tap `Tổng quan` launcher from all modules
- 44/48px touch-target baseline
- mobile input zoom protection
- focus / reduced-motion / safe-area support
- horizontal-scroll protection for every TSX table

T1 through T10 migrations remain LOCKED.

Run:

```powershell
npm run t11:verify
```


## T11 FINAL CHECKPOINT

```text
T11 LOCAL REPRODUCIBILITY: PASS
T11 FINAL CORE CHECKS: PASS
T11 RESPONSIVE UI CHECK: PASS
T11 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T11_LOCAL_VERIFY_20260830_223809.txt
```

T1 through T11 migrations are LOCKED.
The responsive PC/tablet/phone UI/UX standard remains mandatory for later stages.


## T12 CANDIDATE CHECKPOINT

T12 activates the public QR warranty flow prepared in T7.

- `/w/<opaque-token>` works without login.
- Anonymous clients only execute `warranty_public_lookup`; protected tables remain unreadable.
- Public payload masks phone/serial and excludes internal IDs/claim notes.
- Warranty staff can generate, copy, download and print QR labels.
- Cloudflare `/w/*` responses are noindex/no-referrer/no-store.
- T11 PC/tablet/phone responsive standard remains mandatory.

T1 through T11 migrations remain LOCKED.

Run:

```powershell
npm run t12:verify
```


## T12 v1.1 verifier correction

v1.1 corrects the Windows acceptance fixture for a VOID warranty by supplying the
required `void_reason`. T1–T12 migrations remain unchanged; rerun:

```powershell
npm run t12:verify
```


## T12 FINAL CHECKPOINT

T12 QR Warranty / public lookup acceptance completed on 30/08/2026.

```text
T12 LOCAL REPRODUCIBILITY: PASS
T12 FINAL CORE CHECKS: PASS
T12 RESPONSIVE UI CHECK: PASS
T12 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T12_LOCAL_VERIFY_20260830_235308.txt
```

T1 through T12 migration chains are now LOCKED.
T13 must add new migrations only.


## T13 CANDIDATE CHECKPOINT

T13 adds permission-aware operational Reports:

- custom date range up to 366 days
- 7 / 30 / 90 / 365 quick ranges
- DAY / WEEK / MONTH grouping
- Sales / cash collection / refunds / receivables
- Repair operations and technician output
- Inventory movement quantities
- Warranty / claim metrics
- Service / License exposure
- CSV export and print
- profit reporting only with `report.profit`

Profit is deliberately conservative:

- missing Sales item cost excludes the entire order from known gross profit
- missing Repair issued-part cost excludes the repair from known gross profit
- returned Repair parts are not charged to current repair cost
- coverage percentage is always exposed with known profit
- no inventory valuation, service history or license-renewal history is invented

Metric definitions are documented in:

```text
docs/T13_REPORT_DEFINITIONS.md
```

T1 through T12 migrations remain LOCKED.

Run:

```powershell
npm run t13:verify
```


## T13 FINAL CHECKPOINT

T13 Reports acceptance completed on 31/08/2026.

```text
T13 LOCAL REPRODUCIBILITY: PASS
T13 FINAL CORE CHECKS: PASS
T13 RESPONSIVE UI CHECK: PASS
T13 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T13_LOCAL_VERIFY_20260831_004615.txt
```

T1 through T13 migration chains are now LOCKED.
T14 must add new migrations only.


## T14 CANDIDATE CHECKPOINT

T14 converts HomeTechVN into an installable PWA for Windows, Android and
ChromeOS while preserving the T11 responsive standard.

Key policy:

```text
App shell offline cache: YES
Business data offline writes: NO
Background Sync: NO
Supabase API runtime cache: NO
Update mode: PROMPT
```

T14 intentionally adds no database migration; the T1–T13 chain remains 33/33.

Run:

```powershell
npm run t14:verify
```


## T14 FINAL CHECKPOINT

T14 PWA acceptance completed on 31/08/2026.

```text
T14 LOCAL REPRODUCIBILITY: PASS
T14 PWA CORE CHECKS: PASS
T14 RESPONSIVE UI CHECK: PASS
T14 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T14_LOCAL_VERIFY_20260831_011207.txt
```

T14 added no database migration.
The locked migration baseline remains T1–T13 = 33/33.

T15 must preserve the T11 responsive standard and T14 offline-write prohibition.


## T15 CANDIDATE CHECKPOINT

T15 adds operational backup and restore verification without changing the
database schema.

Backup set:

```text
roles.sql
schema.sql
data.sql
migration history
Storage metadata
Storage objects when present
source.zip
checksums.sha256
manifest.json
```

Security:

```text
DB password      Windows DPAPI
S3 credentials   Windows DPAPI
source secrets   excluded
```

Acceptance requires a real remote FULL backup and an actual local restore drill:

```powershell
npm run t15:verify
```

T15 adds zero database migrations; the locked chain remains T1–T13 = 33/33.


### T15 v1.1 compatibility fix

- Windows PowerShell 5.1: no `Path.GetRelativePath`.
- Checksum paths use `Get-RelativePathCompat`.
- Disposable restore drill uses `pg_restore --disable-triggers` for circular
  FK data.
- Existing DPAPI backup credentials are reused; no reconfiguration required.


### T15 v1.2 restore redesign

- no `pg_terminate_backend`;
- no clone of active `postgres`;
- independent `template0` scratch DB;
- full local `pg_dump` / `pg_restore`;
- local SUPERUSER detection (`supabase_admin` preferred);
- cleanup with `DROP DATABASE ... WITH (FORCE)`;
- existing DPAPI backup credentials reused.


### T15 v1.3 Windows/docker JSON fix

Restore-marker JSON is constructed by PostgreSQL `jsonb_build_object(...)`;
no embedded JSON double quotes cross the Windows/docker command line.

Existing backup credentials are reused.


## T15 FINAL CHECKPOINT

T15 Backup & Restore acceptance completed on 31/08/2026.

```text
T15 LOCAL REPRODUCIBILITY: PASS
T15 BACKUP CORE CHECKS: PASS
T15 RESTORE DRILL: PASS
T15 RESPONSIVE UI CHECK: PASS
T15 APP BUILD: PASS
Production backup: D:\HOMETECHVN_BACKUPS\HomeTechVN_20260831_171756
Snapshot: D:\HOMETECHVN\docs\snapshots\T15_LOCAL_VERIFY_20260831_172248.txt
```

T15 adds zero database migrations.
The locked database baseline remains T1–T13 = 33/33.

T16 must preserve the T15 backup/restore safety policy.


## T16 CANDIDATE CHECKPOINT

T16 first reconciles T1–T15 technical debt, then hardens Security/Audit.

Remote migration chain:

```text
#34 20260831104002_t16_security_audit_core_hardening.sql
#35 20260831104029_t16_audit_search_and_security_snapshot.sql
#36 20260831105049_t16_audit_actor_history_independence.sql
```

Key changes:

- explicit deny-all sequence-counter RLS policy;
- remove service-role direct sequence table access;
- append-only audit history;
- hardened SECURITY DEFINER audit trigger;
- bounded `audit_search` RPC;
- `security_audit_snapshot` RPC;
- responsive Admin/Manager Audit UI;
- T1–T15 debt register;
- true multi-session sequence/inventory race test;
- root/app/worker dependency-lock + `npm ci` gate.

Run:

```powershell
npm run t16:verify
```

T16 remains candidate until the Windows verifier passes.


### T16 v1.1 verifier correction

T16 v1.1 fixes the Windows PowerShell parser error in
`scripts/t16-concurrency-check.ps1` reported by the first v1.0 verifier run.
No database migration changed. Re-run `npm run t16:verify`.


## T16 FINAL CHECKPOINT

T16 Security / Audit Hardening completed on 31/08/2026.

```text
T16 LOCAL REPRODUCIBILITY: PASS
T16 T1-T15 DEBT CLEANUP CHECKS: PASS
T16 SECURITY CORE CHECKS: PASS
T16 CONCURRENCY CHECK: PASS
T16 AUDIT RESPONSIVE UI CHECK: PASS
T16 APP BUILD: PASS
T16 WORKER CHECK: PASS
Dependency lock bundle: D:\HOMETECHVN\docs\snapshots\T16_DEPENDENCY_LOCKS_20260831_182122.zip
Snapshot: D:\HOMETECHVN\docs\snapshots\T16_LOCAL_VERIFY_20260831_182440.txt
```

Migration baseline is now locked through **#36**.

T17 starts from this FINAL checkpoint. First new migration, if required, is #37.


## T17 CANDIDATE CHECKPOINT

T17 is a **LOCAL Demo Integration** stage.

It does not add a database migration and does not seed the hosted Supabase
project.

```text
T1 → T16 migrations = 36/36
T17 DB migration     = 0
```

Load only the local demo:

```powershell
npm run t17:demo-load
```

Run the authoritative stage verifier:

```powershell
npm run t17:verify
```

The demo loader creates login-capable local users through the local Auth signup
API, runs an integrated business scenario across all major modules, verifies
real password login + JWT role mapping and enables the local demo UI through
ignored `app/.env.local`.


### T17 v1.5 full reliability pass

See `docs/T17_V1_5_FULL_REVIEW.md` and `docs/T17_REAL_REMOTE_VALIDATION.md`. PowerShell source is globally normalized for Windows PowerShell 5.1 and `npm run t17:verify` now performs an independent Node static gate before entering PowerShell.


## T17 FINAL checkpoint

T17 Demo Integration was accepted on 2026-09-01 after a full Windows runtime
verification.

```text
T17 status: FINAL & LOCKED
Root version: 0.17.14-t17.14
App version: 0.17.14
Migration chain: #1–#36
T17 migrations: 0
Next migration if required by T18: #37
```

See `docs/T17_FINAL_ACCEPTANCE.md` for the accepted runtime markers and
snapshot paths.


## T18 Production Release Gate FINAL

T18 v1.3 preserves the T17 FINAL database/application baseline and adds a
production release gate. It adds zero migrations; migration #37 remains
reserved.

Run:

```powershell
cd D:\HOMETECHVN
npm run t18:configure
npm run t18:verify
```

Run `t18:configure` once when `app/.env.local` is absent. It accepts only the
hosted Project URL plus a browser-safe Publishable key (or legacy `anon` key).
The release packager permits this local working-copy file but excludes it from
staging and verifies the completed ZIP. The notification Worker ships with
`WORKER_CRON_ENABLED=false` and `DRY_RUN=true`.

T18 v1.3 passed all seven Windows acceptance gates on 2026-09-04 and is now
COMPLETE & LOCKED. The accepted deployable release remains the Windows-created
`HOMETECHVN_T18_RELEASE_20260904_011535.zip` with SHA-256
`473e12c80062632f95412e43a8eb39a0e1192e2abc701c96ff76e90e1518547e`.
