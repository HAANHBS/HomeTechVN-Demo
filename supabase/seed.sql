-- HomeTechVN T1 seed
-- Safe foundation seed: roles, permissions, role mappings, non-secret settings.
-- Does NOT seed real Auth users.

begin;

insert into public.roles(code, name, description)
values
  ('admin', 'Admin', 'Toan quyen he thong'),
  ('manager', 'Quan ly', 'Quan ly nghiep vu, khong quan ly tai khoan Admin'),
  ('sales', 'Ban hang', 'CRM, san pham, don hang, bao hanh co ban'),
  ('technician', 'Ky thuat', 'Sua chua, checklist, linh kien, bao hanh ky thuat'),
  ('cashier', 'Thu ngan', 'Thanh toan, cong no, xem don lien quan')
on conflict (code) do update
set name = excluded.name,
    description = excluded.description,
    is_active = true,
    updated_at = now();

insert into public.permissions(code, name, module)
values
  ('dashboard.view','Xem Dashboard','dashboard'),

  ('user.view','Xem nguoi dung','admin'),
  ('user.manage','Quan ly nguoi dung','admin'),
  ('role.manage','Quan ly role/permission','admin'),
  ('settings.view','Xem cau hinh','admin'),
  ('settings.manage','Quan ly cau hinh','admin'),
  ('audit.view','Xem audit log','admin'),

  ('customer.view','Xem khach hang','customer'),
  ('customer.create','Tao khach hang','customer'),
  ('customer.update','Sua khach hang','customer'),

  ('device.view','Xem thiet bi','device'),
  ('device.create','Tao thiet bi','device'),
  ('device.update','Sua thiet bi','device'),

  ('product.view','Xem san pham','product'),
  ('product.manage','Quan ly san pham','product'),
  ('cost_price.view','Xem gia von','product'),

  ('inventory.view','Xem kho','inventory'),
  ('inventory.receive','Nhap kho','inventory'),
  ('inventory.issue','Xuat kho','inventory'),
  ('inventory.adjust','Dieu chinh kho','inventory'),

  ('sale.view','Xem don ban','sales'),
  ('sale.create','Tao don ban','sales'),
  ('sale.update','Sua don ban','sales'),
  ('sale.cancel','Huy don ban','sales'),

  ('payment.view','Xem thanh toan','payment'),
  ('payment.create','Tao thanh toan','payment'),
  ('payment.update','Sua thanh toan','payment'),

  ('repair.view','Xem phieu sua','repair'),
  ('repair.create','Tao phieu sua','repair'),
  ('repair.update','Cap nhat phieu sua','repair'),
  ('repair.diagnose','Chan doan','repair'),
  ('repair.quote','Bao gia','repair'),
  ('repair.qc','QC','repair'),
  ('repair.cancel','Huy phieu sua','repair'),

  ('warranty.view','Xem bao hanh','warranty'),
  ('warranty.manage','Quan ly bao hanh','warranty'),

  ('service.view','Xem dich vu dinh ky','service'),
  ('service.manage','Quan ly dich vu dinh ky','service'),

  ('license.view','Xem license','license'),
  ('license.manage','Quan ly license','license'),

  ('checklist.run','Thuc hien checklist','checklist'),
  ('checklist.manage','Quan ly checklist template','checklist'),

  ('notification.view','Xem thong bao','notification'),
  ('notification.manage','Quan ly thong bao','notification'),

  ('report.view','Xem bao cao','report'),
  ('report.profit','Xem bao cao loi nhuan','report'),

  ('qr.issue','Tao ma QR nghiep vu','qr'),
  ('qr.revoke','Thu hoi ma QR nghiep vu','qr')
on conflict (code) do update
set name = excluded.name,
    module = excluded.module;

-- Admin: all permissions.
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'admin'
on conflict do nothing;

-- Manager: broad operational access, excluding user/role administration.
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in (
  'dashboard.view',
  'settings.view','audit.view',
  'customer.view','customer.create','customer.update',
  'device.view','device.create','device.update',
  'product.view','product.manage','cost_price.view',
  'inventory.view','inventory.receive','inventory.issue','inventory.adjust',
  'sale.view','sale.create','sale.update','sale.cancel',
  'payment.view','payment.create','payment.update',
  'repair.view','repair.create','repair.update','repair.diagnose','repair.quote','repair.qc','repair.cancel',
  'warranty.view','warranty.manage',
  'service.view','service.manage',
  'license.view','license.manage',
  'checklist.run','checklist.manage',
  'notification.view','notification.manage',
  'report.view','report.profit',
  'qr.issue','qr.revoke'
)
where r.code = 'manager'
on conflict do nothing;

-- Sales
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in (
  'dashboard.view',
  'customer.view','customer.create','customer.update',
  'device.view','device.create','device.update',
  'product.view','inventory.view',
  'sale.view','sale.create','sale.update',
  'payment.view',
  'repair.view','repair.create',
  'warranty.view','warranty.manage',
  'service.view','service.manage',
  'license.view','license.manage',
  'checklist.run',
  'notification.view',
  'report.view',
  'qr.issue'
)
where r.code = 'sales'
on conflict do nothing;

-- Technician
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in (
  'dashboard.view',
  'customer.view',
  'device.view','device.update',
  'product.view',
  'inventory.view','inventory.issue',
  'sale.view',
  'repair.view','repair.create','repair.update','repair.diagnose','repair.quote','repair.qc',
  'warranty.view','warranty.manage',
  'service.view',
  'license.view',
  'checklist.run',
  'notification.view',
  'qr.issue'
)
where r.code = 'technician'
on conflict do nothing;

-- Cashier
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in (
  'dashboard.view',
  'customer.view',
  'device.view',
  'product.view',
  'inventory.view',
  'sale.view',
  'payment.view','payment.create','payment.update',
  'repair.view',
  'warranty.view',
  'notification.view',
  'report.view',
  'qr.issue'
)
where r.code = 'cashier'
on conflict do nothing;

insert into public.settings(key, value, description, is_sensitive)
values
  ('business.name', '"HomeTechVN"'::jsonb, 'Ten thuong hieu/cua hang', false),
  ('business.timezone', '"Asia/Bangkok"'::jsonb, 'Mui gio nghiep vu', false),
  ('auth.public_signup_expected', 'false'::jsonb, 'Production nen tat public signup sau bootstrap Admin', false),
  ('security.store_secrets_in_settings', 'false'::jsonb, 'Khong luu secret that trong bang settings', false),
  ('code.customer_prefix', '"CUS"'::jsonb, 'Prefix ma khach hang', false),
  ('code.device_prefix', '"DEV"'::jsonb, 'Prefix ma thiet bi', false),
  ('code.sale_prefix', '"SO"'::jsonb, 'Prefix don ban', false),
  ('code.repair_prefix', '"SRV"'::jsonb, 'Prefix phieu sua', false),
  ('code.warranty_prefix', '"WAR"'::jsonb, 'Prefix bao hanh', false),
  ('code.payment_prefix', '"PAY"'::jsonb, 'Prefix thanh toan', false)
on conflict (key) do update
set value = excluded.value,
    description = excluded.description,
    is_sensitive = excluded.is_sensitive,
    updated_at = now();

commit;
