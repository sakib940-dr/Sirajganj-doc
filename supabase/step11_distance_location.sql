-- ============================================================
-- Doctor V1 Step 11 — Exact visitor location + chamber coordinates
-- Run ONCE after Step 10.
-- ============================================================

alter table public.profiles
  add column if not exists location_latitude double precision,
  add column if not exists location_longitude double precision,
  add column if not exists location_district text,
  add column if not exists location_upazila text,
  add column if not exists location_updated_at timestamptz;

alter table public.shops
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

create index if not exists idx_shops_lat_lng on public.shops (latitude, longitude);
create index if not exists idx_profiles_location on public.profiles (location_latitude, location_longitude);

-- The existing profiles_update_own policy already lets a user update
-- their own non-role profile fields. No role/account-status fields are exposed
-- by the location UI.

-- Optional helper for server-side distance calculations in future features.
create or replace function public.distance_km(
  lat1 double precision,
  lon1 double precision,
  lat2 double precision,
  lon2 double precision
) returns double precision
language sql
immutable
as $$
  select case
    when lat1 is null or lon1 is null or lat2 is null or lon2 is null then null
    else 6371.0 * 2 * asin(
      sqrt(
        power(sin(radians(lat2 - lat1) / 2), 2) +
        cos(radians(lat1)) * cos(radians(lat2)) *
        power(sin(radians(lon2 - lon1) / 2), 2)
      )
    )
  end;
$$;

-- Starter chamber coordinates can be filled later from the actual map location.
-- Example:
-- update public.shops set latitude=24.4539, longitude=89.7000 where slug='chamber-01';
