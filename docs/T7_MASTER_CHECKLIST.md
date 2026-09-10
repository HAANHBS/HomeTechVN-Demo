# HomeTechVN — T7 MASTER CHECKLIST

## Scope
T7 — Warranty / Warranty Claims.

## Database
- [x] `warranties`
- [x] `warranty_claims`
- [x] `warranty_status_history`
- [x] RLS enabled from creation
- [x] Explicit authenticated SELECT grants
- [x] No authenticated direct INSERT / UPDATE / DELETE
- [x] No anonymous table access
- [x] Security-invoker summary views
- [x] FK covering indexes
- [x] Audit + updated_at integration
- [x] `WAR-YYMMDD-0001`
- [x] `WCL-YYMMDD-0001`
- [x] 64-hex opaque lookup token
- [x] SALE source
- [x] REPAIR source
- [x] SERVICE source reserved for T8 integration
- [x] Serialized-sale warranty validation
- [x] Warranty start/end validation
- [x] VOID with reason and active-claim guard

## Claim workflow
- [x] RECEIVED → CHECKING
- [x] CHECKING → APPROVED / REJECTED
- [x] APPROVED → IN_SERVICE
- [x] IN_SERVICE → QC
- [x] QC fail → IN_SERVICE
- [x] QC pass → READY
- [x] READY → RETURNED
- [x] RETURNED → CLOSED
- [x] REJECTED → CLOSED
- [x] One active claim per warranty
- [x] Status history

## Security / QR contract
- [x] Browser/anon cannot read warranty tables
- [x] Browser/anon cannot execute server lookup RPC
- [x] Server lookup is SECURITY INVOKER
- [x] Server lookup executable only by service_role
- [x] Phone/Serial are masked
- [x] Public payload excludes internal IDs
- [x] Anonymous `/w/<token>` route remains T12

## Acceptance
- [x] Remote runtime lifecycle
- [x] Role matrix
- [x] Masked server lookup
- [x] Remote rollback clean
- [x] Security Advisor: no new T7 finding
- [x] Performance Advisor: T7 FK issue fixed
- [x] TS/TSX parse 18/18
- [x] Structural TypeScript check
- [x] RPC-only frontend mutation scan
- [ ] Windows local reproducibility
- [ ] Windows SQL verifier
- [ ] Windows production build
