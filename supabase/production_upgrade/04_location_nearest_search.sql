-- ============================================================
-- Production Upgrade V2 — STEP 04: LOCATION / NEAREST SEARCH
-- Idempotent. Public-safe server-side distance queries.
-- ============================================================

create or replace function public.location_distance_km(
  p_lat1 double precision, p_lon1 double precision,
  p_lat2 double precision, p_lon2 double precision
)
returns double precision
language sql immutable parallel safe set search_path=public as $$
  select case
    when p_lat1 is null or p_lon1 is null or p_lat2 is null or p_lon2 is null then null
    else 6371 * 2 * asin(sqrt(
      power(sin(radians(p_lat2-p_lat1)/2),2) +
      cos(radians(p_lat1))*cos(radians(p_lat2))*power(sin(radians(p_lon2-p_lon1)/2),2)
    ))
  end;
$$;

create or replace function public.search_nearby_doctors(
  p_district text default null,
  p_upazila text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_radius_km double precision default 100,
  p_limit integer default 50,
  p_offset integer default 0
)
returns setof jsonb
language sql stable security definer set search_path=public as $$
  select to_jsonb(p)
    || jsonb_build_object(
      'shops', jsonb_build_object(
        'shop_name',s.shop_name,'chamber_name',s.chamber_name,'slug',s.slug,
        'whatsapp_number',s.whatsapp_number,'phone',s.phone,'address',s.address,
        'district',s.district,'upazila',s.upazila,'google_map_link',s.google_map_link,
        'facebook_link',s.facebook_link,'messenger_link',s.messenger_link,
        'visiting_days',s.visiting_days,'visiting_time',s.visiting_time,
        'consultation_fee',s.consultation_fee,'latitude',s.latitude,'longitude',s.longitude,
        'location_visibility',s.location_visibility
      ),
      'categories', case when c.id is null then null else jsonb_build_object('name',c.name,'slug',c.slug) end,
      'distance_km', case when p_latitude is not null and p_longitude is not null
        then round(public.location_distance_km(p_latitude,p_longitude,s.latitude,s.longitude)::numeric,2)::double precision
        else null end
    )
  from public.products p
  join public.shops s on s.id=p.shop_id
  left join public.categories c on c.id=p.category_id
  where p.is_active=true
    and s.is_active=true
    and public.is_doctor_account_public(p.doctor_id)
    and public.is_provider_account_public(s.owner_id)
    and (p_district is null or btrim(p_district)='' or s.district=p_district)
    and (p_upazila is null or btrim(p_upazila)='' or s.upazila=p_upazila)
    and (
      p_latitude is null or p_longitude is null
      or (
        s.latitude is not null and s.longitude is not null
        and public.location_distance_km(p_latitude,p_longitude,s.latitude,s.longitude) <= greatest(coalesce(p_radius_km,100),0)
      )
    )
  order by
    case when p_latitude is not null and p_longitude is not null
      then public.location_distance_km(p_latitude,p_longitude,s.latitude,s.longitude) end nulls last,
    p.view_count desc nulls last,
    p.created_at desc
  limit greatest(1,least(coalesce(p_limit,50),100))
  offset greatest(coalesce(p_offset,0),0);
$$;

revoke all on function public.search_nearby_doctors(text,text,double precision,double precision,double precision,integer,integer) from public;
grant execute on function public.search_nearby_doctors(text,text,double precision,double precision,double precision,integer,integer) to anon,authenticated,service_role;

create or replace function public.search_nearby_ambulances(
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_radius_km double precision default 100,
  p_limit integer default 50,
  p_offset integer default 0
)
returns setof jsonb
language sql stable security definer set search_path=public as $$
  select to_jsonb(a) || jsonb_build_object(
    'distance_km', case when p_latitude is not null and p_longitude is not null
      then round(public.location_distance_km(p_latitude,p_longitude,a.latitude,a.longitude)::numeric,2)::double precision
      else null end
  )
  from public.ambulance_services a
  where a.is_verified=true
    and (
      p_latitude is null or p_longitude is null
      or (
        a.latitude is not null and a.longitude is not null
        and public.location_distance_km(p_latitude,p_longitude,a.latitude,a.longitude) <= greatest(coalesce(p_radius_km,100),0)
      )
    )
  order by a.is_available desc,
    case when p_latitude is not null and p_longitude is not null
      then public.location_distance_km(p_latitude,p_longitude,a.latitude,a.longitude) end nulls last,
    a.name
  limit greatest(1,least(coalesce(p_limit,50),100))
  offset greatest(coalesce(p_offset,0),0);
$$;

revoke all on function public.search_nearby_ambulances(double precision,double precision,double precision,integer,integer) from public;
grant execute on function public.search_nearby_ambulances(double precision,double precision,double precision,integer,integer) to anon,authenticated,service_role;

-- Existing Blood Bank remains public-safe without exposing exact donor coordinates.
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
    p.location_district,
    p.location_upazila,
    case
      when p_latitude is null or p_longitude is null or p.location_latitude is null or p.location_longitude is null then null
      else public.location_distance_km(p_latitude,p_longitude,p.location_latitude,p.location_longitude)
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
  limit greatest(1,least(coalesce(p_limit,30),100));
$$;
revoke all on function public.search_blood_donors(text,double precision,double precision,integer) from public;
grant execute on function public.search_blood_donors(text,double precision,double precision,integer) to anon,authenticated,service_role;

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
  if not exists(
    select 1 from public.profiles
    where id=p_donor_id and role='patient' and blood_donor_volunteer=true
      and blood_group=p_blood_group and account_status='active'
  ) then
    raise exception 'এই ব্যক্তি বর্তমানে স্বেচ্ছাসেবী রক্তদাতা হিসেবে সক্রিয় নন।';
  end if;
  insert into public.blood_requests(
    requester_id,donor_id,blood_group,patient_name,patient_phone,needed_date,needed_time,reason,hospital_name,location_text
  ) values(
    auth.uid(),p_donor_id,p_blood_group,p_patient_name,p_patient_phone,p_needed_date,p_needed_time,p_reason,p_hospital_name,p_location_text
  ) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.create_blood_request(uuid,text,text,text,date,text,text,text,text) from public;
grant execute on function public.create_blood_request(uuid,text,text,text,date,text,text,text,text) to authenticated,service_role;

create index if not exists idx_shops_public_location_filters on public.shops(is_active,district,upazila);
create index if not exists idx_shops_lat_lon on public.shops(latitude,longitude) where latitude is not null and longitude is not null;
create index if not exists idx_profiles_blood_volunteer on public.profiles(blood_donor_volunteer,blood_group) where blood_donor_volunteer=true;
create index if not exists idx_ambulance_verified_available on public.ambulance_services(is_verified,is_available);
create index if not exists idx_ambulance_lat_lon on public.ambulance_services(latitude,longitude) where latitude is not null and longitude is not null;

notify pgrst, 'reload schema';
