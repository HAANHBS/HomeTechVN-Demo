begin;

-- T20.2 deliberately kept the operational integrity snapshot internal. T22's
-- extended implementation remains available to trusted acceptance sessions,
-- but the browser does not need or receive an RPC for it.
drop function if exists public.operational_integrity_snapshot();

revoke execute on function private.operational_integrity_t20_snapshot_impl()
from public,anon,authenticated;

revoke execute on function private.operational_integrity_snapshot_impl()
from public,anon,authenticated;

commit;

