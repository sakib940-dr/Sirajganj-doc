-- ============================================================
-- Doctor V1 Step 10 — Visitor Location + District/Upazila
-- Run this AFTER Step 8 upgrade/demo and Step 9 website-builder SQL.
-- Safe to run once; columns are added only if missing.
-- ============================================================

alter table public.shops
  add column if not exists district text,
  add column if not exists upazila text;

create index if not exists idx_shops_district_upazila
  on public.shops (district, upazila);

-- Starter chamber locations. These are editable later by Super Admin
-- or through the chamber settings flow.
update public.shops set district='সিরাজগঞ্জ', upazila='সিরাজগঞ্জ সদর'
where slug in ('chamber-01','chamber-02');

update public.shops set district='সিরাজগঞ্জ', upazila='শাহজাদপুর'
where slug = 'chamber-03';

update public.shops set district='সিরাজগঞ্জ', upazila='উল্লাপাড়া'
where slug = 'chamber-04';

update public.shops set district='সিরাজগঞ্জ', upazila='কাজীপুর'
where slug = 'chamber-05';

-- Keep the location fields available to public doctor/chamber reads.
-- Existing public SELECT/RLS policies already govern shop visibility.
