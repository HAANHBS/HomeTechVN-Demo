# HomeTechVN — T12 MASTER CHECKLIST

## Scope
T12 — QR Warranty / public warranty lookup.

## Public security contract
- [x] Opaque random token from T7 reused; no sequential/public DB id.
- [x] Token validation requires exactly 64 lowercase hex characters.
- [x] Existing unique btree index on `warranties.lookup_token` reused.
- [x] `anon` has no SELECT on `warranties`.
- [x] `anon` has no SELECT on `customers`.
- [x] Public access is only `public.warranty_public_lookup(text)`.
- [x] Public wrapper is SECURITY INVOKER.
- [x] Privileged lookup implementation is isolated in non-exposed `public_lookup_private` schema.
- [x] Public payload excludes UUIDs, source ids and lookup token.
- [x] Phone is masked.
- [x] Serial is masked.
- [x] Claim issue / customer request / internal notes are excluded.
- [x] Latest claim exposes only status and lifecycle timestamps.
- [x] Invalid/unknown tokens return the same `{found:false}` contract.

## Public payload
- [x] `found`
- [x] `warranty_code`
- [x] effective `status`
- [x] `start_date`
- [x] `end_date`
- [x] `days_remaining`
- [x] `coverage`
- [x] product/allowed device snapshot
- [x] masked serial
- [x] masked phone
- [x] minimal latest claim status/timestamps

## Public page
- [x] `/w/<opaque-token>` route works without login.
- [x] Invalid `/w/*` remains on public lookup UI, not Login.
- [x] Responsive PC/tablet/phone layout.
- [x] T11 touch/focus/mobile rules preserved.
- [x] ACTIVE / EXPIRED / VOID states visible with text and color.
- [x] Minimal latest claim progress visible.
- [x] No direct protected-table query from public component.
- [x] Cloudflare Pages SPA behavior compatible: no top-level `404.html`.
- [x] `/w/*` sends `X-Robots-Tag: noindex, nofollow, noarchive`.
- [x] `/w/*` sends `Referrer-Policy: no-referrer`.
- [x] `/w/*` sends `Cache-Control: no-store`.

## Internal Warranty UI
- [x] QR generated locally in browser.
- [x] QR URL uses current `window.location.origin`.
- [x] Copy public link.
- [x] Download QR PNG.
- [x] Print compact warranty label.
- [x] Raw token removed from ordinary detail display.
- [x] `qrcode` pinned to 1.5.4.
- [x] `@types/qrcode` pinned to 1.5.6.

## Remote runtime
- [x] anon valid-token lookup PASS.
- [x] anon invalid-token lookup PASS.
- [x] anon unknown-token lookup PASS.
- [x] ACTIVE status PASS.
- [x] masked phone PASS.
- [x] masked serial PASS.
- [x] UUID leak check PASS.
- [x] claim issue leak check PASS.
- [x] test rollback cleanup PASS.
- [x] Security Advisor: no new T12 issue.
- [x] Performance Advisor: no new T12 issue; existing unused-index INFO only.

## Static UI regression
- [x] T11 responsive table scan PASS (25 tables).
- [x] T11 touch/focus/mobile foundation PASS.
- [x] T12 public route-before-auth check PASS.
- [x] T12 RPC-only privacy scan PASS.
- [x] T12 QR action scan PASS.
- [x] T12 Cloudflare header scan PASS.
- [ ] Windows production app build.

## Final acceptance
- [x] T12 LOCAL REPRODUCIBILITY: PASS
- [x] T12 FINAL CORE CHECKS: PASS
- [x] T12 RESPONSIVE UI CHECK: PASS
- [x] T12 APP BUILD: PASS
