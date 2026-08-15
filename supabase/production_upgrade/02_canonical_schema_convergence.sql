-- ============================================================
-- Production Upgrade V2 — STEP 02: CANONICAL SCHEMA CONVERGENCE
-- Idempotent. Designed for an existing Doctor V1 production DB.
-- Historical migrations are intentionally NOT replayed.
-- ============================================================

create extension if not exists pgcrypto;

-- Fail early if the indispensable legacy/core objects are not present.
do $$
begin
  if to_regclass('public.profiles') is null then raise exception '[STEP02] public.profiles is missing'; end if;
  if to_regclass('public.shops') is null then raise exception '[STEP02] public.shops is missing'; end if;
  if to_regclass('public.products') is null then raise exception '[STEP02] public.products is missing'; end if;
  if to_regclass('public.categories') is null then raise exception '[STEP02] public.categories is missing'; end if;
  if to_regclass('public.site_settings') is null then raise exception '[STEP02] public.site_settings is missing'; end if;
end $$;

-- --------------------------------------------------------------------------
-- 1) Profiles: converge old marketplace roles to the Doctor V1 role model.
-- --------------------------------------------------------------------------
alter table public.profiles
  add column if not exists full_name text,
  add column if not exists phone text,
  add column if not exists email text,
  add column if not exists role text,
  add column if not exists seller_status text,
  add column if not exists account_status text not null default 'active',
  add column if not exists gender text,
  add column if not exists avatar_url text,
  add column if not exists address text,
  add column if not exists phone_public boolean not null default false,
  add column if not exists location_latitude double precision,
  add column if not exists location_longitude double precision,
  add column if not exists location_district text,
  add column if not exists location_upazila text,
  add column if not exists location_updated_at timestamptz,
  add column if not exists blood_group text,
  add column if not exists blood_donor_volunteer boolean not null default false,
  add column if not exists blood_public_phone boolean not null default false,
  add column if not exists last_blood_donation_date date,
  add column if not exists blood_donor_updated_at timestamptz,
  add column if not exists created_at timestamptz not null default now();

-- Legacy values only. Modern role values are left untouched.
update public.profiles set role='patient' where role is null or role='visitor';
update public.profiles set role='doctor' where role='seller';
update public.profiles set role='patient' where role not in ('patient','doctor','hospital','admin','super_admin');
update public.profiles set seller_status='none' where seller_status is null or seller_status not in ('none','pending','approved','rejected');
update public.profiles set account_status='active' where account_status is null or account_status not in ('active','banned');
update public.profiles set gender=lower(gender) where gender is not null and lower(gender) in ('male','female','other');
update public.profiles set gender=null where gender is not null and gender not in ('male','female','other');
update public.profiles set blood_group=null where blood_group is not null and blood_group not in ('A+','A-','B+','B-','AB+','AB-','O+','O-');

alter table public.profiles alter column role set default 'patient';
alter table public.profiles alter column role set not null;
alter table public.profiles alter column seller_status set default 'none';
alter table public.profiles alter column seller_status set not null;

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('patient','doctor','hospital','admin','super_admin'));
alter table public.profiles drop constraint if exists profiles_seller_status_check;
alter table public.profiles add constraint profiles_seller_status_check
  check (seller_status in ('none','pending','approved','rejected'));
alter table public.profiles drop constraint if exists profiles_account_status_check;
alter table public.profiles add constraint profiles_account_status_check
  check (account_status in ('active','banned'));
alter table public.profiles drop constraint if exists profiles_gender_check;
alter table public.profiles add constraint profiles_gender_check
  check (gender is null or gender in ('male','female','other'));
alter table public.profiles drop constraint if exists profiles_blood_group_check;
alter table public.profiles add constraint profiles_blood_group_check
  check (blood_group is null or blood_group in ('A+','A-','B+','B-','AB+','AB-','O+','O-'));

-- --------------------------------------------------------------------------
-- 2) Shops: one provider-owned public chamber/hospital record.
-- --------------------------------------------------------------------------
alter table public.shops
  add column if not exists chamber_name text,
  add column if not exists chamber_type text,
  add column if not exists district text,
  add column if not exists upazila text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists visiting_days text,
  add column if not exists visiting_time text,
  add column if not exists consultation_fee numeric(12,2),
  add column if not exists assistant_phone text,
  add column if not exists messenger_link text,
  add column if not exists hospital_photo_urls text[] not null default '{}',
  add column if not exists phone_public boolean not null default true,
  add column if not exists whatsapp_public boolean not null default false,
  add column if not exists assistant_phone_public boolean not null default false,
  add column if not exists website_config jsonb not null default '{}'::jsonb,
  add column if not exists location_visibility boolean not null default true,
  add column if not exists max_products_override integer;

alter table public.shops drop constraint if exists shops_max_products_override_check;
alter table public.shops add constraint shops_max_products_override_check
  check (max_products_override is null or max_products_override > 0);

-- --------------------------------------------------------------------------
-- 3) Products: keep the current frontend contract, but converge medical fields.
-- --------------------------------------------------------------------------
alter table public.products
  add column if not exists doctor_id uuid references public.profiles(id) on delete cascade,
  add column if not exists name_en text,
  add column if not exists name_bn text,
  add column if not exists search_keywords text,
  add column if not exists degree text,
  add column if not exists designation text,
  add column if not exists bmdc_registration_no text,
  add column if not exists consultation_fee numeric(12,2),
  add column if not exists visiting_days text,
  add column if not exists visiting_time text,
  add column if not exists profile_photo_url text,
  add column if not exists verified_badge boolean not null default false,
  add column if not exists specialty text,
  add column if not exists view_count integer not null default 0,
  add column if not exists save_count integer not null default 0,
  add column if not exists click_count integer not null default 0,
  add column if not exists sold_count integer not null default 0,
  add column if not exists stock_quantity integer not null default 0,
  add column if not exists discount_type text not null default 'none',
  add column if not exists discount_value numeric(12,2) not null default 0;

update public.products
set consultation_fee = coalesce(consultation_fee, price),
    profile_photo_url = coalesce(profile_photo_url, thumbnail_url)
where consultation_fee is null or profile_photo_url is null;
update public.products set view_count=greatest(coalesce(view_count,0),0), save_count=greatest(coalesce(save_count,0),0), click_count=greatest(coalesce(click_count,0),0), sold_count=greatest(coalesce(sold_count,0),0), stock_quantity=greatest(coalesce(stock_quantity,0),0);
update public.products set discount_type='none',discount_value=0 where discount_value is null or discount_value<0 or (discount_type='percentage' and discount_value>100);
update public.products set discount_type='none' where discount_type is null;

alter table public.products drop constraint if exists products_view_count_check;
alter table public.products add constraint products_view_count_check check (view_count >= 0);
alter table public.products drop constraint if exists products_save_count_check;
alter table public.products add constraint products_save_count_check check (save_count >= 0);
alter table public.products drop constraint if exists products_click_count_check;
alter table public.products add constraint products_click_count_check check (click_count >= 0);
alter table public.products drop constraint if exists products_stock_quantity_check;
alter table public.products add constraint products_stock_quantity_check check (stock_quantity >= 0);
alter table public.products drop constraint if exists products_sold_count_check;
alter table public.products add constraint products_sold_count_check check (sold_count >= 0);
alter table public.products drop constraint if exists products_discount_percentage_check;
alter table public.products add constraint products_discount_percentage_check
  check (discount_type <> 'percentage' or discount_value <= 100);

-- Category hierarchy used by the existing UI.
alter table public.categories
  add column if not exists parent_id uuid references public.categories(id) on delete cascade;

-- --------------------------------------------------------------------------
-- 4) Verification table: support both Doctor and Hospital proof flows/history.
-- --------------------------------------------------------------------------
create table if not exists public.seller_verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.seller_verifications
  add column if not exists status text not null default 'pending',
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists full_name text,
  add column if not exists profile_photo_url text,
  add column if not exists phone text,
  add column if not exists address text,
  add column if not exists google_map_link text,
  add column if not exists facebook_link text,
  add column if not exists nid_number text,
  add column if not exists nid_front_url text,
  add column if not exists nid_back_url text,
  add column if not exists admin_note text,
  add column if not exists verification_type text default 'bmdc',
  add column if not exists trade_license_no text,
  add column if not exists trade_license_url text,
  add column if not exists degree text,
  add column if not exists specialty text,
  add column if not exists designation text,
  add column if not exists bmdc_registration_no text,
  add column if not exists bmdc_document_url text,
  add column if not exists chamber_name text,
  add column if not exists chamber_address text,
  add column if not exists visiting_days text,
  add column if not exists visiting_time text,
  add column if not exists consultation_fee numeric(12,2),
  add column if not exists business_type text,
  add column if not exists product_type text,
  add column if not exists avg_monthly_sales_bdt numeric(14,2),
  add column if not exists monthly_sales_target_bdt numeric(14,2),
  add column if not exists sales_channel text,
  add column if not exists sells_via_facebook_page boolean,
  add column if not exists uses_other_ecommerce_platform boolean,
  add column if not exists other_ecommerce_platform_name text;

update public.seller_verifications set status='pending' where status is null or status not in ('pending','approved','rejected');

-- Preserve application history: old schemas had UNIQUE(user_id).
alter table public.seller_verifications drop constraint if exists seller_verifications_user_id_key;
alter table public.seller_verifications drop constraint if exists seller_verifications_status_check;
alter table public.seller_verifications add constraint seller_verifications_status_check
  check (status in ('pending','approved','rejected'));

-- --------------------------------------------------------------------------
-- 5) Appointment/blood/ambulance baseline if a historical deployment skipped it.
-- --------------------------------------------------------------------------
create sequence if not exists public.appointment_number_seq;

create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  appointment_number text unique,
  doctor_id uuid not null references public.profiles(id) on delete cascade,
  patient_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  shop_id uuid references public.shops(id) on delete set null,
  doctor_name text,
  patient_name text,
  patient_phone text,
  chamber_name text,
  appointment_date date not null,
  appointment_time text,
  note text,
  status text not null default 'pending',
  doctor_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.appointments
  add column if not exists appointment_number text,
  add column if not exists doctor_id uuid references public.profiles(id) on delete cascade,
  add column if not exists patient_id uuid references public.profiles(id) on delete cascade,
  add column if not exists product_id uuid references public.products(id) on delete set null,
  add column if not exists shop_id uuid references public.shops(id) on delete set null,
  add column if not exists doctor_name text,
  add column if not exists patient_name text,
  add column if not exists patient_phone text,
  add column if not exists chamber_name text,
  add column if not exists appointment_date date,
  add column if not exists appointment_time text,
  add column if not exists note text,
  add column if not exists status text not null default 'pending',
  add column if not exists doctor_note text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();
update public.appointments set status='pending' where status is null or status not in ('pending','confirmed','cancelled','completed','rescheduled');

alter table public.appointments drop constraint if exists appointments_status_check;
alter table public.appointments add constraint appointments_status_check
  check (status in ('pending','confirmed','cancelled','completed','rescheduled'));

create table if not exists public.blood_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  donor_id uuid not null references public.profiles(id) on delete cascade,
  blood_group text not null,
  patient_name text not null,
  patient_phone text,
  needed_date date,
  needed_time text,
  reason text,
  hospital_name text,
  location_text text,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.blood_requests drop constraint if exists blood_requests_blood_group_check;
alter table public.blood_requests add constraint blood_requests_blood_group_check
  check (blood_group in ('A+','A-','B+','B-','AB+','AB-','O+','O-'));
alter table public.blood_requests drop constraint if exists blood_requests_status_check;
alter table public.blood_requests add constraint blood_requests_status_check
  check (status in ('pending','accepted','declined','cancelled','completed'));

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

alter table public.ambulance_services
  add column if not exists name text,
  add column if not exists phone text,
  add column if not exists alternate_phone text,
  add column if not exists address text,
  add column if not exists service_area text,
  add column if not exists ambulance_type text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists is_available boolean not null default true,
  add column if not exists is_verified boolean not null default false,
  add column if not exists description text,
  add column if not exists image_url text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

-- --------------------------------------------------------------------------
-- 6) Canonical helper/RPC semantics used by all later RLS and migrations.
-- --------------------------------------------------------------------------
create or replace function public.is_admin_or_above()
returns boolean language sql security definer set search_path=public stable as $$
  select exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','super_admin') and account_status='active');
$$;

create or replace function public.is_super_admin()
returns boolean language sql security definer set search_path=public stable as $$
  select exists(select 1 from public.profiles where id=auth.uid() and role='super_admin' and account_status='active');
$$;

create or replace function public.count_super_admins()
returns integer language sql security definer set search_path=public stable as $$
  select count(*)::integer from public.profiles where role='super_admin' and account_status='active';
$$;

create or replace function public.is_provider_account_public(p_owner_id uuid)
returns boolean language sql security definer set search_path=public stable as $$
  select exists(
    select 1 from public.profiles
    where id=p_owner_id and role in ('doctor','hospital')
      and seller_status='approved' and account_status='active'
  );
$$;

create or replace function public.is_doctor_account_public(p_owner_id uuid)
returns boolean language sql security definer set search_path=public stable as $$
  select exists(
    select 1 from public.profiles
    where id=p_owner_id and role='doctor'
      and seller_status='approved' and account_status='active'
  );
$$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id, full_name, email, phone, role, seller_status, account_status)
  values(new.id, new.raw_user_meta_data->>'full_name', new.email, new.raw_user_meta_data->>'phone', 'patient', 'none', 'active')
  on conflict(id) do update set
    email=coalesce(excluded.email, public.profiles.email),
    full_name=coalesce(public.profiles.full_name, excluded.full_name),
    phone=coalesce(public.profiles.phone, excluded.phone);
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.request_doctor_status()
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  perform set_config('app.bypass_role_guard','true',true);
  update public.profiles
    set role='doctor', seller_status='pending'
  where id=auth.uid()
    and role in ('patient','doctor')
    and seller_status in ('none','rejected');
end $$;

create or replace function public.request_hospital_status()
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  perform set_config('app.bypass_role_guard','true',true);
  update public.profiles
    set role='hospital', seller_status='pending'
  where id=auth.uid()
    and role in ('patient','hospital')
    and seller_status in ('none','rejected');
end $$;

create or replace function public.request_seller_status()
returns void language plpgsql security definer set search_path=public as $$
begin
  perform public.request_doctor_status();
end $$;

-- Sync approved/rejected verification decisions to provider status.
create or replace function public.sync_provider_verification_status()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status in ('approved','rejected') then
    perform set_config('app.bypass_role_guard','true',true);
    update public.profiles
      set seller_status=new.status
      where id=new.user_id and role in ('doctor','hospital');
  end if;
  return new;
end $$;

drop trigger if exists trg_sync_provider_verification_status on public.seller_verifications;
create trigger trg_sync_provider_verification_status
  after insert or update of status on public.seller_verifications
  for each row execute procedure public.sync_provider_verification_status();

-- Explicit execution posture. Helpers are required by RLS for anon reads.
revoke all on function public.is_admin_or_above() from public;
revoke all on function public.is_super_admin() from public;
revoke all on function public.count_super_admins() from public;
revoke all on function public.is_provider_account_public(uuid) from public;
revoke all on function public.is_doctor_account_public(uuid) from public;
revoke all on function public.request_doctor_status() from public;
revoke all on function public.request_hospital_status() from public;
revoke all on function public.request_seller_status() from public;

grant execute on function public.is_admin_or_above() to anon, authenticated, service_role;
grant execute on function public.is_super_admin() to anon, authenticated, service_role;
grant execute on function public.count_super_admins() to authenticated, service_role;
grant execute on function public.is_provider_account_public(uuid) to anon, authenticated, service_role;
grant execute on function public.is_doctor_account_public(uuid) to anon, authenticated, service_role;
grant execute on function public.request_doctor_status() to authenticated;
grant execute on function public.request_hospital_status() to authenticated;
grant execute on function public.request_seller_status() to authenticated;

-- Canonical baseline indexes used immediately by existing frontend queries.
create index if not exists idx_profiles_role_status on public.profiles(role, seller_status, account_status);
create index if not exists idx_shops_owner on public.shops(owner_id);
create index if not exists idx_shops_district_upazila on public.shops(district, upazila);
create index if not exists idx_categories_parent on public.categories(parent_id);
create index if not exists idx_products_shop on public.products(shop_id);
create index if not exists idx_products_category on public.products(category_id);
create index if not exists idx_products_doctor on public.products(doctor_id);
create index if not exists idx_seller_verifications_user on public.seller_verifications(user_id, created_at desc);
do $$ begin
  if to_regclass('public.ux_appointments_number') is null and not exists(
    select 1 from public.appointments where appointment_number is not null group by appointment_number having count(*)>1
  ) then
    execute 'create unique index ux_appointments_number on public.appointments(appointment_number) where appointment_number is not null';
  end if;
end $$;

notify pgrst, 'reload schema';
