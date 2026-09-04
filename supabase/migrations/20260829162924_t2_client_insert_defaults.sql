begin;
alter table public.customers alter column customer_code set default ''::text;
alter table public.customer_devices alter column device_code set default ''::text;
commit;
