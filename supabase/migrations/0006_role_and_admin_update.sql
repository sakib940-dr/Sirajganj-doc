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
-- 3. এক-বারের ডাটা মাইগ্রেশন: পুরনো super_admin -> admin
--    (site_settings-এ ফ্ল্যাগ দিয়ে নিশ্চিত করা হচ্ছে এটা শুধু একবারই হয়)
-- ------------------------------------------------------------
do $$
begin
  if not exists (select 1 from public.site_settings where key = 'role_migration_0006_done') then
    update public.profiles set role = 'admin' where role = 'super_admin';
    insert into public.site_settings (key, value) values ('role_migration_0006_done', 'true')
      on conflict (key) do nothing;
  end if;
end $$;

-- ------------------------------------------------------------
-- 4. HELPER — "Admin অথবা তার উপরে" (Admin + Super Admin) কিনা
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
