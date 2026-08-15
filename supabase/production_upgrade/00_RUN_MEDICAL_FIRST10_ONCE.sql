-- ============================================================
-- DOCTOR V1 — MEDICAL OPERATIONS MASTER UPGRADE + REGRESSION FIX 21
-- Generated from canonical production_upgrade migrations 02..21.
-- For a DB that has NOT yet applied the prior Medical First-10 master.
-- Existing upgraded production DBs should run 00_RUN_REGRESSION_HOTFIX21_ONCE.sql instead.
-- DO NOT run historical clean snapshots, root step*.sql, or demo-data cleanup scripts.
-- Transactional: any SQL error rolls back the entire batch.
-- ============================================================

begin;
set local statement_timeout = 0;

-- >>> BEGIN 02_canonical_schema_convergence.sql
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
-- <<< END 02_canonical_schema_convergence.sql

-- >>> BEGIN 03_rls_rpc_security_hardening.sql
-- ============================================================
-- Production Upgrade V2 — STEP 03: RLS / RPC / STORAGE HARDENING
-- Idempotent. Preserves the current UI contract while closing known leaks.
-- ============================================================

-- Runtime caller helper. SECURITY DEFINER functions must not trust `current_user`,
-- because it becomes the function owner. JWT role/uid distinguish app callers from
-- service-role/direct trusted maintenance sessions.
create or replace function public.is_trusted_backend_context()
returns boolean
language sql
stable
set search_path=public
as $$
  select coalesce(auth.role(),'')='service_role'
     or (auth.uid() is null and auth.role() is null);
$$;
revoke all on function public.is_trusted_backend_context() from public;
grant execute on function public.is_trusted_backend_context() to anon,authenticated,service_role;

-- --------------------------------------------------------------------------
-- 1) Role/account guard. Admin can review provider status, but only Super Admin
--    can change role/account_status. Providers cannot self-approve.
-- --------------------------------------------------------------------------
create or replace function public.prevent_self_role_change()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  -- Hard invariant: the last active Super Admin cannot disappear.
  if old.role='super_admin' and old.account_status='active'
     and (new.role is distinct from 'super_admin' or new.account_status is distinct from 'active')
     and public.count_super_admins() <= 1 then
    raise exception 'The last active Super Admin cannot be demoted or banned.';
  end if;

  -- SQL editor / service-role remains the emergency/bootstrap path.
  if current_user in ('service_role','postgres','supabase_admin') then return new; end if;

  -- App clients cannot create a second Super Admin through profile updates.
  if new.role='super_admin' and old.role is distinct from 'super_admin' then
    raise exception 'Creating/transferring the Super Admin must use the trusted admin/bootstrap path.';
  end if;

  if auth.uid()=old.id
     and not public.is_super_admin()
     and coalesce(current_setting('app.bypass_role_guard',true),'false') <> 'true'
     and (
       new.role is distinct from old.role
       or new.seller_status is distinct from old.seller_status
       or new.account_status is distinct from old.account_status
     ) then
    raise exception 'Role, provider verification status and account status cannot be changed by yourself.';
  end if;

  if (new.role is distinct from old.role or new.account_status is distinct from old.account_status)
     and not public.is_super_admin() then
    raise exception 'Only the Super Admin can change role/account status.';
  end if;
  return new;
end $$;

drop trigger if exists trg_prevent_self_role_change on public.profiles;
create trigger trg_prevent_self_role_change
  before update on public.profiles
  for each row execute procedure public.prevent_self_role_change();

-- Verification status cannot be changed by the applicant.
create or replace function public.prevent_self_verification_status_change()
returns trigger language plpgsql set search_path=public as $$
begin
  if auth.uid()=old.user_id and not public.is_admin_or_above()
     and new.status is distinct from old.status then
    raise exception 'Verification status can only be changed by an Admin.';
  end if;
  return new;
end $$;

drop trigger if exists trg_prevent_self_verification_status_change on public.seller_verifications;
create trigger trg_prevent_self_verification_status_change
  before update on public.seller_verifications
  for each row execute procedure public.prevent_self_verification_status_change();

-- --------------------------------------------------------------------------
-- 2) Safe provider-only doctor chooser. Do NOT expose full profiles publicly.
-- --------------------------------------------------------------------------
create or replace function public.list_approved_doctors_for_provider()
returns table(id uuid, full_name text)
language sql security definer set search_path=public stable as $$
  select p.id, p.full_name
  from public.profiles p
  where p.role='doctor'
    and p.seller_status='approved'
    and p.account_status='active'
    and (
      public.is_admin_or_above()
      or exists(
        select 1 from public.profiles caller
        where caller.id=auth.uid()
          and caller.role in ('doctor','hospital')
          and caller.seller_status='approved'
          and caller.account_status='active'
      )
    )
  order by p.full_name nulls last;
$$;
revoke all on function public.list_approved_doctors_for_provider() from public;
grant execute on function public.list_approved_doctors_for_provider() to authenticated, service_role;

-- --------------------------------------------------------------------------
-- 3) Canonical RLS: profiles / shops / products / verification.
-- --------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.shops enable row level security;
alter table public.products enable row level security;
alter table public.product_images enable row level security;
alter table public.shop_gallery enable row level security;
alter table public.categories enable row level security;
alter table public.seller_verifications enable row level security;
alter table public.appointments enable row level security;
alter table public.blood_requests enable row level security;
alter table public.ambulance_services enable row level security;

-- profiles: never expose the complete row to anonymous users.
drop policy if exists "profiles_select_own_or_admin" on public.profiles;
drop policy if exists "profiles_select_approved_doctors" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "profiles_update_admin" on public.profiles;
create policy "profiles_select_own_or_admin" on public.profiles for select
  using (id=auth.uid() or public.is_admin_or_above());
create policy "profiles_update_own" on public.profiles for update
  using (id=auth.uid()) with check (id=auth.uid());
create policy "profiles_update_admin" on public.profiles for update
  using (public.is_admin_or_above()) with check (public.is_admin_or_above());

-- Shops are public only when both the row and provider account are public.
drop policy if exists "shops_select_public_active" on public.shops;
drop policy if exists "shops_insert_approved_seller" on public.shops;
drop policy if exists "shops_insert_approved_provider" on public.shops;
drop policy if exists "shops_insert_provider_profile" on public.shops;
drop policy if exists "shops_update_own_or_admin" on public.shops;
drop policy if exists "shops_delete_admin" on public.shops;
create policy "shops_select_public_active" on public.shops for select using (
  (is_active=true and public.is_provider_account_public(owner_id))
  or owner_id=auth.uid()
  or public.is_admin_or_above()
);
-- Provider may save a draft chamber before verification; RLS hides it publicly.
create policy "shops_insert_provider_profile" on public.shops for insert with check (
  owner_id=auth.uid()
  and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role in ('doctor','hospital') and p.account_status='active')
);
create policy "shops_update_own_or_admin" on public.shops for update
  using (owner_id=auth.uid() or public.is_admin_or_above())
  with check (owner_id=auth.uid() or public.is_admin_or_above());
create policy "shops_delete_admin" on public.shops for delete using (public.is_admin_or_above());

-- Product/Doctor profile public visibility must validate BOTH doctor and provider.
drop policy if exists "products_select_public_active" on public.products;
drop policy if exists "products_insert_own_shop" on public.products;
drop policy if exists "products_insert_own_provider_shop" on public.products;
drop policy if exists "products_update_own_or_admin" on public.products;
drop policy if exists "products_delete_own_or_admin" on public.products;
create policy "products_select_public_active" on public.products for select using (
  (
    is_active=true
    and public.is_doctor_account_public(doctor_id)
    and exists(
      select 1 from public.shops s
      where s.id=shop_id and s.is_active=true and public.is_provider_account_public(s.owner_id)
    )
  )
  or public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
);
create policy "products_insert_own_provider_shop" on public.products for insert with check (
  exists(
    select 1 from public.shops s
    join public.profiles owner on owner.id=s.owner_id
    where s.id=shop_id and s.owner_id=auth.uid()
      and owner.role in ('doctor','hospital')
      and owner.seller_status='approved' and owner.account_status='active'
  )
  and public.is_doctor_account_public(doctor_id)
);
create policy "products_update_own_or_admin" on public.products for update using (
  public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
) with check (
  public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
);
create policy "products_delete_own_or_admin" on public.products for delete using (
  public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
);

-- Product images: public only for a public product; owner/admin can manage.
drop policy if exists "product_images_select" on public.product_images;
drop policy if exists "product_images_write_owner_or_admin" on public.product_images;
create policy "product_images_select" on public.product_images for select using (
  public.is_admin_or_above()
  or exists(
    select 1 from public.products pr join public.shops s on s.id=pr.shop_id
    where pr.id=product_id
      and (
        (pr.is_active=true and public.is_doctor_account_public(pr.doctor_id) and s.is_active=true and public.is_provider_account_public(s.owner_id))
        or s.owner_id=auth.uid()
      )
  )
);
create policy "product_images_write_owner_or_admin" on public.product_images for all using (
  public.is_admin_or_above()
  or exists(select 1 from public.products pr join public.shops s on s.id=pr.shop_id where pr.id=product_id and s.owner_id=auth.uid())
) with check (
  public.is_admin_or_above()
  or exists(select 1 from public.products pr join public.shops s on s.id=pr.shop_id where pr.id=product_id and s.owner_id=auth.uid())
);

-- Shop gallery follows the shop's provider visibility.
drop policy if exists "shop_gallery_select" on public.shop_gallery;
drop policy if exists "shop_gallery_write_owner_or_admin" on public.shop_gallery;
create policy "shop_gallery_select" on public.shop_gallery for select using (
  public.is_admin_or_above()
  or exists(
    select 1 from public.shops s where s.id=shop_id
      and ((s.is_active=true and public.is_provider_account_public(s.owner_id)) or s.owner_id=auth.uid())
  )
);
create policy "shop_gallery_write_owner_or_admin" on public.shop_gallery for all using (
  public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
) with check (
  public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
);

-- Categories: public read; admin write.
drop policy if exists "categories_select_all" on public.categories;
drop policy if exists "categories_write_admin" on public.categories;
create policy "categories_select_all" on public.categories for select using (true);
create policy "categories_write_admin" on public.categories for all
  using (public.is_admin_or_above()) with check (public.is_admin_or_above());

-- Verification: only applicant and admins can read; applicant can edit only pending.
drop policy if exists "seller_verifications_select_own_or_admin" on public.seller_verifications;
drop policy if exists "seller_verifications_insert_own" on public.seller_verifications;
drop policy if exists "seller_verifications_update_own_or_admin" on public.seller_verifications;
create policy "seller_verifications_select_own_or_admin" on public.seller_verifications for select
  using (user_id=auth.uid() or public.is_admin_or_above());
create policy "seller_verifications_insert_own" on public.seller_verifications for insert with check (
  user_id=auth.uid()
  and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role in ('doctor','hospital') and p.account_status='active')
);
create policy "seller_verifications_update_own_or_admin" on public.seller_verifications for update using (
  (user_id=auth.uid() and status='pending') or public.is_admin_or_above()
) with check (
  (user_id=auth.uid() and status='pending') or public.is_admin_or_above()
);

-- Appointment participants only. No client DELETE policy: cancellation is an update.
drop policy if exists "appointments_select_participant_or_admin" on public.appointments;
drop policy if exists "appointments_insert_patient" on public.appointments;
drop policy if exists "appointments_update_participant_or_admin" on public.appointments;
create policy "appointments_select_participant_or_admin" on public.appointments for select
  using (patient_id=auth.uid() or doctor_id=auth.uid() or public.is_admin_or_above());
create policy "appointments_insert_patient" on public.appointments for insert with check
  (patient_id=auth.uid());
create policy "appointments_update_participant_or_admin" on public.appointments for update
  using (patient_id=auth.uid() or doctor_id=auth.uid() or public.is_admin_or_above())
  with check (patient_id=auth.uid() or doctor_id=auth.uid() or public.is_admin_or_above());

-- Blood request participant policies.
drop policy if exists "blood_requests_select_participants" on public.blood_requests;
drop policy if exists "blood_requests_update_participants" on public.blood_requests;
drop policy if exists "blood_requests_delete_requester" on public.blood_requests;
create policy "blood_requests_select_participants" on public.blood_requests for select
  using (requester_id=auth.uid() or donor_id=auth.uid() or public.is_admin_or_above());
create policy "blood_requests_update_participants" on public.blood_requests for update
  using (requester_id=auth.uid() or donor_id=auth.uid() or public.is_admin_or_above())
  with check (requester_id=auth.uid() or donor_id=auth.uid() or public.is_admin_or_above());
create policy "blood_requests_delete_requester" on public.blood_requests for delete
  using (requester_id=auth.uid() or public.is_admin_or_above());

-- Blood requests: participants can see the row, but status transitions are role-scoped.
create or replace function public.guard_blood_request_update()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if public.is_trusted_backend_context() or public.is_admin_or_above() then
    new.updated_at:=now();
    return new;
  end if;
  if auth.uid() is null or auth.uid() not in (old.requester_id,old.donor_id) then
    raise exception 'You are not allowed to update this blood request.';
  end if;
  if new.requester_id<>old.requester_id or new.donor_id<>old.donor_id
     or new.blood_group is distinct from old.blood_group
     or new.patient_name is distinct from old.patient_name
     or new.patient_phone is distinct from old.patient_phone
     or new.needed_date is distinct from old.needed_date
     or new.needed_time is distinct from old.needed_time
     or new.reason is distinct from old.reason
     or new.hospital_name is distinct from old.hospital_name
     or new.location_text is distinct from old.location_text then
    raise exception 'Blood request details cannot be changed after submission.';
  end if;
  if auth.uid()=old.requester_id then
    if new.status is distinct from old.status and not (new.status='cancelled' and old.status in ('pending','accepted')) then
      raise exception 'Requester can only cancel an active request.';
    end if;
  elsif auth.uid()=old.donor_id then
    if new.status is distinct from old.status and not (
      (old.status='pending' and new.status in ('accepted','declined'))
      or (old.status='accepted' and new.status='completed')
    ) then
      raise exception 'Invalid donor status transition.';
    end if;
  end if;
  new.updated_at:=now();
  return new;
end $$;
drop trigger if exists trg_guard_blood_request_update on public.blood_requests;
create trigger trg_guard_blood_request_update before update on public.blood_requests
  for each row execute procedure public.guard_blood_request_update();

-- Public ambulance list only exposes admin-verified entries; Admin sees/manages all.
drop policy if exists "ambulance_public_read" on public.ambulance_services;
drop policy if exists "ambulance_admin_insert" on public.ambulance_services;
drop policy if exists "ambulance_admin_update" on public.ambulance_services;
drop policy if exists "ambulance_admin_delete" on public.ambulance_services;
create policy "ambulance_public_read" on public.ambulance_services for select
  using (is_verified=true or public.is_admin_or_above());
create policy "ambulance_admin_insert" on public.ambulance_services for insert
  with check (public.is_admin_or_above());
create policy "ambulance_admin_update" on public.ambulance_services for update
  using (public.is_admin_or_above()) with check (public.is_admin_or_above());
create policy "ambulance_admin_delete" on public.ambulance_services for delete
  using (public.is_admin_or_above());

-- --------------------------------------------------------------------------
-- 4) Storage: public presentation media remains public, writes are owner-folder
--    scoped. Verification evidence becomes PRIVATE.
-- --------------------------------------------------------------------------
insert into storage.buckets(id,name,public,file_size_limit) values
  ('shop-logos','shop-logos',true,1048576),
  ('shop-banners','shop-banners',true,1048576),
  ('shop-gallery','shop-gallery',true,1048576),
  ('product-images','product-images',true,1048576),
  ('user-avatars','user-avatars',true,1048576),
  ('site-assets','site-assets',true,1048576),
  ('seller-verification','seller-verification',false,1048576),
  ('verification-docs','verification-docs',false,1048576)
on conflict(id) do update set public=excluded.public, file_size_limit=excluded.file_size_limit;

-- Remove known historical broad policies before canonical policies are created.
drop policy if exists "public_read_marketplace_media" on storage.objects;
drop policy if exists "authenticated_upload_marketplace_media" on storage.objects;
drop policy if exists "authenticated_update_own_media" on storage.objects;
drop policy if exists "authenticated_delete_own_media" on storage.objects;
drop policy if exists "admin_manage_site_assets" on storage.objects;
drop policy if exists "public_read_user_avatars" on storage.objects;
drop policy if exists "authenticated_upload_own_avatar" on storage.objects;
drop policy if exists "authenticated_update_own_avatar" on storage.objects;
drop policy if exists "authenticated_delete_own_avatar" on storage.objects;
drop policy if exists "public_read_provider_shop_gallery" on storage.objects;
drop policy if exists "authenticated_upload_provider_shop_gallery" on storage.objects;
drop policy if exists "authenticated_update_provider_shop_gallery" on storage.objects;
drop policy if exists "authenticated_delete_provider_shop_gallery" on storage.objects;
drop policy if exists "public_read_provider_avatars" on storage.objects;
drop policy if exists "authenticated_upload_provider_avatars" on storage.objects;
drop policy if exists "authenticated_update_provider_avatars" on storage.objects;
drop policy if exists "authenticated_delete_provider_avatars" on storage.objects;
drop policy if exists "public_read_provider_verification" on storage.objects;
drop policy if exists "authenticated_upload_provider_verification" on storage.objects;
drop policy if exists "authenticated_update_provider_verification" on storage.objects;
drop policy if exists "authenticated_delete_provider_verification" on storage.objects;
drop policy if exists "public_read_seller_verification" on storage.objects;
drop policy if exists "authenticated_upload_seller_verification" on storage.objects;
drop policy if exists "authenticated_update_own_seller_verification" on storage.objects;
drop policy if exists "authenticated_delete_own_seller_verification" on storage.objects;

-- Clean canonical policy names too, making reruns safe.
drop policy if exists "media_public_read" on storage.objects;
drop policy if exists "media_owner_insert" on storage.objects;
drop policy if exists "media_owner_update" on storage.objects;
drop policy if exists "media_owner_delete" on storage.objects;
drop policy if exists "site_assets_admin_manage" on storage.objects;
drop policy if exists "verification_owner_admin_read" on storage.objects;
drop policy if exists "verification_owner_insert" on storage.objects;
drop policy if exists "verification_owner_update" on storage.objects;
drop policy if exists "verification_owner_delete" on storage.objects;

create policy "media_public_read" on storage.objects for select using (
  bucket_id in ('shop-logos','shop-banners','shop-gallery','product-images','user-avatars','site-assets')
);
create policy "media_owner_insert" on storage.objects for insert with check (
  bucket_id in ('shop-logos','shop-banners','shop-gallery','product-images','user-avatars')
  and auth.role()='authenticated'
  and (storage.foldername(name))[1]=auth.uid()::text
);
create policy "media_owner_update" on storage.objects for update using (
  bucket_id in ('shop-logos','shop-banners','shop-gallery','product-images','user-avatars')
  and (storage.foldername(name))[1]=auth.uid()::text
) with check (
  bucket_id in ('shop-logos','shop-banners','shop-gallery','product-images','user-avatars')
  and (storage.foldername(name))[1]=auth.uid()::text
);
create policy "media_owner_delete" on storage.objects for delete using (
  bucket_id in ('shop-logos','shop-banners','shop-gallery','product-images','user-avatars')
  and (storage.foldername(name))[1]=auth.uid()::text
);
create policy "site_assets_admin_manage" on storage.objects for all
  using (bucket_id='site-assets' and public.is_admin_or_above())
  with check (bucket_id='site-assets' and public.is_admin_or_above());

-- Private verification files: owner/admin may read; owner-folder writes only.
create policy "verification_owner_admin_read" on storage.objects for select using (
  bucket_id in ('seller-verification','verification-docs')
  and (
    (storage.foldername(name))[1]=auth.uid()::text
    or public.is_admin_or_above()
  )
);
create policy "verification_owner_insert" on storage.objects for insert with check (
  bucket_id in ('seller-verification','verification-docs')
  and auth.role()='authenticated'
  and (storage.foldername(name))[1]=auth.uid()::text
);
create policy "verification_owner_update" on storage.objects for update using (
  bucket_id in ('seller-verification','verification-docs')
  and ((storage.foldername(name))[1]=auth.uid()::text or public.is_admin_or_above())
) with check (
  bucket_id in ('seller-verification','verification-docs')
  and ((storage.foldername(name))[1]=auth.uid()::text or public.is_admin_or_above())
);
create policy "verification_owner_delete" on storage.objects for delete using (
  bucket_id in ('seller-verification','verification-docs')
  and ((storage.foldername(name))[1]=auth.uid()::text or public.is_admin_or_above())
);

notify pgrst, 'reload schema';
-- <<< END 03_rls_rpc_security_hardening.sql

-- >>> BEGIN 04_location_nearest_search.sql
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
-- <<< END 04_location_nearest_search.sql

-- >>> BEGIN 05_doctor_provider_relationships.sql
-- ============================================================
-- Production Upgrade V2 — STEP 05: DOCTOR <-> PROVIDER MODEL
-- Keeps products/shops frontend-compatible while normalizing affiliations.
-- ============================================================

create table if not exists public.doctor_provider_links (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles(id) on delete cascade,
  provider_id uuid not null references public.shops(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  status text not null default 'approved',
  consultation_fee numeric(12,2),
  visiting_days text,
  visiting_time text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint doctor_provider_links_status_check check(status in ('pending','approved','rejected','inactive')),
  constraint doctor_provider_links_doctor_provider_unique unique(doctor_id,provider_id)
);

-- Historical Product = Doctor Profile rows become approved affiliations.
insert into public.doctor_provider_links(doctor_id,provider_id,product_id,status,consultation_fee,visiting_days,visiting_time)
select p.doctor_id,p.shop_id,p.id,'approved',coalesce(p.consultation_fee,p.price),p.visiting_days,p.visiting_time
from public.products p
join public.profiles d on d.id=p.doctor_id and d.role='doctor'
join public.shops s on s.id=p.shop_id
where p.doctor_id is not null and p.shop_id is not null
on conflict(doctor_id,provider_id) do update set
  product_id=excluded.product_id,
  consultation_fee=excluded.consultation_fee,
  visiting_days=excluded.visiting_days,
  visiting_time=excluded.visiting_time,
  updated_at=now();

-- Remove marketplace-era global one-profile restriction. Same doctor may appear at many providers.
drop index if exists public.ux_one_doctor_profile_per_owner;
do $$ begin
  if to_regclass('public.ux_products_doctor_shop') is null and not exists(
    select 1 from public.products where doctor_id is not null and shop_id is not null group by doctor_id,shop_id having count(*)>1
  ) then
    execute 'create unique index ux_products_doctor_shop on public.products(doctor_id,shop_id) where doctor_id is not null and shop_id is not null';
  end if;
end $$;
create index if not exists idx_doctor_provider_links_provider_status on public.doctor_provider_links(provider_id,status);
create index if not exists idx_doctor_provider_links_doctor_status on public.doctor_provider_links(doctor_id,status);

create or replace function public.set_product_doctor_id()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_owner uuid;
  v_owner_role text;
begin
  select s.owner_id,p.role into v_owner,v_owner_role
  from public.shops s join public.profiles p on p.id=s.owner_id
  where s.id=new.shop_id;

  if v_owner is null then raise exception 'A valid Chamber/Hospital is required.'; end if;
  if new.doctor_id is null and v_owner_role='doctor' then new.doctor_id:=v_owner; end if;
  if new.doctor_id is null then raise exception 'ডাক্তারের প্রোফাইলের জন্য ডাক্তার নির্বাচন করতে হবে।'; end if;

  if not exists(select 1 from public.profiles p where p.id=new.doctor_id and p.role='doctor' and p.seller_status='approved' and p.account_status='active') then
    raise exception 'শুধু অনুমোদিত ডাক্তার অ্যাকাউন্টকে Doctor Profile হিসেবে যোগ করা যাবে।';
  end if;
  if not exists(select 1 from public.profiles p where p.id=v_owner and p.role in ('doctor','hospital') and p.seller_status='approved' and p.account_status='active') then
    raise exception 'অনুমোদিত চেম্বার/হাসপাতাল প্রয়োজন।';
  end if;
  if exists(select 1 from public.products x where x.doctor_id=new.doctor_id and x.shop_id=new.shop_id and x.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)) then
    raise exception 'This Doctor is already listed at this provider.';
  end if;
  return new;
end $$;

drop trigger if exists trg_set_product_doctor_id on public.products;
create trigger trg_set_product_doctor_id
  before insert or update of doctor_id,shop_id on public.products
  for each row execute procedure public.set_product_doctor_id();

create or replace function public.sync_product_doctor_provider_link()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.doctor_provider_links(
    doctor_id,provider_id,product_id,status,consultation_fee,visiting_days,visiting_time,updated_at
  ) values(
    new.doctor_id,new.shop_id,new.id,'approved',coalesce(new.consultation_fee,new.price),new.visiting_days,new.visiting_time,now()
  )
  on conflict(doctor_id,provider_id) do update set
    product_id=excluded.product_id,
    status=case when public.doctor_provider_links.status in ('rejected','inactive') then public.doctor_provider_links.status else 'approved' end,
    consultation_fee=excluded.consultation_fee,
    visiting_days=excluded.visiting_days,
    visiting_time=excluded.visiting_time,
    updated_at=now();
  return new;
end $$;

drop trigger if exists trg_sync_product_doctor_provider_link on public.products;
create trigger trg_sync_product_doctor_provider_link
  after insert or update of doctor_id,shop_id,consultation_fee,price,visiting_days,visiting_time on public.products
  for each row execute procedure public.sync_product_doctor_provider_link();

alter table public.doctor_provider_links enable row level security;
drop policy if exists "doctor_provider_links_public_read" on public.doctor_provider_links;
drop policy if exists "doctor_provider_links_participants" on public.doctor_provider_links;
drop policy if exists "doctor_provider_links_provider_manage" on public.doctor_provider_links;
create policy "doctor_provider_links_public_read" on public.doctor_provider_links for select using(
  status='approved'
  and public.is_doctor_account_public(doctor_id)
  and exists(select 1 from public.shops s where s.id=provider_id and s.is_active=true and public.is_provider_account_public(s.owner_id))
);
create policy "doctor_provider_links_participants" on public.doctor_provider_links for select using(
  doctor_id=auth.uid()
  or exists(select 1 from public.shops s where s.id=provider_id and s.owner_id=auth.uid())
  or public.is_admin_or_above()
);
create policy "doctor_provider_links_provider_manage" on public.doctor_provider_links for all using(
  exists(select 1 from public.shops s where s.id=provider_id and s.owner_id=auth.uid()) or public.is_admin_or_above()
) with check(
  exists(select 1 from public.shops s where s.id=provider_id and s.owner_id=auth.uid()) or public.is_admin_or_above()
);

notify pgrst, 'reload schema';
-- <<< END 05_doctor_provider_relationships.sql

-- >>> BEGIN 06_appointment_schedule_integrity.sql
-- ============================================================
-- Production Upgrade V2 — STEP 06: APPOINTMENT / SCHEDULE INTEGRITY
-- Backward compatible with appointment_date + appointment_time.
-- ============================================================

alter table public.appointments
  add column if not exists appointment_start timestamptz,
  add column if not exists duration_minutes integer not null default 30,
  add column if not exists cancellation_reason text;

alter table public.appointments drop constraint if exists appointments_duration_minutes_check;
alter table public.appointments add constraint appointments_duration_minutes_check check(duration_minutes between 5 and 240);

create table if not exists public.doctor_schedules (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  day_of_week integer not null check(day_of_week between 0 and 6),
  start_time time not null,
  end_time time not null,
  slot_duration_minutes integer not null default 30 check(slot_duration_minutes between 5 and 240),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint doctor_schedules_time_check check(end_time>start_time),
  constraint doctor_schedules_unique_window unique(doctor_id,shop_id,day_of_week,start_time,end_time)
);

create table if not exists public.doctor_schedule_exceptions (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles(id) on delete cascade,
  shop_id uuid references public.shops(id) on delete cascade,
  exception_date date not null,
  is_available boolean not null default false,
  note text,
  created_at timestamptz not null default now(),
  constraint doctor_schedule_exceptions_unique unique(doctor_id,shop_id,exception_date)
);

create index if not exists idx_doctor_schedules_lookup on public.doctor_schedules(doctor_id,shop_id,day_of_week,is_active);
create index if not exists idx_schedule_exceptions_lookup on public.doctor_schedule_exceptions(doctor_id,shop_id,exception_date);
create index if not exists idx_appointments_doctor_start on public.appointments(doctor_id,appointment_start,status) where appointment_start is not null;
create index if not exists idx_appointments_shop_date on public.appointments(shop_id,appointment_date,status);

create or replace function public.is_appointment_provider_owner(p_shop_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select p_shop_id is not null and exists(select 1 from public.shops s where s.id=p_shop_id and s.owner_id=auth.uid());
$$;

create or replace function public.set_appointment_defaults()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  d record; pat record; ch record; v_time time; v_has_schedule boolean;
begin
  if auth.uid() is not null and not public.is_trusted_backend_context() then
    new.patient_id:=auth.uid();
  end if;
  if new.patient_id is null then raise exception 'Patient login is required.'; end if;
  select p.id,p.full_name,p.phone into pat from public.profiles p where p.id=new.patient_id and p.account_status='active';
  if pat.id is null then raise exception 'Patient profile not found.'; end if;
  select p.id,p.full_name into d from public.profiles p
    where p.id=new.doctor_id and p.role='doctor' and p.seller_status='approved' and p.account_status='active';
  if d.id is null then raise exception 'Doctor is not approved/active.'; end if;

  if new.product_id is not null then
    select s.id,s.shop_name,pr.doctor_id into ch
    from public.products pr join public.shops s on s.id=pr.shop_id
    where pr.id=new.product_id and pr.is_active=true and s.is_active=true
      and public.is_provider_account_public(s.owner_id);
    if ch.id is null or ch.doctor_id is distinct from new.doctor_id then raise exception 'Invalid Doctor profile.'; end if;
    new.shop_id:=ch.id;
    new.chamber_name:=coalesce(new.chamber_name,ch.shop_name);
  elsif new.shop_id is not null then
    select s.id,s.shop_name into ch from public.shops s
    where s.id=new.shop_id and s.is_active=true and public.is_provider_account_public(s.owner_id)
      and exists(select 1 from public.doctor_provider_links l where l.provider_id=s.id and l.doctor_id=new.doctor_id and l.status='approved');
    if ch.id is null then raise exception 'Invalid doctor/chamber affiliation.'; end if;
    new.chamber_name:=coalesce(new.chamber_name,ch.shop_name);
  end if;

  if new.appointment_time is not null and btrim(new.appointment_time) ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
    v_time:=new.appointment_time::time;
    new.appointment_start:=((new.appointment_date::text||' '||new.appointment_time)::timestamp at time zone 'Asia/Dhaka');
  end if;

  if new.appointment_start is not null and new.shop_id is not null then
    if exists(select 1 from public.doctor_schedule_exceptions e where e.doctor_id=new.doctor_id
      and (e.shop_id is null or e.shop_id=new.shop_id) and e.exception_date=new.appointment_date and e.is_available=false) then
      raise exception 'Doctor is unavailable on this date.';
    end if;
    select exists(select 1 from public.doctor_schedules ds where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true)
      into v_has_schedule;
    if v_has_schedule and not exists(
      select 1 from public.doctor_schedules ds
      where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true
        and ds.day_of_week=extract(dow from new.appointment_date)::integer
        and v_time>=ds.start_time
        and (v_time + make_interval(mins=>coalesce(new.duration_minutes,ds.slot_duration_minutes)))<=ds.end_time
    ) then raise exception 'Selected time is outside the Doctor schedule.'; end if;

    perform pg_advisory_xact_lock(hashtextextended(new.doctor_id::text||'|'||new.appointment_start::text,0));
    if exists(select 1 from public.appointments a where a.doctor_id=new.doctor_id
      and a.appointment_start=new.appointment_start and a.status in ('pending','confirmed','rescheduled')) then
      raise exception 'This appointment slot is already booked.';
    end if;
  end if;

  new.appointment_number:='APT-'||to_char(now(),'YYYYMMDD')||'-'||lpad(nextval('public.appointment_number_seq')::text,5,'0');
  new.doctor_name:=d.full_name;
  new.patient_name:=coalesce(nullif(trim(new.patient_name),''),pat.full_name);
  new.patient_phone:=coalesce(nullif(trim(new.patient_phone),''),pat.phone);
  new.status:='pending'; new.created_at:=now(); new.updated_at:=now();
  return new;
end $$;

drop trigger if exists trg_appointments_set_defaults on public.appointments;
create trigger trg_appointments_set_defaults before insert on public.appointments for each row execute procedure public.set_appointment_defaults();

create or replace function public.guard_appointment_update()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_provider boolean; v_time time; v_has_schedule boolean;
begin
  if public.is_trusted_backend_context() then new.updated_at:=now(); return new; end if;
  v_provider:=public.is_appointment_provider_owner(old.shop_id);
  if not (auth.uid()=old.doctor_id or auth.uid()=old.patient_id or v_provider or public.is_admin_or_above()) then
    raise exception 'You are not allowed to update this appointment.';
  end if;
  if new.doctor_id<>old.doctor_id or new.patient_id<>old.patient_id or new.product_id is distinct from old.product_id or new.shop_id is distinct from old.shop_id then
    raise exception 'Appointment ownership cannot be changed.';
  end if;
  if new.doctor_name is distinct from old.doctor_name or new.patient_name is distinct from old.patient_name
     or new.patient_phone is distinct from old.patient_phone or new.chamber_name is distinct from old.chamber_name
     or new.appointment_number is distinct from old.appointment_number then
    raise exception 'Appointment identity fields cannot be changed.';
  end if;

  if auth.uid()=old.patient_id and not public.is_admin_or_above() then
    if new.status is distinct from old.status and not (new.status='cancelled' and old.status in ('pending','confirmed','rescheduled')) then
      raise exception 'Patient can only cancel an active appointment.';
    end if;
    if new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time
       or new.duration_minutes is distinct from old.duration_minutes or new.doctor_note is distinct from old.doctor_note then
      raise exception 'Patient cannot change the Doctor schedule or Doctor note.';
    end if;
  end if;

  if (auth.uid()=old.doctor_id or v_provider) and not public.is_admin_or_above()
     and new.status not in ('confirmed','cancelled','completed','rescheduled','pending') then
    raise exception 'Invalid appointment status.';
  end if;

  if (new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time)
     and new.appointment_time is not null and btrim(new.appointment_time) ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
    v_time:=new.appointment_time::time;
    new.appointment_start:=((new.appointment_date::text||' '||new.appointment_time)::timestamp at time zone 'Asia/Dhaka');
  end if;

  if not public.is_admin_or_above() and (auth.uid()=old.doctor_id or v_provider)
     and (new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time)
     and new.appointment_start is not null and new.shop_id is not null then
    if exists(select 1 from public.doctor_schedule_exceptions e where e.doctor_id=new.doctor_id
      and (e.shop_id is null or e.shop_id=new.shop_id) and e.exception_date=new.appointment_date and e.is_available=false) then
      raise exception 'Doctor is unavailable on this date.';
    end if;
    select exists(select 1 from public.doctor_schedules ds where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true)
      into v_has_schedule;
    if v_has_schedule and not exists(
      select 1 from public.doctor_schedules ds
      where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true
        and ds.day_of_week=extract(dow from new.appointment_date)::integer
        and v_time>=ds.start_time
        and (v_time + make_interval(mins=>coalesce(new.duration_minutes,ds.slot_duration_minutes)))<=ds.end_time
    ) then raise exception 'Selected time is outside the Doctor schedule.'; end if;
  end if;

  if new.status in ('pending','confirmed','rescheduled') and new.appointment_start is not null then
    perform pg_advisory_xact_lock(hashtextextended(new.doctor_id::text||'|'||new.appointment_start::text,0));
    if exists(select 1 from public.appointments a where a.id<>old.id and a.doctor_id=new.doctor_id
      and a.appointment_start=new.appointment_start and a.status in ('pending','confirmed','rescheduled')) then
      raise exception 'This appointment slot is already booked.';
    end if;
  end if;

  new.updated_at:=now(); return new;
end $$;
drop trigger if exists trg_guard_appointment_update on public.appointments;
create trigger trg_guard_appointment_update before update on public.appointments for each row execute procedure public.guard_appointment_update();

alter table public.appointments enable row level security;
drop policy if exists "appointments_select_participant_or_admin" on public.appointments;
drop policy if exists "appointments_update_participant_or_admin" on public.appointments;
create policy "appointments_select_participant_or_admin" on public.appointments for select using(
  patient_id=auth.uid() or doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above()
);
create policy "appointments_update_participant_or_admin" on public.appointments for update using(
  patient_id=auth.uid() or doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above()
) with check(
  patient_id=auth.uid() or doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above()
);

alter table public.doctor_schedules enable row level security;
alter table public.doctor_schedule_exceptions enable row level security;
drop policy if exists "doctor_schedules_public_read" on public.doctor_schedules;
drop policy if exists "doctor_schedules_manage" on public.doctor_schedules;
create policy "doctor_schedules_public_read" on public.doctor_schedules for select using(is_active=true or doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above());
create policy "doctor_schedules_manage" on public.doctor_schedules for all using(doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above()) with check(doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above());
drop policy if exists "doctor_schedule_exceptions_public_read" on public.doctor_schedule_exceptions;
drop policy if exists "doctor_schedule_exceptions_manage" on public.doctor_schedule_exceptions;
create policy "doctor_schedule_exceptions_public_read" on public.doctor_schedule_exceptions for select using(doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above());
create policy "doctor_schedule_exceptions_manage" on public.doctor_schedule_exceptions for all using(doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above()) with check(doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above());

create or replace function public.get_doctor_available_slots(p_doctor_id uuid,p_shop_id uuid,p_date date)
returns table(slot_time text)
language sql stable security definer set search_path=public as $$
  with schedule as (
    select ds.start_time,ds.end_time,ds.slot_duration_minutes
    from public.doctor_schedules ds
    where ds.doctor_id=p_doctor_id and ds.shop_id=p_shop_id and ds.is_active=true
      and ds.day_of_week=extract(dow from p_date)::integer
      and not exists(select 1 from public.doctor_schedule_exceptions e where e.doctor_id=p_doctor_id
        and (e.shop_id is null or e.shop_id=p_shop_id) and e.exception_date=p_date and e.is_available=false)
  ), slots as (
    select gs::time as t, s.slot_duration_minutes
    from schedule s cross join lateral generate_series(
      p_date+s.start_time,
      p_date+(s.end_time-make_interval(mins=>s.slot_duration_minutes)),
      make_interval(mins=>s.slot_duration_minutes)
    ) gs
  )
  select to_char(slots.t,'HH24:MI')
  from slots
  where public.is_doctor_account_public(p_doctor_id)
    and exists(select 1 from public.doctor_provider_links l where l.doctor_id=p_doctor_id and l.provider_id=p_shop_id and l.status='approved')
    and not exists(select 1 from public.appointments a where a.doctor_id=p_doctor_id and a.shop_id=p_shop_id
      and a.appointment_date=p_date and a.appointment_time=to_char(slots.t,'HH24:MI') and a.status in ('pending','confirmed','rescheduled'))
  order by slots.t;
$$;
revoke all on function public.get_doctor_available_slots(uuid,uuid,date) from public;
grant execute on function public.get_doctor_available_slots(uuid,uuid,date) to anon,authenticated,service_role;

notify pgrst, 'reload schema';
-- <<< END 06_appointment_schedule_integrity.sql

-- >>> BEGIN 07_admin_audit_hardening.sql
-- ============================================================
-- Production Upgrade V2 — STEP 07: ADMIN / AUDIT HARDENING
-- Audits sensitive state transitions without storing document/PII payloads.
-- ============================================================

create table if not exists public.admin_audit_logs (
  id bigint generated by default as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_admin_audit_created on public.admin_audit_logs(created_at desc);
create index if not exists idx_admin_audit_entity on public.admin_audit_logs(entity_type,entity_id,created_at desc);
create index if not exists idx_admin_audit_actor on public.admin_audit_logs(actor_id,created_at desc);

alter table public.admin_audit_logs enable row level security;
drop policy if exists "admin_audit_admin_read" on public.admin_audit_logs;
create policy "admin_audit_admin_read" on public.admin_audit_logs for select using(public.is_admin_or_above());
revoke insert,update,delete on public.admin_audit_logs from anon,authenticated;
grant select on public.admin_audit_logs to authenticated,service_role;

create or replace function public.audit_sensitive_change()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_old jsonb := case when tg_op='INSERT' then '{}'::jsonb else to_jsonb(old) end;
  v_new jsonb := case when tg_op='DELETE' then '{}'::jsonb else to_jsonb(new) end;
  v_id text;
  v_details jsonb := '{}'::jsonb;
  v_should_log boolean := false;
begin
  v_id:=coalesce(v_new->>'id',v_old->>'id');

  if tg_table_name='profiles' then
    v_should_log := tg_op<>'UPDATE'
      or (v_old->>'role') is distinct from (v_new->>'role')
      or (v_old->>'seller_status') is distinct from (v_new->>'seller_status')
      or (v_old->>'account_status') is distinct from (v_new->>'account_status');
    v_details:=jsonb_build_object(
      'old_role',v_old->>'role','new_role',v_new->>'role',
      'old_provider_status',v_old->>'seller_status','new_provider_status',v_new->>'seller_status',
      'old_account_status',v_old->>'account_status','new_account_status',v_new->>'account_status'
    );
  elsif tg_table_name='seller_verifications' then
    v_should_log := tg_op<>'UPDATE' or (v_old->>'status') is distinct from (v_new->>'status');
    v_details:=jsonb_build_object('user_id',coalesce(v_new->>'user_id',v_old->>'user_id'),'old_status',v_old->>'status','new_status',v_new->>'status');
  elsif tg_table_name='appointments' then
    v_should_log := tg_op<>'UPDATE' or (v_old->>'status') is distinct from (v_new->>'status');
    v_details:=jsonb_build_object(
      'doctor_id',coalesce(v_new->>'doctor_id',v_old->>'doctor_id'),
      'patient_id',coalesce(v_new->>'patient_id',v_old->>'patient_id'),
      'old_status',v_old->>'status','new_status',v_new->>'status'
    );
  elsif tg_table_name='ambulance_services' then
    v_should_log := tg_op<>'UPDATE'
      or (v_old->>'is_verified') is distinct from (v_new->>'is_verified')
      or (v_old->>'is_available') is distinct from (v_new->>'is_available');
    v_details:=jsonb_build_object('old_verified',v_old->>'is_verified','new_verified',v_new->>'is_verified','old_available',v_old->>'is_available','new_available',v_new->>'is_available');
  elsif tg_table_name='doctor_provider_links' then
    v_should_log := tg_op<>'UPDATE' or (v_old->>'status') is distinct from (v_new->>'status');
    v_details:=jsonb_build_object('doctor_id',coalesce(v_new->>'doctor_id',v_old->>'doctor_id'),'provider_id',coalesce(v_new->>'provider_id',v_old->>'provider_id'),'old_status',v_old->>'status','new_status',v_new->>'status');
  elsif tg_table_name='blood_requests' then
    v_should_log := tg_op<>'UPDATE' or (v_old->>'status') is distinct from (v_new->>'status');
    v_details:=jsonb_build_object(
      'requester_id',coalesce(v_new->>'requester_id',v_old->>'requester_id'),
      'donor_id',coalesce(v_new->>'donor_id',v_old->>'donor_id'),
      'old_status',v_old->>'status','new_status',v_new->>'status'
    );
  end if;

  if v_should_log then
    insert into public.admin_audit_logs(actor_id,action,entity_type,entity_id,details)
    values(auth.uid(),lower(tg_op),tg_table_name,v_id,jsonb_strip_nulls(v_details));
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;

-- Replace only our audit triggers; business triggers remain untouched.
do $$ declare t text; begin
  foreach t in array array['profiles','seller_verifications','appointments','ambulance_services','doctor_provider_links','blood_requests'] loop
    execute format('drop trigger if exists %I on public.%I','trg_audit_'||t,t);
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute procedure public.audit_sensitive_change()','trg_audit_'||t,t);
  end loop;
end $$;

create or replace function public.get_admin_audit_logs(p_limit integer default 100,p_offset integer default 0)
returns setof public.admin_audit_logs
language plpgsql stable security definer set search_path=public as $$
begin
  if not public.is_admin_or_above() then raise exception 'Admin access required.'; end if;
  return query select * from public.admin_audit_logs order by created_at desc
    limit greatest(1,least(coalesce(p_limit,100),500)) offset greatest(coalesce(p_offset,0),0);
end $$;
revoke all on function public.get_admin_audit_logs(integer,integer) from public;
grant execute on function public.get_admin_audit_logs(integer,integer) to authenticated,service_role;

notify pgrst, 'reload schema';
-- <<< END 07_admin_audit_hardening.sql

-- >>> BEGIN 08_performance_search.sql
-- ============================================================
-- Production Upgrade V2 — STEP 08: PERFORMANCE / SEARCH
-- ============================================================
create extension if not exists pg_trgm;

create index if not exists idx_products_public_sort on public.products(is_active,view_count desc,created_at desc);
create index if not exists idx_products_shop_active on public.products(shop_id,is_active);
create index if not exists idx_products_category_active on public.products(category_id,is_active);
create index if not exists idx_products_doctor_active on public.products(doctor_id,is_active);
create index if not exists idx_products_name_trgm on public.products using gin(name gin_trgm_ops);
create index if not exists idx_products_name_bn_trgm on public.products using gin(name_bn gin_trgm_ops);
create index if not exists idx_products_name_en_trgm on public.products using gin(name_en gin_trgm_ops);
create index if not exists idx_products_keywords_trgm on public.products using gin(search_keywords gin_trgm_ops);
create index if not exists idx_categories_name_trgm on public.categories using gin(name gin_trgm_ops);
create index if not exists idx_shops_area_active on public.shops(district,upazila,is_active);
create index if not exists idx_profiles_provider_state on public.profiles(role,seller_status,account_status);
create index if not exists idx_appointments_doctor_date_status on public.appointments(doctor_id,appointment_date,status);
create index if not exists idx_appointments_patient_date on public.appointments(patient_id,appointment_date desc);

-- Preserve the existing analytics counters used by the public Product/Doctor cards.
create or replace function public.increment_product_view(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  update public.products set view_count=greatest(coalesce(view_count,0),0)+1
  where id=p_product_id and is_active=true;
end;
$$;
revoke all on function public.increment_product_view(uuid) from public;
grant execute on function public.increment_product_view(uuid) to anon,authenticated,service_role;

create or replace function public.increment_product_order_click(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  update public.products set click_count=greatest(coalesce(click_count,0),0)+1
  where id=p_product_id and is_active=true;
end;
$$;
revoke all on function public.increment_product_order_click(uuid) from public;
grant execute on function public.increment_product_order_click(uuid) to anon,authenticated,service_role;

-- Canonicalize the existing Super Admin analytics contract so drift cannot break the dashboard.
create or replace function public.super_admin_analytics_summary()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare result jsonb;
begin
  if not public.is_super_admin() then raise exception 'শুধুমাত্র Super Admin এই তথ্য দেখতে পারবেন'; end if;
  select jsonb_build_object(
    'totals',jsonb_build_object(
      'total_users',(select count(*) from public.profiles),
      'total_unverified_seller_applications',(select count(*) from public.seller_verifications where status='pending'),
      'total_verified_sellers',(select count(*) from public.seller_verifications where status='approved'),
      'total_products',(select count(*) from public.products),
      'total_product_views',(select coalesce(sum(view_count),0) from public.products)
    ),
    'top_sellers',(select coalesce(jsonb_agg(t),'[]'::jsonb) from (
      select s.id as shop_id,s.shop_name,s.slug,s.logo_url,coalesce(sum(p.click_count),0) as total_order_clicks
      from public.shops s join public.products p on p.shop_id=s.id
      group by s.id,s.shop_name,s.slug,s.logo_url
      having coalesce(sum(p.click_count),0)>0
      order by total_order_clicks desc,s.shop_name asc limit 10
    ) t),
    'top_viewed_products',(select coalesce(jsonb_agg(t),'[]'::jsonb) from (
      select p.id,p.name,p.slug,p.thumbnail_url,p.view_count,s.shop_name
      from public.products p join public.shops s on s.id=p.shop_id
      where p.view_count>0 order by p.view_count desc,p.name asc limit 10
    ) t),
    'top_saved_products',(select coalesce(jsonb_agg(t),'[]'::jsonb) from (
      select p.id,p.name,p.slug,p.thumbnail_url,p.save_count,s.shop_name
      from public.products p join public.shops s on s.id=p.shop_id
      where p.save_count>0 order by p.save_count desc,p.name asc limit 10
    ) t),
    'top_categories',(select coalesce(jsonb_agg(t),'[]'::jsonb) from (
      select c.id,c.name,c.slug,count(p.id) as product_count,coalesce(sum(p.view_count),0) as total_views
      from public.categories c join public.products p on p.category_id=c.id
      group by c.id,c.name,c.slug having count(p.id)>0
      order by product_count desc,total_views desc limit 10
    ) t),
    'growth',jsonb_build_object(
      'daily',jsonb_build_object(
        'new_users',(select count(*) from public.profiles where created_at>=now()-interval '1 day'),
        'new_seller_applications',(select count(*) from public.seller_verifications where created_at>=now()-interval '1 day'),
        'new_products',(select count(*) from public.products where created_at>=now()-interval '1 day')
      ),
      'weekly',jsonb_build_object(
        'new_users',(select count(*) from public.profiles where created_at>=now()-interval '7 days'),
        'new_seller_applications',(select count(*) from public.seller_verifications where created_at>=now()-interval '7 days'),
        'new_products',(select count(*) from public.products where created_at>=now()-interval '7 days')
      ),
      'monthly',jsonb_build_object(
        'new_users',(select count(*) from public.profiles where created_at>=now()-interval '30 days'),
        'new_seller_applications',(select count(*) from public.seller_verifications where created_at>=now()-interval '30 days'),
        'new_products',(select count(*) from public.products where created_at>=now()-interval '30 days')
      )
    )
  ) into result;
  return result;
end;
$$;
revoke all on function public.super_admin_analytics_summary() from public;
grant execute on function public.super_admin_analytics_summary() to authenticated,service_role;

create or replace function public.search_doctors_catalog(
  p_terms text[] default null,
  p_district text default null,
  p_upazila text default null,
  p_section text default 'popular',
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language sql stable security definer set search_path=public as $$
with filtered as (
  select p.*,s.shop_name,s.chamber_name,s.slug as shop_slug,s.whatsapp_number,s.phone as shop_phone,
    s.address as shop_address,s.district,s.upazila,s.google_map_link,s.facebook_link,s.messenger_link,
    s.visiting_days as shop_visiting_days,s.visiting_time as shop_visiting_time,s.consultation_fee as shop_consultation_fee,
    s.latitude,s.longitude,s.location_visibility,c.name as category_name,c.slug as category_slug
  from public.products p
  join public.shops s on s.id=p.shop_id
  left join public.categories c on c.id=p.category_id
  where p.is_active=true and s.is_active=true
    and public.is_doctor_account_public(p.doctor_id)
    and public.is_provider_account_public(s.owner_id)
    and (p_district is null or btrim(p_district)='' or s.district=p_district)
    and (p_upazila is null or btrim(p_upazila)='' or s.upazila=p_upazila)
    and (
      p_terms is null or cardinality(p_terms)=0 or exists(
        select 1 from unnest(p_terms) t where nullif(btrim(t),'') is not null and (
          p.name ilike '%'||t||'%' or coalesce(p.description,'') ilike '%'||t||'%'
          or coalesce(p.name_bn,'') ilike '%'||t||'%' or coalesce(p.name_en,'') ilike '%'||t||'%'
          or coalesce(p.search_keywords,'') ilike '%'||t||'%' or coalesce(c.name,'') ilike '%'||t||'%'
        )
      )
    )
), total as (select count(*)::integer n from filtered), paged as (
  select * from filtered
  order by case when p_section='latest' then created_at end desc nulls last,
           case when p_section<>'latest' then view_count end desc nulls last,
           created_at desc
  limit greatest(1,least(coalesce(p_limit,20),100)) offset greatest(coalesce(p_offset,0),0)
), items as (
  select coalesce(jsonb_agg(
    (to_jsonb(paged) - array['shop_name','chamber_name','shop_slug','whatsapp_number','shop_phone','shop_address','district','upazila','google_map_link','facebook_link','messenger_link','shop_visiting_days','shop_visiting_time','shop_consultation_fee','latitude','longitude','location_visibility','category_name','category_slug']::text[])
    || jsonb_build_object(
      'shops',jsonb_build_object('shop_name',shop_name,'chamber_name',chamber_name,'slug',shop_slug,'whatsapp_number',whatsapp_number,'phone',shop_phone,'address',shop_address,'district',district,'upazila',upazila,'google_map_link',google_map_link,'facebook_link',facebook_link,'messenger_link',messenger_link,'visiting_days',shop_visiting_days,'visiting_time',shop_visiting_time,'consultation_fee',shop_consultation_fee,'latitude',latitude,'longitude',longitude,'location_visibility',location_visibility),
      'categories',case when category_name is null then null else jsonb_build_object('name',category_name,'slug',category_slug) end
    ) order by case when p_section='latest' then created_at end desc nulls last,case when p_section<>'latest' then view_count end desc nulls last,created_at desc
  ),'[]'::jsonb) v from paged
)
select jsonb_build_object('items',items.v,'total',total.n) from items cross join total;
$$;

revoke all on function public.search_doctors_catalog(text[],text,text,text,integer,integer) from public;
grant execute on function public.search_doctors_catalog(text[],text,text,text,integer,integer) to anon,authenticated,service_role;

notify pgrst, 'reload schema';
-- <<< END 08_performance_search.sql

-- >>> BEGIN 09_data_consistency_services.sql
-- ============================================================
-- Production Upgrade V2 — STEP 09: DATA CONSISTENCY / HEALTH CONTRACT
-- ============================================================

-- Re-run safe backfills after all relationship/appointment migrations.
insert into public.doctor_provider_links(doctor_id,provider_id,product_id,status,consultation_fee,visiting_days,visiting_time)
select p.doctor_id,p.shop_id,p.id,'approved',coalesce(p.consultation_fee,p.price),p.visiting_days,p.visiting_time
from public.products p join public.profiles d on d.id=p.doctor_id and d.role='doctor'
where p.doctor_id is not null and p.shop_id is not null
on conflict(doctor_id,provider_id) do update set
  product_id=excluded.product_id,
  consultation_fee=excluded.consultation_fee,
  visiting_days=excluded.visiting_days,
  visiting_time=excluded.visiting_time,
  updated_at=now();

update public.products set consultation_fee=price where consultation_fee is null and price is not null;
update public.products set profile_photo_url=thumbnail_url where profile_photo_url is null and thumbnail_url is not null;
update public.appointments
set appointment_start=((appointment_date::text||' '||appointment_time)::timestamp at time zone 'Asia/Dhaka')
where appointment_start is null and appointment_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$';

-- A compact privileged health check used before/after deploys.
create or replace function public.get_backend_integrity_summary()
returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare v jsonb;
begin
  if not public.is_admin_or_above() and not public.is_trusted_backend_context() then
    raise exception 'Admin access required.';
  end if;
  select jsonb_build_object(
    'orphan_products_without_doctor', (select count(*) from public.products p left join public.profiles d on d.id=p.doctor_id where p.doctor_id is null or d.id is null),
    'orphan_products_without_shop', (select count(*) from public.products p left join public.shops s on s.id=p.shop_id where p.shop_id is null or s.id is null),
    'missing_affiliation_links', (select count(*) from public.products p where p.doctor_id is not null and p.shop_id is not null and not exists(select 1 from public.doctor_provider_links l where l.doctor_id=p.doctor_id and l.provider_id=p.shop_id)),
    'duplicate_doctor_provider_products', (select count(*) from (select doctor_id,shop_id from public.products where doctor_id is not null and shop_id is not null group by doctor_id,shop_id having count(*)>1) d),
    'appointments_with_invalid_doctor', (select count(*) from public.appointments a left join public.profiles d on d.id=a.doctor_id where d.id is null or d.role<>'doctor'),
    'approved_provider_rows', (select count(*) from public.profiles where role in ('doctor','hospital') and seller_status='approved' and account_status='active'),
    'generated_at', now()
  ) into v;
  return v;
end $$;
revoke all on function public.get_backend_integrity_summary() from public;
grant execute on function public.get_backend_integrity_summary() to authenticated,service_role;

notify pgrst, 'reload schema';
-- <<< END 09_data_consistency_services.sql

-- >>> BEGIN 10_final_verification.sql
-- ============================================================
-- Production Upgrade V2 — STEP 10: FINAL STRUCTURAL VERIFICATION
-- ============================================================

create table if not exists public.backend_schema_versions (
  version text primary key,
  applied_at timestamptz not null default now(),
  notes text
);

-- Structural assertions only. Existing business data is not required to be perfect.
do $$
declare rls_ok boolean;
begin
  if to_regclass('public.doctor_provider_links') is null then raise exception '[STEP10] doctor_provider_links missing'; end if;
  if to_regclass('public.doctor_schedules') is null then raise exception '[STEP10] doctor_schedules missing'; end if;
  if to_regclass('public.admin_audit_logs') is null then raise exception '[STEP10] admin_audit_logs missing'; end if;
  if to_regprocedure('public.search_nearby_doctors(text,text,double precision,double precision,double precision,integer,integer)') is null then raise exception '[STEP10] nearby Doctor RPC missing'; end if;
  if to_regprocedure('public.search_nearby_ambulances(double precision,double precision,double precision,integer,integer)') is null then raise exception '[STEP10] nearby Ambulance RPC missing'; end if;
  if to_regprocedure('public.search_doctors_catalog(text[],text,text,text,integer,integer)') is null then raise exception '[STEP10] Doctor catalog RPC missing'; end if;
  if to_regprocedure('public.get_doctor_available_slots(uuid,uuid,date)') is null then raise exception '[STEP10] appointment slot RPC missing'; end if;
  if to_regprocedure('public.list_approved_doctors_for_provider()') is null then raise exception '[STEP10] provider Doctor chooser RPC missing'; end if;
  if to_regprocedure('public.search_blood_donors(text,double precision,double precision,integer)') is null then raise exception '[STEP10] Blood Bank search RPC missing'; end if;
  if to_regprocedure('public.create_blood_request(uuid,text,text,text,date,text,text,text,text)') is null then raise exception '[STEP10] Blood request RPC missing'; end if;
  if to_regprocedure('public.increment_product_view(uuid)') is null then raise exception '[STEP10] Product view counter RPC missing'; end if;
  if to_regprocedure('public.increment_product_order_click(uuid)') is null then raise exception '[STEP10] Product click counter RPC missing'; end if;
  if to_regprocedure('public.super_admin_analytics_summary()') is null then raise exception '[STEP10] Super Admin analytics RPC missing'; end if;
  if exists(select 1 from public.profiles where role not in ('patient','doctor','hospital','admin','super_admin')) then raise exception '[STEP10] unsupported profile role remains'; end if;

  select bool_and(c.relrowsecurity) into rls_ok
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in ('profiles','shops','products','seller_verifications','appointments','doctor_provider_links','doctor_schedules','ambulance_services');
  if coalesce(rls_ok,false)=false then raise exception '[STEP10] RLS is not enabled on every protected core table'; end if;

  if exists(select 1 from storage.buckets where id in ('seller-verification','verification-docs') and public=true) then
    raise exception '[STEP10] verification document bucket is unexpectedly public';
  end if;

  if public.count_super_admins()=0 then
    raise warning '[STEP10] No active Super Admin found. Keep a trusted bootstrap/service-role path available.';
  end if;
end $$;

insert into public.backend_schema_versions(version,notes)
values('doctor-v1-backend-v10','Canonical schema, RLS, location RPCs, doctor-provider links, appointment integrity, audit, performance and service/data consistency')
on conflict(version) do update set applied_at=now(),notes=excluded.notes;

create or replace function public.get_backend_schema_version()
returns text language sql stable security definer set search_path=public as $$
  select version from public.backend_schema_versions order by applied_at desc limit 1;
$$;
revoke all on function public.get_backend_schema_version() from public;
grant execute on function public.get_backend_schema_version() to authenticated,service_role;

notify pgrst, 'reload schema';
-- <<< END 10_final_verification.sql

-- >>> BEGIN 11_super_admin_user_locations.sql
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
-- <<< END 11_super_admin_user_locations.sql

-- >>> BEGIN 12_verification_unified_flow.sql
-- ============================================================
-- Medical Operations Upgrade — STEP 02 / MIGRATION 12
-- SINGLE PROVIDER VERIFICATION DECISION PATH
-- ============================================================


alter table public.seller_verifications drop constraint if exists seller_verifications_status_check;
alter table public.seller_verifications add constraint seller_verifications_status_check
  check (status in ('pending','under_review','approved','rejected'));

-- Applicants may only submit a pending application. They cannot forge admin review fields.
create or replace function public.enforce_provider_verification_submission()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if auth.uid()=new.user_id and not public.is_admin_or_above() then
    if tg_op='INSERT' then
      if exists(
        select 1 from public.seller_verifications sv
        where sv.user_id=auth.uid() and sv.status in ('pending','under_review')
      ) then
        raise exception 'An active verification application already exists.';
      end if;
      new.status:='pending';
      new.admin_note:=null;
    else
      if new.status is distinct from old.status then
        raise exception 'Verification status can only be changed by an Admin.';
      end if;
      if new.admin_note is distinct from old.admin_note then
        raise exception 'Admin review notes cannot be changed by the applicant.';
      end if;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_prevent_self_verification_status_change on public.seller_verifications;
drop trigger if exists trg_enforce_provider_verification_submission on public.seller_verifications;
create trigger trg_enforce_provider_verification_submission
  before insert or update on public.seller_verifications
  for each row execute procedure public.enforce_provider_verification_submission();

drop policy if exists "seller_verifications_insert_own" on public.seller_verifications;
create policy "seller_verifications_insert_own" on public.seller_verifications for insert with check (
  user_id=auth.uid()
  and status='pending'
  and admin_note is null
  and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role in ('doctor','hospital') and p.account_status='active')
);

-- Direct REST updates to profiles.seller_status are no longer a valid approval path.
create or replace function public.guard_provider_status_direct_write()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  if new.seller_status is not distinct from old.seller_status then return new; end if;
  if current_user in ('service_role','postgres','supabase_admin') then return new; end if;
  if coalesce(current_setting('app.bypass_role_guard',true),'false')='true' then return new; end if;
  raise exception 'Provider status must be changed through the verification workflow.';
end $$;
drop trigger if exists trg_guard_provider_status_direct_write on public.profiles;
create trigger trg_guard_provider_status_direct_write
  before update of seller_status on public.profiles
  for each row execute procedure public.guard_provider_status_direct_write();

create or replace function public.review_provider_verification(
  p_verification_id uuid,
  p_status text,
  p_admin_note text default null
)
returns public.seller_verifications
language plpgsql
security definer
set search_path=public
as $$
declare v public.seller_verifications;
begin
  if not public.is_admin_or_above() and not public.is_trusted_backend_context() then
    raise exception 'Admin access required.';
  end if;
  if p_status not in ('under_review','approved','rejected') then
    raise exception 'Invalid verification review status.';
  end if;

  select * into v from public.seller_verifications where id=p_verification_id for update;
  if v.id is null then raise exception 'Verification application not found.'; end if;

  if p_status='under_review' and v.status<>'pending' then
    raise exception 'Only a pending application can move to Under Review.';
  end if;
  if p_status in ('approved','rejected') and v.status<>'under_review' then
    raise exception 'Application must be Under Review before a final decision.';
  end if;
  if p_status='rejected' and nullif(btrim(coalesce(p_admin_note,'')),'') is null then
    raise exception 'Rejection reason is required.';
  end if;

  update public.seller_verifications
  set status=p_status,admin_note=case when p_status='under_review' then null else nullif(btrim(p_admin_note),'') end,updated_at=now()
  where id=p_verification_id
  returning * into v;
  return v;
end $$;
revoke all on function public.review_provider_verification(uuid,text,text) from public;
grant execute on function public.review_provider_verification(uuid,text,text) to authenticated,service_role;

-- Make sure verification decisions still synchronize profile status.
create or replace function public.sync_provider_verification_status()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status in ('approved','rejected') then
    perform set_config('app.bypass_role_guard','true',true);
    update public.profiles
      set seller_status=new.status
      where id=new.user_id and role in ('doctor','hospital');
  elsif new.status in ('pending','under_review') then
    perform set_config('app.bypass_role_guard','true',true);
    update public.profiles
      set seller_status='pending'
      where id=new.user_id and role in ('doctor','hospital') and seller_status<>'approved';
  end if;
  return new;
end $$;

notify pgrst, 'reload schema';
-- <<< END 12_verification_unified_flow.sql

-- >>> BEGIN 13_doctor_provider_invitations.sql
-- ============================================================
-- Medical Operations Upgrade — STEP 03 / MIGRATION 13
-- HOSPITAL <-> DOCTOR INVITATION / ACCEPTANCE FLOW
-- ============================================================

alter table public.doctor_provider_links
  add column if not exists invited_by uuid references public.profiles(id) on delete set null,
  add column if not exists invitation_message text,
  add column if not exists responded_at timestamptz,
  add column if not exists inactive_at timestamptz;

-- Existing approved relationships remain valid. New hospital relationships must start pending.
create or replace function public.guard_doctor_provider_link_change()
returns trigger
language plpgsql
set search_path=public
as $$
declare
  v_owner uuid;
  v_owner_role text;
  v_owner_status text;
  v_owner_account text;
begin
  if current_user in ('service_role','postgres','supabase_admin') or public.is_admin_or_above() then
    return new;
  end if;

  if tg_op='INSERT' then
    select s.owner_id,p.role,p.seller_status,p.account_status into v_owner,v_owner_role,v_owner_status,v_owner_account
    from public.shops s join public.profiles p on p.id=s.owner_id
    where s.id=new.provider_id;
    if v_owner is null then raise exception 'Provider not found.'; end if;
    if auth.uid()=v_owner and v_owner_role='hospital' then
      if v_owner_status<>'approved' or v_owner_account<>'active' then raise exception 'Approved active Hospital account required.'; end if;
      if new.status<>'pending' then raise exception 'Hospital invitations must start as pending.'; end if;
      new.invited_by:=auth.uid();
    elsif auth.uid()=v_owner and v_owner_role='doctor' and new.doctor_id=auth.uid() then
      new.status:='approved';
      new.responded_at:=coalesce(new.responded_at,now());
    else
      raise exception 'You cannot create this Doctor affiliation.';
    end if;
    return new;
  end if;

  select s.owner_id,p.role into v_owner,v_owner_role
  from public.shops s join public.profiles p on p.id=s.owner_id
  where s.id=old.provider_id;
  if v_owner is null then raise exception 'Provider not found.'; end if;

  if new.doctor_id is distinct from old.doctor_id or new.provider_id is distinct from old.provider_id then
    raise exception 'Doctor/provider identity cannot be changed.';
  end if;

  if auth.uid()=old.doctor_id then
    if old.status='pending' and new.status in ('approved','rejected') then
      new.responded_at:=now();
      return new;
    end if;
    if old.status='approved' and new.status='inactive' then
      new.inactive_at:=now();
      return new;
    end if;
    if new.status is not distinct from old.status then return new; end if;
    raise exception 'Doctor can only accept/reject a pending invitation or leave an approved affiliation.';
  end if;

  if auth.uid()=v_owner then
    if old.status in ('rejected','inactive') and new.status='pending' then
      new.invited_by:=auth.uid(); new.responded_at:=null; new.inactive_at:=null;
      return new;
    end if;
    if old.status='approved' and new.status='inactive' then
      new.inactive_at:=now();
      return new;
    end if;
    if new.status is not distinct from old.status then return new; end if;
    raise exception 'Provider cannot approve its own Doctor invitation.';
  end if;

  raise exception 'You cannot update this Doctor affiliation.';
end $$;

drop trigger if exists trg_guard_doctor_provider_link_change on public.doctor_provider_links;
create trigger trg_guard_doctor_provider_link_change
  before insert or update on public.doctor_provider_links
  for each row execute procedure public.guard_doctor_provider_link_change();

-- Tighten table policies. Approval is a Doctor decision, not a Hospital decision.
drop policy if exists "doctor_provider_links_public_read" on public.doctor_provider_links;
drop policy if exists "doctor_provider_links_participants" on public.doctor_provider_links;
drop policy if exists "doctor_provider_links_provider_manage" on public.doctor_provider_links;
drop policy if exists "doctor_provider_links_admin_all" on public.doctor_provider_links;
drop policy if exists "doctor_provider_links_participant_insert" on public.doctor_provider_links;
drop policy if exists "doctor_provider_links_participant_update" on public.doctor_provider_links;
create policy "doctor_provider_links_public_read" on public.doctor_provider_links for select using(
  status='approved'
  and public.is_doctor_account_public(doctor_id)
  and exists(select 1 from public.shops s where s.id=provider_id and s.is_active=true and public.is_provider_account_public(s.owner_id))
);
create policy "doctor_provider_links_participants" on public.doctor_provider_links for select using(
  doctor_id=auth.uid()
  or exists(select 1 from public.shops s where s.id=provider_id and s.owner_id=auth.uid())
  or public.is_admin_or_above()
);
create policy "doctor_provider_links_participant_insert" on public.doctor_provider_links for insert with check(
  public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=provider_id and s.owner_id=auth.uid())
);
create policy "doctor_provider_links_participant_update" on public.doctor_provider_links for update using(
  public.is_admin_or_above()
  or doctor_id=auth.uid()
  or exists(select 1 from public.shops s where s.id=provider_id and s.owner_id=auth.uid())
) with check(
  public.is_admin_or_above()
  or doctor_id=auth.uid()
  or exists(select 1 from public.shops s where s.id=provider_id and s.owner_id=auth.uid())
);
create policy "doctor_provider_links_admin_all" on public.doctor_provider_links for delete using(public.is_admin_or_above());

-- Product/Doctor listing now requires an accepted affiliation at Hospital-owned providers.
-- Public visibility also enforces the accepted affiliation, so historical/disabled
-- Hospital rows cannot remain visible merely because products.is_active=true.
drop policy if exists "products_select_public_active" on public.products;
create policy "products_select_public_active" on public.products for select using (
  (
    is_active=true
    and public.is_doctor_account_public(doctor_id)
    and exists(
      select 1
      from public.shops s
      join public.profiles owner on owner.id=s.owner_id
      where s.id=shop_id and s.is_active=true and public.is_provider_account_public(s.owner_id)
        and (
          (owner.role='doctor' and owner.id=doctor_id)
          or (
            owner.role='hospital'
            and exists(select 1 from public.doctor_provider_links l
                       where l.doctor_id=products.doctor_id and l.provider_id=products.shop_id and l.status='approved')
          )
        )
    )
  )
  or public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
);

create or replace function public.set_product_doctor_id()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_owner uuid;
  v_owner_role text;
begin
  select s.owner_id,p.role into v_owner,v_owner_role
  from public.shops s join public.profiles p on p.id=s.owner_id
  where s.id=new.shop_id;

  if v_owner is null then raise exception 'A valid Chamber/Hospital is required.'; end if;
  if new.doctor_id is null and v_owner_role='doctor' then new.doctor_id:=v_owner; end if;
  if new.doctor_id is null then raise exception 'ডাক্তারের প্রোফাইলের জন্য ডাক্তার নির্বাচন করতে হবে।'; end if;

  if not exists(select 1 from public.profiles p where p.id=new.doctor_id and p.role='doctor' and p.seller_status='approved' and p.account_status='active') then
    raise exception 'শুধু অনুমোদিত ডাক্তার অ্যাকাউন্টকে Doctor Profile হিসেবে যোগ করা যাবে।';
  end if;
  if not exists(select 1 from public.profiles p where p.id=v_owner and p.role in ('doctor','hospital') and p.seller_status='approved' and p.account_status='active') then
    raise exception 'অনুমোদিত চেম্বার/হাসপাতাল প্রয়োজন।';
  end if;
  if v_owner_role='doctor' and new.doctor_id<>v_owner then
    raise exception 'A Doctor-owned chamber can only publish its owner Doctor profile.';
  end if;
  if v_owner_role='hospital' and not exists(
    select 1 from public.doctor_provider_links l
    where l.doctor_id=new.doctor_id and l.provider_id=new.shop_id and l.status='approved'
  ) then
    raise exception 'Doctor must accept the Hospital invitation before the profile can be published.';
  end if;
  if exists(select 1 from public.products x where x.doctor_id=new.doctor_id and x.shop_id=new.shop_id and x.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)) then
    raise exception 'This Doctor is already listed at this provider.';
  end if;
  return new;
end $$;

create or replace function public.sync_product_doctor_provider_link()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_owner_role text;
begin
  select p.role into v_owner_role from public.shops s join public.profiles p on p.id=s.owner_id where s.id=new.shop_id;
  if v_owner_role='doctor' then
    insert into public.doctor_provider_links(
      doctor_id,provider_id,product_id,status,consultation_fee,visiting_days,visiting_time,responded_at,updated_at
    ) values(
      new.doctor_id,new.shop_id,new.id,'approved',coalesce(new.consultation_fee,new.price),new.visiting_days,new.visiting_time,now(),now()
    ) on conflict(doctor_id,provider_id) do update set
      product_id=excluded.product_id,status='approved',consultation_fee=excluded.consultation_fee,
      visiting_days=excluded.visiting_days,visiting_time=excluded.visiting_time,updated_at=now();
  else
    update public.doctor_provider_links set
      product_id=new.id,
      consultation_fee=coalesce(new.consultation_fee,new.price),
      visiting_days=new.visiting_days,
      visiting_time=new.visiting_time,
      updated_at=now()
    where doctor_id=new.doctor_id and provider_id=new.shop_id and status='approved';
  end if;
  return new;
end $$;

create or replace function public.invite_doctor_to_provider(p_doctor_id uuid,p_message text default null)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare v_shop uuid; v_role text; v_provider_status text; v_account_status text; v_id uuid; v_status text;
begin
  if auth.uid() is null then raise exception 'Login required.'; end if;
  select s.id,p.role,p.seller_status,p.account_status into v_shop,v_role,v_provider_status,v_account_status from public.shops s join public.profiles p on p.id=s.owner_id where s.owner_id=auth.uid();
  if v_shop is null or v_role<>'hospital' or v_provider_status<>'approved' or v_account_status<>'active' then raise exception 'Approved active Hospital/Chamber account required.'; end if;
  if not exists(select 1 from public.profiles where id=p_doctor_id and role='doctor' and seller_status='approved' and account_status='active') then
    raise exception 'Approved active Doctor not found.';
  end if;
  select id,status into v_id,v_status from public.doctor_provider_links where doctor_id=p_doctor_id and provider_id=v_shop;
  if v_status='approved' then return v_id; end if;
  if v_id is null then
    insert into public.doctor_provider_links(doctor_id,provider_id,status,invited_by,invitation_message,created_at,updated_at)
    values(p_doctor_id,v_shop,'pending',auth.uid(),nullif(btrim(p_message),''),now(),now()) returning id into v_id;
  else
    update public.doctor_provider_links set status='pending',invited_by=auth.uid(),invitation_message=nullif(btrim(p_message),''),responded_at=null,inactive_at=null,updated_at=now()
    where id=v_id;
  end if;
  return v_id;
end $$;
revoke all on function public.invite_doctor_to_provider(uuid,text) from public;
grant execute on function public.invite_doctor_to_provider(uuid,text) to authenticated,service_role;

create or replace function public.respond_doctor_provider_invitation(p_link_id uuid,p_accept boolean)
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  if auth.uid() is null then raise exception 'Login required.'; end if;
  update public.doctor_provider_links
  set status=case when p_accept then 'approved' else 'rejected' end,responded_at=now(),updated_at=now()
  where id=p_link_id and doctor_id=auth.uid() and status='pending';
  if not found then raise exception 'Pending invitation not found.'; end if;
end $$;
revoke all on function public.respond_doctor_provider_invitation(uuid,boolean) from public;
grant execute on function public.respond_doctor_provider_invitation(uuid,boolean) to authenticated,service_role;

create or replace function public.leave_doctor_provider_affiliation(p_link_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'Login required.'; end if;
  update public.doctor_provider_links set status='inactive',inactive_at=now(),updated_at=now()
  where id=p_link_id and status='approved'
    and (doctor_id=auth.uid() or exists(select 1 from public.shops s where s.id=provider_id and s.owner_id=auth.uid()));
  if not found then raise exception 'Active affiliation not found.'; end if;
end $$;
revoke all on function public.leave_doctor_provider_affiliation(uuid) from public;
grant execute on function public.leave_doctor_provider_affiliation(uuid) to authenticated,service_role;

create or replace function public.list_my_provider_invitations()
returns table(link_id uuid,provider_id uuid,provider_name text,status text,invitation_message text,created_at timestamptz,responded_at timestamptz)
language sql stable security definer set search_path=public as $$
  select l.id,l.provider_id,coalesce(s.chamber_name,s.shop_name),l.status,l.invitation_message,l.created_at,l.responded_at
  from public.doctor_provider_links l join public.shops s on s.id=l.provider_id
  where l.doctor_id=auth.uid()
  order by case l.status when 'pending' then 0 when 'approved' then 1 else 2 end,l.updated_at desc;
$$;
revoke all on function public.list_my_provider_invitations() from public;
grant execute on function public.list_my_provider_invitations() to authenticated,service_role;

create or replace function public.list_provider_doctor_links()
returns table(link_id uuid,doctor_id uuid,doctor_name text,status text,invitation_message text,created_at timestamptz,responded_at timestamptz,product_id uuid)
language plpgsql stable security definer set search_path=public as $$
declare v_shop uuid;
begin
  select id into v_shop from public.shops where owner_id=auth.uid();
  if v_shop is null then return; end if;
  return query
    select l.id,l.doctor_id,p.full_name,l.status,l.invitation_message,l.created_at,l.responded_at,l.product_id
    from public.doctor_provider_links l join public.profiles p on p.id=l.doctor_id
    where l.provider_id=v_shop order by case l.status when 'pending' then 0 when 'approved' then 1 else 2 end,l.updated_at desc;
end $$;
revoke all on function public.list_provider_doctor_links() from public;
grant execute on function public.list_provider_doctor_links() to authenticated,service_role;

create or replace function public.search_invitable_doctors_for_provider(p_query text default null,p_limit integer default 50)
returns table(id uuid,full_name text,phone text,existing_status text)
language plpgsql stable security definer set search_path=public as $$
declare v_shop uuid; v_role text; v_provider_status text; v_account_status text;
begin
  select s.id,p.role,p.seller_status,p.account_status into v_shop,v_role,v_provider_status,v_account_status from public.shops s join public.profiles p on p.id=s.owner_id where s.owner_id=auth.uid();
  if v_shop is null or v_role<>'hospital' or v_provider_status<>'approved' or v_account_status<>'active' then return; end if;
  return query
  select d.id,d.full_name,d.phone,l.status
  from public.profiles d
  left join public.doctor_provider_links l on l.doctor_id=d.id and l.provider_id=v_shop
  where d.role='doctor' and d.seller_status='approved' and d.account_status='active'
    and (p_query is null or btrim(p_query)='' or coalesce(d.full_name,'') ilike '%'||p_query||'%' or coalesce(d.phone,'') ilike '%'||p_query||'%')
  order by d.full_name nulls last limit greatest(1,least(coalesce(p_limit,50),100));
end $$;
revoke all on function public.search_invitable_doctors_for_provider(text,integer) from public;
grant execute on function public.search_invitable_doctors_for_provider(text,integer) to authenticated,service_role;

-- Existing ProductEdit caller: now returns only Doctors who accepted this provider.
create or replace function public.list_approved_doctors_for_provider()
returns table(id uuid, full_name text)
language plpgsql stable security definer set search_path=public as $$
declare v_shop uuid; v_role text;
begin
  select s.id,p.role into v_shop,v_role from public.shops s join public.profiles p on p.id=s.owner_id where s.owner_id=auth.uid();
  if v_shop is null then return; end if;
  if v_role='doctor' then
    return query select p.id,p.full_name from public.profiles p where p.id=auth.uid() and p.role='doctor' and p.seller_status='approved';
  else
    return query
    select p.id,p.full_name from public.doctor_provider_links l join public.profiles p on p.id=l.doctor_id
    where l.provider_id=v_shop and l.status='approved' and p.role='doctor' and p.seller_status='approved' and p.account_status='active'
    order by p.full_name nulls last;
  end if;
end $$;
revoke all on function public.list_approved_doctors_for_provider() from public;
grant execute on function public.list_approved_doctors_for_provider() to authenticated,service_role;

create index if not exists idx_doctor_provider_links_pending_doctor on public.doctor_provider_links(doctor_id,status,updated_at desc);
create index if not exists idx_doctor_provider_links_provider_updated on public.doctor_provider_links(provider_id,status,updated_at desc);

notify pgrst, 'reload schema';
-- <<< END 13_doctor_provider_invitations.sql

-- >>> BEGIN 14_doctor_schedule_management.sql
-- ============================================================
-- Medical Operations Upgrade — STEP 04 / MIGRATION 14
-- STRUCTURED DOCTOR SCHEDULE / BREAK / EXCEPTION MANAGEMENT
-- ============================================================

alter table public.doctor_schedules
  add column if not exists break_start_time time,
  add column if not exists break_end_time time;

alter table public.doctor_schedules drop constraint if exists doctor_schedules_break_check;
alter table public.doctor_schedules add constraint doctor_schedules_break_check check(
  (break_start_time is null and break_end_time is null)
  or (break_start_time is not null and break_end_time is not null and break_end_time>break_start_time and break_start_time>=start_time and break_end_time<=end_time)
);

-- Hospital may manage a Doctor schedule only after the Doctor accepted affiliation.
drop policy if exists "doctor_schedules_public_read" on public.doctor_schedules;
drop policy if exists "doctor_schedules_manage" on public.doctor_schedules;
create policy "doctor_schedules_public_read" on public.doctor_schedules for select using(
  (is_active=true and exists(select 1 from public.doctor_provider_links l where l.doctor_id=doctor_schedules.doctor_id and l.provider_id=doctor_schedules.shop_id and l.status='approved'))
  or doctor_schedules.doctor_id=auth.uid()
  or public.is_admin_or_above()
  or (public.is_appointment_provider_owner(shop_id) and exists(select 1 from public.doctor_provider_links l where l.doctor_id=doctor_schedules.doctor_id and l.provider_id=doctor_schedules.shop_id and l.status='approved'))
);
create policy "doctor_schedules_manage" on public.doctor_schedules for all using(
  public.is_admin_or_above()
  or (
    exists(select 1 from public.doctor_provider_links l where l.doctor_id=doctor_schedules.doctor_id and l.provider_id=doctor_schedules.shop_id and l.status='approved')
    and (doctor_schedules.doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id))
  )
) with check(
  public.is_admin_or_above()
  or (
    exists(select 1 from public.doctor_provider_links l where l.doctor_id=doctor_schedules.doctor_id and l.provider_id=doctor_schedules.shop_id and l.status='approved')
    and (doctor_schedules.doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id))
  )
);

-- Exceptions follow the same accepted-affiliation requirement for Hospital users.
drop policy if exists "doctor_schedule_exceptions_public_read" on public.doctor_schedule_exceptions;
drop policy if exists "doctor_schedule_exceptions_manage" on public.doctor_schedule_exceptions;
create policy "doctor_schedule_exceptions_public_read" on public.doctor_schedule_exceptions for select using(
  doctor_schedule_exceptions.doctor_id=auth.uid() or public.is_admin_or_above()
  or (doctor_schedule_exceptions.shop_id is not null and public.is_appointment_provider_owner(doctor_schedule_exceptions.shop_id)
      and exists(select 1 from public.doctor_provider_links l where l.doctor_id=doctor_schedule_exceptions.doctor_id and l.provider_id=doctor_schedule_exceptions.shop_id and l.status='approved'))
);
create policy "doctor_schedule_exceptions_manage" on public.doctor_schedule_exceptions for all using(
  public.is_admin_or_above()
  or (
    doctor_schedule_exceptions.shop_id is not null
    and exists(select 1 from public.doctor_provider_links l where l.doctor_id=doctor_schedule_exceptions.doctor_id and l.provider_id=doctor_schedule_exceptions.shop_id and l.status='approved')
    and (doctor_schedule_exceptions.doctor_id=auth.uid() or public.is_appointment_provider_owner(doctor_schedule_exceptions.shop_id))
  )
) with check(
  public.is_admin_or_above()
  or (
    doctor_schedule_exceptions.shop_id is not null
    and exists(select 1 from public.doctor_provider_links l where l.doctor_id=doctor_schedule_exceptions.doctor_id and l.provider_id=doctor_schedule_exceptions.shop_id and l.status='approved')
    and (doctor_schedule_exceptions.doctor_id=auth.uid() or public.is_appointment_provider_owner(doctor_schedule_exceptions.shop_id))
  )
);

-- Atomic day-level schedule save. Avoids the UI delete-then-insert gap and re-checks authorization server-side.
create or replace function public.save_doctor_schedule_day(
  p_doctor_id uuid,
  p_shop_id uuid,
  p_day_of_week integer,
  p_enabled boolean,
  p_start_time time default null,
  p_end_time time default null,
  p_slot_duration_minutes integer default 30,
  p_break_start_time time default null,
  p_break_end_time time default null
)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare v_allowed boolean:=false;
begin
  if auth.uid() is null then raise exception 'Login required.'; end if;
  if p_day_of_week not between 0 and 6 then raise exception 'Invalid day of week.'; end if;
  if coalesce(p_slot_duration_minutes,30) not between 5 and 240 then raise exception 'Invalid slot duration.'; end if;

  v_allowed:=public.is_admin_or_above()
    or (
      exists(select 1 from public.doctor_provider_links l
             where l.doctor_id=p_doctor_id and l.provider_id=p_shop_id and l.status='approved')
      and (p_doctor_id=auth.uid() or public.is_appointment_provider_owner(p_shop_id))
    );
  if not v_allowed then raise exception 'You cannot manage this Doctor schedule.'; end if;

  if p_enabled then
    if p_start_time is null or p_end_time is null or p_end_time<=p_start_time then
      raise exception 'Valid schedule start/end time is required.';
    end if;
    if (p_break_start_time is null) <> (p_break_end_time is null) then
      raise exception 'Both break start and end are required.';
    end if;
    if p_break_start_time is not null and (
      p_break_end_time<=p_break_start_time or p_break_start_time<p_start_time or p_break_end_time>p_end_time
    ) then raise exception 'Invalid break period.'; end if;
  end if;

  delete from public.doctor_schedules
  where doctor_id=p_doctor_id and shop_id=p_shop_id and day_of_week=p_day_of_week;

  if p_enabled then
    insert into public.doctor_schedules(
      doctor_id,shop_id,day_of_week,start_time,end_time,slot_duration_minutes,
      break_start_time,break_end_time,is_active,updated_at
    ) values(
      p_doctor_id,p_shop_id,p_day_of_week,p_start_time,p_end_time,coalesce(p_slot_duration_minutes,30),
      p_break_start_time,p_break_end_time,true,now()
    );
  end if;
end $$;
revoke all on function public.save_doctor_schedule_day(uuid,uuid,integer,boolean,time,time,integer,time,time) from public;
grant execute on function public.save_doctor_schedule_day(uuid,uuid,integer,boolean,time,time,integer,time,time) to authenticated,service_role;

create or replace function public.get_doctor_available_slots(p_doctor_id uuid,p_shop_id uuid,p_date date)
returns table(slot_time text)
language sql stable security definer set search_path=public as $$
  with schedule as (
    select ds.start_time,ds.end_time,ds.slot_duration_minutes,ds.break_start_time,ds.break_end_time
    from public.doctor_schedules ds
    where ds.doctor_id=p_doctor_id and ds.shop_id=p_shop_id and ds.is_active=true
      and ds.day_of_week=extract(dow from p_date)::integer
      and not exists(select 1 from public.doctor_schedule_exceptions e where e.doctor_id=p_doctor_id
        and (e.shop_id is null or e.shop_id=p_shop_id) and e.exception_date=p_date and e.is_available=false)
  ), slots as (
    select gs as slot_start,
           (gs at time zone 'Asia/Dhaka')::time as t,
           s.slot_duration_minutes,s.break_start_time,s.break_end_time
    from schedule s cross join lateral generate_series(
      (p_date+s.start_time) at time zone 'Asia/Dhaka',
      (p_date+(s.end_time-make_interval(mins=>s.slot_duration_minutes))) at time zone 'Asia/Dhaka',
      make_interval(mins=>s.slot_duration_minutes)
    ) gs
  )
  select to_char(slots.t,'HH24:MI')
  from slots
  where public.is_doctor_account_public(p_doctor_id)
    and exists(select 1 from public.doctor_provider_links l where l.doctor_id=p_doctor_id and l.provider_id=p_shop_id and l.status='approved')
    and not (
      slots.break_start_time is not null and slots.break_end_time is not null
      and slots.t < slots.break_end_time
      and (slots.t + make_interval(mins=>slots.slot_duration_minutes)) > slots.break_start_time
    )
    and not exists(
      select 1 from public.appointments a
      where a.doctor_id=p_doctor_id
        and a.status in ('pending','confirmed','rescheduled')
        and a.appointment_start is not null
        and a.appointment_start < slots.slot_start + make_interval(mins=>slots.slot_duration_minutes)
        and a.appointment_start + make_interval(mins=>coalesce(a.duration_minutes,30)) > slots.slot_start
    )
  order by slots.t;
$$;
revoke all on function public.get_doctor_available_slots(uuid,uuid,date) from public;
grant execute on function public.get_doctor_available_slots(uuid,uuid,date) to anon,authenticated,service_role;

create or replace function public.has_doctor_schedule(p_doctor_id uuid,p_shop_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.doctor_schedules ds
    where ds.doctor_id=p_doctor_id and ds.shop_id=p_shop_id and ds.is_active=true
  ) and exists(
    select 1 from public.doctor_provider_links l
    where l.doctor_id=p_doctor_id and l.provider_id=p_shop_id and l.status='approved'
  );
$$;
revoke all on function public.has_doctor_schedule(uuid,uuid) from public;
grant execute on function public.has_doctor_schedule(uuid,uuid) to anon,authenticated,service_role;

create index if not exists idx_doctor_schedules_provider_day on public.doctor_schedules(shop_id,doctor_id,day_of_week,is_active);

notify pgrst, 'reload schema';
-- <<< END 14_doctor_schedule_management.sql

-- >>> BEGIN 15_appointment_lifecycle_notifications.sql
-- ============================================================
-- Medical Operations Upgrade — STEP 05 / MIGRATION 15
-- COMPLETE APPOINTMENT LIFECYCLE + HISTORY + NOTIFICATION FOUNDATION
-- ============================================================

alter table public.appointments
  add column if not exists reschedule_reason text,
  add column if not exists completed_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists no_show_at timestamptz;

alter table public.appointments drop constraint if exists appointments_status_check;
alter table public.appointments add constraint appointments_status_check
  check (status in ('pending','confirmed','cancelled','completed','rescheduled','no_show'));

-- Bring valid legacy appointment times into the structured conflict engine before new bookings start.
update public.appointments
set appointment_time=btrim(appointment_time),
    appointment_start=((appointment_date::text||' '||btrim(appointment_time))::timestamp at time zone 'Asia/Dhaka')
where appointment_start is null
  and appointment_date is not null
  and nullif(btrim(coalesce(appointment_time,'')),'') is not null
  and btrim(appointment_time) ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$';

create table if not exists public.appointment_status_history (
  id uuid primary key default gen_random_uuid(),
  appointment_id uuid not null references public.appointments(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  old_status text,
  new_status text not null,
  old_date date,
  new_date date,
  old_time text,
  new_time text,
  note text,
  created_at timestamptz not null default now()
);
create index if not exists idx_appointment_history_appointment on public.appointment_status_history(appointment_id,created_at desc);

alter table public.appointment_status_history enable row level security;
drop policy if exists "appointment_history_participant_read" on public.appointment_status_history;
create policy "appointment_history_participant_read" on public.appointment_status_history for select using(
  public.is_admin_or_above() or exists(
    select 1 from public.appointments a where a.id=appointment_id and (
      a.patient_id=auth.uid() or a.doctor_id=auth.uid() or public.is_appointment_provider_owner(a.shop_id)
    )
  )
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  message text,
  entity_type text,
  entity_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_notifications_user_unread on public.notifications(user_id,is_read,created_at desc);
alter table public.notifications enable row level security;
drop policy if exists "notifications_own_read" on public.notifications;
drop policy if exists "notifications_own_update" on public.notifications;
create policy "notifications_own_read" on public.notifications for select using(user_id=auth.uid() or public.is_admin_or_above());
create policy "notifications_own_update" on public.notifications for update using(user_id=auth.uid()) with check(user_id=auth.uid());

create or replace function public.push_notification(p_user_id uuid,p_type text,p_title text,p_message text default null,p_entity_type text default null,p_entity_id uuid default null)
returns void language plpgsql security definer set search_path=public as $$
begin
  if p_user_id is null then return; end if;
  insert into public.notifications(user_id,type,title,message,entity_type,entity_id)
  values(p_user_id,p_type,p_title,p_message,p_entity_type,p_entity_id);
end $$;
revoke all on function public.push_notification(uuid,text,text,text,text,uuid) from public;
grant execute on function public.push_notification(uuid,text,text,text,text,uuid) to service_role;

-- Re-validate insert bookings, including schedule breaks.
create or replace function public.set_appointment_defaults()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  d record; pat record; ch record; v_time time; v_has_schedule boolean; v_duration integer; v_schedule_start time;
begin
  if auth.uid() is not null and not public.is_trusted_backend_context() then
    new.patient_id:=auth.uid();
  end if;
  if new.patient_id is null then raise exception 'Patient login is required.'; end if;
  select p.id,p.full_name,p.phone,p.role into pat from public.profiles p where p.id=new.patient_id and p.account_status='active';
  if pat.id is null or pat.role<>'patient' then raise exception 'Active Patient profile required.'; end if;
  if nullif(btrim(coalesce(pat.phone,'')),'') is null then raise exception 'অ্যাপয়েন্টমেন্ট নিতে আগে আপনার প্রোফাইলে ফোন নম্বর যোগ করুন।'; end if;
  select p.id,p.full_name into d from public.profiles p
    where p.id=new.doctor_id and p.role='doctor' and p.seller_status='approved' and p.account_status='active';
  if d.id is null then raise exception 'Doctor is not approved/active.'; end if;
  if new.appointment_date is null or new.appointment_date < (now() at time zone 'Asia/Dhaka')::date then
    raise exception 'Appointment date cannot be in the past.';
  end if;

  if new.product_id is null then
    raise exception 'A published Doctor profile is required for an appointment.';
  end if;

  if new.product_id is not null then
    select s.id,s.shop_name,pr.doctor_id into ch
    from public.products pr join public.shops s on s.id=pr.shop_id
    where pr.id=new.product_id and pr.is_active=true and s.is_active=true
      and public.is_provider_account_public(s.owner_id)
      and exists(select 1 from public.doctor_provider_links l where l.provider_id=s.id and l.doctor_id=pr.doctor_id and l.status='approved');
    if ch.id is null or ch.doctor_id is distinct from new.doctor_id then raise exception 'Invalid Doctor profile.'; end if;
    new.shop_id:=ch.id;
    new.chamber_name:=coalesce(new.chamber_name,ch.shop_name);
  elsif new.shop_id is not null then
    select s.id,s.shop_name into ch from public.shops s
    where s.id=new.shop_id and s.is_active=true and public.is_provider_account_public(s.owner_id)
      and exists(select 1 from public.doctor_provider_links l where l.provider_id=s.id and l.doctor_id=new.doctor_id and l.status='approved');
    if ch.id is null then raise exception 'Invalid doctor/chamber affiliation.'; end if;
    new.chamber_name:=coalesce(new.chamber_name,ch.shop_name);
  end if;

  if new.shop_id is null then
    raise exception 'A valid Hospital/Chamber is required for an appointment.';
  end if;

  if new.shop_id is not null then
    select exists(select 1 from public.doctor_schedules ds where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true)
      into v_has_schedule;
    if v_has_schedule and (new.appointment_time is null or btrim(new.appointment_time) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$') then
      raise exception 'An available appointment slot is required for this Doctor.';
    end if;
  end if;

  if nullif(btrim(coalesce(new.appointment_time,'')),'') is not null then
    if btrim(new.appointment_time) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
      raise exception 'Appointment time must use HH:MM format.';
    end if;
    new.appointment_time:=btrim(new.appointment_time);
    v_time:=new.appointment_time::time;
    new.appointment_start:=((new.appointment_date::text||' '||new.appointment_time)::timestamp at time zone 'Asia/Dhaka');
    if new.appointment_start < now() then raise exception 'Appointment time cannot be in the past.'; end if;
  else
    new.appointment_time:=null;
    new.appointment_start:=null;
  end if;

  if new.appointment_start is not null and new.shop_id is not null then
    if exists(select 1 from public.doctor_schedule_exceptions e where e.doctor_id=new.doctor_id
      and (e.shop_id is null or e.shop_id=new.shop_id) and e.exception_date=new.appointment_date and e.is_available=false) then
      raise exception 'Doctor is unavailable on this date.';
    end if;
    select exists(select 1 from public.doctor_schedules ds where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true)
      into v_has_schedule;
    if v_has_schedule then
      select ds.slot_duration_minutes,ds.start_time into v_duration,v_schedule_start
      from public.doctor_schedules ds
      where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true
        and ds.day_of_week=extract(dow from new.appointment_date)::integer
        and v_time>=ds.start_time
        and (v_time + make_interval(mins=>ds.slot_duration_minutes))<=ds.end_time
        and mod(floor(extract(epoch from (v_time-ds.start_time))/60)::integer,ds.slot_duration_minutes)=0
      order by ds.start_time limit 1;
      if v_duration is null then raise exception 'Please select a valid available Doctor slot.'; end if;
      new.duration_minutes:=v_duration;
      if exists(
        select 1 from public.doctor_schedules ds
        where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true
          and ds.day_of_week=extract(dow from new.appointment_date)::integer
          and ds.break_start_time is not null and ds.break_end_time is not null
          and v_time < ds.break_end_time
          and (v_time + make_interval(mins=>v_duration)) > ds.break_start_time
      ) then raise exception 'Selected time is inside the Doctor break period.'; end if;
    end if;

    perform pg_advisory_xact_lock(hashtextextended(new.doctor_id::text||'|'||new.appointment_date::text,0));
    if exists(select 1 from public.appointments a where a.doctor_id=new.doctor_id
      and a.status in ('pending','confirmed','rescheduled') and a.appointment_start is not null
      and a.appointment_start < new.appointment_start + make_interval(mins=>coalesce(new.duration_minutes,30))
      and a.appointment_start + make_interval(mins=>coalesce(a.duration_minutes,30)) > new.appointment_start) then
      raise exception 'This appointment time overlaps another active booking.';
    end if;
  end if;

  new.appointment_number:='APT-'||to_char(now(),'YYYYMMDD')||'-'||lpad(nextval('public.appointment_number_seq')::text,5,'0');
  new.doctor_name:=d.full_name;
  new.patient_name:=pat.full_name;
  new.patient_phone:=pat.phone;
  new.status:='pending'; new.created_at:=now(); new.updated_at:=now();
  return new;
end $$;

create or replace function public.guard_appointment_update()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_provider boolean; v_time time; v_has_schedule boolean; v_duration integer; v_schedule_start time;
begin
  if public.is_trusted_backend_context() then new.updated_at:=now(); return new; end if;
  v_provider:=public.is_appointment_provider_owner(old.shop_id);
  if not (auth.uid()=old.doctor_id or auth.uid()=old.patient_id or v_provider or public.is_admin_or_above()) then
    raise exception 'You are not allowed to update this appointment.';
  end if;
  if new.doctor_id<>old.doctor_id or new.patient_id<>old.patient_id or new.product_id is distinct from old.product_id or new.shop_id is distinct from old.shop_id then
    raise exception 'Appointment ownership cannot be changed.';
  end if;
  if new.doctor_name is distinct from old.doctor_name or new.patient_name is distinct from old.patient_name
     or new.patient_phone is distinct from old.patient_phone or new.chamber_name is distinct from old.chamber_name
     or new.appointment_number is distinct from old.appointment_number
     or new.created_at is distinct from old.created_at then
    raise exception 'Appointment identity fields cannot be changed.';
  end if;

  -- Server owns derived timestamps. Ignore direct client attempts to forge them.
  new.appointment_start:=old.appointment_start;
  new.completed_at:=old.completed_at;
  new.cancelled_at:=old.cancelled_at;
  new.no_show_at:=old.no_show_at;

  if auth.uid()=old.patient_id and not public.is_admin_or_above() then
    if new.status is distinct from old.status and not (new.status='cancelled' and old.status in ('pending','confirmed','rescheduled')) then
      raise exception 'Patient can only cancel an active appointment.';
    end if;
    if new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time
       or new.duration_minutes is distinct from old.duration_minutes or new.doctor_note is distinct from old.doctor_note
       or new.reschedule_reason is distinct from old.reschedule_reason then
      raise exception 'Patient cannot change the Doctor schedule or Doctor note.';
    end if;
    if new.status='cancelled' and old.status<>'cancelled' and nullif(btrim(coalesce(new.cancellation_reason,'')),'') is null then
      raise exception 'Cancellation reason is required.';
    end if;
    if new.status<>'cancelled' and new.cancellation_reason is distinct from old.cancellation_reason then
      raise exception 'Cancellation reason can only be set while cancelling an appointment.';
    end if;
  end if;

  if (auth.uid()=old.doctor_id or v_provider) and not public.is_admin_or_above() then
    if new.duration_minutes is distinct from old.duration_minutes
       and not (new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time) then
      raise exception 'Appointment duration is controlled by the Doctor schedule.';
    end if;
    if new.status is distinct from old.status then
      if old.status='pending' and new.status not in ('confirmed','cancelled','rescheduled') then
        raise exception 'Pending appointment can only be confirmed, cancelled or rescheduled.';
      elsif old.status='confirmed' and new.status not in ('completed','cancelled','rescheduled','no_show') then
        raise exception 'Confirmed appointment can only be completed, cancelled, rescheduled or marked no-show.';
      elsif old.status='rescheduled' and new.status not in ('confirmed','completed','cancelled','rescheduled','no_show') then
        raise exception 'Invalid rescheduled appointment transition.';
      elsif old.status in ('completed','cancelled','no_show') then
        raise exception 'Final appointment status cannot be reopened.';
      end if;
    end if;
    if new.status='cancelled' and old.status<>'cancelled' and nullif(btrim(coalesce(new.cancellation_reason,'')),'') is null then
      raise exception 'Cancellation reason is required.';
    end if;
  end if;

  if (new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time) then
    if new.appointment_date is null or new.appointment_date < (now() at time zone 'Asia/Dhaka')::date then
      raise exception 'Appointment date cannot be in the past.';
    end if;
    if nullif(btrim(coalesce(new.appointment_time,'')),'') is null then
      new.appointment_time:=null;
      new.appointment_start:=null;
      v_time:=null;
    else
      if btrim(new.appointment_time) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
        raise exception 'Appointment time must use HH:MM format.';
      end if;
      new.appointment_time:=btrim(new.appointment_time);
      v_time:=new.appointment_time::time;
      new.appointment_start:=((new.appointment_date::text||' '||new.appointment_time)::timestamp at time zone 'Asia/Dhaka');
      if new.appointment_start < now() then raise exception 'Appointment time cannot be in the past.'; end if;
    end if;
    if (auth.uid()=old.doctor_id or v_provider) and not public.is_admin_or_above() then
      new.status:='rescheduled';
      if nullif(btrim(coalesce(new.reschedule_reason,'')),'') is null then new.reschedule_reason:='Provider rescheduled'; end if;
    end if;
  else
    -- Recompute the derived start even when a client tries to submit it directly.
    if nullif(btrim(coalesce(new.appointment_time,'')),'') is not null then
      new.appointment_start:=((new.appointment_date::text||' '||btrim(new.appointment_time))::timestamp at time zone 'Asia/Dhaka');
      v_time:=btrim(new.appointment_time)::time;
    else
      new.appointment_start:=null;
      v_time:=null;
    end if;
  end if;

  if not public.is_admin_or_above() and (auth.uid()=old.doctor_id or v_provider)
     and (new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time)
     and new.shop_id is not null then
    if exists(select 1 from public.doctor_schedule_exceptions e where e.doctor_id=new.doctor_id
      and (e.shop_id is null or e.shop_id=new.shop_id) and e.exception_date=new.appointment_date and e.is_available=false) then
      raise exception 'Doctor is unavailable on this date.';
    end if;
    select exists(select 1 from public.doctor_schedules ds where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true)
      into v_has_schedule;
    if v_has_schedule then
      if new.appointment_start is null or v_time is null then
        raise exception 'An available appointment slot is required for this Doctor.';
      end if;
      v_duration:=null; v_schedule_start:=null;
      select ds.slot_duration_minutes,ds.start_time into v_duration,v_schedule_start
      from public.doctor_schedules ds
      where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true
        and ds.day_of_week=extract(dow from new.appointment_date)::integer
        and v_time>=ds.start_time
        and (v_time + make_interval(mins=>ds.slot_duration_minutes))<=ds.end_time
        and mod(floor(extract(epoch from (v_time-ds.start_time))/60)::integer,ds.slot_duration_minutes)=0
      order by ds.start_time limit 1;
      if v_duration is null then raise exception 'Please select a valid available Doctor slot.'; end if;
      new.duration_minutes:=v_duration;
      if exists(
        select 1 from public.doctor_schedules ds
        where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true
          and ds.day_of_week=extract(dow from new.appointment_date)::integer
          and ds.break_start_time is not null and ds.break_end_time is not null
          and v_time < ds.break_end_time
          and (v_time + make_interval(mins=>v_duration)) > ds.break_start_time
      ) then raise exception 'Selected time is inside the Doctor break period.'; end if;
    end if;
  end if;

  if new.status in ('pending','confirmed','rescheduled') and new.appointment_start is not null then
    perform pg_advisory_xact_lock(hashtextextended(new.doctor_id::text||'|'||new.appointment_date::text,0));
    if exists(select 1 from public.appointments a where a.id<>old.id and a.doctor_id=new.doctor_id
      and a.status in ('pending','confirmed','rescheduled') and a.appointment_start is not null
      and a.appointment_start < new.appointment_start + make_interval(mins=>coalesce(new.duration_minutes,30))
      and a.appointment_start + make_interval(mins=>coalesce(a.duration_minutes,30)) > new.appointment_start) then
      raise exception 'This appointment time overlaps another active booking.';
    end if;
  end if;

  if not public.is_admin_or_above() and new.status in ('completed','no_show') and old.status is distinct from new.status
     and new.appointment_start is not null and new.appointment_start>now() then
    raise exception 'Future appointment cannot be completed or marked no-show.';
  end if;
  if new.status='completed' and old.status<>'completed' then new.completed_at:=now(); end if;
  if new.status='cancelled' and old.status<>'cancelled' then new.cancelled_at:=now(); end if;
  if new.status='no_show' and old.status<>'no_show' then new.no_show_at:=now(); end if;
  new.updated_at:=now(); return new;
end $$;

create or replace function public.record_appointment_history_and_notify()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_owner uuid;
begin
  if tg_op='INSERT' then
    insert into public.appointment_status_history(appointment_id,actor_id,new_status,new_date,new_time,note)
    values(new.id,auth.uid(),new.status,new.appointment_date,new.appointment_time,'Appointment created');
    perform public.push_notification(new.doctor_id,'appointment_new','নতুন অ্যাপয়েন্টমেন্ট অনুরোধ',coalesce(new.patient_name,'একজন রোগী')||' অ্যাপয়েন্টমেন্ট অনুরোধ পাঠিয়েছেন।','appointment',new.id);
    if new.shop_id is not null then
      select owner_id into v_owner from public.shops where id=new.shop_id;
      if v_owner is not null and v_owner<>new.doctor_id then
        perform public.push_notification(v_owner,'appointment_new','নতুন অ্যাপয়েন্টমেন্ট অনুরোধ',coalesce(new.patient_name,'একজন রোগী')||' অ্যাপয়েন্টমেন্ট অনুরোধ পাঠিয়েছেন।','appointment',new.id);
      end if;
    end if;
  elsif new.status is distinct from old.status or new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time then
    insert into public.appointment_status_history(appointment_id,actor_id,old_status,new_status,old_date,new_date,old_time,new_time,note)
    values(new.id,auth.uid(),old.status,new.status,old.appointment_date,new.appointment_date,old.appointment_time,new.appointment_time,
      coalesce(new.cancellation_reason,new.reschedule_reason,new.doctor_note));
    perform public.push_notification(new.patient_id,'appointment_update','অ্যাপয়েন্টমেন্ট আপডেট হয়েছে',
      'আপনার অ্যাপয়েন্টমেন্টের অবস্থা: '||new.status||case when new.appointment_time is not null then ' • '||new.appointment_date::text||' '||new.appointment_time else '' end,
      'appointment',new.id);
  end if;
  return new;
end $$;
drop trigger if exists trg_record_appointment_history_notify on public.appointments;
create trigger trg_record_appointment_history_notify
  after insert or update on public.appointments
  for each row execute procedure public.record_appointment_history_and_notify();

notify pgrst, 'reload schema';
-- <<< END 15_appointment_lifecycle_notifications.sql

-- >>> BEGIN 16_blood_donor_profile_flow.sql
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
-- <<< END 16_blood_donor_profile_flow.sql

-- >>> BEGIN 17_admin_blood_donor_directory.sql
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
-- <<< END 17_admin_blood_donor_directory.sql

-- >>> BEGIN 18_blood_request_lifecycle.sql
-- ============================================================
-- Medical Operations Upgrade — STEP 08 / MIGRATION 18
-- BLOOD SEARCH / REQUEST LIFECYCLE / ANTI-SPAM / AUDIT
-- ============================================================

create sequence if not exists public.blood_request_number_seq;
alter table public.blood_requests
  add column if not exists request_number text,
  add column if not exists completed_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists donor_response_note text,
  add column if not exists donor_contact_phone text;

-- Backfill stable request numbers for historical rows.
update public.blood_requests
set request_number='BR-'||to_char(created_at,'YYYYMMDD')||'-'||substr(replace(id::text,'-',''),1,8)
where request_number is null;
create unique index if not exists ux_blood_requests_request_number on public.blood_requests(request_number) where request_number is not null;
update public.blood_requests b
set donor_contact_phone=p.phone
from public.profiles p
where p.id=b.donor_id and b.status in ('accepted','completed')
  and b.donor_contact_phone is null and nullif(btrim(coalesce(p.phone,'')),'') is not null;
create index if not exists idx_blood_requests_donor_status_created on public.blood_requests(donor_id,status,created_at desc);
create index if not exists idx_blood_requests_requester_status_created on public.blood_requests(requester_id,status,created_at desc);

-- Keep legacy signature for frontend compatibility, but identity comes from auth.uid()/profiles.
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
declare v_id uuid; v_patient record;
begin
  if auth.uid() is null then raise exception 'লগইন করতে হবে'; end if;
  select id,full_name,phone,role,account_status into v_patient from public.profiles where id=auth.uid();
  if v_patient.id is null or v_patient.role<>'patient' or v_patient.account_status<>'active' then
    raise exception 'সক্রিয় রোগী অ্যাকাউন্ট প্রয়োজন।';
  end if;
  if nullif(btrim(coalesce(v_patient.phone,'')),'') is null then
    raise exception 'রক্তের অনুরোধ পাঠাতে আগে আপনার প্রোফাইলে ফোন নম্বর যোগ করুন।';
  end if;
  if nullif(btrim(coalesce(p_reason,'')),'') is null then raise exception 'রক্তের প্রয়োজনের কারণ লিখুন।'; end if;
  if p_needed_date is not null and p_needed_date<(now() at time zone 'Asia/Dhaka')::date then raise exception 'প্রয়োজনের তারিখ অতীত হতে পারে না।'; end if;
  if not exists(
    select 1 from public.profiles
    where id=p_donor_id and role='patient' and blood_donor_volunteer=true
      and blood_is_available=true and blood_accept_requests=true
      and nullif(btrim(coalesce(phone,'')),'') is not null
      and blood_group=p_blood_group and account_status='active'
  ) then
    raise exception 'এই ব্যক্তি বর্তমানে রক্তের অনুরোধ গ্রহণ করছেন না।';
  end if;
  if p_donor_id=auth.uid() then raise exception 'নিজেকে রক্তের অনুরোধ পাঠানো যাবে না।'; end if;

  -- Prevent duplicate/spam requests to the same donor while an active request already exists recently.
  if exists(
    select 1 from public.blood_requests
    where requester_id=auth.uid() and donor_id=p_donor_id and blood_group=p_blood_group
      and status in ('pending','accepted')
      and created_at>now()-interval '6 hours'
  ) then
    raise exception 'এই রক্তদাতাকে ইতিমধ্যে সাম্প্রতিক একটি সক্রিয় অনুরোধ পাঠানো হয়েছে।';
  end if;

  insert into public.blood_requests(
    request_number,requester_id,donor_id,blood_group,patient_name,patient_phone,needed_date,needed_time,reason,hospital_name,location_text
  ) values(
    'BR-'||to_char(now(),'YYYYMMDD')||'-'||lpad(nextval('public.blood_request_number_seq')::text,5,'0'),
    auth.uid(),p_donor_id,p_blood_group,coalesce(v_patient.full_name,'রোগী'),v_patient.phone,p_needed_date,p_needed_time,btrim(p_reason),
    nullif(btrim(p_hospital_name),''),nullif(btrim(p_location_text),'')
  ) returning id into v_id;
  perform public.push_notification(p_donor_id,'blood_request_new','নতুন রক্তের অনুরোধ',
    coalesce(v_patient.full_name,'একজন রোগী')||' আপনার '||p_blood_group||' রক্তের জন্য অনুরোধ পাঠিয়েছেন।','blood_request',v_id);
  return v_id;
end;
$$;
revoke all on function public.create_blood_request(uuid,text,text,text,date,text,text,text,text) from public;
grant execute on function public.create_blood_request(uuid,text,text,text,date,text,text,text,text) to authenticated,service_role;

create or replace function public.guard_blood_request_update()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare v_donor_phone text;
begin
  -- Donor contact is server-managed and is disclosed to this requester only after acceptance.
  new.donor_contact_phone:=old.donor_contact_phone;
  if new.status='accepted' and old.status<>'accepted' then
    select phone into v_donor_phone from public.profiles where id=old.donor_id and blood_donor_volunteer=true;
    if nullif(btrim(coalesce(v_donor_phone,'')),'') is null then
      raise exception 'রক্তদাতার প্রোফাইলে যোগাযোগের ফোন নম্বর নেই।';
    end if;
    new.donor_contact_phone:=v_donor_phone;
  end if;

  if public.is_trusted_backend_context() or public.is_admin_or_above() then
    if new.status='completed' and old.status<>'completed' then new.completed_at:=now(); end if;
    if new.status='cancelled' and old.status<>'cancelled' then new.cancelled_at:=now(); end if;
    new.updated_at:=now(); return new;
  end if;
  if auth.uid() is null or auth.uid() not in (old.requester_id,old.donor_id) then
    raise exception 'You are not allowed to update this blood request.';
  end if;
  if new.requester_id<>old.requester_id or new.donor_id<>old.donor_id
     or new.blood_group is distinct from old.blood_group
     or new.patient_name is distinct from old.patient_name
     or new.patient_phone is distinct from old.patient_phone
     or new.needed_date is distinct from old.needed_date
     or new.needed_time is distinct from old.needed_time
     or new.reason is distinct from old.reason
     or new.hospital_name is distinct from old.hospital_name
     or new.location_text is distinct from old.location_text
     or new.request_number is distinct from old.request_number then
    raise exception 'Blood request details cannot be changed after submission.';
  end if;
  if auth.uid()=old.requester_id then
    if new.status is distinct from old.status and not (new.status='cancelled' and old.status in ('pending','accepted')) then
      raise exception 'Requester can only cancel an active request.';
    end if;
    if new.donor_response_note is distinct from old.donor_response_note then raise exception 'Requester cannot edit donor response note.'; end if;
  elsif auth.uid()=old.donor_id then
    if new.status is distinct from old.status and not (
      (old.status='pending' and new.status in ('accepted','declined'))
      or (old.status='accepted' and new.status='completed')
    ) then
      raise exception 'Invalid donor status transition.';
    end if;
  end if;
  if new.status='completed' and old.status<>'completed' then new.completed_at:=now(); end if;
  if new.status='cancelled' and old.status<>'cancelled' then new.cancelled_at:=now(); end if;
  new.updated_at:=now();
  return new;
end $$;

create or replace function public.notify_blood_request_change()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='UPDATE' and new.status is distinct from old.status then
    if auth.uid()=new.donor_id or new.status in ('accepted','declined','completed') then
      perform public.push_notification(new.requester_id,'blood_request_update','রক্তের অনুরোধ আপডেট',
        'আপনার '||new.blood_group||' রক্তের অনুরোধের অবস্থা: '||new.status,'blood_request',new.id);
    elsif auth.uid()=new.requester_id and new.status='cancelled' then
      perform public.push_notification(new.donor_id,'blood_request_cancelled','রক্তের অনুরোধ বাতিল',
        'রোগী রক্তের অনুরোধটি বাতিল করেছেন।','blood_request',new.id);
    end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_notify_blood_request_change on public.blood_requests;
create trigger trg_notify_blood_request_change after update on public.blood_requests
  for each row execute procedure public.notify_blood_request_change();

create or replace function public.admin_list_blood_requests(p_limit integer default 300)
returns table(
  id uuid, request_number text, requester_id uuid, donor_id uuid,
  requester_name text, requester_phone text, donor_name text, donor_phone text,
  blood_group text, needed_date date, needed_time text, reason text,
  hospital_name text, location_text text, status text, donor_response_note text,
  donor_contact_phone text, created_at timestamptz, updated_at timestamptz,
  completed_at timestamptz, cancelled_at timestamptz
)
language plpgsql stable security definer set search_path=public as $$
begin
  if not public.is_admin_or_above() and not public.is_trusted_backend_context() then
    raise exception 'Admin access required.';
  end if;
  return query
  select b.id,b.request_number,b.requester_id,b.donor_id,
         coalesce(r.full_name,b.patient_name),coalesce(r.phone,b.patient_phone),
         d.full_name,d.phone,b.blood_group,b.needed_date,b.needed_time,b.reason,
         b.hospital_name,b.location_text,b.status,b.donor_response_note,b.donor_contact_phone,
         b.created_at,b.updated_at,b.completed_at,b.cancelled_at
  from public.blood_requests b
  left join public.profiles r on r.id=b.requester_id
  left join public.profiles d on d.id=b.donor_id
  order by b.created_at desc
  limit greatest(1,least(coalesce(p_limit,300),1000));
end $$;
revoke all on function public.admin_list_blood_requests(integer) from public;
grant execute on function public.admin_list_blood_requests(integer) to authenticated,service_role;

create or replace function public.admin_blood_request_summary()
returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
  if not public.is_admin_or_above() and not public.is_trusted_backend_context() then raise exception 'Admin access required.'; end if;
  return jsonb_build_object(
    'total',(select count(*) from public.blood_requests),
    'pending',(select count(*) from public.blood_requests where status='pending'),
    'accepted',(select count(*) from public.blood_requests where status='accepted'),
    'completed',(select count(*) from public.blood_requests where status='completed'),
    'cancelled',(select count(*) from public.blood_requests where status='cancelled'),
    'declined',(select count(*) from public.blood_requests where status='declined')
  );
end $$;
revoke all on function public.admin_blood_request_summary() from public;
grant execute on function public.admin_blood_request_summary() to authenticated,service_role;

notify pgrst, 'reload schema';
-- <<< END 18_blood_request_lifecycle.sql

-- >>> BEGIN 19_ambulance_operations_analytics.sql
-- ============================================================
-- Medical Operations Upgrade — STEP 09 / MIGRATION 19
-- AMBULANCE COUNT FIX + CONTACT/DIRECTION ANALYTICS
-- ============================================================

alter table public.ambulance_services
  add column if not exists call_click_count integer not null default 0,
  add column if not exists direction_click_count integer not null default 0;

alter table public.ambulance_services drop constraint if exists ambulance_call_click_count_check;
alter table public.ambulance_services add constraint ambulance_call_click_count_check check(call_click_count>=0);
alter table public.ambulance_services drop constraint if exists ambulance_direction_click_count_check;
alter table public.ambulance_services add constraint ambulance_direction_click_count_check check(direction_click_count>=0);

create or replace function public.increment_ambulance_call_click(p_ambulance_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.ambulance_services set call_click_count=call_click_count+1 where id=p_ambulance_id and is_verified=true;
end $$;
revoke all on function public.increment_ambulance_call_click(uuid) from public;
grant execute on function public.increment_ambulance_call_click(uuid) to anon,authenticated,service_role;

create or replace function public.increment_ambulance_direction_click(p_ambulance_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.ambulance_services set direction_click_count=direction_click_count+1 where id=p_ambulance_id and is_verified=true;
end $$;
revoke all on function public.increment_ambulance_direction_click(uuid) from public;
grant execute on function public.increment_ambulance_direction_click(uuid) to anon,authenticated,service_role;

create index if not exists idx_ambulance_available_verified on public.ambulance_services(is_available,is_verified,updated_at desc);

notify pgrst, 'reload schema';
-- <<< END 19_ambulance_operations_analytics.sql

-- >>> BEGIN 20_modern_admin_medical_analytics.sql
-- ============================================================
-- Medical Operations Upgrade — STEP 10 / MIGRATION 20
-- MODERN ADMIN/SUPER ADMIN MEDICAL ANALYTICS
-- ============================================================

-- Supporting indexes for period growth cards/charts.
create index if not exists idx_profiles_created_at on public.profiles(created_at);
create index if not exists idx_profiles_role_created_at on public.profiles(role,created_at);
create index if not exists idx_appointments_created_at on public.appointments(created_at);
create index if not exists idx_appointments_status_date on public.appointments(status,appointment_date);
create index if not exists idx_blood_requests_created_at on public.blood_requests(created_at);
create index if not exists idx_seller_verifications_status_created on public.seller_verifications(status,created_at);

create or replace function public.admin_medical_analytics(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_days integer:=least(greatest(coalesce(p_days,30),7),365);
  v_today date:=(now() at time zone 'Asia/Dhaka')::date;
  v_start date:=v_today-(least(greatest(coalesce(p_days,30),7),365)-1);
  v_prev_start date:=v_today-(least(greatest(coalesce(p_days,30),7),365)*2-1);
  v_prev_end date:=v_today-least(greatest(coalesce(p_days,30),7),365);
  v_result jsonb;
begin
  if not public.is_admin_or_above() and not public.is_trusted_backend_context() then
    raise exception 'Admin access required.';
  end if;

  with days as (
    select generate_series(v_start,v_today,interval '1 day')::date as d
  ), daily as (
    select d.d,
      (select count(*) from public.profiles p where (p.created_at at time zone 'Asia/Dhaka')::date=d.d)::integer as new_users,
      (select count(*) from public.profiles p where p.role='doctor' and (p.created_at at time zone 'Asia/Dhaka')::date=d.d)::integer as new_doctors,
      (select count(*) from public.appointments a where (a.created_at at time zone 'Asia/Dhaka')::date=d.d)::integer as appointments,
      (select count(*) from public.blood_requests b where (b.created_at at time zone 'Asia/Dhaka')::date=d.d)::integer as blood_requests
    from days d
  ), appointment_status as (
    select s.status, count(a.id)::integer as value
    from (values('pending'),('confirmed'),('completed'),('cancelled'),('rescheduled'),('no_show')) s(status)
    left join public.appointments a on a.status=s.status
    group by s.status
  ), blood_groups as (
    select g.blood_group, count(p.id)::integer as value
    from (values('A+'),('A-'),('B+'),('B-'),('AB+'),('AB-'),('O+'),('O-')) g(blood_group)
    left join public.profiles p on p.blood_group=g.blood_group and p.role='patient' and p.blood_donor_volunteer=true and p.blood_is_available=true and p.account_status='active'
    group by g.blood_group
  )
  select jsonb_build_object(
    'period_days',v_days,
    'totals',jsonb_build_object(
      'users',(select count(*) from public.profiles),
      'patients',(select count(*) from public.profiles where role='patient'),
      'doctors',(select count(*) from public.profiles where role='doctor'),
      'approved_doctors',(select count(*) from public.profiles where role='doctor' and seller_status='approved' and account_status='active'),
      'hospitals',(select count(*) from public.profiles where role='hospital'),
      'approved_hospitals',(select count(*) from public.profiles where role='hospital' and seller_status='approved' and account_status='active'),
      'pending_verifications',(select count(*) from public.seller_verifications where status in ('pending','under_review')),
      'appointments_today',(select count(*) from public.appointments where appointment_date=v_today),
      'appointments_pending',(select count(*) from public.appointments where status='pending'),
      'appointments_completed',(select count(*) from public.appointments where status='completed'),
      'active_donors',(select count(*) from public.profiles where role='patient' and blood_donor_volunteer=true and blood_is_available=true and account_status='active'),
      'pending_blood_requests',(select count(*) from public.blood_requests where status='pending'),
      'ambulances',(select count(*) from public.ambulance_services),
      'available_ambulances',(select count(*) from public.ambulance_services where is_verified=true and is_available=true),
      'users_with_location',(select count(*) from public.user_last_locations)
    ),
    'growth',jsonb_build_object(
      'users_current',(select count(*) from public.profiles where (created_at at time zone 'Asia/Dhaka')::date>=v_start),
      'users_previous',(select count(*) from public.profiles where (created_at at time zone 'Asia/Dhaka')::date>=v_prev_start and (created_at at time zone 'Asia/Dhaka')::date<v_start),
      'doctors_current',(select count(*) from public.profiles where role='doctor' and (created_at at time zone 'Asia/Dhaka')::date>=v_start),
      'doctors_previous',(select count(*) from public.profiles where role='doctor' and (created_at at time zone 'Asia/Dhaka')::date>=v_prev_start and (created_at at time zone 'Asia/Dhaka')::date<v_start),
      'appointments_current',(select count(*) from public.appointments where (created_at at time zone 'Asia/Dhaka')::date>=v_start),
      'appointments_previous',(select count(*) from public.appointments where (created_at at time zone 'Asia/Dhaka')::date>=v_prev_start and (created_at at time zone 'Asia/Dhaka')::date<v_start),
      'blood_requests_current',(select count(*) from public.blood_requests where (created_at at time zone 'Asia/Dhaka')::date>=v_start),
      'blood_requests_previous',(select count(*) from public.blood_requests where (created_at at time zone 'Asia/Dhaka')::date>=v_prev_start and (created_at at time zone 'Asia/Dhaka')::date<v_start)
    ),
    'daily',(select coalesce(jsonb_agg(jsonb_build_object('date',d,'new_users',new_users,'new_doctors',new_doctors,'appointments',appointments,'blood_requests',blood_requests) order by d),'[]'::jsonb) from daily),
    'appointment_status',(select coalesce(jsonb_agg(jsonb_build_object('status',status,'value',value) order by status),'[]'::jsonb) from appointment_status),
    'blood_groups',(select coalesce(jsonb_agg(jsonb_build_object('blood_group',blood_group,'value',value) order by blood_group),'[]'::jsonb) from blood_groups),
    'ambulance_engagement',jsonb_build_object(
      'call_clicks',(select coalesce(sum(call_click_count),0) from public.ambulance_services),
      'direction_clicks',(select coalesce(sum(direction_click_count),0) from public.ambulance_services)
    ),
    'generated_at',now()
  ) into v_result;
  return v_result;
end $$;
revoke all on function public.admin_medical_analytics(integer) from public;
grant execute on function public.admin_medical_analytics(integer) to authenticated,service_role;

-- Final assertions for the first 10 medical-operation steps.
do $$
begin
  if to_regclass('public.user_last_locations') is null then raise exception '[MEDICAL STEP10] user_last_locations missing'; end if;
  if to_regclass('public.appointment_status_history') is null then raise exception '[MEDICAL STEP10] appointment_status_history missing'; end if;
  if to_regclass('public.notifications') is null then raise exception '[MEDICAL STEP10] notifications missing'; end if;
  if to_regprocedure('public.review_provider_verification(uuid,text,text)') is null then raise exception '[MEDICAL STEP10] review_provider_verification missing'; end if;
  if to_regprocedure('public.invite_doctor_to_provider(uuid,text)') is null then raise exception '[MEDICAL STEP10] invite_doctor_to_provider missing'; end if;
  if to_regprocedure('public.respond_doctor_provider_invitation(uuid,boolean)') is null then raise exception '[MEDICAL STEP10] invitation response missing'; end if;
  if to_regprocedure('public.save_doctor_schedule_day(uuid,uuid,integer,boolean,time without time zone,time without time zone,integer,time without time zone,time without time zone)') is null then raise exception '[MEDICAL STEP10] atomic schedule save missing'; end if;
  if to_regprocedure('public.get_doctor_available_slots(uuid,uuid,date)') is null then raise exception '[MEDICAL STEP10] available slot RPC missing'; end if;
  if to_regprocedure('public.create_blood_request(uuid,text,text,text,date,text,text,text,text)') is null then raise exception '[MEDICAL STEP10] blood request RPC missing'; end if;
  if to_regprocedure('public.admin_list_blood_requests(integer)') is null then raise exception '[MEDICAL STEP10] blood request admin list missing'; end if;
  if to_regprocedure('public.admin_list_blood_donors(text,text,text,text,boolean,integer,integer)') is null then raise exception '[MEDICAL STEP10] donor admin list missing'; end if;
  if to_regprocedure('public.admin_medical_analytics(integer)') is null then raise exception '[MEDICAL STEP10] medical analytics missing'; end if;
  if exists(select 1 from public.profiles where location_latitude is not null or location_longitude is not null) then
    raise exception '[MEDICAL STEP10] exact user coordinates remain in profiles';
  end if;
end $$;

insert into public.backend_schema_versions(version,notes)
values('doctor-v1-medical-ops-first10','Super Admin location, unified verification, Doctor invitations, schedules, appointment lifecycle, blood donor/request operations, ambulance analytics and modern Admin dashboard')
on conflict(version) do update set applied_at=now(),notes=excluded.notes;

notify pgrst, 'reload schema';
-- <<< END 20_modern_admin_medical_analytics.sql

-- >>> BEGIN 21_regression_compatibility_restore.sql
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
-- <<< END 21_regression_compatibility_restore.sql

commit;
