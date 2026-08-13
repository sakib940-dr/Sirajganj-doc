-- Step 21: location/distance controls.
-- Run once after Step 20.

insert into public.site_settings (key, value)
values ('show_location_distance', 'true')
on conflict (key) do nothing;

alter table public.shops
  add column if not exists location_visibility boolean not null default true;

notify pgrst, 'reload schema';
