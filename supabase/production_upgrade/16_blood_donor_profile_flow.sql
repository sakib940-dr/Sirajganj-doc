-- ============================================================
-- Medical Operations Upgrade — STEP 06 / MIGRATION 16
-- BLOOD DONOR PROFILE / AVAILABILITY / REQUEST PREFERENCES
-- ============================================================

alter table public.profiles
  add column if not exists blood_accept_requests boolean not null default true,
  add column if not exists blood_is_available boolean not null default true,
  add column if not exists blood_address text;

update public.profiles
set blood_address=coalesce(blood_address,address)
where blood_donor_volunteer=true and blood_address is null;

create or replace function public.normalize_blood_donor_settings()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  if new.blood_donor_volunteer=true and new.blood_group is null then
    raise exception 'Blood group is required to become a donor.';
  end if;
  if new.blood_donor_volunteer=true and new.blood_accept_requests=true
     and nullif(btrim(coalesce(new.phone,'')),'') is null then
    raise exception 'রক্তের অনুরোধ গ্রহণ করতে প্রোফাইলে ফোন নম্বর যোগ করুন।';
  end if;
  if new.last_blood_donation_date is not null and new.last_blood_donation_date>(now() at time zone 'Asia/Dhaka')::date then
    raise exception 'শেষ রক্তদানের তারিখ ভবিষ্যতের হতে পারে না।';
  end if;
  if new.blood_donor_volunteer=false then
    new.blood_public_phone:=false;
    new.blood_accept_requests:=false;
    new.blood_is_available:=false;
  end if;
  if new.blood_donor_volunteer is distinct from old.blood_donor_volunteer
     or new.blood_group is distinct from old.blood_group
     or new.blood_public_phone is distinct from old.blood_public_phone
     or new.blood_accept_requests is distinct from old.blood_accept_requests
     or new.blood_is_available is distinct from old.blood_is_available
     or new.last_blood_donation_date is distinct from old.last_blood_donation_date
     or new.blood_address is distinct from old.blood_address then
    new.blood_donor_updated_at:=now();
  end if;
  return new;
end $$;
drop trigger if exists trg_normalize_blood_donor_settings on public.profiles;
create trigger trg_normalize_blood_donor_settings
  before update of phone,blood_group,blood_donor_volunteer,blood_public_phone,blood_accept_requests,blood_is_available,last_blood_donation_date,blood_address on public.profiles
  for each row execute procedure public.normalize_blood_donor_settings();

-- Public search intentionally hides full address and exact coordinates.
-- PostgreSQL cannot CREATE OR REPLACE a function when the TABLE return shape changes.
-- Step 04 / legacy production exposes 8 columns; this medical flow adds
-- can_request + is_available, so replace the signature explicitly.
drop function if exists public.search_blood_donors(text,double precision,double precision,integer);

create function public.search_blood_donors(
  p_blood_group text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_limit integer default 30
)
returns table (
  id uuid,
  full_name text,
  phone text,
  blood_group text,
  last_blood_donation_date date,
  location_district text,
  location_upazila text,
  distance_km double precision,
  can_request boolean,
  is_available boolean
)
language sql
stable
security definer
set search_path=public
as $$
  select
    p.id,
    p.full_name,
    case when p.blood_public_phone then p.phone else null end,
    p.blood_group,
    p.last_blood_donation_date,
    coalesce(l.district,p.location_district),
    coalesce(l.upazila,p.location_upazila),
    case
      when p_latitude is null or p_longitude is null or l.latitude is null or l.longitude is null then null
      else round(public.location_distance_km(p_latitude,p_longitude,l.latitude,l.longitude)::numeric,0)::double precision
    end as distance_km,
    (p.blood_accept_requests and p.blood_is_available and nullif(btrim(coalesce(p.phone,'')),'') is not null) as can_request,
    p.blood_is_available
  from public.profiles p
  left join public.user_last_locations l on l.user_id=p.id
  where p.role='patient'
    and p.account_status='active'
    and p.blood_donor_volunteer=true
    and p.blood_is_available=true
    and p.blood_group is not null
    and (p_blood_group is null or p.blood_group=p_blood_group)
  order by
    case when p_latitude is null or p_longitude is null or l.latitude is null or l.longitude is null then 1 else 0 end,
    distance_km nulls last,
    p.full_name nulls last
  limit greatest(1,least(coalesce(p_limit,30),100));
$$;
revoke all on function public.search_blood_donors(text,double precision,double precision,integer) from public;
grant execute on function public.search_blood_donors(text,double precision,double precision,integer) to anon,authenticated,service_role;

create index if not exists idx_profiles_blood_directory on public.profiles(blood_donor_volunteer,blood_is_available,blood_group,blood_accept_requests)
  where blood_donor_volunteer=true;

notify pgrst, 'reload schema';
