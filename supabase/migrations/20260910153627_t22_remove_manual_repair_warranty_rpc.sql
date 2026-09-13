begin;

-- Repair warranties are now an invariant of repair completion. Keep the
-- adjustment implementation private for trusted maintenance, and remove the
-- obsolete browser-facing manual creation route.
drop function if exists public.warranty_create_repair(uuid,date,integer,text,text);

revoke execute on function private.warranty_create_repair_impl(uuid,date,integer,text,text)
from public,anon,authenticated;

commit;

