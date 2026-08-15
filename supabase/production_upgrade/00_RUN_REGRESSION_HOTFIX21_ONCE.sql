-- ============================================================
-- DOCTOR V1 — REGRESSION HOTFIX 21 ONE-TIME RUNNER
-- Use this ONLY when the Medical First-10 master has already been applied.
-- Transactional: any error rolls back the hotfix.
-- ============================================================

begin;
set local statement_timeout = 0;

-- ============================================================
-- Medical Operations Regression Hotfix — MIGRATION 21
-- Restores legacy public Doctor/Chamber visibility, resilient location
-- discovery, and Super Admin bootstrap compatibility without weakening
-- the medical verification/security model.
-- Safe to re-run after 00_RUN_MEDICAL_FIRST10_ONCE.sql.
-- ============================================================

-- --------------------------------------------------------------------------
-- 1) Super Admin lockout recovery.
-- Historical Doctor V1 deployments intentionally auto-healed a missing
-- Super Admin by promoting the oldest active Admin. Preserve that contract.
-- --------------------------------------------------------------------------
do $$
declare
  v_candidate uuid;
begin
  if not exists(
    select 1 from public.profiles
    where role='super_admin' and account_status='active'
  ) then
    -- If the designated Super Admin row exists but was left banned by an old
    -- deployment, reactivate that same row instead of promoting someone else.
    select id into v_candidate
    from public.profiles
    where role='super_admin'
    order by created_at asc
    limit 1;

    if v_candidate is not null then
      update public.profiles
      set account_status='active'
      where id=v_candidate;
    else
      select id into v_candidate
      from public.profiles
      where role='admin' and account_status='active'
      order by created_at asc
      limit 1;

      if v_candidate is not null then
        update public.profiles
        set role='super_admin'
        where id=v_candidate;
      end if;
    end if;
  end if;
end $$;

-- Own-profile RPC: login/bootstrap must not depend on a drifting SELECT policy.
create or replace function public.get_my_auth_profile()
returns jsonb
language sql
stable
security definer
set search_path=public
as $$
  select to_jsonb(p)
  from public.profiles p
  where p.id=auth.uid();
$$;
revoke all on function public.get_my_auth_profile() from public;
grant execute on function public.get_my_auth_profile() to authenticated,service_role;

-- --------------------------------------------------------------------------
-- 2) Repair legacy Product = Doctor Profile rows.
-- Older marketplace-era product rows can predate products.doctor_id. The
-- stricter public policy correctly requires a Doctor identity, so backfill it
-- from the strongest deterministic sources before applying visibility rules.
-- --------------------------------------------------------------------------

-- Temporarily disable product identity/sync triggers while deterministic legacy
-- rows are repaired. The current medical trigger correctly rejects a Hospital
-- listing until an approved affiliation exists, but these rows predate that
-- rule; the migration creates grandfathered affiliations immediately below.
do $$
begin
  if exists(select 1 from pg_trigger where tgrelid='public.products'::regclass and tgname='trg_set_product_doctor_id' and not tgisinternal) then
    execute 'alter table public.products disable trigger trg_set_product_doctor_id';
  end if;
  if exists(select 1 from pg_trigger where tgrelid='public.products'::regclass and tgname='trg_sync_product_doctor_provider_link' and not tgisinternal) then
    execute 'alter table public.products disable trigger trg_sync_product_doctor_provider_link';
  end if;
end $$;

-- A prior relationship row is the strongest available mapping.
update public.products p
set doctor_id=l.doctor_id
from public.doctor_provider_links l
where p.doctor_id is null
  and l.product_id=p.id
  and l.doctor_id is not null;

-- Historical appointments can also identify a legacy Product when every
-- appointment for that Product points to one and only one Doctor.
with appointment_map as (
  select product_id,min(doctor_id::text)::uuid as doctor_id
  from public.appointments
  where product_id is not null and doctor_id is not null
  group by product_id
  having count(distinct doctor_id)=1
)
update public.products p
set doctor_id=m.doctor_id
from appointment_map m
where p.id=m.product_id
  and p.doctor_id is null
  and exists(
    select 1 from public.profiles d
    where d.id=m.doctor_id and d.role='doctor'
  );

-- Original Doctor V1 mapping: a Doctor-owned Chamber's legacy Product belongs
-- to that owner Doctor.
update public.products p
set doctor_id=s.owner_id
from public.shops s
join public.profiles d on d.id=s.owner_id and d.role='doctor'
where p.shop_id=s.id
  and p.doctor_id is null;

-- Restore normal product validation/synchronisation before application traffic
-- can see the transaction.
do $$
begin
  if exists(select 1 from pg_trigger where tgrelid='public.products'::regclass and tgname='trg_set_product_doctor_id' and not tgisinternal) then
    execute 'alter table public.products enable trigger trg_set_product_doctor_id';
  end if;
  if exists(select 1 from pg_trigger where tgrelid='public.products'::regclass and tgname='trg_sync_product_doctor_provider_link' and not tgisinternal) then
    execute 'alter table public.products enable trigger trg_sync_product_doctor_provider_link';
  end if;
end $$;

-- A legacy Hospital listing with a deterministic Doctor identity predates the
-- invitation system. Grandfather only a MISSING relationship; never overwrite
-- an explicit pending/rejected/inactive relationship.
insert into public.doctor_provider_links(
  doctor_id,provider_id,product_id,status,consultation_fee,visiting_days,visiting_time,responded_at,updated_at
)
select p.doctor_id,p.shop_id,p.id,'approved',coalesce(p.consultation_fee,p.price),p.visiting_days,p.visiting_time,now(),now()
from public.products p
join public.shops s on s.id=p.shop_id
join public.profiles d on d.id=p.doctor_id
join public.profiles owner on owner.id=s.owner_id
where p.doctor_id is not null
  and d.role='doctor' and d.seller_status='approved' and d.account_status='active'
  and owner.role in ('doctor','hospital') and owner.seller_status='approved' and owner.account_status='active'
  and not exists(
    select 1 from public.doctor_provider_links l
    where l.doctor_id=p.doctor_id and l.provider_id=p.shop_id
  )
on conflict(doctor_id,provider_id) do nothing;

-- Rebuild deterministic affiliations for repaired historical rows. A
-- Doctor-owned Chamber is the Doctor's own affiliation and remains approved.
insert into public.doctor_provider_links(
  doctor_id,provider_id,product_id,status,consultation_fee,visiting_days,visiting_time,responded_at,updated_at
)
select p.doctor_id,p.shop_id,p.id,'approved',coalesce(p.consultation_fee,p.price),p.visiting_days,p.visiting_time,now(),now()
from public.products p
join public.shops s on s.id=p.shop_id
join public.profiles owner on owner.id=s.owner_id
where p.doctor_id is not null
  and owner.role='doctor'
  and owner.id=p.doctor_id
on conflict(doctor_id,provider_id) do update set
  product_id=excluded.product_id,
  status='approved',
  consultation_fee=excluded.consultation_fee,
  visiting_days=excluded.visiting_days,
  visiting_time=excluded.visiting_time,
  responded_at=coalesce(public.doctor_provider_links.responded_at,excluded.responded_at),
  updated_at=now();

-- Existing chambers that never opened Website Builder still receive a complete
-- default config. Explicit owner choices (including enabled=false) are kept.
update public.shops
set website_config = jsonb_build_object(
  'enabled',true,
  'hero_title',coalesce(shop_name,'চেম্বার / হাসপাতাল'),
  'hero_subtitle','সিরাজগঞ্জের রোগীদের জন্য বিশ্বস্ত চিকিৎসা সেবা',
  'about_title','আমাদের সম্পর্কে',
  'contact_title','যোগাযোগ ও দিকনির্দেশনা',
  'show_doctors',true,
  'show_gallery',true,
  'show_about',true,
  'cta_text','অ্যাপয়েন্টমেন্ট নিন'
) || coalesce(website_config,'{}'::jsonb)
where website_config is null or website_config='{}'::jsonb;

-- Public Product visibility must NOT join private profiles/link tables under
-- the anonymous caller's RLS context. This SECURITY DEFINER helper returns only
-- a boolean public-eligibility decision and keeps private profile fields hidden.
create or replace function public.is_public_doctor_listing(p_provider_id uuid,p_doctor_id uuid)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select exists(
    select 1
    from public.shops s
    join public.profiles owner on owner.id=s.owner_id
    join public.profiles doctor on doctor.id=coalesce(
      p_doctor_id,
      case when owner.role='doctor' then owner.id else null end
    )
    where s.id=p_provider_id
      and s.is_active=true
      and owner.role in ('doctor','hospital')
      and owner.seller_status='approved'
      and owner.account_status='active'
      and doctor.role='doctor'
      and doctor.seller_status='approved'
      and doctor.account_status='active'
      and (
        (owner.role='doctor' and doctor.id=owner.id)
        or (
          owner.role='hospital'
          and exists(
            select 1 from public.doctor_provider_links l
            where l.doctor_id=doctor.id
              and l.provider_id=s.id
              and l.status='approved'
          )
        )
      )
  );
$$;
revoke all on function public.is_public_doctor_listing(uuid,uuid) from public;
grant execute on function public.is_public_doctor_listing(uuid,uuid) to anon,authenticated,service_role;

-- Public Product policy now delegates all private eligibility checks to the
-- public-safe helper. Legacy Doctor-owned rows with doctor_id=NULL are resolved
-- by the helper without exposing profiles directly.
drop policy if exists "products_select_public_active" on public.products;
create policy "products_select_public_active" on public.products for select using (
  (is_active=true and public.is_public_doctor_listing(shop_id,doctor_id))
  or public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=products.shop_id and s.owner_id=auth.uid())
);

-- --------------------------------------------------------------------------
-- 3) Location normalization + resilient district discovery.
-- --------------------------------------------------------------------------
create or replace function public.normalize_doctor_district(p_value text)
returns text
language sql
immutable
set search_path=public
as $$
  select case
    when p_value is null or btrim(p_value)='' then ''
    when lower(btrim(p_value)) in ('sirajganj','sirajganj district') or btrim(p_value) like '%সিরাজগঞ্জ%' then 'sirajganj'
    else lower(btrim(p_value))
  end;
$$;

create or replace function public.normalize_doctor_upazila(p_value text)
returns text
language sql
immutable
set search_path=public
as $$
  select case
    when p_value is null or btrim(p_value)='' then ''
    when lower(btrim(p_value)) in ('sirajganj sadar','sirajganj sadar upazila') or btrim(p_value)='সিরাজগঞ্জ সদর' then 'sirajganj-sadar'
    when lower(btrim(p_value)) in ('belkuchi','belkuchi upazila') or btrim(p_value)='বেলকুচি' then 'belkuchi'
    when lower(btrim(p_value)) in ('chauhali','chowhali','chauhali upazila') or btrim(p_value)='চৌহালী' then 'chauhali'
    when lower(btrim(p_value)) in ('kamarkhanda','kamarkhand','kamarkhanda upazila') or btrim(p_value)='কামারখন্দ' then 'kamarkhanda'
    when lower(btrim(p_value)) in ('kazipur','kazipur upazila') or btrim(p_value)='কাজীপুর' then 'kazipur'
    when lower(btrim(p_value)) in ('raiganj','rayganj','raiganj upazila') or btrim(p_value)='রায়গঞ্জ' then 'raiganj'
    when lower(btrim(p_value)) in ('shahjadpur','shahzadpur','shahjadpur upazila') or btrim(p_value)='শাহজাদপুর' then 'shahjadpur'
    when lower(btrim(p_value)) in ('tarash','tarash upazila') or btrim(p_value)='তাড়াশ' then 'tarash'
    when lower(btrim(p_value)) in ('ullapara','ullahpara','ullapara upazila') or btrim(p_value)='উল্লাপাড়া' then 'ullapara'
    else lower(btrim(p_value))
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
language sql
stable
security definer
set search_path=public
as $$
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
      'categories',case when c.id is null then null else jsonb_build_object('name',c.name,'slug',c.slug) end,
      'distance_km',case when p_latitude is not null and p_longitude is not null and s.latitude is not null and s.longitude is not null
        then round(public.location_distance_km(p_latitude,p_longitude,s.latitude,s.longitude)::numeric,2)::double precision
        else null end
    )
  from public.products p
  join public.shops s on s.id=p.shop_id
  join public.profiles owner on owner.id=s.owner_id
  left join public.categories c on c.id=p.category_id
  where p.is_active=true
    and s.is_active=true
    and public.is_provider_account_public(s.owner_id)
    and public.is_doctor_account_public(
      coalesce(p.doctor_id,case when owner.role='doctor' then s.owner_id else null end)
    )
    and (
      p_district is null or btrim(p_district)=''
      or public.normalize_doctor_district(s.district)=public.normalize_doctor_district(p_district)
    )
    and (
      p_upazila is null or btrim(p_upazila)=''
      or public.normalize_doctor_upazila(s.upazila)=public.normalize_doctor_upazila(p_upazila)
    )
    and (
      -- Once a district/upazila is known, do not hide valid same-area Doctors
      -- merely because an old Chamber has no exact coordinates.
      (p_district is not null and btrim(p_district)<>'')
      or p_latitude is null or p_longitude is null
      or (
        s.latitude is not null and s.longitude is not null
        and public.location_distance_km(p_latitude,p_longitude,s.latitude,s.longitude)<=greatest(coalesce(p_radius_km,100),0)
      )
    )
  order by
    case when p_latitude is not null and p_longitude is not null and s.latitude is not null and s.longitude is not null
      then public.location_distance_km(p_latitude,p_longitude,s.latitude,s.longitude) end nulls last,
    p.view_count desc nulls last,
    p.created_at desc
  limit greatest(1,least(coalesce(p_limit,50),100))
  offset greatest(coalesce(p_offset,0),0);
$$;
revoke all on function public.search_nearby_doctors(text,text,double precision,double precision,double precision,integer,integer) from public;
grant execute on function public.search_nearby_doctors(text,text,double precision,double precision,double precision,integer,integer) to anon,authenticated,service_role;

-- --------------------------------------------------------------------------
-- 4) Integrity notices/assertions. These do not fail for unresolved Hospital
-- legacy products because they need a human Doctor mapping rather than a guess.
-- --------------------------------------------------------------------------
do $$
declare
  v_active_super_admins integer;
  v_repaired_visible integer;
  v_unresolved integer;
begin
  select count(*) into v_active_super_admins
  from public.profiles where role='super_admin' and account_status='active';
  if v_active_super_admins=0 then
    raise warning '[HOTFIX21] No active Super Admin could be auto-restored. Other regression repairs will still commit; promote a trusted Admin manually if needed.';
  end if;

  select count(*) into v_repaired_visible
  from public.products p
  join public.shops s on s.id=p.shop_id
  where p.is_active=true and p.doctor_id is not null and s.is_active=true;

  select count(*) into v_unresolved
  from public.products p
  where p.is_active=true and p.doctor_id is null;

  raise notice '[HOTFIX21] Active mapped Doctor profiles: %, unresolved active legacy profiles: %',v_repaired_visible,v_unresolved;
end $$;

insert into public.backend_schema_versions(version,notes)
values(
  'doctor-v1-medical-regression-hotfix21',
  'Legacy Doctor visibility repair, district/location discovery normalization, resilient own-profile auth and Super Admin lockout recovery.'
)
on conflict(version) do update set applied_at=now(),notes=excluded.notes;

notify pgrst, 'reload schema';

commit;
