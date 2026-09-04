# T10 Build / Test

## Remote database / outbox — PASS

Validated inside rollback transactions:

- four notification channels
- per-rule staff/customer routing
- IN_APP per active staff profile
- Telegram per configured staff profile/chat
- Email per customer email
- Zalo ZBS_PHONE via normalized phone
- Zalo OA_UID via customer Zalo UID
- delivery_key dedupe
- prepare rerun idempotency
- service-role-only dispatch claims
- `FOR UPDATE SKIP LOCKED`
- one log per attempt
- provider failure -> retry
- second Email attempt -> sent
- Sales own-inbox RLS
- Sales cannot configure channels
- secret settings store only external refs
- recursive config secret-key guard
- rollback cleanup

## Advisor — PASS for T10

No new T10 security warning.
No new missing-FK-index warning.

Existing project notices are unchanged:
- private `sequence_counters`: RLS enabled without policy, intentionally private.
- Supabase Auth leaked-password protection remains a pre-public hardening item.
- unused-index INFO reflects low/no production workload.

## Static source — PASS

- Cloudflare Worker `node --check`: PASS
- 21 TS/TSX files parse with zero syntax errors
- focused structural TypeScript scan found no non-stub T10-specific type error
- notification frontend mutations use RPC
- frontend provider/service-role secret scan: PASS

## Artifact environment limitation

The artifact environment timed out while installing frontend npm dependencies.
Therefore the real React production build and Wrangler bundle are intentionally
was later completed by the Windows verifier: PASS.
