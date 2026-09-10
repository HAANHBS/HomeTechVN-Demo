-- HomeTechVN T1
-- Remote migration version: 20260829144121
-- Purpose: remove Data API execution rights from Supabase's RLS auto-enable event function.
-- The function may not exist in every local Supabase build, so this migration is guarded.

do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke execute on function public.rls_auto_enable() from public';
    execute 'revoke execute on function public.rls_auto_enable() from anon';
    execute 'revoke execute on function public.rls_auto_enable() from authenticated';
  end if;
end
$$;
