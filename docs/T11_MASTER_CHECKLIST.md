# HomeTechVN — T11 MASTER CHECKLIST

## Backend / Dashboard data
- [x] `dashboard.view` is required
- [x] Aggregate RPC is permission-aware per module
- [x] No new public table
- [x] No new direct Data API table surface
- [x] 7 / 30 / 90 day period validation
- [x] Asia/Bangkok business-day boundaries
- [x] Customer KPI
- [x] Sales KPI
- [x] Payment KPI only with `payment.view`
- [x] Repair KPI + attention queue
- [x] Inventory KPI + low-stock queue
- [x] Warranty expiry KPI
- [x] Service due/overdue KPI
- [x] License expiry KPI
- [x] Reminder due/urgent KPI
- [x] User-specific unread in-app notification KPI
- [x] Notification delivery quality only with `notification.manage`
- [x] Sales daily series
- [x] Repair status series
- [x] Notification channel series

## Permission tests
- [x] Admin full dashboard KPI path
- [x] Cashier Service/License aggregate hidden
- [x] Technician payment aggregate hidden
- [x] invalid 14-day period rejected
- [x] anon cannot execute Dashboard RPC

## Global responsive UI/UX
- [x] Dashboard becomes default landing page
- [x] One-tap global `Tổng quan` launcher
- [x] PC/tablet/phone responsive Dashboard
- [x] touch target 44px baseline
- [x] coarse-pointer 48px baseline
- [x] mobile input font guard
- [x] focus-visible ring
- [x] reduced-motion support
- [x] safe-area handling
- [x] momentum horizontal scrolling
- [x] 3 legacy table wrappers fixed
- [x] all 25 TSX tables pass overflow scan
- [x] `docs/UI_UX_STANDARD.md` established as global rule

## Static source
- [x] TS/TSX parse 22/22
- [x] Dashboard focused semantic check: 0 errors
- [x] T11 UI static checker PASS
- [x] Windows production app build

## Remote
- [x] T11 Dashboard runtime PASS
- [x] transaction rollback cleanup
- [x] Security Advisor: no new T11 issue
- [x] Performance Advisor: no new T11 missing-index issue

## Final acceptance
- [x] T11 LOCAL REPRODUCIBILITY: PASS
- [x] T11 FINAL CORE CHECKS: PASS
- [x] T11 RESPONSIVE UI CHECK: PASS
- [x] T11 APP BUILD: PASS
