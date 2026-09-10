# HomeTechVN — T12 FINAL ACCEPTANCE

Date: 30/08/2026

## Result

**T12 — QR Warranty / Public Warranty Lookup: COMPLETE**

## Windows runtime evidence

```text
T12 LOCAL REPRODUCIBILITY: PASS
T12 FINAL CORE CHECKS: PASS
T12 RESPONSIVE UI CHECK: PASS
T12 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T12_LOCAL_VERIFY_20260830_235308.txt
```

## Accepted T12 capabilities

- Public route `/w/<opaque-token>`
- Anonymous warranty lookup without login
- 64-hex opaque lookup token
- Public RPC-only lookup
- No anonymous direct SELECT on warranty/customer tables
- Masked customer phone
- Masked serial number
- No internal UUID/source leakage
- Latest warranty claim status only
- Responsive public warranty page
- QR generation inside the browser
- Copy public link
- Download QR PNG
- Print QR label
- Public route privacy headers
- `noindex`, `nofollow`, `noarchive`
- `Referrer-Policy: no-referrer`
- T11 responsive UI/UX standard preserved

## Locked T12 migration

```text
20260830154502_t12_public_warranty_lookup.sql
```

T1 through T12 migrations are now LOCKED.
T13 and later stages must add new migrations only.

The T11 global responsive UI/UX standard remains mandatory.
