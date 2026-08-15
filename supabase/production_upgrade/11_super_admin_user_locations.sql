-- ============================================================
-- Medical Operations Upgrade — STEP 01 / MIGRATION 11
-- CONSENTED LAST LOCATION + SUPER ADMIN MAP ACCESS
-- Exact coordinates live outside public.profiles.
-- ============================================================

create table if not exists public.user_last_locations (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  latitude double precision,
  longitude double precision,
  district text,
  upazila text,
  source text not null default 'gps',
  accuracy_m double precision,
  updated_at timestamptz not null default now(),
  constraint user_last_locations_source_check check (source in ('gps','manual','legacy')),
  constraint user_last_locations_lat_check check (latitude is null or latitude between -90 and 90),
  constraint user_last_locations_lon_check check (longitude is null or longitude between -180 and 180),
  constraint user_last_locations_accuracy_check check (accuracy_m is null or accuracy_m >= 0)
);

-- Preserve already-collected consented locations before retiring exact coordinates from profiles.
insert into public.user_last_locations(user_id,latitude,longitude,district,upazila,source,updated_at)
select id,location_latitude,location_longitude,location_district,location_upazila,'legacy',coalesce(location_updated_at,now())
from public.profiles
where location_latitude is not null or location_longitude is not null or location_district is not null or location_upazila is not null
on conflict(user_id) do update set
  latitude=coalesce(public.user_last_locations.latitude,excluded.latitude),
  longitude=coalesce(public.user_last_locations.longitude,excluded.longitude),
  district=coalesce(public.user_last_locations.district,excluded.district),
  upazila=coalesce(public.user_last_locations.upazila,excluded.upazila),
  updated_at=greatest(public.user_last_locations.updated_at,excluded.updated_at);

-- Exact coordinates are no longer stored in profiles, because Admin has broad profile read access.
update public.profiles
set location_latitude=null, location_longitude=null
where location_latitude is not null or location_longitude is not null;

create or replace function public.strip_legacy_profile_exact_location()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  -- Area text may stay in profiles for ordinary Admin/support use; exact coordinates may not.
  new.location_latitude:=null;
  new.location_longitude:=null;
  return new;
end $$;

drop trigger if exists trg_strip_legacy_profile_exact_location on public.profiles;
create trigger trg_strip_legacy_profile_exact_location
  before insert or update of location_latitude,location_longitude on public.profiles
  for each row execute procedure public.strip_legacy_profile_exact_location();

alter table public.user_last_locations enable row level security;
drop policy if exists "user_last_locations_own_read" on public.user_last_locations;
drop policy if exists "user_last_locations_own_insert" on public.user_last_locations;
drop policy if exists "user_last_locations_own_update" on public.user_last_locations;
drop policy if exists "user_last_locations_super_admin_read" on public.user_last_locations;
create policy "user_last_locations_own_read" on public.user_last_locations for select
  using(user_id=auth.uid());
create policy "user_last_locations_super_admin_read" on public.user_last_locations for select
  using(public.is_super_admin());

-- Exact coordinates are RPC-only for app clients; RLS remains defense-in-depth.
revoke all on table public.user_last_locations from anon,authenticated;
grant all on table public.user_last_locations to service_role;

create or replace function public.save_my_last_location(
  p_latitude double precision,
  p_longitude double precision,
  p_district text default null,
  p_upazila text default null,
  p_source text default 'gps',
  p_accuracy_m double precision default null
)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare v_source text;
begin
  if auth.uid() is null then raise exception 'Login required.'; end if;
  v_source:=case when p_source in ('gps','manual') then p_source else 'gps' end;
  if p_latitude is not null and (p_latitude < -90 or p_latitude > 90) then raise exception 'Invalid latitude.'; end if;
  if p_longitude is not null and (p_longitude < -180 or p_longitude > 180) then raise exception 'Invalid longitude.'; end if;

  insert into public.user_last_locations(user_id,latitude,longitude,district,upazila,source,accuracy_m,updated_at)
  values(auth.uid(),p_latitude,p_longitude,nullif(btrim(p_district),''),nullif(btrim(p_upazila),''),v_source,p_accuracy_m,now())
  on conflict(user_id) do update set
    latitude=excluded.latitude,
    longitude=excluded.longitude,
    district=excluded.district,
    upazila=excluded.upazila,
    source=excluded.source,
    accuracy_m=excluded.accuracy_m,
    updated_at=now();

  update public.profiles
  set location_district=nullif(btrim(p_district),''),
      location_upazila=nullif(btrim(p_upazila),''),
      location_updated_at=now()
  where id=auth.uid();
end $$;
revoke all on function public.save_my_last_location(double precision,double precision,text,text,text,double precision) from public;
grant execute on function public.save_my_last_location(double precision,double precision,text,text,text,double precision) to authenticated,service_role;

create or replace function public.get_my_last_location()
returns table(latitude double precision,longitude double precision,district text,upazila text,source text,accuracy_m double precision,updated_at timestamptz)
language sql
stable
security definer
set search_path=public
as $$
  select l.latitude,l.longitude,l.district,l.upazila,l.source,l.accuracy_m,l.updated_at
  from public.user_last_locations l where l.user_id=auth.uid();
$$;
revoke all on function public.get_my_last_location() from public;
grant execute on function public.get_my_last_location() to authenticated,service_role;

create or replace function public.get_super_admin_user_locations()
returns table(
  user_id uuid,
  full_name text,
  phone text,
  role text,
  latitude double precision,
  longitude double precision,
  district text,
  upazila text,
  source text,
  accuracy_m double precision,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.is_super_admin() and not public.is_trusted_backend_context() then
    raise exception 'Super Admin access required.';
  end if;
  return query
  select p.id,p.full_name,p.phone,p.role,l.latitude,l.longitude,l.district,l.upazila,l.source,l.accuracy_m,l.updated_at
  from public.profiles p
  left join public.user_last_locations l on l.user_id=p.id
  order by coalesce(l.updated_at,p.created_at) desc;
end $$;
revoke all on function public.get_super_admin_user_locations() from public;
grant execute on function public.get_super_admin_user_locations() to authenticated,service_role;

create index if not exists idx_user_last_locations_updated on public.user_last_locations(updated_at desc);
create index if not exists idx_user_last_locations_area on public.user_last_locations(district,upazila);

notify pgrst, 'reload schema';
