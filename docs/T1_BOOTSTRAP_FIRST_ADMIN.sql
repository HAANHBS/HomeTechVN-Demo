-- HomeTechVN T1 — Bootstrap Admin đầu tiên
-- CHỈ chạy sau khi đã tạo user trong Supabase Authentication > Users.
--
-- Không lưu password ở đây.
-- Không thay đổi migration để hard-code user thật.

do $$
declare
  v_admin_user_id uuid := null; -- REQUIRED INPUT: set the target Auth user UUID before manual execution
  v_admin_role_id uuid;
begin
  if v_admin_user_id is null then
    raise exception 'CHUA DAT ADMIN UUID. Hay dien v_admin_user_id truoc khi chay.';
  end if;

  select id into v_admin_role_id
  from public.roles
  where code = 'admin';

  if v_admin_role_id is null then
    raise exception 'Khong tim thay role admin. Hay chay migration/seed T1 truoc.';
  end if;

  if not exists (select 1 from public.profiles where id = v_admin_user_id) then
    raise exception 'Khong tim thay profile cho UUID %. Hay kiem tra Auth user/trigger.', v_admin_user_id;
  end if;

  update public.profiles
  set role_id = v_admin_role_id,
      is_active = true,
      updated_at = now()
  where id = v_admin_user_id;

  raise notice 'Bootstrap Admin thanh cong cho user UUID %', v_admin_user_id;
end
$$;

-- VERIFY:
select
  p.id,
  p.email,
  p.full_name,
  p.is_active,
  r.code as role_code
from public.profiles p
left join public.roles r on r.id = p.role_id
where r.code = 'admin'
order by p.created_at;
