# T20.2 automated hosted-demo runbook

T20.2 không yêu cầu nghiệm thu trên PC. Dữ liệu nghiệm thu phải thuộc project
hosted demo và `demo.t20.hosted` phải ghi rõ:

```json
{"mode":"HOSTED_DEMO","contains_real_customer_data":false}
```

## Trình tự phát hành

1. Kiểm hash migration #1–#40; không sửa migration đã áp.
2. Chạy `supabase/tests/t20_demo_acceptance.sql` trên hosted. Test mở transaction,
   tạo dữ liệu giả, kiểm lỗi vận hành rồi `ROLLBACK`.
3. Chạy `supabase/t20_hosted_demo_operational_upgrade.sql` để duy trì một đơn giả
   đã hoàn tất có serial `DEMO-T20-SN-001` và bảo hành còn hiệu lực.
4. Chạy `npm run t20:demo-gate` để kiểm source, TypeScript, Vite/PWA, bundle và Worker.
5. Chỉ đẩy đúng source sạch lên GitHub; cấm `.env*`, secret, JWT, mật khẩu,
   `node_modules`, `dist`, snapshot và log.
6. Deploy đúng commit đã đẩy, rồi smoke-test quét bảo hành trên hosted.

Marker bắt buộc:

```text
T20 AUTOMATED FAKE-DATA ACCEPTANCE: PASS
T20 HOSTED COMPLETED SERIAL/WARRANTY DEMO: PASS
T20 LOCKED MIGRATION REGRESSION: PASS (#1-#40 hosted hashes locked)
T20 PAYMENT/WORKFLOW DATABASE CONTRACT: PASS
T20 ACTION ERROR PLACEMENT CHECK: PASS
T20 WORKFLOW GUIDANCE UI CHECK: PASS
T20 AUTOMATED DEMO SOURCE/BUILD GATE: PASS
T20 PC ACCEPTANCE REQUIRED: NO
```

Không dùng dữ liệu khách thật để nghiệm thu. Không cấp quyền trực tiếp bảng/private
implementation cho `anon` hoặc `authenticated`; “full quyền” chỉ là toàn bộ RBAC
nghiệp vụ dành cho vai trò Demo Admin.
