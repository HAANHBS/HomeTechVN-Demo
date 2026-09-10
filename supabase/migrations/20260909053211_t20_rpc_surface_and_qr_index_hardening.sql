begin;

-- T20.2 keeps only browser RPCs that are required by an operational screen.
-- Warranty activation is automatic at handover and integrity audits run only
-- from trusted migration/acceptance sessions, so neither needs public exposure.
drop function if exists public.warranty_activate_sale(uuid);
drop function if exists public.operational_integrity_snapshot();
drop function if exists private.warranty_activate_sale_manual_impl(uuid);

-- Complete the two foreign-key access paths reported by the hosted advisor.
create index if not exists idx_qr_codes_created_by
  on private.qr_codes(created_by)
  where created_by is not null;

create index if not exists idx_qr_codes_revoked_by
  on private.qr_codes(revoked_by)
  where revoked_by is not null;

commit;
