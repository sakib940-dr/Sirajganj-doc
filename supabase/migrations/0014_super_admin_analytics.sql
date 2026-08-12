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
