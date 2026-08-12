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
