-- ============================================================
-- SIRAJGANJ DOCTOR V1 — STEP 8 UPGRADE
-- Run ONCE after the original Doctor V1 SQL.
-- This is an incremental migration; do NOT rerun the old full SQL.
-- ============================================================

-- 1) Role: add Chamber/Hospital account.
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('patient','doctor','hospital','admin','super_admin'));

-- 2) Chamber/Hospital application RPC.
create or replace function public.request_hospital_status()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('app.bypass_role_guard','true',true);
  update public.profiles
  set role='hospital', seller_status='pending'
  where id=auth.uid() and seller_status='none';
end;
$$;
grant execute on function public.request_hospital_status() to authenticated;

-- 3) Verification approval/rejection should update the provider account.
create or replace function public.sync_provider_verification_status()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if new.status='approved' then
    perform set_config('app.bypass_role_guard','true',true);
    update public.profiles
      set seller_status='approved'
      where id=new.user_id and role in ('doctor','hospital');
  elsif new.status='rejected' then
    perform set_config('app.bypass_role_guard','true',true);
    update public.profiles
      set seller_status='rejected'
      where id=new.user_id and role in ('doctor','hospital');
  end if;
  return new;
end;
$$;
drop trigger if exists trg_sync_provider_verification_status on public.seller_verifications;
create trigger trg_sync_provider_verification_status
after insert or update of status on public.seller_verifications
for each row execute procedure public.sync_provider_verification_status();

-- 4) Public chamber visibility: Doctor OR Chamber/Hospital owner.
create or replace function public.is_provider_account_public(p_owner_id uuid)
returns boolean
language sql
security definer
set search_path=public
stable
as $$
  select exists(
    select 1 from public.profiles
    where id=p_owner_id
      and role in ('doctor','hospital')
      and seller_status='approved'
      and account_status='active'
  );
$$;

-- Keep the old function name for existing frontend code.
create or replace function public.is_doctor_account_public(p_owner_id uuid)
returns boolean
language sql
security definer
set search_path=public
stable
as $$
  select exists(
    select 1 from public.profiles
    where id=p_owner_id
      and role='doctor'
      and seller_status='approved'
      and account_status='active'
  );
$$;

-- Approved Doctor names are discoverable so a Chamber/Hospital can add a Doctor ID.
drop policy if exists "profiles_select_approved_doctors" on public.profiles;
create policy "profiles_select_approved_doctors" on public.profiles
for select using (
  role='doctor' and seller_status='approved' and account_status='active'
);

-- 5) Chamber/Hospital owners can create/manage their own chamber.
drop policy if exists "shops_insert_approved_seller" on public.shops;
create policy "shops_insert_approved_provider" on public.shops
for insert with check (
  owner_id=auth.uid()
  and exists(
    select 1 from public.profiles
    where id=auth.uid()
      and role in ('doctor','hospital')
      and seller_status='approved'
      and account_status='active'
  )
);

drop policy if exists "shops_select_public_active" on public.shops;
create policy "shops_select_public_active" on public.shops
for select using (
  (is_active=true and public.is_provider_account_public(owner_id))
  or owner_id=auth.uid()
  or public.is_admin_or_above()
);

-- 6) Chamber/Hospital can add approved Doctor profiles to its chamber.
drop policy if exists "products_insert_own_shop" on public.products;
create policy "products_insert_own_provider_shop" on public.products
for insert with check (
  exists(
    select 1 from public.shops s
    join public.profiles owner_profile on owner_profile.id=s.owner_id
    where s.id=shop_id
      and s.owner_id=auth.uid()
      and owner_profile.role in ('doctor','hospital')
      and owner_profile.seller_status='approved'
      and owner_profile.account_status='active'
  )
  and exists(
    select 1 from public.profiles d
    where d.id=doctor_id
      and d.role='doctor'
      and d.seller_status='approved'
      and d.account_status='active'
  )
);

-- 7) Public Doctor profiles only when the actual Doctor account is approved.
drop policy if exists "products_select_public_active" on public.products;
create policy "products_select_public_active" on public.products
for select using (
  (
    is_active=true
    and exists(
      select 1 from public.profiles d
      where d.id=doctor_id
        and d.role='doctor'
        and d.seller_status='approved'
        and d.account_status='active'
    )
    and exists(
      select 1 from public.shops s
      where s.id=shop_id
        and s.is_active=true
        and public.is_provider_account_public(s.owner_id)
    )
  )
  or public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
);

-- 8) Storage hard limit: client may select up to 1 MB; frontend compresses to ~100–200 KB.
update storage.buckets
set file_size_limit = 1048576
where id in (
  'shop-logos','shop-banners','shop-gallery','product-images',
  'site-assets','seller-verification','user-avatars'
);

-- 9) Bangla medical categories + local icons.
update public.categories set name='মেডিসিন', icon_url='/demo/category-6.svg' where slug='medicine';
update public.categories set name='হৃদরোগ', icon_url='/demo/category-1.svg' where slug='cardiology';
update public.categories set name='স্নায়ুরোগ', icon_url='/demo/category-10.svg' where slug='neurology';
update public.categories set name='চক্ষু', icon_url='/demo/category-2.svg' where slug='ophthalmology';
update public.categories set name='দন্ত চিকিৎসা', icon_url='/demo/category-3.svg' where slug='dentistry';
update public.categories set name='হাড় ও জয়েন্ট', icon_url='/demo/category-4.svg' where slug='orthopedics';
update public.categories set name='স্ত্রী ও প্রসূতি', icon_url='/demo/category-7.svg' where slug='gynecology-obstetrics';
update public.categories set name='শিশু রোগ', icon_url='/demo/category-5.svg' where slug='pediatrics';
update public.categories set name='চর্মরোগ', icon_url='/demo/category-8.svg' where slug='dermatology';
update public.categories set name='নাক-কান-গলা', icon_url='/demo/category-9.svg' where slug='ent';
update public.categories set name='মনোরোগ' where slug='psychiatry';
update public.categories set name='মূত্ররোগ' where slug='urology';
update public.categories set name='সাধারণ সার্জারি' where slug='general-surgery';
update public.categories set name='কিডনি রোগ' where slug='nephrology';
update public.categories set name='পরিপাকতন্ত্র' where slug='gastroenterology';
update public.categories set name='ফুসফুস ও শ্বাসতন্ত্র' where slug='pulmonology';
update public.categories set name='ক্যান্সার' where slug='oncology';
update public.categories set name='হরমোন ও ডায়াবেটিস' where slug='endocrinology';
update public.categories set name='রেডিওলজি' where slug='radiology';
update public.categories set name='অ্যানেস্থেসিওলজি' where slug='anesthesiology';

-- 10) Site branding defaults.
insert into public.site_settings(key,value) values
('site_name','সিরাজগঞ্জ ডাক্তার'),
('site_motto','সিরাজগঞ্জের ডাক্তার, চেম্বার ও হাসপাতালের তথ্য এক জায়গায়'),
('site_logo_url','/doctor-logo.svg'),
('seo_meta_title','সিরাজগঞ্জ ডাক্তার — ডাক্তার খুঁজুন'),
('seo_meta_description','সিরাজগঞ্জের ডাক্তার, বিশেষজ্ঞ, চেম্বার ও হাসপাতালের তথ্য খুঁজে দেখুন।')
on conflict(key) do update set value=excluded.value;

-- ============================================================
-- 11) OPTIONAL DEMO DATA
-- Public demo records are provided in a separate file:
-- supabase/step8_demo_data.sql
-- Run it only if you want 10 starter Doctor profiles + 5 Chambers.
-- ============================================================
