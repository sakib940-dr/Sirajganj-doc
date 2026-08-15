-- ============================================================
-- Medical Operations Upgrade — STEP 07 / MIGRATION 17
-- ADMIN + SUPER ADMIN BLOOD DONOR DIRECTORY
-- ============================================================

create or replace function public.admin_list_blood_donors(
  p_search text default null,
  p_blood_group text default null,
  p_district text default null,
  p_upazila text default null,
  p_available_only boolean default false,
  p_limit integer default 100,
  p_offset integer default 0
)
returns table(
  id uuid,
  full_name text,
  phone text,
  address text,
  blood_group text,
  last_blood_donation_date date,
  blood_donor_volunteer boolean,
  blood_public_phone boolean,
  blood_accept_requests boolean,
  blood_is_available boolean,
  district text,
  upazila text,
  location_latitude double precision,
  location_longitude double precision,
  location_source text,
  location_updated_at timestamptz,
  blood_donor_updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.is_admin_or_above() and not public.is_trusted_backend_context() then
    raise exception 'Admin access required.';
  end if;
  return query
  select
    p.id,p.full_name,p.phone,coalesce(p.blood_address,p.address),p.blood_group,p.last_blood_donation_date,
    p.blood_donor_volunteer,p.blood_public_phone,p.blood_accept_requests,p.blood_is_available,
    coalesce(l.district,p.location_district),coalesce(l.upazila,p.location_upazila),
    case when public.is_super_admin() or public.is_trusted_backend_context() then l.latitude else null end,
    case when public.is_super_admin() or public.is_trusted_backend_context() then l.longitude else null end,
    case when public.is_super_admin() or public.is_trusted_backend_context() then l.source else null end,
    l.updated_at,p.blood_donor_updated_at
  from public.profiles p
  left join public.user_last_locations l on l.user_id=p.id
  where p.role='patient'
    and p.blood_donor_volunteer=true
    and (p_search is null or btrim(p_search)='' or coalesce(p.full_name,'') ilike '%'||p_search||'%' or coalesce(p.phone,'') ilike '%'||p_search||'%')
    and (p_blood_group is null or p_blood_group='' or p.blood_group=p_blood_group)
    and (p_district is null or p_district='' or coalesce(l.district,p.location_district)=p_district)
    and (p_upazila is null or p_upazila='' or coalesce(l.upazila,p.location_upazila)=p_upazila)
    and (not coalesce(p_available_only,false) or p.blood_is_available=true)
  order by p.blood_is_available desc,p.blood_donor_updated_at desc nulls last,p.full_name nulls last
  limit greatest(1,least(coalesce(p_limit,100),500)) offset greatest(coalesce(p_offset,0),0);
end $$;
revoke all on function public.admin_list_blood_donors(text,text,text,text,boolean,integer,integer) from public;
grant execute on function public.admin_list_blood_donors(text,text,text,text,boolean,integer,integer) to authenticated,service_role;

create or replace function public.admin_set_blood_donor_availability(
  p_user_id uuid,
  p_is_available boolean,
  p_accept_requests boolean default null
)
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.is_admin_or_above() and not public.is_trusted_backend_context() then
    raise exception 'Admin access required.';
  end if;
  update public.profiles set
    blood_is_available=coalesce(p_is_available,false),
    blood_accept_requests=coalesce(p_accept_requests,blood_accept_requests),
    blood_donor_updated_at=now()
  where id=p_user_id and role='patient' and blood_donor_volunteer=true;
  if not found then raise exception 'Blood donor not found.'; end if;
end $$;
revoke all on function public.admin_set_blood_donor_availability(uuid,boolean,boolean) from public;
grant execute on function public.admin_set_blood_donor_availability(uuid,boolean,boolean) to authenticated,service_role;

notify pgrst, 'reload schema';
