-- ============================================================
-- DOCTOR PLATFORM V1 — CONSOLIDATED SUPABASE SETUP
-- Generated from the approved Sirajganj Marketplace codebase schema.
--
-- IMPORTANT:
-- 1) Run this file in a BRAND-NEW Supabase project only.
-- 2) This intentionally excludes marketplace demo seed users/data.
-- 3) It also excludes the old Orders migration; V1 uses Appointments.
-- 4) Existing table names such as shops/products/seller_verifications are
--    retained internally for maximum code reuse. The application layer will
--    relabel them as Chamber/Doctor/Doctor Verification in Step 3.
-- ============================================================

-- ================= SOURCE MERGE: 0001_init.sql =================
-- ============================================================
-- বাংলা Local Marketplace — Initial Database Migration
-- Run this in Supabase SQL Editor (or via `supabase db push`)
-- ============================================================

-- ------------------------------------------------------------
-- 1. EXTENSIONS
-- ------------------------------------------------------------
create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- 2. TABLES
-- ------------------------------------------------------------

-- 2.1 profiles — auth.users এর সাথে ১:১ সম্পর্ক
-- FIXED (merged from 0002_profiles_contact_info.sql): email কলাম শুরু থেকেই
-- যোগ করা হলো, নাহলে Admin প্যানেলে ইউজারের ইমেইল দেখানো যেত না।
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  phone text,
  email text,
  role text not null default 'visitor' check (role in ('visitor', 'seller', 'super_admin')),
  seller_status text not null default 'none' check (seller_status in ('none', 'pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

-- 2.2 shops
create table if not exists public.shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  shop_name text not null,
  slug text not null unique,
  logo_url text,
  banner_url text,
  about text,
  phone text,
  whatsapp_number text,
  address text,
  google_map_link text,
  facebook_link text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists idx_shops_owner on public.shops (owner_id);

-- 2.3 categories
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  icon_url text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- 2.4 products
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  category_id uuid references public.categories (id) on delete set null,
  name text not null,
  slug text not null unique,
  description text,
  price numeric(12, 2) not null default 0,
  thumbnail_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists idx_products_shop on public.products (shop_id);
create index if not exists idx_products_category on public.products (category_id);

-- 2.5 product_images
create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  image_url text not null,
  sort_order int not null default 0
);
create index if not exists idx_product_images_product on public.product_images (product_id);

-- 2.6 shop_gallery
create table if not exists public.shop_gallery (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  image_url text not null,
  sort_order int not null default 0
);
create index if not exists idx_shop_gallery_shop on public.shop_gallery (shop_id);

-- 2.7 banners
create table if not exists public.banners (
  id uuid primary key default gen_random_uuid(),
  title text,
  image_url text not null,
  link_url text,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- 2.8 site_settings
create table if not exists public.site_settings (
  key text primary key,
  value text
);

-- ------------------------------------------------------------
-- 3. AUTO-CREATE PROFILE ON SIGNUP
-- ------------------------------------------------------------
-- FIXED (merged from 0002_profiles_contact_info.sql): email ও phone দুটোই
-- signup metadata থেকে profiles টেবিলে সেভ করা হচ্ছে (আগে শুধু full_name সেভ হতো)।
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, phone)
  values (
    new.id,
    new.raw_user_meta_data ->> 'full_name',
    new.email,
    new.raw_user_meta_data ->> 'phone'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ------------------------------------------------------------
-- 4. RPC — ভিজিটর নিরাপদে "সেলার হতে চাই" আবেদন করতে পারবে
--    (role/seller_status সরাসরি টেবিল থেকে আপডেট করা যায় না — RLS দ্বারা সুরক্ষিত)
-- ------------------------------------------------------------
-- FIXED (merged from 0004_fix_role_trigger.sql): নিচের trg_prevent_self_role_change
-- trigger যাতে এই RPC-কে ব্লক না করে, তাই একটা transaction-local bypass flag সেট
-- করে দেওয়া হয়।
create or replace function public.request_seller_status()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('app.bypass_role_guard', 'true', true); -- শুধু বর্তমান transaction-এর জন্য
  update public.profiles
  set role = 'seller',
      seller_status = 'pending'
  where id = auth.uid()
    and seller_status = 'none';
end;
$$;

grant execute on function public.request_seller_status() to authenticated;

-- ------------------------------------------------------------
-- 5. HELPER — বর্তমান ইউজার সুপার অ্যাডমিন কিনা যাচাই
-- ------------------------------------------------------------
create or replace function public.is_super_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'super_admin'
  );
$$;

-- ------------------------------------------------------------
-- 6. ENABLE RLS
-- ------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.shops enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_images enable row level security;
alter table public.shop_gallery enable row level security;
alter table public.banners enable row level security;
alter table public.site_settings enable row level security;

-- ------------------------------------------------------------
-- 7. POLICIES — profiles
-- ------------------------------------------------------------
create policy "profiles_select_own_or_admin"
  on public.profiles for select
  using (auth.uid() = id or public.is_super_admin());

-- সাধারণ ইউজার শুধু নিজের full_name/phone আপডেট করতে পারবে (role/seller_status নয় —
-- সেটা trigger দিয়ে সুরক্ষিত করা হয়েছে নিচে)
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "profiles_update_admin"
  on public.profiles for update
  using (public.is_super_admin());

-- role/seller_status কলাম শুধুমাত্র Super Admin বা request_seller_status() RPC
-- (যেটি security definer হিসেবে চলে) পরিবর্তন করতে পারবে — সাধারণ self-update block
-- FIXED (merged from 0004_fix_role_trigger.sql): app.bypass_role_guard flag চেক করে,
-- তাহলে request_seller_status() RPC-কে block করবে না। ব্রাউজার থেকে সরাসরি
-- profiles.update({role: 'super_admin'}) করার চেষ্টা আগের মতোই ব্লক থাকবে।
create or replace function public.prevent_self_role_change()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() = old.id
     and not public.is_super_admin()
     and coalesce(current_setting('app.bypass_role_guard', true), 'false') <> 'true'
  then
    if new.role is distinct from old.role or new.seller_status is distinct from old.seller_status then
      raise exception 'role এবং seller_status নিজে পরিবর্তন করা যাবে না';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_self_role_change on public.profiles;
create trigger trg_prevent_self_role_change
  before update on public.profiles
  for each row execute procedure public.prevent_self_role_change();

-- ------------------------------------------------------------
-- 8. POLICIES — shops
-- ------------------------------------------------------------
create policy "shops_select_public_active"
  on public.shops for select
  using (is_active = true or owner_id = auth.uid() or public.is_super_admin());

create policy "shops_insert_approved_seller"
  on public.shops for insert
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'seller' and seller_status = 'approved'
    )
  );

create policy "shops_update_own_or_admin"
  on public.shops for update
  using (owner_id = auth.uid() or public.is_super_admin());

create policy "shops_delete_admin"
  on public.shops for delete
  using (public.is_super_admin());

-- ------------------------------------------------------------
-- 9. POLICIES — categories
-- ------------------------------------------------------------
create policy "categories_select_all"
  on public.categories for select
  using (true);

create policy "categories_write_admin"
  on public.categories for all
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- ------------------------------------------------------------
-- 10. POLICIES — products
-- ------------------------------------------------------------
create policy "products_select_public_active"
  on public.products for select
  using (
    is_active = true
    or public.is_super_admin()
    or exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid())
  );

create policy "products_insert_own_shop"
  on public.products for insert
  with check (
    exists (
      select 1 from public.shops s
      join public.profiles p on p.id = s.owner_id
      where s.id = shop_id
        and s.owner_id = auth.uid()
        and p.seller_status = 'approved'
    )
  );

create policy "products_update_own_or_admin"
  on public.products for update
  using (
    public.is_super_admin()
    or exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid())
  );

create policy "products_delete_own_or_admin"
  on public.products for delete
  using (
    public.is_super_admin()
    or exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid())
  );

-- ------------------------------------------------------------
-- 11. POLICIES — product_images
-- ------------------------------------------------------------
create policy "product_images_select"
  on public.product_images for select
  using (
    public.is_super_admin()
    or exists (
      select 1 from public.products pr
      join public.shops s on s.id = pr.shop_id
      where pr.id = product_id and (pr.is_active = true or s.owner_id = auth.uid())
    )
  );

create policy "product_images_write_owner_or_admin"
  on public.product_images for all
  using (
    public.is_super_admin()
    or exists (
      select 1 from public.products pr
      join public.shops s on s.id = pr.shop_id
      where pr.id = product_id and s.owner_id = auth.uid()
    )
  )
  with check (
    public.is_super_admin()
    or exists (
      select 1 from public.products pr
      join public.shops s on s.id = pr.shop_id
      where pr.id = product_id and s.owner_id = auth.uid()
    )
  );

-- ------------------------------------------------------------
-- 12. POLICIES — shop_gallery
-- ------------------------------------------------------------
create policy "shop_gallery_select"
  on public.shop_gallery for select
  using (
    public.is_super_admin()
    or exists (
      select 1 from public.shops s
      where s.id = shop_id and (s.is_active = true or s.owner_id = auth.uid())
    )
  );

create policy "shop_gallery_write_owner_or_admin"
  on public.shop_gallery for all
  using (
    public.is_super_admin()
    or exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid())
  )
  with check (
    public.is_super_admin()
    or exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid())
  );

-- ------------------------------------------------------------
-- 13. POLICIES — banners
-- ------------------------------------------------------------
create policy "banners_select_active_or_admin"
  on public.banners for select
  using (is_active = true or public.is_super_admin());

create policy "banners_write_admin"
  on public.banners for all
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- ------------------------------------------------------------
-- 14. POLICIES — site_settings
-- ------------------------------------------------------------
create policy "site_settings_select_all"
  on public.site_settings for select
  using (true);

create policy "site_settings_write_admin"
  on public.site_settings for all
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- ------------------------------------------------------------
-- 15. STORAGE BUCKETS
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values
  ('shop-logos', 'shop-logos', true),
  ('shop-banners', 'shop-banners', true),
  ('shop-gallery', 'shop-gallery', true),
  ('product-images', 'product-images', true),
  ('site-assets', 'site-assets', true)
on conflict (id) do nothing;

-- Public read for all marketplace media buckets
create policy "public_read_marketplace_media"
  on storage.objects for select
  using (bucket_id in ('shop-logos', 'shop-banners', 'shop-gallery', 'product-images', 'site-assets'));

-- Authenticated seller/admin uploads (folder-per-user convention: <user_id>/filename.ext)
create policy "authenticated_upload_marketplace_media"
  on storage.objects for insert
  with check (
    bucket_id in ('shop-logos', 'shop-banners', 'shop-gallery', 'product-images')
    and auth.role() = 'authenticated'
  );

create policy "authenticated_update_own_media"
  on storage.objects for update
  using (
    bucket_id in ('shop-logos', 'shop-banners', 'shop-gallery', 'product-images')
    and auth.role() = 'authenticated'
  );

create policy "authenticated_delete_own_media"
  on storage.objects for delete
  using (
    bucket_id in ('shop-logos', 'shop-banners', 'shop-gallery', 'product-images')
    and auth.role() = 'authenticated'
  );

create policy "admin_manage_site_assets"
  on storage.objects for all
  using (bucket_id = 'site-assets' and public.is_super_admin())
  with check (bucket_id = 'site-assets' and public.is_super_admin());

-- ------------------------------------------------------------
-- 16. SEED — প্রথম Super Admin সেট করার জন্য (ম্যানুয়ালি রান করুন)
-- ------------------------------------------------------------
-- প্রথমে সাইটে সাধারণভাবে Register করুন, তারপর নিচের কোয়েরি চালিয়ে
-- নিজেকে Super Admin বানান (আপনার ইমেইল বসান):
--
-- update public.profiles
-- set role = 'super_admin', seller_status = 'none'
-- where id = (select id from auth.users where email = 'your-admin-email@example.com');


-- ================= SOURCE MERGE: 0002_profiles_contact_info.sql =================
-- ============================================================
-- Migration 0002 — profiles-এ email/phone যোগ, registration আপডেট
--
-- NOTE (আপডেট): এই ফিক্সও এখন সরাসরি 0001_init.sql-এর মধ্যেই merge
-- করা হয়েছে। নতুন (fresh) Supabase প্রজেক্টে শুধু 0001 রান করলেই
-- হবে। এই ফাইলটি শুধু পুরনো (এই ফিক্সের আগে বানানো) প্রজেক্টের
-- জন্য দরকার — আবার রান করলে কোনো ক্ষতি নেই (idempotent)।
-- ============================================================

alter table public.profiles
  add column if not exists email text,
  add column if not exists phone text;

-- signup-এর সময় email ও phone (যদি metadata-তে দেওয়া থাকে) সংরক্ষণ করবে
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, phone)
  values (
    new.id,
    new.raw_user_meta_data ->> 'full_name',
    new.email,
    new.raw_user_meta_data ->> 'phone'
  );
  return new;
end;
$$;

-- বিদ্যমান ইউজারদের জন্য email ব্যাকফিল (auth.users থেকে) — সুপার অ্যাডমিন হিসেবে একবার রান করুন
update public.profiles p
set email = u.email
from auth.users u
where p.id = u.id and p.email is null;


-- ================= SOURCE MERGE: 0004_fix_role_trigger.sql =================
-- ============================================================
-- Migration 0004 — CRITICAL FIX
-- prevent_self_role_change trigger আগে request_seller_status()
-- RPC-কেও ব্লক করে দিচ্ছিল, ফলে কেউ কখনো 'seller'/'pending' হতে
-- পারছিল না। এই মাইগ্রেশন সেটা ঠিক করে এবং আটকে থাকা ইউজারদের
-- অবস্থা মেরামত করে।
--
-- NOTE (আপডেট): এই ফিক্স এখন সরাসরি 0001_init.sql-এর মধ্যেই merge
-- করা হয়েছে, তাই নতুন (fresh) Supabase প্রজেক্টে শুধু 0001 রান
-- করলেই এই বাগ থাকবে না। এই ফাইলটি (0004) শুধু তখনই দরকার যদি
-- আপনার Supabase প্রজেক্টে আগে থেকেই পুরনো (bug-যুক্ত) 0001 রান করা
-- থাকে — এটি আবার রান করলে কোনো ক্ষতি নেই (idempotent), শুধু
-- পুরনো ডাটাবেসে থাকা bug ঠিক করে দেবে।
-- ============================================================

-- ------------------------------------------------------------
-- 1. request_seller_status() RPC — এখন একটা নিরাপদ session flag সেট
--    করে দেয়, যাতে trigger বুঝতে পারে এই আপডেট RPC থেকে আসছে
-- ------------------------------------------------------------
create or replace function public.request_seller_status()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('app.bypass_role_guard', 'true', true); -- শুধু বর্তমান transaction-এর জন্য
  update public.profiles
  set role = 'seller',
      seller_status = 'pending'
  where id = auth.uid()
    and seller_status = 'none';
end;
$$;

-- ------------------------------------------------------------
-- 2. Trigger আপডেট — উপরের flag চেক করবে, তাহলে RPC-কে block করবে না
--    (কিন্তু ব্রাউজার থেকে সরাসরি profiles.update({role: 'super_admin'})
--     করার চেষ্টা আগের মতোই ব্লক থাকবে — নিরাপত্তা অক্ষুণ্ণ)
-- ------------------------------------------------------------
create or replace function public.prevent_self_role_change()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() = old.id
     and not public.is_super_admin()
     and coalesce(current_setting('app.bypass_role_guard', true), 'false') <> 'true'
  then
    if new.role is distinct from old.role or new.seller_status is distinct from old.seller_status then
      raise exception 'role এবং seller_status নিজে পরিবর্তন করা যাবে না';
    end if;
  end if;
  return new;
end;
$$;

-- ------------------------------------------------------------
-- 3. মেরামত — যদি কেউ আগে Register করার সময় "সেলার হতে চাই" টিক
--    দিয়ে থাকে কিন্তু বাগের কারণে role/seller_status আপডেট হয়নি,
--    তাদের এখনো role='visitor' & seller_status='none' অবস্থায় আছে।
--    এই কমান্ডটা এমন কাউকে খুঁজে পেলে দেখাবে (এটা শুধু SELECT, কিছু বদলাবে না):
-- ------------------------------------------------------------
-- select id, email, full_name, role, seller_status, created_at
-- from public.profiles
-- order by created_at desc;

-- যদি উপরের লিস্টে এমন কাউকে দেখেন যে সেলার হতে চেয়েছিল কিন্তু
-- role='visitor' রয়ে গেছে, তাকে ম্যানুয়ালি pending করে দিতে চাইলে
-- (ইমেইল বসিয়ে) এটা রান করুন:
--
-- update public.profiles
-- set role = 'seller', seller_status = 'pending'
-- where email = 'sellers-email@example.com';


-- ================= SOURCE MERGE: 0005_product_seller_update.sql =================
-- ============================================================
-- Product & Seller System Update
-- নতুন ফিচার: পণ্যের ডিসকাউন্ট, পণ্য/ছবি লিমিট, সাব-ক্যাটাগরি,
-- সেলার ভেরিফিকেশন ফর্ম
-- এই মাইগ্রেশনটি idempotent (আবার রান করলেও সমস্যা নেই)
-- ============================================================

-- ------------------------------------------------------------
-- 1. PRODUCTS — ডিসকাউন্ট কলাম যোগ
-- ------------------------------------------------------------
alter table public.products
  add column if not exists discount_type text not null default 'none'
    check (discount_type in ('none', 'fixed', 'percentage'));

alter table public.products
  add column if not exists discount_value numeric(12, 2) not null default 0
    check (discount_value >= 0);

-- percentage ডিসকাউন্ট ১০০%-এর বেশি হতে পারবে না
alter table public.products drop constraint if exists products_discount_percentage_check;
alter table public.products
  add constraint products_discount_percentage_check
  check (discount_type <> 'percentage' or discount_value <= 100);

-- ------------------------------------------------------------
-- 2. প্রতি সেলারের সর্বোচ্চ ৫০টি পণ্যের সীমা (shop প্রতি)
-- ------------------------------------------------------------
create or replace function public.enforce_product_limit()
returns trigger
language plpgsql
as $$
declare
  current_count int;
begin
  select count(*) into current_count from public.products where shop_id = new.shop_id;
  if current_count >= 50 then
    raise exception 'একটি দোকান সর্বোচ্চ ৫০টি পণ্য যোগ করতে পারবে।';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_product_limit on public.products;
create trigger trg_enforce_product_limit
  before insert on public.products
  for each row execute procedure public.enforce_product_limit();

-- ------------------------------------------------------------
-- 3. প্রতি পণ্যে সর্বোচ্চ ৪টি ছবি (thumbnail + ৩টি অতিরিক্ত = ৪টি)
-- ------------------------------------------------------------
create or replace function public.enforce_product_images_limit()
returns trigger
language plpgsql
as $$
declare
  current_count int;
begin
  select count(*) into current_count from public.product_images where product_id = new.product_id;
  if current_count >= 3 then
    raise exception 'একটি পণ্যে সর্বোচ্চ ৪টি ছবি (মূল ছবি + ৩টি অতিরিক্ত) যোগ করা যাবে।';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_product_images_limit on public.product_images;
create trigger trg_enforce_product_images_limit
  before insert on public.product_images
  for each row execute procedure public.enforce_product_images_limit();

-- ------------------------------------------------------------
-- 4. CATEGORIES — সাব-ক্যাটাগরি সাপোর্ট (parent_id)
-- ------------------------------------------------------------
alter table public.categories
  add column if not exists parent_id uuid references public.categories (id) on delete cascade;

create index if not exists idx_categories_parent on public.categories (parent_id);

-- ------------------------------------------------------------
-- 5. আরও ক্যাটাগরি ও সাব-ক্যাটাগরি যোগ (থাকলে স্কিপ হবে)
-- ------------------------------------------------------------
insert into public.categories (name, slug, sort_order)
values
  ('ফ্যাশন ও পোশাক', 'fashion', 1),
  ('ইলেকট্রনিক্স', 'electronics', 2),
  ('খাবার ও মুদি', 'food-grocery', 3),
  ('ঘর সাজানো ও আসবাব', 'home-furniture', 4),
  ('স্বাস্থ্য ও সৌন্দর্য', 'health-beauty', 5),
  ('বই ও স্টেশনারি', 'books-stationery', 6),
  ('মোবাইল ও এক্সেসরিজ', 'mobile-accessories', 7),
  ('কৃষি ও গবাদি পশু', 'agriculture-livestock', 8),
  ('হস্তশিল্প ও উপহার', 'handicrafts-gifts', 9),
  ('শিশু ও খেলনা', 'baby-kids', 10),
  ('খেলাধুলা ও ফিটনেস', 'sports-fitness', 11),
  ('গাড়ি ও যন্ত্রাংশ', 'automobile', 12)
on conflict (slug) do nothing;

-- সাব-ক্যাটাগরি — প্রতিটি parent slug অনুযায়ী parent_id বসানো হচ্ছে
insert into public.categories (name, slug, sort_order, parent_id)
select v.name, v.slug, v.sort_order, p.id
from (
  values
    -- ফ্যাশন ও পোশাক
    ('পুরুষদের পোশাক', 'fashion-mens-wear', 1, 'fashion'),
    ('মহিলাদের পোশাক', 'fashion-womens-wear', 2, 'fashion'),
    ('শাড়ি ও থ্রি-পিস', 'fashion-saree-threepiece', 3, 'fashion'),
    ('জুতা ও ব্যাগ', 'fashion-shoes-bags', 4, 'fashion'),
    -- ইলেকট্রনিক্স
    ('টিভি ও অডিও', 'electronics-tv-audio', 1, 'electronics'),
    ('হোম অ্যাপ্লায়েন্স', 'electronics-home-appliance', 2, 'electronics'),
    ('কম্পিউটার ও ল্যাপটপ', 'electronics-computer-laptop', 3, 'electronics'),
    -- খাবার ও মুদি
    ('তাজা সবজি ও ফল', 'food-fresh-produce', 1, 'food-grocery'),
    ('চাল, ডাল ও মসলা', 'food-rice-spices', 2, 'food-grocery'),
    ('বেকারি ও স্ন্যাকস', 'food-bakery-snacks', 3, 'food-grocery'),
    -- ঘর সাজানো ও আসবাব
    ('খাট ও সোফা', 'home-bed-sofa', 1, 'home-furniture'),
    ('রান্নাঘর সামগ্রী', 'home-kitchenware', 2, 'home-furniture'),
    ('হোম ডেকর', 'home-decor', 3, 'home-furniture'),
    -- স্বাস্থ্য ও সৌন্দর্য
    ('প্রসাধনী', 'health-cosmetics', 1, 'health-beauty'),
    ('পারফিউম', 'health-perfume', 2, 'health-beauty'),
    ('স্বাস্থ্য সামগ্রী', 'health-wellness', 3, 'health-beauty'),
    -- বই ও স্টেশনারি
    ('পাঠ্যবই', 'books-textbook', 1, 'books-stationery'),
    ('অফিস স্টেশনারি', 'books-office-stationery', 2, 'books-stationery'),
    -- মোবাইল ও এক্সেসরিজ
    ('স্মার্টফোন', 'mobile-smartphone', 1, 'mobile-accessories'),
    ('মোবাইল কভার ও চার্জার', 'mobile-cover-charger', 2, 'mobile-accessories'),
    -- কৃষি ও গবাদি পশু
    ('বীজ ও সার', 'agriculture-seed-fertilizer', 1, 'agriculture-livestock'),
    ('গবাদি পশু ও পাখি', 'agriculture-livestock-birds', 2, 'agriculture-livestock'),
    -- হস্তশিল্প ও উপহার
    ('হাতে তৈরি পণ্য', 'handicrafts-handmade', 1, 'handicrafts-gifts'),
    ('উপহার সামগ্রী', 'handicrafts-gift-items', 2, 'handicrafts-gifts'),
    -- শিশু ও খেলনা
    ('শিশুদের পোশাক', 'baby-clothing', 1, 'baby-kids'),
    ('খেলনা', 'baby-toys', 2, 'baby-kids'),
    -- খেলাধুলা ও ফিটনেস
    ('ব্যায়ামের সরঞ্জাম', 'sports-fitness-equipment', 1, 'sports-fitness'),
    ('খেলাধুলার সামগ্রী', 'sports-outdoor', 2, 'sports-fitness'),
    -- গাড়ি ও যন্ত্রাংশ
    ('মোটরসাইকেল ও পার্টস', 'automobile-motorcycle-parts', 1, 'automobile'),
    ('গাড়ির যন্ত্রাংশ', 'automobile-car-parts', 2, 'automobile')
) as v(name, slug, sort_order, parent_slug)
join public.categories p on p.slug = v.parent_slug
on conflict (slug) do nothing;

-- ------------------------------------------------------------
-- 6. SELLER VERIFICATION — সেলার ভেরিফিকেশন তথ্য
-- ------------------------------------------------------------
create table if not exists public.seller_verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles (id) on delete cascade,
  full_name text,
  profile_photo_url text,
  phone text,
  address text,
  google_map_link text,
  facebook_link text,
  nid_number text,
  nid_front_url text,
  nid_back_url text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_seller_verifications_user on public.seller_verifications (user_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_seller_verifications_updated_at on public.seller_verifications;
create trigger trg_seller_verifications_updated_at
  before update on public.seller_verifications
  for each row execute procedure public.set_updated_at();

alter table public.seller_verifications enable row level security;

create policy "seller_verifications_select_own_or_admin"
  on public.seller_verifications for select
  using (user_id = auth.uid() or public.is_super_admin());

create policy "seller_verifications_insert_own"
  on public.seller_verifications for insert
  with check (user_id = auth.uid());

-- ইউজার নিজের তথ্য আপডেট করতে পারবে, কিন্তু status কলাম শুধু Super Admin বদলাতে পারবে
create or replace function public.prevent_self_verification_status_change()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() = old.user_id and not public.is_super_admin() then
    if new.status is distinct from old.status then
      raise exception 'ভেরিফিকেশনের status নিজে পরিবর্তন করা যাবে না — শুধুমাত্র Super Admin অনুমোদন/প্রত্যাখ্যান করতে পারবেন।';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_self_verification_status_change on public.seller_verifications;
create trigger trg_prevent_self_verification_status_change
  before update on public.seller_verifications
  for each row execute procedure public.prevent_self_verification_status_change();

create policy "seller_verifications_update_own_or_admin"
  on public.seller_verifications for update
  using (user_id = auth.uid() or public.is_super_admin())
  with check (user_id = auth.uid() or public.is_super_admin());

-- ------------------------------------------------------------
-- 7. STORAGE — সেলার ভেরিফিকেশন ডকুমেন্ট বাকেট
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('seller-verification', 'seller-verification', true)
on conflict (id) do nothing;

create policy "public_read_seller_verification"
  on storage.objects for select
  using (bucket_id = 'seller-verification');

create policy "authenticated_upload_seller_verification"
  on storage.objects for insert
  with check (bucket_id = 'seller-verification' and auth.role() = 'authenticated');

create policy "authenticated_update_own_seller_verification"
  on storage.objects for update
  using (bucket_id = 'seller-verification' and auth.role() = 'authenticated');

create policy "authenticated_delete_own_seller_verification"
  on storage.objects for delete
  using (bucket_id = 'seller-verification' and auth.role() = 'authenticated');


-- ================= SOURCE MERGE: 0006_role_and_admin_update.sql =================
-- ============================================================
-- Role System Update — Admin / Super Admin
-- এই মাইগ্রেশনটি অবশ্যই Supabase SQL Editor-এ রান করতে হবে (idempotent)।
--
-- কী পরিবর্তন হচ্ছে:
-- 1) আগের 'super_admin' role-কে এখন থেকে "Admin" হিসেবে ধরা হবে (normal
--    admin functions — কিন্তু role/permission/account-status পরিবর্তন করতে
--    পারবে না, নতুন Admin/Super Admin বানাতে পারবে না)।
-- 2) একটি সম্পূর্ণ নতুন সর্বোচ্চ-লেভেল 'super_admin' role তৈরি হলো, যার
--    ফুল সিস্টেম অ্যাক্সেস আছে।
-- 3) প্রতিটি বিদ্যমান 'super_admin' ইউজারকে (এই মাইগ্রেশন প্রথমবার রান হওয়ার
--    সময়) স্বয়ংক্রিয়ভাবে 'admin'-এ রূপান্তর করা হচ্ছে — এই রূপান্তর
--    ঠিক একবারই ঘটে (site_settings-এ একটা ফ্ল্যাগ রেখে), যাতে এই ফাইল
--    আবার রান করলে সত্যিকারের নতুন Super Admin-কে ভুলবশত Admin-এ নামিয়ে
--    না দেয়।
--
-- ⚠️ রান করার পর: আপনাকে ম্যানুয়ালি অন্তত একজনকে আসল Super Admin বানাতে হবে:
--
--   update public.profiles
--   set role = 'super_admin'
--   where id = (select id from auth.users where email = 'your-admin-email@example.com');
--
-- (যদি রান না করেন, তাহলে পুরনো সব super_admin এখন শুধু 'admin' — এবং কেউ
--  role change / ban / delete করতে পারবে না যতক্ষণ না একজন Super Admin আছে।)
-- ============================================================

-- ------------------------------------------------------------
-- 1. profiles.role চেক কনস্ট্রেইন্ট আপডেট — 'admin' যোগ করা হলো
-- ------------------------------------------------------------
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('visitor', 'seller', 'admin', 'super_admin'));

-- ------------------------------------------------------------
-- 2. profiles.account_status — ban/unban এর জন্য
-- ------------------------------------------------------------
alter table public.profiles
  add column if not exists account_status text not null default 'active';

alter table public.profiles drop constraint if exists profiles_account_status_check;
alter table public.profiles
  add constraint profiles_account_status_check
  check (account_status in ('active', 'banned'));

-- ------------------------------------------------------------
-- 3. HELPER — "Admin অথবা তার উপরে" (Admin + Super Admin) কিনা
--    সাধারণ অ্যাডমিন প্যানেল ফিচারগুলোর (প্রোডাক্ট, ক্যাটাগরি, ব্যানার,
--    সেটিংস, সেলার অনুমোদন) জন্য ব্যবহৃত হবে
-- ------------------------------------------------------------
create or replace function public.is_admin_or_above()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin', 'super_admin')
  );
$$;

-- is_super_admin() আগে থেকেই আছে (0001), role = 'super_admin' চেক করে —
-- রূপান্তরের পর এটা এখন সঠিকভাবে শুধু আসল Super Admin-কেই ধরবে।
-- কোনো পরিবর্তনের দরকার নেই, শুধু নিশ্চিত করতে আবার তৈরি করা হলো।
create or replace function public.is_super_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'super_admin'
  );
$$;

-- ------------------------------------------------------------
-- 5. GUARD TRIGGER আপডেট — role/account_status পরিবর্তনের সুরক্ষা
--    - কেউ নিজের role/seller_status/account_status নিজে বদলাতে পারবে না
--      (Super Admin এবং request_seller_status() RPC ছাড়া)
--    - role অথবা account_status *যেকোনো* ইউজারের জন্য বদলাতে হলে অবশ্যই
--      Super Admin হতে হবে — Admin এটা পারবে না, এমনকি অন্য কারো জন্যও না।
--      (এর মানে: Admin নতুন Admin/Super Admin বানাতে পারবে না, ban/unban
--      করতে পারবে না)
--    - service_role (Edge Function থেকে, যেমন ban/delete) সবসময় bypass করবে
-- ------------------------------------------------------------
create or replace function public.prevent_self_role_change()
returns trigger
language plpgsql
as $$
begin
  -- Edge Function / service_role থেকে হওয়া পরিবর্তন সবসময় অনুমোদিত।
  -- এবং Supabase Dashboard-এর SQL Editor থেকে সরাসরি রান করা কমান্ডও
  -- অনুমোদিত (এটা 'postgres'/'supabase_admin' role হিসেবে চলে) — নাহলে
  -- প্রথম Super Admin বানানোর SQL-ই ব্লক হয়ে যাবে (bootstrapping সমস্যা)।
  if current_user in ('service_role', 'postgres', 'supabase_admin') then
    return new;
  end if;

  -- নিজের role/seller_status/account_status নিজে বদলানো ব্লক (Super Admin ও RPC bypass বাদে)
  if auth.uid() = old.id
     and not public.is_super_admin()
     and coalesce(current_setting('app.bypass_role_guard', true), 'false') <> 'true'
  then
    if new.role is distinct from old.role
       or new.seller_status is distinct from old.seller_status
       or new.account_status is distinct from old.account_status
    then
      raise exception 'role, seller_status এবং account_status নিজে পরিবর্তন করা যাবে না';
    end if;
  end if;

  -- role বা account_status বদলানো (যে কারো জন্যই) — শুধুমাত্র Super Admin পারবেন
  if (new.role is distinct from old.role or new.account_status is distinct from old.account_status)
     and not public.is_super_admin()
  then
    raise exception 'শুধুমাত্র Super Admin ইউজার role বা account status পরিবর্তন করতে পারবেন।';
  end if;

  return new;
end;
$$;

-- ------------------------------------------------------------
-- 6. profiles পলিসি — এখন is_admin_or_above() ব্যবহার করবে (Admin এখনও
--    সব ইউজার দেখতে/সাধারণ তথ্য (যেমন seller_status অনুমোদন) আপডেট করতে
--    পারবে — role/account_status ট্রিগার দিয়ে আলাদাভাবে সুরক্ষিত)
-- ------------------------------------------------------------
drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin"
  on public.profiles for select
  using (auth.uid() = id or public.is_admin_or_above());

drop policy if exists "profiles_update_admin" on public.profiles;
create policy "profiles_update_admin"
  on public.profiles for update
  using (public.is_admin_or_above());

-- ------------------------------------------------------------
-- 7. বাকি টেবিলের পলিসি — "Admin" যেন normal admin functions হারিয়ে না
--    ফেলে, তাই is_super_admin() -> is_admin_or_above() এ পরিবর্তন করা হলো
-- ------------------------------------------------------------

-- shops
drop policy if exists "shops_select_public_active" on public.shops;
create policy "shops_select_public_active"
  on public.shops for select
  using (is_active = true or owner_id = auth.uid() or public.is_admin_or_above());

drop policy if exists "shops_update_own_or_admin" on public.shops;
create policy "shops_update_own_or_admin"
  on public.shops for update
  using (owner_id = auth.uid() or public.is_admin_or_above());

drop policy if exists "shops_delete_admin" on public.shops;
create policy "shops_delete_admin"
  on public.shops for delete
  using (public.is_admin_or_above());

-- categories
drop policy if exists "categories_write_admin" on public.categories;
create policy "categories_write_admin"
  on public.categories for all
  using (public.is_admin_or_above())
  with check (public.is_admin_or_above());

-- products
drop policy if exists "products_select_public_active" on public.products;
create policy "products_select_public_active"
  on public.products for select
  using (
    is_active = true
    or public.is_admin_or_above()
    or exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid())
  );

drop policy if exists "products_update_own_or_admin" on public.products;
create policy "products_update_own_or_admin"
  on public.products for update
  using (
    public.is_admin_or_above()
    or exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid())
  );

drop policy if exists "products_delete_own_or_admin" on public.products;
create policy "products_delete_own_or_admin"
  on public.products for delete
  using (
    public.is_admin_or_above()
    or exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid())
  );

-- product_images
drop policy if exists "product_images_select" on public.product_images;
create policy "product_images_select"
  on public.product_images for select
  using (
    public.is_admin_or_above()
    or exists (
      select 1 from public.products pr
      join public.shops s on s.id = pr.shop_id
      where pr.id = product_id and (pr.is_active = true or s.owner_id = auth.uid())
    )
  );

drop policy if exists "product_images_write_owner_or_admin" on public.product_images;
create policy "product_images_write_owner_or_admin"
  on public.product_images for all
  using (
    public.is_admin_or_above()
    or exists (
      select 1 from public.products pr
      join public.shops s on s.id = pr.shop_id
      where pr.id = product_id and s.owner_id = auth.uid()
    )
  )
  with check (
    public.is_admin_or_above()
    or exists (
      select 1 from public.products pr
      join public.shops s on s.id = pr.shop_id
      where pr.id = product_id and s.owner_id = auth.uid()
    )
  );

-- shop_gallery
drop policy if exists "shop_gallery_select" on public.shop_gallery;
create policy "shop_gallery_select"
  on public.shop_gallery for select
  using (
    public.is_admin_or_above()
    or exists (
      select 1 from public.shops s
      where s.id = shop_id and (s.is_active = true or s.owner_id = auth.uid())
    )
  );

drop policy if exists "shop_gallery_write_owner_or_admin" on public.shop_gallery;
create policy "shop_gallery_write_owner_or_admin"
  on public.shop_gallery for all
  using (
    public.is_admin_or_above()
    or exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid())
  )
  with check (
    public.is_admin_or_above()
    or exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid())
  );

-- banners
drop policy if exists "banners_select_active_or_admin" on public.banners;
create policy "banners_select_active_or_admin"
  on public.banners for select
  using (is_active = true or public.is_admin_or_above());

drop policy if exists "banners_write_admin" on public.banners;
create policy "banners_write_admin"
  on public.banners for all
  using (public.is_admin_or_above())
  with check (public.is_admin_or_above());

-- site_settings (সাইট-ওয়াইড কনটেন্ট সেটিংস — system roles/permissions নয়,
-- তাই এটা normal admin function হিসেবেই থাকছে)
drop policy if exists "site_settings_write_admin" on public.site_settings;
create policy "site_settings_write_admin"
  on public.site_settings for all
  using (public.is_admin_or_above())
  with check (public.is_admin_or_above());

-- storage: site-assets
drop policy if exists "admin_manage_site_assets" on storage.objects;
create policy "admin_manage_site_assets"
  on storage.objects for all
  using (bucket_id = 'site-assets' and public.is_admin_or_above())
  with check (bucket_id = 'site-assets' and public.is_admin_or_above());

-- seller_verifications (verification রিভিউ/অনুমোদন normal admin function)
drop policy if exists "seller_verifications_select_own_or_admin" on public.seller_verifications;
create policy "seller_verifications_select_own_or_admin"
  on public.seller_verifications for select
  using (user_id = auth.uid() or public.is_admin_or_above());

drop policy if exists "seller_verifications_update_own_or_admin" on public.seller_verifications;
create policy "seller_verifications_update_own_or_admin"
  on public.seller_verifications for update
  using (user_id = auth.uid() or public.is_admin_or_above())
  with check (user_id = auth.uid() or public.is_admin_or_above());

-- ------------------------------------------------------------
-- 8. shops.max_products_override — Super Admin প্রতি দোকানের জন্য
--    ডিফল্ট ৫০-এর সীমা বাড়াতে/কমাতে পারবেন (NULL মানে ডিফল্ট ৫০)
-- ------------------------------------------------------------
alter table public.shops add column if not exists max_products_override int;
alter table public.shops drop constraint if exists shops_max_products_override_check;
alter table public.shops
  add constraint shops_max_products_override_check
  check (max_products_override is null or max_products_override > 0);

-- শুধু Admin/Super Admin আপডেট করতে পারবে এই কলাম — কিন্তু চূড়ান্ত সিদ্ধান্ত
-- (limit বাড়ানো/কমানো) Super Admin-এর কাজ, তাই আলাদা guard trigger:
create or replace function public.guard_max_products_override()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('service_role', 'postgres', 'supabase_admin') then
    return new;
  end if;
  if new.max_products_override is distinct from old.max_products_override
     and not public.is_super_admin()
  then
    raise exception 'শুধুমাত্র Super Admin পণ্যের সর্বোচ্চ সীমা পরিবর্তন করতে পারবেন।';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_max_products_override on public.shops;
create trigger trg_guard_max_products_override
  before update on public.shops
  for each row execute procedure public.guard_max_products_override();

-- enforce_product_limit() এখন override থাকলে সেটা ব্যবহার করবে, নাহলে ডিফল্ট ৫০
create or replace function public.enforce_product_limit()
returns trigger
language plpgsql
as $$
declare
  current_count int;
  limit_value int;
begin
  select count(*) into current_count from public.products where shop_id = new.shop_id;
  select coalesce(max_products_override, 50) into limit_value from public.shops where id = new.shop_id;
  if current_count >= limit_value then
    raise exception 'এই দোকান সর্বোচ্চ %টি পণ্য যোগ করতে পারবে।', limit_value;
  end if;
  return new;
end;
$$;

-- ------------------------------------------------------------
-- ৯. নোট: এই মাইগ্রেশনের পরে অন্তত একজন আসল Super Admin ম্যানুয়ালি বানাতে
--    ভুলবেন না (ফাইলের শুরুতে দেওয়া SQL দেখুন)।
-- ============================================================


-- ================= SOURCE MERGE: 0007_super_admin_lockout_fix.sql =================
-- ============================================================
-- Super Admin Lockout Fix
-- এই মাইগ্রেশনটি Supabase SQL Editor-এ রান করতে হবে (idempotent, নতুন ও
-- বিদ্যমান উভয় প্রজেক্টেই নিরাপদ)।
--
-- সমাধান করা সমস্যা:
--   0006_role_and_admin_update.sql প্রতিটি পুরনো 'super_admin'-কে
--   'admin'-এ রূপান্তর করেছিল, এবং নতুন Super Admin ম্যানুয়ালি SQL চালিয়ে
--   বানানোর কথা ছিল। যদি সেই ধাপটি বাদ পড়ে (বা কেউ ভুলে যায়), তাহলে
--   সিস্টেমে কোনো Super Admin থাকে না — এবং শুধুমাত্র Super Admin-ই নতুন
--   Super Admin বানাতে পারে বলে, সিস্টেম স্থায়ীভাবে লক হয়ে যায় (কেউই আর
--   role পরিবর্তন করতে পারে না)।
--
-- এই মাইগ্রেশন যা করে:
--   ১. স্বয়ংক্রিয়ভাবে সিস্টেম পরীক্ষা করে — যদি বর্তমানে কোনো Super Admin
--      না থাকে, তাহলে সবচেয়ে পুরনো (প্রথম তৈরি হওয়া) 'admin' ইউজারকে
--      আবার 'super_admin'-এ উন্নীত করে দেয় (এটাই আসলে আগের প্রকৃত Super
--      Admin হওয়ার সম্ভাবনা সবচেয়ে বেশি)। যদি কোনো 'admin'-ও না থাকে,
--      কিছু পরিবর্তন করা হয় না (অনুমান করে কাউকে তুলে দেওয়া নিরাপদ না)।
--      এই ধাপটি প্রকৃতিগতভাবেই idempotent — একবার অন্তত ১ জন Super Admin
--      হয়ে গেলে, পরের বার এই মাইগ্রেশন আবার রান করলেও কিছু বদলাবে না।
--   ২. স্থায়ীভাবে একটি গার্ড যোগ করে: এখন থেকে কোনো অ্যাকশনই (role
--      পরিবর্তন হোক বা ব্যান) শেষ অবশিষ্ট Super Admin-কে সরাতে পারবে না —
--      ফলে ভবিষ্যতে এই লকআউট আর কখনো ঘটবে না।
--
-- বিদ্যমান ডেটা, টেবিল স্ট্রাকচার, RLS পলিসি বা অন্য কোনো ফিচার এখানে
-- পরিবর্তন করা হয়নি।
-- ============================================================

-- ------------------------------------------------------------
-- ১. Auto-heal: সিস্টেমে কোনো Super Admin না থাকলে, সবচেয়ে পুরনো Admin-কে
--    Super Admin-এ উন্নীত করা হচ্ছে।
-- ------------------------------------------------------------
do $$
declare
  candidate_id uuid;
begin
  if not exists (select 1 from public.profiles where role = 'super_admin') then
    select id into candidate_id
    from public.profiles
    where role = 'admin'
    order by created_at asc
    limit 1;

    if candidate_id is not null then
      update public.profiles set role = 'super_admin' where id = candidate_id;
    end if;
  end if;
end $$;

-- ------------------------------------------------------------
-- ২. HELPER — বর্তমানে কতজন Super Admin আছে
-- ------------------------------------------------------------
create or replace function public.count_super_admins()
returns int
language sql
security definer
set search_path = public
stable
as $$
  select count(*)::int from public.profiles where role = 'super_admin';
$$;

-- ------------------------------------------------------------
-- ৩. prevent_self_role_change() আপডেট — শেষ Super Admin-কে role/ban
--    পরিবর্তনের মাধ্যমে সরানো স্থায়ীভাবে ব্লক করা হচ্ছে (bypass ছাড়াই,
--    যাতে ভুলবশতও সিস্টেম আর কখনো লক না হয়ে যায়)।
-- ------------------------------------------------------------
create or replace function public.prevent_self_role_change()
returns trigger
language plpgsql
as $$
begin
  -- সিস্টেমে অন্তত ১ জন Super Admin সবসময় থাকতেই হবে — এই চেক কোনো
  -- bypass ছাড়াই সবার জন্য (service_role/postgres সহ) প্রযোজ্য, কারণ এটা
  -- একটা hard invariant, permission check না।
  if old.role = 'super_admin'
     and new.role is distinct from 'super_admin'
     and public.count_super_admins() <= 1
  then
    raise exception 'সিস্টেমে অন্তত একজন Super Admin থাকতেই হবে — শেষ Super Admin-এর role পরিবর্তন করা যাবে না।';
  end if;

  if old.role = 'super_admin'
     and new.account_status = 'banned'
     and old.account_status is distinct from 'banned'
     and public.count_super_admins() <= 1
  then
    raise exception 'সিস্টেমে অন্তত একজন Super Admin থাকতেই হবে — শেষ Super Admin-কে ব্যান করা যাবে না।';
  end if;

  -- Edge Function / service_role থেকে হওয়া পরিবর্তন এবং Supabase Dashboard
  -- SQL Editor থেকে সরাসরি রান করা কমান্ড (postgres/supabase_admin) সবসময়
  -- অনুমোদিত — নাহলে প্রথম Super Admin বানানোর SQL-ই ব্লক হয়ে যাবে
  -- (bootstrapping সমস্যা)। উপরের ২টি হার্ড-ইনভ্যারিয়েন্ট চেক অবশ্য এর
  -- আগেই রান হয়ে গেছে, তাই এই bypass দিয়ে শেষ Super Admin সরানো যাবে না।
  if current_user in ('service_role', 'postgres', 'supabase_admin') then
    return new;
  end if;

  -- নিজের role/seller_status/account_status নিজে বদলানো ব্লক (Super Admin ও RPC bypass বাদে)
  if auth.uid() = old.id
     and not public.is_super_admin()
     and coalesce(current_setting('app.bypass_role_guard', true), 'false') <> 'true'
  then
    if new.role is distinct from old.role
       or new.seller_status is distinct from old.seller_status
       or new.account_status is distinct from old.account_status
    then
      raise exception 'role, seller_status এবং account_status নিজে পরিবর্তন করা যাবে না';
    end if;
  end if;

  -- role বা account_status বদলানো (যে কারো জন্যই) — শুধুমাত্র Super Admin পারবেন
  if (new.role is distinct from old.role or new.account_status is distinct from old.account_status)
     and not public.is_super_admin()
  then
    raise exception 'শুধুমাত্র Super Admin ইউজার role বা account status পরিবর্তন করতে পারবেন।';
  end if;

  return new;
end;
$$;

-- trigger আগে থেকেই profiles টেবিলে attach করা আছে (0001-এ তৈরি) — শুধু
-- function replace করলেই যথেষ্ট, trigger পুনরায় তৈরির দরকার নেই।

-- ============================================================
-- রান করার পর: `select role, email, created_at from public.profiles
-- where role = 'super_admin';` চালিয়ে নিশ্চিত করুন অন্তত ১ জন Super Admin
-- আছে। যদি কোনো 'admin' ইউজারই আগে না থেকে থাকে (তাই auto-heal কাউকে
-- খুঁজে না পায়), README-এর ধাপ ৫ অনুসরণ করে ম্যানুয়ালি একজনকে বানিয়ে নিন।
-- ============================================================


-- ================= SOURCE MERGE: 0008_admin_permission_scope.sql =================
-- ============================================================
-- Admin Permission Scope Update
-- এই মাইগ্রেশনটি Supabase SQL Editor-এ রান করতে হবে (idempotent, নতুন ও
-- বিদ্যমান উভয় প্রজেক্টেই নিরাপদ)।
--
-- কী পরিবর্তন হচ্ছে (শুধু এই দুইটা টেবিলের write policy):
--   - banners       : এখন থেকে শুধুমাত্র Super Admin ব্যানার
--                      যোগ/এডিট/মুছতে পারবেন (আগে Admin-ও পারতো)।
--   - site_settings : এখন থেকে শুধুমাত্র Super Admin সাইট সেটিংস
--                      পরিবর্তন করতে পারবেন (আগে Admin-ও পারতো)।
--
-- Admin-এর বাকি সব permission অপরিবর্তিত থাকছে — সেলার ম্যানেজমেন্ট
-- (প্রোফাইল দেখা, active/deactivate), সেলার ভেরিফিকেশন, ক্যাটাগরি এবং
-- পণ্য ম্যানেজমেন্ট — এসবের কোনো পলিসি এখানে বদলানো হয়নি।
--
-- (SELECT policy অপরিবর্তিত আছে — banners/site_settings public read
-- আগের মতোই কাজ করবে, শুধু write/all অ্যাক্সেসটাই সংকুচিত হলো।)
-- ============================================================

-- banners — শুধুমাত্র Super Admin write করতে পারবেন
drop policy if exists "banners_write_admin" on public.banners;
create policy "banners_write_admin"
  on public.banners for all
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- site_settings — শুধুমাত্র Super Admin write করতে পারবেন
drop policy if exists "site_settings_write_admin" on public.site_settings;
create policy "site_settings_write_admin"
  on public.site_settings for all
  using (public.is_super_admin())
  with check (public.is_super_admin());


-- ================= SOURCE MERGE: 0009_product_stock_sold.sql =================
-- ============================================================
-- Product Stock & Sold Amount
-- এই মাইগ্রেশনটি Supabase SQL Editor-এ রান করতে হবে (idempotent, নতুন ও
-- বিদ্যমান উভয় প্রজেক্টেই নিরাপদ)।
--
-- কী যোগ হচ্ছে:
--   - products.stock_quantity : সেলার ম্যানুয়ালি স্টকের পরিমাণ সেট করতে পারবেন
--   - products.sold_count     : সেলার ম্যানুয়ালি বিক্রিত পরিমাণ সেট করতে পারবেন
--
-- কোনো নতুন policy তৈরি হচ্ছে না — বিদ্যমান
-- "products_update_own_or_admin" policy (row-level) অনুযায়ী দোকানের
-- মালিক/অ্যাডমিন আগে যেভাবে products টেবিলের যেকোনো কলাম আপডেট করতে
-- পারতেন, এই নতুন দুইটি কলামও একইভাবে আপডেট করতে পারবেন — permission-এ
-- কোনো পরিবর্তন হয়নি।
-- ============================================================

alter table public.products
  add column if not exists stock_quantity integer not null default 0,
  add column if not exists sold_count integer not null default 0;

alter table public.products
  drop constraint if exists products_stock_quantity_check;
alter table public.products
  add constraint products_stock_quantity_check check (stock_quantity >= 0);

alter table public.products
  drop constraint if exists products_sold_count_check;
alter table public.products
  add constraint products_sold_count_check check (sold_count >= 0);


-- ================= SOURCE MERGE: 0010_product_analytics.sql =================
-- ============================================================
-- Product Analytics: Views, Saves, Order-Button Clicks
-- এই মাইগ্রেশনটি Supabase SQL Editor-এ রান করতে হবে (idempotent, নতুন ও
-- বিদ্যমান উভয় প্রজেক্টেই নিরাপদ)।
--
-- কী যোগ হচ্ছে:
--   - products.view_count  : পণ্যের পেজ কতবার দেখা হয়েছে
--   - products.save_count  : কতজন ভিজিটর/সেলার পণ্যটি সেভ করেছেন
--   - products.click_count : "অর্ডার করুন" বাটনে কতবার ক্লিক হয়েছে
--     (WhatsApp / Facebook Page-Messenger এ সেলারের সাথে যোগাযোগ করতে)
--   - product_saves টেবিল  : কোন লগইন ইউজার কোন পণ্য সেভ করেছেন (toggle-able)
--   - increment_product_view() / increment_product_order_click() RPC:
--     visitor/anon সহ যে কেউ কল করতে পারবে, কিন্তু শুধুমাত্র নির্দিষ্ট
--     কাউন্টার কলামটাই atomic ভাবে বাড়বে — SECURITY DEFINER দিয়ে সুরক্ষিত,
--     products টেবিলে সরাসরি update permission না দিয়েই এটা সম্ভব হচ্ছে।
--   - products টেবিলকে Supabase Realtime publication-এ যোগ করা হচ্ছে, যাতে
--     Seller Dashboard-এর Analytics পেজ নতুন view/save/click near-real-time
--     দেখতে পারে (polling ছাড়াই)।
-- ============================================================

-- ------------------------------------------------------------
-- 1. COUNTER COLUMNS
-- ------------------------------------------------------------
alter table public.products
  add column if not exists view_count integer not null default 0,
  add column if not exists save_count integer not null default 0,
  add column if not exists click_count integer not null default 0;

alter table public.products drop constraint if exists products_view_count_check;
alter table public.products add constraint products_view_count_check check (view_count >= 0);

alter table public.products drop constraint if exists products_save_count_check;
alter table public.products add constraint products_save_count_check check (save_count >= 0);

alter table public.products drop constraint if exists products_click_count_check;
alter table public.products add constraint products_click_count_check check (click_count >= 0);

-- ------------------------------------------------------------
-- 2. product_saves — কে কোন পণ্য সেভ করেছেন (শুধুমাত্র লগইন ইউজার)
-- ------------------------------------------------------------
create table if not exists public.product_saves (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (product_id, user_id)
);
create index if not exists idx_product_saves_product on public.product_saves (product_id);
create index if not exists idx_product_saves_user on public.product_saves (user_id);

alter table public.product_saves enable row level security;

drop policy if exists "product_saves_select_own" on public.product_saves;
create policy "product_saves_select_own"
  on public.product_saves for select
  using (user_id = auth.uid() or public.is_super_admin());

drop policy if exists "product_saves_insert_own" on public.product_saves;
create policy "product_saves_insert_own"
  on public.product_saves for insert
  with check (user_id = auth.uid());

drop policy if exists "product_saves_delete_own" on public.product_saves;
create policy "product_saves_delete_own"
  on public.product_saves for delete
  using (user_id = auth.uid());

-- save/unsave হলে products.save_count স্বয়ংক্রিয়ভাবে (atomic) আপডেট হবে
create or replace function public.handle_product_save_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.products set save_count = save_count + 1 where id = new.product_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.products set save_count = greatest(save_count - 1, 0) where id = old.product_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_product_save_insert on public.product_saves;
create trigger trg_product_save_insert
  after insert on public.product_saves
  for each row execute procedure public.handle_product_save_change();

drop trigger if exists trg_product_save_delete on public.product_saves;
create trigger trg_product_save_delete
  after delete on public.product_saves
  for each row execute procedure public.handle_product_save_change();

-- ------------------------------------------------------------
-- 3. RPC — view / order-click কাউন্ট বাড়ানো (visitor/anon সহ যে কেউ কল করতে
--    পারবে, কিন্তু শুধু নির্দিষ্ট কাউন্টার কলামই বাড়বে, নিষ্ক্রিয় পণ্যে নয়)
-- ------------------------------------------------------------
create or replace function public.increment_product_view(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.products
  set view_count = view_count + 1
  where id = p_product_id and is_active = true;
end;
$$;

create or replace function public.increment_product_order_click(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.products
  set click_count = click_count + 1
  where id = p_product_id and is_active = true;
end;
$$;

grant execute on function public.increment_product_view(uuid) to anon, authenticated;
grant execute on function public.increment_product_order_click(uuid) to anon, authenticated;

-- ------------------------------------------------------------
-- 4. REALTIME — Seller Analytics পেজ near-real-time আপডেট পাওয়ার জন্য
--    products টেবিলকে supabase_realtime publication-এ যোগ করা হচ্ছে
--    (আগে থেকে যোগ করা থাকলে চুপচাপ স্কিপ করবে, error দেবে না)
-- ------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'products'
  ) then
    alter publication supabase_realtime add table public.products;
  end if;
end $$;


-- ================= SOURCE MERGE: 0011_visitor_features.sql =================
-- ============================================================
-- Visitor Features: Saved Sellers + Bilingual Search Dictionary
-- এই মাইগ্রেশনটি Supabase SQL Editor-এ রান করতে হবে (idempotent, নতুন ও
-- বিদ্যমান উভয় প্রজেক্টেই নিরাপদ)।
--
-- কী যোগ হচ্ছে:
--   - shop_saves টেবিল      : ভিজিটর কোন দোকান "সেভ" করেছেন তা রাখে
--     (product_saves টেবিলের মতোই প্যাটার্ন — শুধু লগইন ইউজার, RLS-সুরক্ষিত)
--   - search_synonyms টেবিল : বাংলা-ইংরেজি সমার্থক শব্দের একটি ডিকশনারি —
--     সার্চ যাতে "shirt" লিখলেও "শার্ট" পণ্য খুঁজে দেয়, আবার "শার্ট" লিখলেও
--     ইংরেজি নামের পণ্য (যদি থাকে) খুঁজে দেয়। এটি শুধু SELECT-এর জন্য পাবলিক
--     — Admin/Seller Panel থেকে এটি ম্যানেজ করার কোনো UI নেই (ইচ্ছাকৃতভাবে,
--     স্কোপ শুধু Visitor ফিচারের মধ্যেই সীমাবদ্ধ রাখতে)।
-- ============================================================

-- ------------------------------------------------------------
-- 1. shop_saves — কে কোন দোকান সেভ করেছেন (শুধুমাত্র লগইন ইউজার)
-- ------------------------------------------------------------
create table if not exists public.shop_saves (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (shop_id, user_id)
);
create index if not exists idx_shop_saves_shop on public.shop_saves (shop_id);
create index if not exists idx_shop_saves_user on public.shop_saves (user_id);

alter table public.shop_saves enable row level security;

drop policy if exists "shop_saves_select_own" on public.shop_saves;
create policy "shop_saves_select_own"
  on public.shop_saves for select
  using (user_id = auth.uid() or public.is_super_admin());

drop policy if exists "shop_saves_insert_own" on public.shop_saves;
create policy "shop_saves_insert_own"
  on public.shop_saves for insert
  with check (user_id = auth.uid());

drop policy if exists "shop_saves_delete_own" on public.shop_saves;
create policy "shop_saves_delete_own"
  on public.shop_saves for delete
  using (user_id = auth.uid());

-- ------------------------------------------------------------
-- 2. search_synonyms — বাংলা ⇄ ইংরেজি সমার্থক শব্দের ডিকশনারি
-- ------------------------------------------------------------
create table if not exists public.search_synonyms (
  id uuid primary key default gen_random_uuid(),
  term_en text not null,
  term_bn text not null
);
create index if not exists idx_search_synonyms_en on public.search_synonyms (lower(term_en));
create index if not exists idx_search_synonyms_bn on public.search_synonyms (term_bn);

alter table public.search_synonyms enable row level security;

drop policy if exists "search_synonyms_select_all" on public.search_synonyms;
create policy "search_synonyms_select_all"
  on public.search_synonyms for select
  using (true);

-- সাধারণ মার্কেটপ্লেস/ক্যাটাগরি/পণ্যের শব্দভাণ্ডার — শুধুমাত্র তখনই যোগ হবে
-- যদি টেবিলটি খালি থাকে, যাতে বারবার migration রান করলে ডুপ্লিকেট না হয়
insert into public.search_synonyms (term_en, term_bn)
select * from (values
  -- ক্যাটাগরি
  ('fashion', 'ফ্যাশন'),
  ('cloth', 'পোশাক'),
  ('clothes', 'কাপড়'),
  ('electronics', 'ইলেকট্রনিক্স'),
  ('food', 'খাবার'),
  ('grocery', 'মুদি'),
  ('home decor', 'ঘর সাজানো'),
  ('furniture', 'আসবাব'),
  ('health', 'স্বাস্থ্য'),
  ('beauty', 'সৌন্দর্য'),
  ('cosmetics', 'প্রসাধনী'),
  ('books', 'বই'),
  ('stationery', 'স্টেশনারি'),
  -- পোশাক
  ('shirt', 'শার্ট'),
  ('t-shirt', 'টি-শার্ট'),
  ('tshirt', 'টিশার্ট'),
  ('panjabi', 'পাঞ্জাবি'),
  ('punjabi', 'পাঞ্জাবি'),
  ('saree', 'শাড়ি'),
  ('sari', 'শাড়ি'),
  ('three piece', 'থ্রি-পিস'),
  ('pant', 'প্যান্ট'),
  ('pants', 'প্যান্ট'),
  ('trouser', 'ট্রাউজার'),
  ('jeans', 'জিন্স'),
  ('dress', 'জামা'),
  ('kurti', 'কুর্তি'),
  ('lungi', 'লুঙ্গি'),
  ('scarf', 'ওড়না'),
  ('shoe', 'জুতা'),
  ('shoes', 'জুতা'),
  ('sandal', 'স্যান্ডেল'),
  ('bag', 'ব্যাগ'),
  ('watch', 'ঘড়ি'),
  -- ইলেকট্রনিক্স
  ('mobile', 'মোবাইল'),
  ('phone', 'ফোন'),
  ('smartphone', 'স্মার্টফোন'),
  ('charger', 'চার্জার'),
  ('headphone', 'হেডফোন'),
  ('headphones', 'হেডফোন'),
  ('earphone', 'ইয়ারফোন'),
  ('earbuds', 'ইয়ারবাড'),
  ('power bank', 'পাওয়ার ব্যাংক'),
  ('bluetooth', 'ব্লুটুথ'),
  ('speaker', 'স্পিকার'),
  ('television', 'টিভি'),
  ('tv', 'টিভি'),
  ('fan', 'ফ্যান'),
  ('fridge', 'ফ্রিজ'),
  ('refrigerator', 'ফ্রিজ'),
  ('laptop', 'ল্যাপটপ'),
  ('camera', 'ক্যামেরা'),
  ('cable', 'ক্যাবল'),
  -- খাবার ও মুদি
  ('rice', 'চাল'),
  ('oil', 'তেল'),
  ('sugar', 'চিনি'),
  ('salt', 'লবণ'),
  ('tea', 'চা'),
  ('spice', 'মসলা'),
  ('spices', 'মসলা'),
  ('honey', 'মধু'),
  ('snack', 'নাস্তা'),
  ('snacks', 'নাস্তা'),
  ('sweets', 'মিষ্টি'),
  -- ঘর সাজানো
  ('curtain', 'পর্দা'),
  ('lamp', 'বাতি'),
  ('light', 'লাইট'),
  ('carpet', 'কার্পেট'),
  ('rug', 'গালিচা'),
  ('showpiece', 'শোপিস'),
  ('vase', 'ফুলদানি'),
  -- স্বাস্থ্য ও সৌন্দর্য
  ('cream', 'ক্রিম'),
  ('soap', 'সাবান'),
  ('perfume', 'সুগন্ধি'),
  ('lipstick', 'লিপস্টিক'),
  ('shampoo', 'শ্যাম্পু'),
  ('oil hair', 'চুলের তেল'),
  ('medicine', 'ওষুধ'),
  -- বই ও স্টেশনারি
  ('book', 'বই'),
  ('notebook', 'খাতা'),
  ('pen', 'কলম'),
  ('pencil', 'পেন্সিল'),
  ('bag school', 'স্কুল ব্যাগ'),
  ('toy', 'খেলনা'),
  ('toys', 'খেলনা')
) as v(term_en, term_bn)
where not exists (select 1 from public.search_synonyms limit 1);


-- ================= SOURCE MERGE: 0012_cms_settings.sql =================
-- ============================================================
-- Super Admin CMS — Social Links & Announcement Bar
-- Run this in Supabase SQL Editor (or via `supabase db push`)
--
-- এই মাইগ্রেশনটি সম্পূর্ণরূপে সংযোজনমূলক (additive) — বিদ্যমান কোনো টেবিল,
-- কলাম, পলিসি পরিবর্তন বা মোছা হয় না। তাই আগের সব ফিচার (products, shops,
-- banners, site_settings ইত্যাদি) আগের মতোই কাজ করবে।
--
-- বাকি CMS ফিল্ডগুলো (লোগো, সাইটের নাম, মটো, হিরো সেকশন, About Us,
-- Contact Info, Privacy Policy, Terms & Conditions, Footer Content,
-- SEO মেটা, Favicon) বিদ্যমান key-value `public.site_settings` টেবিলেই
-- সংরক্ষিত হয় (0001_init.sql এ ইতিমধ্যে তৈরি), নতুন কোনো টেবিল দরকার নেই।
-- ============================================================

-- ------------------------------------------------------------
-- 1. social_links — একাধিক সোশ্যাল মিডিয়া লিংক (Add/Edit/Delete)
-- ------------------------------------------------------------
create table if not exists public.social_links (
  id uuid primary key default gen_random_uuid(),
  platform text not null,        -- যেমন: facebook, instagram, youtube, whatsapp, tiktok, custom
  label text,                    -- কাস্টম প্ল্যাটফর্মের জন্য ঐচ্ছিক ডিসপ্লে নাম
  url text not null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_social_links_sort on public.social_links (sort_order);

-- ------------------------------------------------------------
-- 2. announcements — নোটিশ / অ্যানাউন্সমেন্ট বার (Add/Edit/Delete)
-- ------------------------------------------------------------
create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  message text not null,
  link_text text,
  link_url text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_announcements_sort on public.announcements (sort_order);

-- ------------------------------------------------------------
-- 3. updated_at অটো-আপডেট ট্রিগার (দুই টেবিলের জন্যই)
-- ------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_social_links_updated_at on public.social_links;
create trigger trg_social_links_updated_at
  before update on public.social_links
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_announcements_updated_at on public.announcements;
create trigger trg_announcements_updated_at
  before update on public.announcements
  for each row execute procedure public.set_updated_at();

-- ------------------------------------------------------------
-- 4. RLS ENABLE
-- ------------------------------------------------------------
alter table public.social_links enable row level security;
alter table public.announcements enable row level security;

-- ------------------------------------------------------------
-- 5. POLICIES — social_links
--    সবাই সক্রিয় লিংক দেখতে পাবে (পাবলিক ফুটার/হেডারে ব্যবহারের জন্য),
--    কিন্তু শুধু Super Admin অ্যাড/এডিট/ডিলিট করতে পারবে।
-- ------------------------------------------------------------
drop policy if exists "social_links_select_active_or_admin" on public.social_links;
create policy "social_links_select_active_or_admin"
  on public.social_links for select
  using (is_active = true or public.is_super_admin());

drop policy if exists "social_links_write_admin" on public.social_links;
create policy "social_links_write_admin"
  on public.social_links for all
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- ------------------------------------------------------------
-- 6. POLICIES — announcements
-- ------------------------------------------------------------
drop policy if exists "announcements_select_active_or_admin" on public.announcements;
create policy "announcements_select_active_or_admin"
  on public.announcements for select
  using (is_active = true or public.is_super_admin());

drop policy if exists "announcements_write_admin" on public.announcements;
create policy "announcements_write_admin"
  on public.announcements for all
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- ------------------------------------------------------------
-- 7. site_settings — নতুন CMS কী-গুলোর জন্য কোনো স্কিমা পরিবর্তন লাগে না
--    (key/value টেবিল), তবে ডকুমেন্টেশনের জন্য প্রত্যাশিত key list:
--
--    site_name, site_motto, site_logo_url, site_favicon_url,
--    hero_title, hero_subtitle, hero_image_url, hero_button_text, hero_button_link,
--    about_us_content,
--    contact_phone, contact_email, contact_whatsapp, footer_address, contact_map_link,
--    privacy_policy_content, terms_conditions_content,
--    footer_content, footer_copyright,
--    seo_meta_title, seo_meta_description, seo_meta_keywords
--
--    এগুলো অ্যাডমিন CMS প্যানেল থেকে upsert (key, value) আকারে সংরক্ষিত হবে।
-- ------------------------------------------------------------


-- ================= SOURCE MERGE: 0013_seller_analytics_indexes.sql =================
-- Seller Analytics dashboard — পারফরম্যান্স ইনডেক্স
-- এই মাইগ্রেশনটা 0010_product_analytics.sql-এর উপর নির্ভরশীল (view_count,
-- save_count, click_count, stock_quantity কলাম আগেই থাকতে হবে)।
-- Idempotent: বারবার রান করলেও সমস্যা নেই।
--
-- কেন দরকার:
-- Seller Analytics পেজ প্রতিবার লোডে ও প্রতিটি realtime আপডেটে
-- `products` টেবিল থেকে `shop_id = ?` দিয়ে ফিল্টার করে, এবং
-- Most Viewed / Most Saved বের করতে view_count ও save_count অনুযায়ী
-- সর্ট করে। নিচের ইনডেক্সগুলো ছাড়া এই কোয়েরিগুলো পণ্যের সংখ্যা
-- বাড়ার সাথে সাথে ধীর হয়ে যাবে (sequential scan)।

-- shop_id দিয়ে ফিল্টার করা সব সেলার-অ্যানালিটিক্স কোয়েরির মূল ভিত্তি
create index if not exists idx_products_shop_id
  on public.products (shop_id);

-- "Most Viewed Products" — shop_id দিয়ে ফিল্টার করে view_count দিয়ে সর্ট
create index if not exists idx_products_shop_view_count
  on public.products (shop_id, view_count desc);

-- "Most Saved Products" — shop_id দিয়ে ফিল্টার করে save_count দিয়ে সর্ট
create index if not exists idx_products_shop_save_count
  on public.products (shop_id, save_count desc);

-- Active vs Out-of-stock গণনা দ্রুত করতে (is_active ও stock_quantity
-- দুটোই সামারি কার্ডে গণনা করা হয়)
create index if not exists idx_products_shop_is_active
  on public.products (shop_id, is_active);

create index if not exists idx_products_shop_stock_quantity
  on public.products (shop_id, stock_quantity);


-- ================= SOURCE MERGE: 0014_super_admin_analytics.sql =================
-- ============================================================
-- Super Admin Analytics Dashboard
-- এই মাইগ্রেশনটি Supabase SQL Editor-এ রান করতে হবে (idempotent, নতুন ও
-- বিদ্যমান উভয় প্রজেক্টেই নিরাপদ)। এটি 0010_product_analytics.sql-এর উপর
-- নির্ভরশীল (view_count/save_count/click_count কলাম আগেই থাকতে হবে)।
--
-- কী যোগ হচ্ছে:
--   - সব দরকারি কলামে ইনডেক্স (created_at, status, view_count, save_count...)
--   - একটি SECURITY DEFINER RPC — `super_admin_analytics_summary()` — যেটা
--     পুরো ড্যাশবোর্ডের সব সংখ্যা এক কলে (single round-trip) জেসন আকারে
--     রিটার্ন করে। সব ভারী কাজ (SUM, COUNT, GROUP BY, TOP-N) ডাটাবেস সাইডে
--     ইনডেক্স ব্যবহার করে হয় — ফ্রন্টএন্ডে শুধু চূড়ান্ত ফলাফল আসে।
--   - শুধুমাত্র Super Admin এই RPC কল করে ডেটা পাবেন (is_super_admin() চেক করে
--     ভেতরেই, নাহলে exception)।
--   - profiles ও seller_verifications টেবিলকে supabase_realtime
--     publication-এ যোগ করা হচ্ছে (products আগে থেকেই আছে) — যাতে ফ্রন্টএন্ড
--     কোনো পরিবর্তন হলেই near-real-time রিফ্রেশ করতে পারে।
-- ============================================================

-- ------------------------------------------------------------
-- 1. পারফরম্যান্স ইনডেক্স
-- ------------------------------------------------------------

-- Total Users / Daily-Weekly-Monthly growth (নতুন ইউজার) দ্রুত গণনার জন্য
create index if not exists idx_profiles_created_at
  on public.profiles (created_at);

-- Total Unverified / Verified Sellers গণনা + growth-এর জন্য
create index if not exists idx_seller_verifications_status
  on public.seller_verifications (status);
create index if not exists idx_seller_verifications_created_at
  on public.seller_verifications (created_at);

-- Total Products / নতুন পণ্যের growth
create index if not exists idx_products_created_at
  on public.products (created_at);

-- Top 10 Most Viewed / Most Saved Products
create index if not exists idx_products_view_count_desc
  on public.products (view_count desc);
create index if not exists idx_products_save_count_desc
  on public.products (save_count desc);

-- Top 10 Sellers (by Order Click) — shop_id দিয়ে গ্রুপ করে click_count যোগ
create index if not exists idx_products_shop_click_count
  on public.products (shop_id, click_count);

-- ------------------------------------------------------------
-- 2. RPC — সম্পূর্ণ Super Admin Analytics সামারি এক কলে
-- ------------------------------------------------------------
create or replace function public.super_admin_analytics_summary()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if not public.is_super_admin() then
    raise exception 'শুধুমাত্র Super Admin এই তথ্য দেখতে পারবেন';
  end if;

  select jsonb_build_object(
    'totals', jsonb_build_object(
      'total_users', (select count(*) from public.profiles),
      'total_unverified_seller_applications',
        (select count(*) from public.seller_verifications where status = 'pending'),
      'total_verified_sellers',
        (select count(*) from public.seller_verifications where status = 'approved'),
      'total_products', (select count(*) from public.products),
      'total_product_views', (select coalesce(sum(view_count), 0) from public.products)
    ),

    -- Top 10 Sellers (by Order Click) — শুধু যাদের অন্তত ১টা ক্লিক আছে
    'top_sellers', (
      select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select
          s.id as shop_id,
          s.shop_name,
          s.slug,
          s.logo_url,
          coalesce(sum(p.click_count), 0) as total_order_clicks
        from public.shops s
        join public.products p on p.shop_id = s.id
        group by s.id, s.shop_name, s.slug, s.logo_url
        having coalesce(sum(p.click_count), 0) > 0
        order by total_order_clicks desc, s.shop_name asc
        limit 10
      ) t
    ),

    -- Top 10 Most Viewed Products
    'top_viewed_products', (
      select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select p.id, p.name, p.slug, p.thumbnail_url, p.view_count, s.shop_name
        from public.products p
        join public.shops s on s.id = p.shop_id
        where p.view_count > 0
        order by p.view_count desc, p.name asc
        limit 10
      ) t
    ),

    -- Top 10 Most Saved Products
    'top_saved_products', (
      select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select p.id, p.name, p.slug, p.thumbnail_url, p.save_count, s.shop_name
        from public.products p
        join public.shops s on s.id = p.shop_id
        where p.save_count > 0
        order by p.save_count desc, p.name asc
        limit 10
      ) t
    ),

    -- Top Categories (পণ্য সংখ্যা অনুযায়ী, টাই হলে মোট ভিউ দিয়ে)
    'top_categories', (
      select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select
          c.id,
          c.name,
          c.slug,
          count(p.id) as product_count,
          coalesce(sum(p.view_count), 0) as total_views
        from public.categories c
        join public.products p on p.category_id = c.id
        group by c.id, c.name, c.slug
        having count(p.id) > 0
        order by product_count desc, total_views desc
        limit 10
      ) t
    ),

    -- Daily / Weekly / Monthly Growth Summary — নতুন ইউজার, নতুন সেলার
    -- আবেদন, নতুন পণ্য (প্রতিটির নিজস্ব created_at অনুযায়ী)
    'growth', jsonb_build_object(
      'daily', jsonb_build_object(
        'new_users', (select count(*) from public.profiles where created_at >= now() - interval '1 day'),
        'new_seller_applications',
          (select count(*) from public.seller_verifications where created_at >= now() - interval '1 day'),
        'new_products', (select count(*) from public.products where created_at >= now() - interval '1 day')
      ),
      'weekly', jsonb_build_object(
        'new_users', (select count(*) from public.profiles where created_at >= now() - interval '7 days'),
        'new_seller_applications',
          (select count(*) from public.seller_verifications where created_at >= now() - interval '7 days'),
        'new_products', (select count(*) from public.products where created_at >= now() - interval '7 days')
      ),
      'monthly', jsonb_build_object(
        'new_users', (select count(*) from public.profiles where created_at >= now() - interval '30 days'),
        'new_seller_applications',
          (select count(*) from public.seller_verifications where created_at >= now() - interval '30 days'),
        'new_products', (select count(*) from public.products where created_at >= now() - interval '30 days')
      )
    )
  ) into result;

  return result;
end;
$$;

grant execute on function public.super_admin_analytics_summary() to authenticated;

-- ------------------------------------------------------------
-- 3. REALTIME — Super Admin Analytics ড্যাশবোর্ড near-real-time রাখার জন্য
--    (products আগে থেকেই যোগ করা আছে 0010 মাইগ্রেশনে)
-- ------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'seller_verifications'
  ) then
    alter publication supabase_realtime add table public.seller_verifications;
  end if;
end $$;


-- ================= SOURCE MERGE: 0015_seller_corrections.sql =================
-- Seller-side সংশোধন — নিচের কলামগুলো যোগ করা হচ্ছে:
--   ১. shops.messenger_link      — সেলারের ডেডিকেটেড Messenger লিংক (Facebook Page
--      লিংক থেকে আলাদা, "Order Now" এর Messenger অপশনে সরাসরি এটাই ব্যবহৃত হবে)
--   ২. products.name_en          — পণ্যের ইংরেজি নাম (সার্চ মেটাডেটা)
--   ৩. products.name_bn          — পণ্যের বাংলা নাম (সার্চ মেটাডেটা)
--   ৪. products.search_keywords  — কমা-দিয়ে-আলাদা সমার্থক শব্দ/কীওয়ার্ড (সার্চ মেটাডেটা)
--
-- Idempotent: বারবার রান করলেও সমস্যা নেই। বিদ্যমান কোনো টেবিল/পলিসি/ডেটা মোছা বা
-- পরিবর্তন করা হয়নি — শুধু নতুন, ঐচ্ছিক (nullable) কলাম যোগ করা হয়েছে।

alter table public.shops
  add column if not exists messenger_link text;

alter table public.products
  add column if not exists name_en text,
  add column if not exists name_bn text,
  add column if not exists search_keywords text;


-- ================= SOURCE MERGE: 0016_seller_verification_history.sql =================
-- ------------------------------------------------------------
-- সেলার ভেরিফিকেশন — আবেদনের ইতিহাস সংরক্ষণ + ব্যবসা-সংক্রান্ত প্রশ্ন
-- ------------------------------------------------------------
-- এই মাইগ্রেশনে যা পরিবর্তন হচ্ছে:
--
--   ১. seller_verifications.user_id থেকে UNIQUE constraint সরানো হচ্ছে,
--      যাতে একজন সেলারের একাধিক (পূর্ববর্তী + বর্তমান) আবেদন সংরক্ষিত থাকতে
--      পারে। আগে upsert(onConflict: user_id) দিয়ে প্রতিটি নতুন সাবমিশন
--      পুরনোটাকে ওভাররাইট করে ফেলত — এখন থেকে প্রতিটি নতুন আবেদন একটি নতুন
--      সারি (row) হিসেবে insert হবে এবং পুরনো আবেদন অপরিবর্তিত থেকে যাবে।
--
--   ২. নতুন ব্যবসা-সংক্রান্ত প্রশ্নের কলাম যোগ করা হচ্ছে (সবই ঐচ্ছিক/nullable,
--      বিদ্যমান কোনো ডেটা প্রভাবিত হয় না)।
--
--   ৩. RLS পলিসি আপডেট করা হচ্ছে:
--      - INSERT: সেলার তখনই নতুন আবেদন জমা দিতে পারবে যখন তার কোনো
--        "pending" আবেদন বিদ্যমান নেই (একসাথে একাধিক pending আবেদন আটকানো)।
--      - UPDATE: সেলার শুধুমাত্র নিজের "pending" অবস্থায় থাকা আবেদন এডিট
--        করতে পারবে — একবার Admin অনুমোদন/প্রত্যাখ্যান করলে সেটি ইতিহাস
--        হিসেবে লক হয়ে যাবে এবং সেলার আর তা পরিবর্তন করতে পারবে না।
--        Admin/Super Admin সবসময় আপডেট করতে পারবেন (status/admin_note সেট
--        করার জন্য)।
--      - DELETE: কোনো পলিসি তৈরি করা হচ্ছে না — অর্থাৎ RLS ডিফল্টভাবে সব
--        ডিলিট আটকে দেবে (সেলার নিজের জমা দেওয়া তথ্য/ছবি কখনো ডিলিট করতে
--        পারবে না, এবং সাধারণ ক্লায়েন্ট থেকে পুরনো আবেদনও মোছা যাবে না)।
--
-- Idempotent: বারবার রান করলেও সমস্যা নেই।

-- ১. UNIQUE constraint সরানো (একই ইউজারের একাধিক আবেদন রাখার জন্য)
alter table public.seller_verifications
  drop constraint if exists seller_verifications_user_id_key;

-- user_id দিয়ে খোঁজার জন্য ইনডেক্স আগে থেকেই আছে (idx_seller_verifications_user),
-- তাই আলাদা করে নতুন ইনডেক্সের দরকার নেই।

-- ২. ব্যবসা-সংক্রান্ত নতুন প্রশ্নের কলাম
alter table public.seller_verifications
  add column if not exists business_type text,
  add column if not exists product_type text,
  add column if not exists avg_monthly_sales_bdt numeric,
  add column if not exists sales_channel text,
  add column if not exists sells_via_facebook_page boolean,
  add column if not exists uses_other_ecommerce_platform boolean,
  add column if not exists other_ecommerce_platform_name text,
  add column if not exists monthly_sales_target_bdt numeric;

-- ৩. INSERT পলিসি — নিজের জন্য, এবং তখনই যখন কোনো pending আবেদন বিদ্যমান নেই
drop policy if exists "seller_verifications_insert_own" on public.seller_verifications;
create policy "seller_verifications_insert_own"
  on public.seller_verifications for insert
  with check (
    user_id = auth.uid()
    and not exists (
      select 1 from public.seller_verifications sv
      where sv.user_id = auth.uid() and sv.status = 'pending'
    )
  );

-- ৪. UPDATE পলিসি — সেলার শুধু নিজের pending আবেদন এডিট করতে পারবে,
--    Admin/Super Admin সবসময় করতে পারবেন
drop policy if exists "seller_verifications_update_own_or_admin" on public.seller_verifications;
create policy "seller_verifications_update_own_or_admin"
  on public.seller_verifications for update
  using (
    (user_id = auth.uid() and status = 'pending')
    or public.is_admin_or_above()
  )
  with check (
    (user_id = auth.uid() and status = 'pending')
    or public.is_admin_or_above()
  );


-- ================= SOURCE MERGE: 0017_hide_deactivated_seller_content.sql =================
-- ------------------------------------------------------------
-- সেলার ডিঅ্যাক্টিভেশন — দোকান ও পণ্য ভিজিটরদের কাছ থেকে সম্পূর্ণ লুকানো
-- ------------------------------------------------------------
-- সমস্যা: Admin যখন কোনো সেলারের অ্যাকাউন্ট ডিঅ্যাক্টিভেট/ব্যান করেন
-- (profiles.account_status = 'banned'), তখন shops.is_active এবং
-- products.is_active কলাম স্বয়ংক্রিয়ভাবে পরিবর্তন হয় না। ফলে আগের RLS
-- পলিসিতে (যা শুধু is_active চেক করত) সেলারের দোকান ও পণ্য ভিজিটরদের
-- কাছে দৃশ্যমানই থেকে যেত — হোমপেজ, সার্চ, ক্যাটাগরি, Related Products,
-- দোকানের পেজ, সরাসরি পণ্যের লিংক, সেভ করা তালিকা — সব জায়গাতেই।
--
-- সমাধান: public visibility-এর SELECT পলিসিতে এখন থেকে দোকানের মালিকের
-- (owner) profiles.account_status = 'active' কিনা তাও যাচাই করা হয়। এটি
-- ডাটাবেস/RLS লেভেলে প্রয়োগ করা হচ্ছে, তাই কোনো ফ্রন্টএন্ড কোড এড়িয়ে সরাসরি
-- API/query দিয়েও ডিঅ্যাক্টিভেটেড সেলারের দোকান/পণ্য দেখা সম্ভব হবে না।
--
-- গুরুত্বপূর্ণ:
--   - সেলার বা তার পণ্য কোনোটাই ডিলিট হচ্ছে না — শুধু ভিজিটরদের কাছ থেকে
--     লুকানো হচ্ছে।
--   - সেলার নিজে (owner_id = auth.uid()) এবং Admin/Super Admin
--     (is_admin_or_above()) — উভয়েই সবসময় দোকান/পণ্য দেখতে পারবেন,
--     account_status নির্বিশেষে।
--   - Admin যখন সেলারকে আবার Active করবেন, তখন এই একই শর্ত (account_status
--     = 'active') আবার সত্যি হয়ে যাবে বলে দোকান/পণ্য স্বয়ংক্রিয়ভাবে আবার
--     দৃশ্যমান হয়ে যাবে — কোনো অতিরিক্ত কাজ লাগবে না।
--
-- Idempotent: বারবার রান করলেও সমস্যা নেই।

-- ------------------------------------------------------------
-- 1. shops — পাবলিক SELECT পলিসি
-- ------------------------------------------------------------
drop policy if exists "shops_select_public_active" on public.shops;
create policy "shops_select_public_active"
  on public.shops for select
  using (
    (
      is_active = true
      and exists (
        select 1 from public.profiles p
        where p.id = shops.owner_id and p.account_status = 'active'
      )
    )
    or owner_id = auth.uid()
    or public.is_admin_or_above()
  );

-- ------------------------------------------------------------
-- 2. products — পাবলিক SELECT পলিসি (হোমপেজ, সার্চ, ক্যাটাগরি, Related
--    Products, দোকানের পেজ, সরাসরি পণ্যের লিংক, সেভ করা তালিকা — সবই এই
--    একটি পলিসির উপর নির্ভর করে)
-- ------------------------------------------------------------
drop policy if exists "products_select_public_active" on public.products;
create policy "products_select_public_active"
  on public.products for select
  using (
    (
      is_active = true
      and exists (
        select 1 from public.shops s
        join public.profiles p on p.id = s.owner_id
        where s.id = products.shop_id and p.account_status = 'active'
      )
    )
    or public.is_admin_or_above()
    or exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid())
  );

-- ------------------------------------------------------------
-- 3. product_images — পণ্যের ছবি (product page-এ যা দেখানো হয়)
-- ------------------------------------------------------------
drop policy if exists "product_images_select" on public.product_images;
create policy "product_images_select"
  on public.product_images for select
  using (
    public.is_admin_or_above()
    or exists (
      select 1 from public.products pr
      join public.shops s on s.id = pr.shop_id
      join public.profiles p on p.id = s.owner_id
      where pr.id = product_id
        and (
          (pr.is_active = true and p.account_status = 'active')
          or s.owner_id = auth.uid()
        )
    )
  );

-- ------------------------------------------------------------
-- 4. shop_gallery — দোকানের গ্যালারি (দোকানের পেজে দেখানো হয়)
-- ------------------------------------------------------------
drop policy if exists "shop_gallery_select" on public.shop_gallery;
create policy "shop_gallery_select"
  on public.shop_gallery for select
  using (
    public.is_admin_or_above()
    or exists (
      select 1 from public.shops s
      join public.profiles p on p.id = s.owner_id
      where s.id = shop_id
        and (
          (s.is_active = true and p.account_status = 'active')
          or s.owner_id = auth.uid()
        )
    )
  );


-- ================= SOURCE MERGE: 0018_super_admin_singleton.sql =================
-- ============================================================
-- Super Admin Singleton Enforcement
-- এই মাইগ্রেশনটি Supabase SQL Editor-এ রান করতে হবে (idempotent, নতুন ও
-- বিদ্যমান উভয় প্রজেক্টেই নিরাপদ)।
--
-- প্রেক্ষাপট: 0007_super_admin_lockout_fix.sql ইতিমধ্যে নিশ্চিত করে যে
-- সিস্টেম থেকে *শেষ* Super Admin-কে কখনো সরানো/ডিমোট করা যায় না (অন্তত ১
-- জন সবসময় থাকবেন)। কিন্তু এতদিন প্রযুক্তিগতভাবে বিদ্যমান Super Admin
-- (via role-change UI) অন্য কোনো ইউজারকে দ্বিতীয় Super Admin বানাতে
-- পারতেন। এই মাইগ্রেশন সেটা বন্ধ করে — এখন থেকে সিস্টেমে সবসময় ঠিক ১ জনই
-- (exactly one) Super Admin থাকবেন, তার বেশি না।
--
-- এই মাইগ্রেশন যা করে:
--   - prevent_self_role_change() ফাংশনে একটি নতুন হার্ড-ইনভ্যারিয়েন্ট চেক
--     যোগ করা হলো: কোনো authenticated অ্যাপ-অ্যাকশন (Super Admin নিজে সহ)
--     আর কাউকে role = 'super_admin'-এ প্রমোট করতে পারবে না।
--   - bootstrap flow (README ধাপ ৫ — Supabase SQL Editor থেকে প্রথম Super
--     Admin ম্যানুয়ালি বানানো, postgres/supabase_admin/service_role
--     হিসেবে) অপরিবর্তিত থাকছে — সেই bypass আগে থেকেই বিদ্যমান এবং এই
--     নতুন চেকের আগেই রান হয়।
--   - যে row-টা ইতিমধ্যে super_admin, সেটাকে আবার super_admin সেট করলে
--     (no-op / অন্য কলাম আপডেট) কোনো সমস্যা হয় না — শুধু *নতুন* কাউকে
--     super_admin বানানো ব্লক করা হচ্ছে।
--   - শেষ Super Admin-কে ডিমোট/ব্যান করা যাবে না — এই সুরক্ষা (0007-এ
--     যোগ হওয়া) অপরিবর্তিত থাকছে, ফলে মিলিয়ে সিস্টেমে সবসময় ঠিক ১ জনই
--     Super Admin থাকবেন — বেশিও না, কমও না।
--
-- বিদ্যমান ডেটা, টেবিল স্ট্রাকচার, RLS পলিসি বা অন্য কোনো ফিচার এখানে
-- পরিবর্তন করা হয়নি।
-- ============================================================

create or replace function public.prevent_self_role_change()
returns trigger
language plpgsql
as $$
begin
  -- Edge Function / service_role থেকে হওয়া পরিবর্তন এবং Supabase Dashboard
  -- SQL Editor থেকে সরাসরি রান করা কমান্ড (postgres/supabase_admin) সবসময়
  -- অনুমোদিত — নাহলে প্রথম Super Admin বানানোর SQL-ই ব্লক হয়ে যাবে
  -- (bootstrapping সমস্যা)।
  if current_user in ('service_role', 'postgres', 'supabase_admin') then
    return new;
  end if;

  -- ============================================================
  -- NEW: সিস্টেমে সবসময় ঠিক ১ জনই (exactly one) Super Admin থাকবেন —
  -- অ্যাপের ভেতর থেকে (Super Admin নিজে সহ) আর কাউকে নতুন করে
  -- super_admin-এ প্রমোট করা যাবে না। ইতিমধ্যে super_admin এমন row-এ কোনো
  -- no-op আপডেট (role অপরিবর্তিত রেখে অন্য কলাম বদলানো) প্রভাবিত হয় না।
  -- ============================================================
  if new.role = 'super_admin' and old.role is distinct from 'super_admin' then
    raise exception 'সিস্টেমে সবসময় ঠিক একজনই সর্বোচ্চ-পর্যায়ের Admin থাকবেন — নতুন কাউকে এই লেভেলে উন্নীত করা যাবে না।';
  end if;

  -- সিস্টেমে অন্তত ১ জন Super Admin সবসময় থাকতেই হবে — এই চেক কোনো
  -- bypass ছাড়াই সবার জন্য (service_role/postgres সহ) প্রযোজ্য, কারণ এটা
  -- একটা hard invariant, permission check না। (0007 থেকে অপরিবর্তিত)
  if old.role = 'super_admin'
     and new.role is distinct from 'super_admin'
     and public.count_super_admins() <= 1
  then
    raise exception 'সিস্টেমে অন্তত একজন Super Admin থাকতেই হবে — শেষ Super Admin-এর role পরিবর্তন করা যাবে না।';
  end if;

  if old.role = 'super_admin'
     and new.account_status = 'banned'
     and old.account_status is distinct from 'banned'
     and public.count_super_admins() <= 1
  then
    raise exception 'সিস্টেমে অন্তত একজন Super Admin থাকতেই হবে — শেষ Super Admin-কে ব্যান করা যাবে না।';
  end if;

  -- নিজের role/seller_status/account_status নিজে বদলানো ব্লক (Super Admin ও RPC bypass বাদে)
  if auth.uid() = old.id
     and not public.is_super_admin()
     and coalesce(current_setting('app.bypass_role_guard', true), 'false') <> 'true'
  then
    if new.role is distinct from old.role
       or new.seller_status is distinct from old.seller_status
       or new.account_status is distinct from old.account_status
    then
      raise exception 'role, seller_status এবং account_status নিজে পরিবর্তন করা যাবে না';
    end if;
  end if;

  -- role বা account_status বদলানো (যে কারো জন্যই) — শুধুমাত্র Super Admin পারবেন
  if (new.role is distinct from old.role or new.account_status is distinct from old.account_status)
     and not public.is_super_admin()
  then
    raise exception 'শুধুমাত্র Super Admin ইউজার role বা account status পরিবর্তন করতে পারবেন।';
  end if;

  return new;
end;
$$;

-- trigger আগে থেকেই profiles টেবিলে attach করা আছে — শুধু function replace
-- করলেই যথেষ্ট, trigger পুনরায় তৈরির দরকার নেই।

-- ============================================================
-- রান করার পর যাচাই করুন:
--   select count(*) from public.profiles where role = 'super_admin';
-- ফলাফল অবশ্যই ১ হতে হবে।
-- ============================================================


-- ================= SOURCE MERGE: 0020_fix_seller_visibility_rls.sql =================
-- ------------------------------------------------------------
-- FIX: Active/Approved Seller-দের Shop/Product ভুলভাবে সবার কাছে লুকানো
--      থাকার bug (root cause fix — শুধু frontend workaround নয়)
-- ------------------------------------------------------------
-- আসল কারণ (root cause):
--   0017_hide_deactivated_seller_content.sql-এ shops/products/product_images/
--   shop_gallery-এর public SELECT পলিসিতে সরাসরি এভাবে লেখা ছিল:
--
--     exists (
--       select 1 from public.profiles p
--       where p.id = shops.owner_id and p.account_status = 'active'
--     )
--
--   এই subquery টা "security definer" নয় — এটা যে ইউজার query চালাচ্ছে
--   (visitor/buyer) তার নিজের permission দিয়েই চলে, এবং তাই profiles
--   টেবিলের নিজের RLS পলিসি (profiles_select_own_or_admin, যেটা শুধু
--   নিজের row বা admin-কে দেখতে দেয়) এখানেও প্রযোজ্য হয়ে যায়।
--
--   ফলে একজন সাধারণ ভিজিটর (যে profiles টেবিলে নিজের কোনো matching row
--   নেই বা admin না) কখনোই সেলারের profiles row দেখতে পারত না — তাই
--   EXISTS(...) সবসময় false রিটার্ন করত, সেলার আসলে active থাকলেও।
--   এই কারণেই active/approved সেলারদের shop ও product হোমপেজ, সার্চ,
--   ক্যাটাগরি, Related Products, Shop page, direct product link — সব
--   জায়গা থেকেই হাওয়া হয়ে যাচ্ছিল।
--
-- সমাধান:
--   is_admin_or_above()-এর মতোই একটা "security definer" helper function
--   public.is_seller_account_active(uuid) বানানো হলো, যেটা RLS বাইপাস করে
--   শুধু একটা boolean রিটার্ন করে (কোনো sensitive profile data expose করে
--   না)। এই function টাই এখন shops/products/product_images/shop_gallery
--   পলিসিতে ব্যবহার হবে, inline subquery-র বদলে।
--
-- এই ফিক্সে:
--   - কোনো ডেটা ডিলিট/পরিবর্তন হচ্ছে না
--   - কোনো seller/admin permission পরিবর্তন হচ্ছে না
--   - deactivated (account_status = 'banned') সেলারদের shop/product
--     এখনও ঠিক আগের মতোই লুকানো থাকবে
--   - শুধু active সেলারদের ক্ষেত্রে ভুলভাবে hide হয়ে যাওয়াটা ঠিক হচ্ছে
--
-- Idempotent: বারবার রান করলেও সমস্যা নেই।

-- ------------------------------------------------------------
-- 1. HELPER — একটি owner_id-এর account_status = 'active' কিনা, RLS বাইপাস
--    করে নিরাপদে চেক করার জন্য (শুধু boolean রিটার্ন করে, কোনো row/column
--    data expose করে না)
-- ------------------------------------------------------------
create or replace function public.is_seller_account_active(p_owner_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = p_owner_id and account_status = 'active'
  );
$$;

-- ------------------------------------------------------------
-- 2. shops — পাবলিক SELECT পলিসি (fixed)
-- ------------------------------------------------------------
drop policy if exists "shops_select_public_active" on public.shops;
create policy "shops_select_public_active"
  on public.shops for select
  using (
    (
      is_active = true
      and public.is_seller_account_active(owner_id)
    )
    or owner_id = auth.uid()
    or public.is_admin_or_above()
  );

-- ------------------------------------------------------------
-- 3. products — পাবলিক SELECT পলিসি (fixed) — হোমপেজ, সার্চ, ক্যাটাগরি,
--    Related Products, দোকানের পেজ, সরাসরি পণ্যের লিংক — সবই এই একটি
--    পলিসির উপর নির্ভর করে
-- ------------------------------------------------------------
drop policy if exists "products_select_public_active" on public.products;
create policy "products_select_public_active"
  on public.products for select
  using (
    (
      is_active = true
      and exists (
        select 1 from public.shops s
        where s.id = products.shop_id
          and public.is_seller_account_active(s.owner_id)
      )
    )
    or public.is_admin_or_above()
    or exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid())
  );

-- ------------------------------------------------------------
-- 4. product_images — পণ্যের ছবি (fixed)
-- ------------------------------------------------------------
drop policy if exists "product_images_select" on public.product_images;
create policy "product_images_select"
  on public.product_images for select
  using (
    public.is_admin_or_above()
    or exists (
      select 1 from public.products pr
      join public.shops s on s.id = pr.shop_id
      where pr.id = product_id
        and (
          (pr.is_active = true and public.is_seller_account_active(s.owner_id))
          or s.owner_id = auth.uid()
        )
    )
  );

-- ------------------------------------------------------------
-- 5. shop_gallery — দোকানের গ্যালারি (fixed)
-- ------------------------------------------------------------
drop policy if exists "shop_gallery_select" on public.shop_gallery;
create policy "shop_gallery_select"
  on public.shop_gallery for select
  using (
    public.is_admin_or_above()
    or exists (
      select 1 from public.shops s
      where s.id = shop_id
        and (
          (s.is_active = true and public.is_seller_account_active(s.owner_id))
          or s.owner_id = auth.uid()
        )
    )
  );


-- ================= SOURCE MERGE: 0021_visitor_profile_fields.sql =================
-- ============================================================
-- 0021: Visitor Profile — gender ও avatar_url যোগ + avatar storage bucket
-- ============================================================
-- উদ্দেশ্য: নতুন "প্রোফাইল" পেজে ইউজার নিজের নাম, ফোন, জেন্ডার এবং
-- প্রোফাইল ছবি (avatar) সেট করতে পারবে। বিদ্যমান profiles টেবিলের
-- structure/RLS/trigger-এ কোনো ভাঙচুর হয় না — শুধু দুটো nullable কলাম
-- এবং একটি নতুন storage bucket যোগ করা হচ্ছে। বিদ্যমান
-- "profiles_update_own" পলিসি (auth.uid() = id) স্বয়ংক্রিয়ভাবেই এই
-- নতুন কলাম দুটোতেও প্রযোজ্য হবে — role/seller_status ছাড়া অন্য কোনো
-- কলাম সেলফ-আপডেট ব্লক করা নেই।

alter table public.profiles
  add column if not exists gender text check (gender in ('male', 'female', 'other')),
  add column if not exists avatar_url text;

-- ------------------------------------------------------------
-- Storage bucket: user-avatars (folder-per-user কনভেনশন: <user_id>/filename.jpg)
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('user-avatars', 'user-avatars', true)
on conflict (id) do nothing;

create policy "public_read_user_avatars"
  on storage.objects for select
  using (bucket_id = 'user-avatars');

create policy "authenticated_upload_own_avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'user-avatars'
    and auth.role() = 'authenticated'
  );

create policy "authenticated_update_own_avatar"
  on storage.objects for update
  using (
    bucket_id = 'user-avatars'
    and auth.role() = 'authenticated'
  );

create policy "authenticated_delete_own_avatar"
  on storage.objects for delete
  using (
    bucket_id = 'user-avatars'
    and auth.role() = 'authenticated'
  );



-- ============================================================
-- DOCTOR V1 FINAL NORMALIZATION
-- ============================================================

-- 1) Final role set: one highest-power Super Admin, normal Admin, Doctor, Patient.
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('patient', 'doctor', 'admin', 'super_admin'));

-- New account defaults for fresh signups.
alter table public.profiles alter column role set default 'patient';

-- Keep the existing legacy seller_status column internally so the converted
-- frontend can be migrated safely without renaming the underlying schema.
-- It is used as Doctor application status in V1.
alter table public.profiles drop constraint if exists profiles_seller_status_check;
alter table public.profiles
  add constraint profiles_seller_status_check
  check (seller_status in ('none', 'pending', 'approved', 'rejected'));

-- 2) Final role/security helpers.
create or replace function public.is_admin_or_above()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','super_admin'));
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'super_admin');
$$;

-- A normal user can never self-promote or change account status.
-- Only Super Admin can change role/account_status. SQL/service-role can bootstrap
-- the first Super Admin.
create or replace function public.prevent_self_role_change()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.role='super_admin' and old.role is distinct from 'super_admin' and public.count_super_admins() >= 1 then
    raise exception 'Only one Super Admin is allowed.';
  end if;
  if old.role='super_admin' and new.role is distinct from 'super_admin' and public.count_super_admins() <= 1 then
    raise exception 'The last Super Admin cannot be demoted.';
  end if;
  if old.role='super_admin' and new.account_status='banned' and old.account_status is distinct from 'banned' and public.count_super_admins() <= 1 then
    raise exception 'The last Super Admin cannot be banned.';
  end if;
  if current_user in ('service_role','postgres','supabase_admin') then return new; end if;
  if auth.uid()=old.id and not public.is_super_admin() and coalesce(current_setting('app.bypass_role_guard',true),'false')<>'true' then
    if new.role is distinct from old.role or new.seller_status is distinct from old.seller_status or new.account_status is distinct from old.account_status then
      raise exception 'Role, Doctor status and account status cannot be changed by yourself.';
    end if;
  end if;
  if (new.role is distinct from old.role or new.account_status is distinct from old.account_status) and not public.is_super_admin() then
    raise exception 'Only Super Admin can change user role or account status.';
  end if;
  return new;
end;
$$;

-- 3) Doctor application RPC. Kept under the legacy function name too so no
--    half-converted frontend call can accidentally break during Step 3.
create or replace function public.request_doctor_status()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('app.bypass_role_guard','true',true);
  update public.profiles
  set role='doctor', seller_status='pending'
  where id=auth.uid() and seller_status='none';
end;
$$;
grant execute on function public.request_doctor_status() to authenticated;

create or replace function public.request_seller_status()
returns void
language plpgsql
security definer
set search_path = public
as $$ begin perform public.request_doctor_status(); end; $$;
grant execute on function public.request_seller_status() to authenticated;

-- 4) Profile policies — Admin can read/manage normal profile fields; role and
--    account_status remain protected by the trigger above.
drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin" on public.profiles for select
using (auth.uid()=id or public.is_admin_or_above());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update
using (auth.uid()=id) with check (auth.uid()=id);

drop policy if exists "profiles_update_admin" on public.profiles;
create policy "profiles_update_admin" on public.profiles for update
using (public.is_admin_or_above()) with check (public.is_admin_or_above());

-- 5) Doctor profile = exactly one existing Product row per Doctor.
--    The existing products table is intentionally reused internally.
create or replace function public.enforce_product_limit()
returns trigger
language plpgsql
as $$
declare
  current_count int;
  v_doctor_id uuid;
begin
  v_doctor_id := new.doctor_id;
  if v_doctor_id is null then
    select s.owner_id into v_doctor_id from public.shops s where s.id=new.shop_id;
  end if;
  select count(*) into current_count from public.products p where p.doctor_id=v_doctor_id;
  if current_count >= 1 then
    raise exception 'A Doctor can publish only one Doctor Profile.';
  end if;
  return new;
end;
$$;

-- 6) Doctor-specific fields stored on the existing product row.
alter table public.products
  add column if not exists degree text,
  add column if not exists designation text,
  add column if not exists bmdc_registration_no text,
  add column if not exists consultation_fee numeric(12,2),
  add column if not exists visiting_days text,
  add column if not exists visiting_time text,
  add column if not exists profile_photo_url text,
  add column if not exists verified_badge boolean not null default false;

-- 7) Chamber-specific fields stored on the existing shop row.
alter table public.shops
  add column if not exists chamber_name text,
  add column if not exists chamber_type text,
  add column if not exists visiting_days text,
  add column if not exists visiting_time text,
  add column if not exists consultation_fee numeric(12,2),
  add column if not exists assistant_phone text;

-- 8) One Doctor Profile per Doctor at DB level.
alter table public.products add column if not exists doctor_id uuid references public.profiles(id) on delete cascade;
create or replace function public.set_product_doctor_id()
returns trigger language plpgsql as $$
begin
  if new.doctor_id is null then select s.owner_id into new.doctor_id from public.shops s where s.id=new.shop_id; end if;
  if new.doctor_id is null then raise exception 'A Doctor-owned Chamber is required.'; end if;
  if not exists(select 1 from public.profiles p where p.id=new.doctor_id and p.role='doctor') then raise exception 'Only a Doctor account can publish a Doctor Profile.'; end if;
  return new;
end;
$$;
drop trigger if exists trg_set_product_doctor_id on public.products;
create trigger trg_set_product_doctor_id before insert on public.products for each row execute procedure public.set_product_doctor_id();
create unique index if not exists ux_one_doctor_profile_per_owner on public.products(doctor_id);

-- 9) Doctor verification: retain existing table/storage internally, but add V1-specific
--    fields. Multiple historical applications remain supported.
alter table public.seller_verifications
  add column if not exists degree text,
  add column if not exists specialty text,
  add column if not exists designation text,
  add column if not exists bmdc_registration_no text,
  add column if not exists bmdc_document_url text,
  add column if not exists chamber_name text,
  add column if not exists chamber_address text,
  add column if not exists visiting_days text,
  add column if not exists visiting_time text,
  add column if not exists consultation_fee numeric(12,2);

-- 10) Specialty / medical category seed. Remove marketplace categories from the new DB.
delete from public.categories;
insert into public.categories (name, slug, sort_order) values
('Medicine','medicine',1),
('Cardiology','cardiology',2),
('Neurology','neurology',3),
('Ophthalmology','ophthalmology',4),
('Dentistry','dentistry',5),
('Orthopedics','orthopedics',6),
('Gynecology & Obstetrics','gynecology-obstetrics',7),
('Pediatrics','pediatrics',8),
('Dermatology','dermatology',9),
('ENT','ent',10),
('Psychiatry','psychiatry',11),
('Urology','urology',12),
('General Surgery','general-surgery',13),
('Nephrology','nephrology',14),
('Gastroenterology','gastroenterology',15),
('Pulmonology','pulmonology',16),
('Oncology','oncology',17),
('Endocrinology','endocrinology',18),
('Radiology','radiology',19),
('Anesthesiology','anesthesiology',20)
on conflict (slug) do nothing;

-- 11) Appointment system — replaces marketplace Orders for V1.
create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  appointment_number text not null unique,
  doctor_id uuid not null references public.profiles(id) on delete cascade,
  patient_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  shop_id uuid references public.shops(id) on delete set null,
  doctor_name text not null,
  patient_name text,
  patient_phone text,
  chamber_name text,
  appointment_date date not null,
  appointment_time text,
  note text,
  status text not null default 'pending' check (status in ('pending','confirmed','cancelled','completed','rescheduled')),
  doctor_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Public Doctor/Chamber visibility requires an active, approved Doctor.
create or replace function public.is_doctor_account_public(p_owner_id uuid)
returns boolean language sql security definer set search_path=public stable as $$
  select exists(select 1 from public.profiles where id=p_owner_id and role='doctor' and seller_status='approved' and account_status='active');
$$;

drop policy if exists "shops_select_public_active" on public.shops;
create policy "shops_select_public_active" on public.shops for select using
  ((is_active=true and public.is_doctor_account_public(owner_id)) or owner_id=auth.uid() or public.is_admin_or_above());
drop policy if exists "shops_insert_approved_seller" on public.shops;
create policy "shops_insert_approved_seller" on public.shops for insert with check
  (owner_id=auth.uid() and exists(select 1 from public.profiles where id=auth.uid() and role='doctor' and seller_status='approved' and account_status='active'));
drop policy if exists "shops_update_own_or_admin" on public.shops;
create policy "shops_update_own_or_admin" on public.shops for update using(owner_id=auth.uid() or public.is_admin_or_above()) with check(owner_id=auth.uid() or public.is_admin_or_above());
drop policy if exists "shops_delete_admin" on public.shops;
create policy "shops_delete_admin" on public.shops for delete using(public.is_admin_or_above());

drop policy if exists "products_select_public_active" on public.products;
create policy "products_select_public_active" on public.products for select using
  ((is_active=true and public.is_doctor_account_public(doctor_id)) or public.is_admin_or_above() or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid()));
drop policy if exists "products_insert_own_shop" on public.products;
create policy "products_insert_own_shop" on public.products for insert with check
  (exists(select 1 from public.shops s join public.profiles p on p.id=s.owner_id where s.id=shop_id and s.owner_id=auth.uid() and p.role='doctor' and p.seller_status='approved' and p.account_status='active'));
drop policy if exists "products_update_own_or_admin" on public.products;
create policy "products_update_own_or_admin" on public.products for update using(public.is_admin_or_above() or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())) with check(public.is_admin_or_above() or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid()));
drop policy if exists "products_delete_own_or_admin" on public.products;
create policy "products_delete_own_or_admin" on public.products for delete using(public.is_admin_or_above() or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid()));

drop policy if exists "seller_verifications_insert_own" on public.seller_verifications;
create policy "seller_verifications_insert_own" on public.seller_verifications for insert with check(user_id=auth.uid() and exists(select 1 from public.profiles where id=auth.uid() and role in ('patient','doctor')));

create sequence if not exists public.appointment_number_seq;

create or replace function public.generate_appointment_number()
returns text language sql as $$
  select 'APT-' || to_char(now(),'YYYYMMDD') || '-' || lpad(nextval('public.appointment_number_seq')::text,5,'0');
$$;

create or replace function public.set_appointment_defaults()
returns trigger language plpgsql security definer set search_path=public as $$
declare d record; p record; c record; begin
  if auth.uid() is not null then
    new.patient_id := auth.uid();
  end if;
  if new.patient_id is null then raise exception 'Patient login is required.'; end if;
  select pr.id,pr.full_name,pr.phone into p from public.profiles pr where pr.id=new.patient_id;
  if p.id is null then raise exception 'Patient profile not found.'; end if;
  select pr.id,pr.full_name into d from public.profiles pr where pr.id=new.doctor_id and pr.role='doctor' and pr.account_status='active';
  if d.id is null then raise exception 'Doctor is not active or does not exist.'; end if;
  if new.product_id is not null then
    select s.id,s.shop_name,s.owner_id into c from public.products pr join public.shops s on s.id=pr.shop_id where pr.id=new.product_id and pr.is_active=true;
    if c.id is null or c.owner_id<>new.doctor_id then raise exception 'Invalid Doctor profile.'; end if;
    new.shop_id:=c.id; new.chamber_name:=coalesce(new.chamber_name,c.shop_name);
  elsif new.shop_id is not null then
    select s.id,s.shop_name,s.owner_id into c from public.shops s where s.id=new.shop_id and s.owner_id=new.doctor_id and s.is_active=true;
    if c.id is null then raise exception 'Invalid chamber.'; end if;
    new.chamber_name:=coalesce(new.chamber_name,c.shop_name);
  end if;
  new.appointment_number:='APT-'||to_char(now(),'YYYYMMDD')||'-'||lpad(nextval('public.appointment_number_seq')::text,5,'0');
  new.doctor_name:=d.full_name;
  new.patient_name:=coalesce(nullif(trim(new.patient_name),''),p.full_name);
  new.patient_phone:=coalesce(nullif(trim(new.patient_phone),''),p.phone);
  new.status:='pending'; new.created_at:=now(); new.updated_at:=now();
  return new;
end; $$;

drop trigger if exists trg_appointments_set_defaults on public.appointments;
create trigger trg_appointments_set_defaults before insert on public.appointments for each row execute procedure public.set_appointment_defaults();

create or replace function public.guard_appointment_update()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if current_user in ('service_role','postgres','supabase_admin') then new.updated_at:=now(); return new; end if;
  if not (auth.uid()=old.doctor_id or auth.uid()=old.patient_id or public.is_admin_or_above()) then
    raise exception 'You are not allowed to update this appointment.';
  end if;
  if new.doctor_id<>old.doctor_id or new.patient_id<>old.patient_id or new.product_id is distinct from old.product_id or new.shop_id is distinct from old.shop_id then
    raise exception 'Appointment ownership cannot be changed.';
  end if;
  if auth.uid()=old.patient_id and not public.is_admin_or_above() and new.status not in ('cancelled','pending') then
    raise exception 'Patient can only cancel a pending appointment.';
  end if;
  if auth.uid()=old.doctor_id and not public.is_admin_or_above() and new.status not in ('confirmed','cancelled','completed','rescheduled','pending') then
    raise exception 'Invalid appointment status.';
  end if;
  new.updated_at:=now(); return new;
end; $$;

drop trigger if exists trg_guard_appointment_update on public.appointments;
create trigger trg_guard_appointment_update before update on public.appointments for each row execute procedure public.guard_appointment_update();

alter table public.appointments enable row level security;
drop policy if exists "appointments_select_participant_or_admin" on public.appointments;
create policy "appointments_select_participant_or_admin" on public.appointments for select
using (patient_id=auth.uid() or doctor_id=auth.uid() or public.is_admin_or_above());

drop policy if exists "appointments_insert_patient" on public.appointments;
create policy "appointments_insert_patient" on public.appointments for insert
with check (patient_id=auth.uid());

drop policy if exists "appointments_update_participant_or_admin" on public.appointments;
create policy "appointments_update_participant_or_admin" on public.appointments for update
using (patient_id=auth.uid() or doctor_id=auth.uid() or public.is_admin_or_above())
with check (patient_id=auth.uid() or doctor_id=auth.uid() or public.is_admin_or_above());

create index if not exists idx_appointments_doctor on public.appointments(doctor_id);
create index if not exists idx_appointments_patient on public.appointments(patient_id);
create index if not exists idx_appointments_date on public.appointments(appointment_date);
create index if not exists idx_appointments_status on public.appointments(status);
create index if not exists idx_appointments_created_at on public.appointments(created_at desc);

drop trigger if exists trg_appointments_updated_at on public.appointments;
create trigger trg_appointments_updated_at before update on public.appointments for each row execute procedure public.set_updated_at();

-- 12) Appointment-related public labels/content seed.
insert into public.site_settings(key,value) values
('platform_name','Doctor Platform'),
('platform_motto','Find the right doctor, simply.'),
('homepage_search_placeholder','Search doctor, specialty, disease or location'),
('about_us_content','একটি verified doctor discovery platform, যেখানে রোগীরা সহজে ডাক্তার খুঁজে, প্রোফাইল দেখে এবং appointment request করতে পারবেন।'),
('terms_conditions_content','ডাক্তার ও রোগীর তথ্য সঠিকভাবে ব্যবহার করা এবং platform-এর নিয়ম মেনে চলা প্রত্যেক ব্যবহারকারীর দায়িত্ব।'),
('privacy_policy_content','আপনার account, profile এবং appointment তথ্য platform-এর সেবা প্রদানের উদ্দেশ্যে ব্যবহৃত হবে।')
on conflict(key) do nothing;

-- 13) Search synonym seed for common medical searches.
insert into public.search_synonyms(term_en,term_bn) values
('cardiologist','হার্টের ডাক্তার'),
('ophthalmologist','চোখের ডাক্তার'),
('dentist','দাঁতের ডাক্তার'),
('gynecologist','গাইনি ডাক্তার'),
('pediatrician','শিশু ডাক্তার'),
('neurologist','স্নায়ুর ডাক্তার'),
('orthopedic','হাড়ের ডাক্তার'),
('dermatologist','চর্মরোগের ডাক্তার'),
('ent','নাক কান গলা ডাক্তার')
on conflict do nothing;

-- 14) Explicitly disable old marketplace purchase table if it somehow exists.
-- The consolidated setup intentionally never creates public.orders.

-- 15) Bootstrap note: after creating your first Auth user, run the following ONCE
-- in Supabase SQL Editor with the real user UUID/email.
-- UPDATE public.profiles SET role='super_admin', seller_status='approved'
-- WHERE id=(SELECT id FROM auth.users WHERE email='YOUR_EMAIL');
-- The role guard allows postgres/supabase_admin to perform this bootstrap.

-- ============================================================
-- END — DOCTOR PLATFORM V1 DATABASE SETUP
-- ============================================================

-- ============================================================
-- DOCTOR V1 BRAND + BANGLA CATEGORY SEED
-- ============================================================
insert into public.site_settings(key,value) values
('site_name','সিরাজগঞ্জ ডাক্তার'),
('site_logo_url','/doctor-logo.svg'),
('footer_address','সিরাজগঞ্জ, বাংলাদেশ')
on conflict (key) do update set value=excluded.value;

insert into public.categories(name,slug,icon_url,sort_order) values
('হৃদরোগ','hridrog','/categories/heart.svg',1),
('চক্ষু','chokshu','/categories/eye.svg',2),
('দন্ত চিকিৎসা','donto-chikitsa','/categories/dental.svg',3),
('হাড় ও জয়েন্ট','har-o-joint','/categories/bone.svg',4),
('শিশু রোগ','shishu-rog','/categories/child.svg',5),
('মেডিসিন','medicine','/categories/medicine.svg',6)
on conflict (slug) do update set name=excluded.name, icon_url=excluded.icon_url, sort_order=excluded.sort_order;
