\set ON_ERROR_STOP on
begin;

-- Public contract/grants.
do $$
begin
  if not has_function_privilege('anon','public.warranty_public_lookup(text)','EXECUTE') then
    raise exception 'anon missing warranty_public_lookup EXECUTE';
  end if;
  if not has_function_privilege('authenticated','public.warranty_public_lookup(text)','EXECUTE') then
    raise exception 'authenticated missing warranty_public_lookup EXECUTE';
  end if;
  if has_table_privilege('anon','public.warranties','SELECT') then
    raise exception 'anon unexpectedly has warranties SELECT';
  end if;
  if has_table_privilege('anon','public.customers','SELECT') then
    raise exception 'anon unexpectedly has customers SELECT';
  end if;
  if not has_schema_privilege('anon','public_lookup_private','USAGE') then
    raise exception 'anon missing public_lookup_private USAGE';
  end if;
end $$;

-- Deterministic public lookup data.
insert into public.customers(id,customer_code,full_name,phone,status)
values('c1200000-0000-4000-8000-000000000001','CUS-120001','T12 Public Customer','0912345678','ACTIVE');

insert into public.customer_devices(id,device_code,customer_id,device_type,brand,model,serial_number,status)
values('c1200000-0000-4000-8000-000000000002','DEV-120001','c1200000-0000-4000-8000-000000000001','Laptop','Dell','Latitude T12','SN-T12-ABCDEFG123456','ACTIVE');

insert into public.warranties(id,warranty_code,lookup_token,customer_id,customer_device_id,source_type,source_id,product_name_snapshot,serial_snapshot,coverage,start_date,end_date,status,void_reason)
values
('c1200000-0000-4000-8000-000000000003','WAR-260830-1201',repeat('c',64),'c1200000-0000-4000-8000-000000000001','c1200000-0000-4000-8000-000000000002','SERVICE','c1200000-0000-4000-8000-000000000004','Laptop Dell T12','SN-T12-ABCDEFG123456','Bảo hành phần cứng','2026-08-01','2099-12-31','ACTIVE',null),
('c1200000-0000-4000-8000-000000000006','WAR-260830-1202',repeat('e',64),'c1200000-0000-4000-8000-000000000001',null,'SERVICE','c1200000-0000-4000-8000-000000000007','Thiết bị hết hạn',null,'Bảo hành tiêu chuẩn','2020-01-01','2020-12-31','ACTIVE',null),
('c1200000-0000-4000-8000-000000000008','WAR-260830-1203',repeat('f',64),'c1200000-0000-4000-8000-000000000001',null,'SERVICE','c1200000-0000-4000-8000-000000000009','Thiết bị VOID',null,'Bảo hành tiêu chuẩn','2026-01-01','2099-12-31','VOID','T12 verifier fixture');

insert into public.warranty_claims(id,claim_code,warranty_id,status,issue_description,received_at)
values('c1200000-0000-4000-8000-000000000005','WCL-260830-1201','c1200000-0000-4000-8000-000000000003','CHECKING','Nội dung lỗi tuyệt đối không được công khai','2026-08-30 08:00+00');

set local role anon;
do $$
declare
  j jsonb;
  expired jsonb;
  voided jsonb;
begin
  j:=public.warranty_public_lookup(repeat('c',64));
  if (j->>'found')::boolean is not true then raise exception 'valid token not found'; end if;
  if j->>'warranty_code'<>'WAR-260830-1201' then raise exception 'warranty code mismatch'; end if;
  if j->>'status'<>'ACTIVE' then raise exception 'active status mismatch'; end if;
  if (j->>'days_remaining')::int<=0 then raise exception 'active days_remaining invalid'; end if;
  if j#>>'{latest_claim,status}'<>'CHECKING' then raise exception 'latest claim status mismatch'; end if;

  if j->>'phone_masked'='0912345678' or position('0912345678' in j::text)>0 then raise exception 'full phone leaked'; end if;
  if j->>'serial_masked'='SN-T12-ABCDEFG123456' or position('SN-T12-ABCDEFG123456' in j::text)>0 then raise exception 'full serial leaked'; end if;
  if position('c1200000-0000-4000-8000-000000000001' in j::text)>0 or position('c1200000-0000-4000-8000-000000000003' in j::text)>0 then raise exception 'UUID leaked'; end if;
  if position('Nội dung lỗi tuyệt đối không được công khai' in j::text)>0 then raise exception 'claim issue leaked'; end if;
  if j ? 'customer_id' or j ? 'source_id' or j ? 'lookup_token' then raise exception 'internal field leaked'; end if;

  expired:=public.warranty_public_lookup(repeat('e',64));
  if expired->>'status'<>'EXPIRED' then raise exception 'expired status mismatch'; end if;
  if (expired->>'days_remaining')::int<>0 then raise exception 'expired days_remaining mismatch'; end if;

  voided:=public.warranty_public_lookup(repeat('f',64));
  if voided->>'status'<>'VOID' then raise exception 'void status mismatch'; end if;
  if voided->'days_remaining'<>'null'::jsonb then raise exception 'VOID days_remaining must be null'; end if;

  if (public.warranty_public_lookup('bad-token')->>'found')::boolean is not false then raise exception 'invalid token should return found=false'; end if;
  if (public.warranty_public_lookup(repeat('d',64))->>'found')::boolean is not false then raise exception 'unknown token should return found=false'; end if;
end $$;
reset role;

do $$ begin
  raise notice 'T12 FINAL CORE CHECKS: PASS';
end $$;
rollback;
