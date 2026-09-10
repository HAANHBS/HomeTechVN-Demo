# HomeTechVN — PRE-PUBLIC AUTH SECURITY CHECKLIST

> Checklist này KHÔNG phải blocker trong giai đoạn DEV.
> Bắt buộc chạy trước khi HomeTechVN được public hoặc giao cho nhiều nhân viên sử dụng.

| Check | Việc | Kết quả/Ghi chú |
|---|---|---|
| [ ] | Xem lại `Allow new users to sign up` | |
| [ ] | Nếu app nội bộ: tắt public signup | |
| [ ] | Xem lại `Allow anonymous sign-ins` | |
| [ ] | Nếu không dùng anonymous: tắt | |
| [ ] | Bật/kiểm tra Confirm Email | |
| [ ] | Cấu hình Site URL production | |
| [ ] | Cấu hình Redirect URLs production | |
| [ ] | Kiểm tra SMTP/email auth | |
| [ ] | Kiểm tra Auth rate limits | |
| [ ] | Leaked Password Protection: nếu project đã nâng Pro+ thì bắt buộc bật; Free plan ghi `N/A — PLAN LIMITATION` và tăng cường password policy/MFA/rate-limit phù hợp | |
| [ ] | Kiểm tra CAPTCHA nếu public signup | |
| [ ] | Kiểm tra user mới vẫn `is_active=false` | |
| [ ] | Kiểm tra user mới không có role | |
| [ ] | Kiểm tra RLS bằng tài khoản user thường | |
| [ ] | Chạy Security Advisor | |
| [ ] | Xử lý WARN/ERROR chưa được chấp nhận | |
| [ ] | Xác nhận không có Secret Key trong frontend | |
| [ ] | Ghi ngày review + người thực hiện | |

## Nghiệm thu
Chỉ được public khi các mục áp dụng đều PASS.
