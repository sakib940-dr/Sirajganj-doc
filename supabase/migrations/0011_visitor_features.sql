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
