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
