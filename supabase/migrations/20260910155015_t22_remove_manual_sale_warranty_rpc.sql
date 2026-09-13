begin;

-- Sale warranties are a transactional consequence of handover. Keep the
-- adjustment implementation private for trusted maintenance only.
drop function if exists public.warranty_create_sale(uuid,uuid,uuid,date,integer,text,text);

revoke execute on function private.warranty_create_sale_impl(uuid,uuid,uuid,date,integer,text,text)
from public,anon,authenticated;

commit;

