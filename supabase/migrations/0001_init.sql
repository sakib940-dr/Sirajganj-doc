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
