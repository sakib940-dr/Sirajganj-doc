-- ============================================================
-- Migration 0003 — Demo/Seed Data
-- এটি ২টি Demo Seller, তাদের Shop, কিছু Product এবং সাধারণ
-- Category তৈরি করবে — যাতে অ্যাপে চালু অবস্থায় কিছু দেখা যায়।
--
-- এটি শুধুমাত্র Demo/Testing-এর জন্য। Production-এ আসল সেলার
-- যোগ হওয়া শুরু করলে demo.seller1 / demo.seller2 ডিলিট করে দিন।
--
-- Demo Login তথ্য (Test করার জন্য):
--   ইমেইল: demo.seller1@example.com   পাসওয়ার্ড: DemoPass123
--   ইমেইল: demo.seller2@example.com   পাসওয়ার্ড: DemoPass123
-- ============================================================

-- ------------------------------------------------------------
-- 1. সাধারণ ক্যাটাগরি
-- ------------------------------------------------------------
insert into public.categories (name, slug, sort_order) values
  ('ফ্যাশন ও পোশাক', 'fashion', 1),
  ('ইলেকট্রনিক্স', 'electronics', 2),
  ('খাবার ও মুদি', 'food-grocery', 3),
  ('ঘর সাজানো', 'home-decor', 4),
  ('স্বাস্থ্য ও সৌন্দর্য', 'health-beauty', 5),
  ('বই ও স্টেশনারি', 'books-stationery', 6)
on conflict (slug) do nothing;

-- ------------------------------------------------------------
-- 2. Demo Seller অ্যাকাউন্ট তৈরি (সরাসরি auth.users-এ)
-- ------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token
)
select
  '00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated',
  'demo.seller1@example.com', crypt('DemoPass123', gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}',
  '{"full_name":"রহিম স্টোর","phone":"01711000001"}', now(), now(), '', ''
where not exists (select 1 from auth.users where email = 'demo.seller1@example.com');

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token
)
select
  '00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated',
  'demo.seller2@example.com', crypt('DemoPass123', gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}',
  '{"full_name":"করিম ইলেকট্রনিক্স","phone":"01711000002"}', now(), now(), '', ''
where not exists (select 1 from auth.users where email = 'demo.seller2@example.com');

-- উপরের insert-এর ফলে on_auth_user_created trigger স্বয়ংক্রিয়ভাবে
-- profiles টেবিলে রো তৈরি করে দেবে (role='visitor', seller_status='none')

-- ------------------------------------------------------------
-- 3. Demo Seller-দের Approve করা (role + seller_status)
-- ------------------------------------------------------------
update public.profiles
set role = 'seller', seller_status = 'approved'
where email in ('demo.seller1@example.com', 'demo.seller2@example.com');

-- ------------------------------------------------------------
-- 4. Demo Shop তৈরি
-- ------------------------------------------------------------
insert into public.shops (owner_id, shop_name, slug, about, phone, whatsapp_number, address, is_active)
select u.id, 'রহিম স্টোর', 'rahim-store',
  'আমরা মানসম্মত পোশাক ও ফ্যাশন পণ্য নিয়ে কাজ করি। দেশীয় ও আরামদায়ক কাপড়ের সংগ্রহ।',
  '01711000001', '8801711000001', 'নিউ মার্কেট, ঢাকা', true
from auth.users u
where u.email = 'demo.seller1@example.com'
  and not exists (select 1 from public.shops where slug = 'rahim-store');

insert into public.shops (owner_id, shop_name, slug, about, phone, whatsapp_number, address, is_active)
select u.id, 'করিম ইলেকট্রনিক্স', 'karim-electronics',
  'মোবাইল, চার্জার, হেডফোনসহ সব ধরনের ইলেকট্রনিক্স পণ্যের নির্ভরযোগ্য দোকান।',
  '01711000002', '8801711000002', 'গুলিস্তান, ঢাকা', true
from auth.users u
where u.email = 'demo.seller2@example.com'
  and not exists (select 1 from public.shops where slug = 'karim-electronics');

-- ------------------------------------------------------------
-- 5. Demo Product তৈরি — রহিম স্টোর (ফ্যাশন)
-- ------------------------------------------------------------
insert into public.products (shop_id, category_id, name, slug, description, price, is_active)
select s.id, c.id, 'পুরুষদের সুতি পাঞ্জাবি', 'mens-cotton-panjabi',
  'নরম সুতি কাপড়ে তৈরি আরামদায়ক পাঞ্জাবি, সব সাইজে পাওয়া যায়।', 850, true
from public.shops s join public.categories c on c.slug = 'fashion'
where s.slug = 'rahim-store' and not exists (select 1 from public.products where slug = 'mens-cotton-panjabi');

insert into public.products (shop_id, category_id, name, slug, description, price, is_active)
select s.id, c.id, 'মহিলাদের থ্রি-পিস', 'ladies-three-piece',
  'প্রিমিয়াম কাপড়ের নতুন ডিজাইনের থ্রি-পিস।', 1450, true
from public.shops s join public.categories c on c.slug = 'fashion'
where s.slug = 'rahim-store' and not exists (select 1 from public.products where slug = 'ladies-three-piece');

insert into public.products (shop_id, category_id, name, slug, description, price, is_active)
select s.id, c.id, 'বাচ্চাদের টি-শার্ট', 'kids-tshirt',
  'নরম কাপড়ের রঙিন বাচ্চাদের টি-শার্ট, ২-১০ বছর।', 350, true
from public.shops s join public.categories c on c.slug = 'fashion'
where s.slug = 'rahim-store' and not exists (select 1 from public.products where slug = 'kids-tshirt');

-- ------------------------------------------------------------
-- 6. Demo Product তৈরি — করিম ইলেকট্রনিক্স
-- ------------------------------------------------------------
insert into public.products (shop_id, category_id, name, slug, description, price, is_active)
select s.id, c.id, 'ফাস্ট চার্জার ৩৩W', 'fast-charger-33w',
  'অরিজিনাল কোয়ালিটির ফাস্ট চার্জিং অ্যাডাপ্টার।', 650, true
from public.shops s join public.categories c on c.slug = 'electronics'
where s.slug = 'karim-electronics' and not exists (select 1 from public.products where slug = 'fast-charger-33w');

insert into public.products (shop_id, category_id, name, slug, description, price, is_active)
select s.id, c.id, 'ব্লুটুথ হেডফোন', 'bluetooth-headphone',
  'নয়েজ ক্যান্সেলেশনসহ হাই-কোয়ালিটি ব্লুটুথ হেডফোন।', 1200, true
from public.shops s join public.categories c on c.slug = 'electronics'
where s.slug = 'karim-electronics' and not exists (select 1 from public.products where slug = 'bluetooth-headphone');

insert into public.products (shop_id, category_id, name, slug, description, price, is_active)
select s.id, c.id, 'পাওয়ার ব্যাংক ১০০০০mAh', 'power-bank-10000mah',
  'দ্রুত চার্জিং সাপোর্টসহ পোর্টেবল পাওয়ার ব্যাংক।', 1800, true
from public.shops s join public.categories c on c.slug = 'electronics'
where s.slug = 'karim-electronics' and not exists (select 1 from public.products where slug = 'power-bank-10000mah');
