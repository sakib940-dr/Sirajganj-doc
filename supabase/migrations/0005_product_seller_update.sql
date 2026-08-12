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
