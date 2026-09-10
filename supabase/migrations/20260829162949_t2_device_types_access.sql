begin;
create policy settings_crm_device_types_select
on public.settings for select
to authenticated
using (
  key = 'crm.device_types'
  and (select private.has_permission('device.view'))
);
commit;
