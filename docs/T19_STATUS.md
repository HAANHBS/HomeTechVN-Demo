# T19 Status

**CANDIDATE**

- Candidate revision: v1.2 (RLS posture regression fixed from the v1.1 Windows failure snapshot).

- Baseline: T18 FINAL.
- Locked migrations #1–#36: unchanged.
- T19 migration: #37 `20260904014416_t19_universal_qr_operations.sql`.
- Universal QR UI: implemented for desktop, tablet, and mobile.
- Real local Auth/RBAC/token/revoke test: pending Windows verification.
- Payment: test workflow only; no real bank/provider acknowledgement.
- Private QR tables: explicit deny-all RLS policies; direct client table grants remain revoked.
