-- ============================================================
-- STEP 16 — BLOOD BANK + AMBULANCE DIRECTORY
-- ============================================================

-- 0) Final role compatibility: hospital/chamber accounts are supported.
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('patient','doctor','hospital','admin','super_admin'));

-- 1) Blood donor fields on patient profiles.
alter table public.profiles
  add column if not exists blood_group text,
  add column if not exists blood_donor_volunteer boolean not null default false,
  add column if not exists blood_public_phone boolean not null default false,
  add column if not exists last_blood_donation_date date,
  add column if not exists blood_donor_updated_at timestamptz;

alter table public.profiles drop constraint if exists profiles_blood_group_check;
alter table public.profiles add constraint profiles_blood_group_check
  check (blood_group is null or blood_group in ('A+','A-','B+','B-','AB+','AB-','O+','O-'));

-- 2) Blood requests: one request can target one donor; donor sees it in dashboard.
create table if not exists public.blood_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  donor_id uuid not null references public.profiles(id) on delete cascade,
  blood_group text not null check (blood_group in ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  patient_name text not null,
  patient_phone text,
  needed_date date,
  needed_time text,
  reason text,
  hospital_name text,
  location_text text,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled','completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_blood_requests_donor_status on public.blood_requests(donor_id,status,created_at desc);
create index if not exists idx_blood_requests_requester on public.blood_requests(requester_id,created_at desc);

-- 3) Public ambulance directory. Admin/super admin manage records.
create table if not exists public.ambulance_services (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null,
  alternate_phone text,
  address text,
  service_area text,
  ambulance_type text,
  latitude double precision,
  longitude double precision,
  is_available boolean not null default true,
  is_verified boolean not null default false,
  description text,
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_ambulance_location on public.ambulance_services(latitude,longitude);

-- 4) Public donor directory RPC: exposes only voluntary/public contact fields,
--    never exact donor coordinates. Distance is calculated server-side.
create or replace function public.search_blood_donors(
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
  distance_km double precision
)
language sql
security definer
set search_path=public
stable
as $$
  select
    p.id,
    p.full_name,
    case when p.blood_public_phone then p.phone else null end as phone,
    p.blood_group,
    p.last_blood_donation_date,
    p.location_district,
    p.location_upazila,
    case
      when p_latitude is null or p_longitude is null or p.location_latitude is null or p.location_longitude is null then null
      else 6371 * 2 * asin(sqrt(
        power(sin(radians(p.location_latitude-p_latitude)/2),2) +
        cos(radians(p_latitude))*cos(radians(p.location_latitude))*power(sin(radians(p.location_longitude-p_longitude)/2),2)
      ))
    end as distance_km
  from public.profiles p
  where p.role='patient'
    and p.account_status='active'
    and p.blood_donor_volunteer=true
    and p.blood_group is not null
    and (p_blood_group is null or p.blood_group=p_blood_group)
  order by
    case when p_latitude is null or p_longitude is null or p.location_latitude is null or p.location_longitude is null then 1 else 0 end,
    distance_km nulls last,
    p.full_name nulls last
  limit greatest(1, least(coalesce(p_limit,30),100));
$$;
grant execute on function public.search_blood_donors(text,double precision,double precision,integer) to anon, authenticated;

-- 5) Donor requests RPC: verifies donor is a voluntary donor before creating.
create or replace function public.create_blood_request(
  p_donor_id uuid,
  p_blood_group text,
  p_patient_name text,
  p_patient_phone text,
  p_needed_date date,
  p_needed_time text,
  p_reason text,
  p_hospital_name text,
  p_location_text text
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'লগইন করতে হবে'; end if;
  if not exists(select 1 from public.profiles where id=p_donor_id and role='patient' and blood_donor_volunteer=true and blood_group=p_blood_group and account_status='active') then
    raise exception 'এই ব্যক্তি বর্তমানে স্বেচ্ছাসেবী রক্তদাতা হিসেবে সক্রিয় নন।';
  end if;
  insert into public.blood_requests(requester_id,donor_id,blood_group,patient_name,patient_phone,needed_date,needed_time,reason,hospital_name,location_text)
  values(auth.uid(),p_donor_id,p_blood_group,p_patient_name,p_patient_phone,p_needed_date,p_needed_time,p_reason,p_hospital_name,p_location_text)
  returning id into v_id;
  return v_id;
end;
$$;
grant execute on function public.create_blood_request(uuid,text,text,text,date,text,text,text,text) to authenticated;

-- 6) RLS.
alter table public.blood_requests enable row level security;
alter table public.ambulance_services enable row level security;

create policy "blood_requests_select_participants" on public.blood_requests
for select using (requester_id=auth.uid() or donor_id=auth.uid() or public.is_admin_or_above());
create policy "blood_requests_update_participants" on public.blood_requests
for update using (donor_id=auth.uid() or requester_id=auth.uid() or public.is_admin_or_above())
with check (donor_id=auth.uid() or requester_id=auth.uid() or public.is_admin_or_above());
create policy "blood_requests_delete_requester" on public.blood_requests
for delete using (requester_id=auth.uid() or public.is_admin_or_above());

create policy "ambulance_public_read" on public.ambulance_services
for select using (true);
create policy "ambulance_admin_insert" on public.ambulance_services
for insert with check (public.is_admin_or_above());
create policy "ambulance_admin_update" on public.ambulance_services
for update using (public.is_admin_or_above()) with check (public.is_admin_or_above());
create policy "ambulance_admin_delete" on public.ambulance_services
for delete using (public.is_admin_or_above());

-- Donor profile updates: existing profiles_update_own policy already permits normal
-- profile fields. These fields therefore need no special self-update policy.

-- 7) Timestamp helper.
create or replace function public.set_blood_ambulance_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists trg_blood_requests_updated_at on public.blood_requests;
create trigger trg_blood_requests_updated_at before update on public.blood_requests for each row execute procedure public.set_blood_ambulance_updated_at();
drop trigger if exists trg_ambulance_updated_at on public.ambulance_services;
create trigger trg_ambulance_updated_at before update on public.ambulance_services for each row execute procedure public.set_blood_ambulance_updated_at();

-- 8) Minimal starter ambulance data. Admin can edit/delete these later.
insert into public.ambulance_services(name,phone,address,service_area,ambulance_type,is_available,is_verified,description)
select * from (values
  ('সিরাজগঞ্জ অ্যাম্বুলেন্স সার্ভিস','01700000001','সিরাজগঞ্জ সদর','সিরাজগঞ্জ ও আশেপাশের এলাকা','এসি অ্যাম্বুলেন্স',true,true,'২৪ ঘণ্টা জরুরি পরিবহন'),
  ('সিরাজগঞ্জ সদর অ্যাম্বুলেন্স','01700000002','সিরাজগঞ্জ সদর হাসপাতাল এলাকা','সিরাজগঞ্জ জেলা','নন-এসি অ্যাম্বুলেন্স',true,true,'জরুরি রোগী পরিবহন')
) as v(name,phone,address,service_area,ambulance_type,is_available,is_verified,description)
where not exists (select 1 from public.ambulance_services);

-- 9) Useful indexes for public doctor/location search.
create index if not exists idx_profiles_blood_volunteer on public.profiles(blood_donor_volunteer,blood_group) where blood_donor_volunteer=true;
create index if not exists idx_profiles_location on public.profiles(location_latitude,location_longitude);

-- 10) Chamber/Hospital accounts can own chambers and publish multiple doctor profiles.
create or replace function public.is_doctor_account_public(p_owner_id uuid)
returns boolean language sql security definer set search_path=public stable as $$
  select exists(select 1 from public.profiles where id=p_owner_id and role in ('doctor','hospital') and seller_status='approved' and account_status='active');
$$;

drop policy if exists "shops_insert_approved_seller" on public.shops;
create policy "shops_insert_approved_provider" on public.shops for insert with check
  (owner_id=auth.uid() and exists(select 1 from public.profiles where id=auth.uid() and role in ('doctor','hospital') and seller_status='approved' and account_status='active'));

drop policy if exists "products_insert_own_shop" on public.products;
create policy "products_insert_own_provider_shop" on public.products for insert with check
  (exists(select 1 from public.shops s join public.profiles owner on owner.id=s.owner_id where s.id=shop_id and s.owner_id=auth.uid() and owner.role in ('doctor','hospital') and owner.seller_status='approved' and owner.account_status='active'));

-- Product row must reference a real Doctor, while a Hospital/Chamber owner may publish many rows.
create or replace function public.set_product_doctor_id()
returns trigger language plpgsql as $$
begin
  if new.doctor_id is null then
    select s.owner_id into new.doctor_id from public.shops s where s.id=new.shop_id;
  end if;
  if new.doctor_id is null then raise exception 'ডাক্তারের প্রোফাইলের জন্য ডাক্তার নির্বাচন করতে হবে।'; end if;
  if not exists(select 1 from public.profiles p where p.id=new.doctor_id and p.role='doctor' and p.seller_status='approved' and p.account_status='active') then
    raise exception 'শুধু অনুমোদিত ডাক্তার অ্যাকাউন্টকে Doctor Profile হিসেবে যোগ করা যাবে।';
  end if;
  if not exists(select 1 from public.shops s join public.profiles owner on owner.id=s.owner_id where s.id=new.shop_id and owner.role in ('doctor','hospital') and owner.seller_status='approved' and owner.account_status='active') then
    raise exception 'অনুমোদিত চেম্বার/হাসপাতাল প্রয়োজন।';
  end if;
  return new;
end;
$$;

-- Keep one profile per Doctor, but a Hospital/Chamber may have many doctors.
create unique index if not exists ux_one_doctor_profile_per_owner on public.products(doctor_id);
