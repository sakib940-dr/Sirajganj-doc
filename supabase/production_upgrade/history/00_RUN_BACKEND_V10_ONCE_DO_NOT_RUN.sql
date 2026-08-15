-- ============================================================================
-- DOCTOR V1 BACKEND V10 — ONE-TIME PRODUCTION UPGRADE
-- Take a full Supabase database backup first.
-- Do NOT replay doctor_v1_supabase_clean.sql, supabase/migrations/*, or step*.sql.
-- Steps 02–10 run inside ONE transaction; any SQL error rolls the transaction back.
-- ============================================================================

begin;
set local statement_timeout = 0;

-- ======================================================================
-- INCLUDED: 02_canonical_schema_convergence.sql
-- ======================================================================

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

create or replace function public.is_doctor_account_public(p_doctor_id uuid)
returns boolean language sql security definer set search_path=public stable as $$
  select exists(
    select 1 from public.profiles
    where id=p_doctor_id and role='doctor'
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

-- ======================================================================
-- INCLUDED: 03_rls_rpc_security_hardening.sql
-- ======================================================================

-- ============================================================
-- Production Upgrade V2 — STEP 03: RLS / RPC / STORAGE HARDENING
-- Idempotent. Preserves the current UI contract while closing known leaks.
-- ============================================================

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
  and not exists(select 1 from public.seller_verifications sv where sv.user_id=auth.uid() and sv.status='pending')
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
  if current_user in ('service_role','postgres','supabase_admin') or public.is_admin_or_above() then
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

-- ======================================================================
-- INCLUDED: 04_location_nearest_search.sql
-- ======================================================================

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

-- ======================================================================
-- INCLUDED: 05_doctor_provider_relationships.sql
-- ======================================================================

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

-- ======================================================================
-- INCLUDED: 06_appointment_schedule_integrity.sql
-- ======================================================================

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
  if auth.uid() is not null and current_user not in ('service_role','postgres','supabase_admin') then
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
  if current_user in ('service_role','postgres','supabase_admin') then new.updated_at:=now(); return new; end if;
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

-- ======================================================================
-- INCLUDED: 07_admin_audit_hardening.sql
-- ======================================================================

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
  foreach t in array array['profiles','seller_verifications','appointments','ambulance_services','doctor_provider_links'] loop
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

-- ======================================================================
-- INCLUDED: 08_performance_search.sql
-- ======================================================================

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

-- ======================================================================
-- INCLUDED: 09_data_consistency_services.sql
-- ======================================================================

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
  if not public.is_admin_or_above() and current_user not in ('service_role','postgres','supabase_admin') then
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

-- ======================================================================
-- INCLUDED: 10_final_verification.sql
-- ======================================================================

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

commit;
