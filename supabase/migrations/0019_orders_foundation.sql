-- ============================================================
-- Migration 0019 — Order System: বেসিক ফাউন্ডেশন
-- এই মাইগ্রেশনটি Supabase SQL Editor-এ রান করতে হবে (idempotent, নতুন ও
-- বিদ্যমান উভয় প্রজেক্টেই নিরাপদ)।
--
-- স্কোপ (শুধুমাত্র বেসিক Order System ফাউন্ডেশন):
--   - প্রয়োজনীয় Order ডেটাবেজ স্ট্রাকচার তৈরি করা
--   - প্রতিটা অর্ডারকে সঠিক Buyer, Seller ও Product-এর সাথে সংযুক্ত করা
--   - প্রতিটা অর্ডারের জন্য একটা ইউনিক, মানুষ-পড়তে-পারে এমন Order ID তৈরি
--   - Product, Quantity, Buyer ও Seller তথ্য (snapshot আকারে) সেভ করা
--   - বেসিক Order Status সাপোর্ট (pending → confirmed/cancelled/completed)
--
-- এই মাইগ্রেশনে যা করা হয়নি (ইচ্ছাকৃতভাবে, স্কোপের বাইরে):
--   - Push Notification — এখনো implement করা হয়নি
--   - বিদ্যমান "অর্ডার করুন" (WhatsApp/Messenger/Facebook) বাটন বা
--     src/lib/orderChannels.js, src/components/shared/OrderNowMenu.jsx —
--     এগুলো অপরিবর্তিত রাখা হয়েছে, এই মাইগ্রেশন সেগুলো ছোঁয়নি
--   - stock_quantity/sold_count অটো-ডিক্রিমেন্ট, cart, multi-item checkout,
--     পেমেন্ট — এসব পরবর্তী ধাপের জন্য বাকি রাখা হলো
--
-- বিদ্যমান টেবিল/ডেটা/RLS/অন্য কোনো ফিচার এখানে পরিবর্তন করা হয়নি; শুধু
-- নতুন orders টেবিল ও তার সাপোর্টিং ফাংশন/ট্রিগার/পলিসি যোগ হচ্ছে।
-- ============================================================

-- ------------------------------------------------------------
-- 1. ORDER NUMBER — ইউনিক, মানুষ-পড়তে-পারে এমন Order ID
--    ফরম্যাট: ORD-YYYYMMDD-00001  (দিন অনুযায়ী রিসেট হয় না, চিরস্থায়ীভাবে বাড়তে থাকে)
-- ------------------------------------------------------------
create sequence if not exists public.order_number_seq;

create or replace function public.generate_order_number()
returns text
language sql
as $$
  select 'ORD-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.order_number_seq')::text, 5, '0');
$$;

-- ------------------------------------------------------------
-- 2. TABLE — orders
--    Product/Shop/Buyer-এর তথ্য FK ছাড়াও snapshot কলামে সেভ করা হয়, যাতে
--    ভবিষ্যতে পণ্যের দাম বদলালে বা পণ্য/দোকান ডিলিট হলেও অর্ডার হিস্টোরি ও
--    Seller/Admin-এর রেকর্ড অক্ষত থাকে।
-- ------------------------------------------------------------
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,

  -- Product সংযোগ + snapshot
  product_id uuid references public.products (id) on delete set null,
  product_name text not null,
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  quantity integer not null default 1 check (quantity > 0),
  total_price numeric(12, 2) generated always as (unit_price * quantity) stored,

  -- Seller/Shop সংযোগ + snapshot
  shop_id uuid references public.shops (id) on delete set null,
  shop_name text not null,
  seller_id uuid references public.profiles (id) on delete set null,

  -- Buyer সংযোগ + snapshot
  buyer_id uuid references public.profiles (id) on delete set null,
  buyer_name text,
  buyer_phone text,

  -- বেসিক অর্ডার স্ট্যাটাস
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'cancelled', 'completed')),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_orders_buyer on public.orders (buyer_id);
create index if not exists idx_orders_seller on public.orders (seller_id);
create index if not exists idx_orders_shop on public.orders (shop_id);
create index if not exists idx_orders_product on public.orders (product_id);
create index if not exists idx_orders_status on public.orders (status);
create index if not exists idx_orders_created_at on public.orders (created_at desc);

-- ------------------------------------------------------------
-- 3. TRIGGER — INSERT-এর সময় স্বয়ংক্রিয়ভাবে:
--    - order_number জেনারেট করা
--    - product/shop/seller/buyer-এর সঠিক তথ্য থেকে snapshot বসানো (ক্লায়েন্ট
--      থেকে পাঠানো দাম/নাম বিশ্বাস না করে সার্ভার-সাইডে গণনা করা হয়, যাতে
--      কেউ দাম বা seller_id জালিয়াতি করতে না পারে)
--    - buyer_id সবসময় বর্তমান লগইন-করা ইউজারের সাথে মিলতে বাধ্য করা
--    - status সবসময় 'pending' দিয়ে শুরু হওয়া নিশ্চিত করা
-- ------------------------------------------------------------
-- নোট: এই ফাংশনটি ইচ্ছাকৃতভাবে SECURITY DEFINER না — কারণ SECURITY DEFINER
-- ফাংশনের ভেতরে current_user সবসময় ফাংশনের owner (postgres) দেখাবে, caller-এর
-- আসল role (authenticated/service_role) না — ফলে নিচের bypass-চেক ভুল ফলাফল
-- দিত। SECURITY DEFINER দরকারও নেই: products/shops-এর RLS policy আগে থেকেই
-- public read allow করে, আর buyer শুধু নিজের profile row পড়ে (যেটা
-- profiles_select_own_or_admin পলিসিতে অনুমোদিত)।
-- নোট: এই ফাংশনটি ইচ্ছাকৃতভাবে SECURITY DEFINER — কারণ products/shops-এর
-- বিদ্যমান পাবলিক SELECT পলিসি (0017_hide_deactivated_seller_content.sql)
-- ভেতরে profiles টেবিলের উপর EXISTS সাবকোয়েরি চালায় যাচাই করতে যে
-- seller-এর account_status = 'active' কিনা — কিন্তু profiles টেবিলের নিজের
-- SELECT পলিসি (profiles_select_own_or_admin) শুধু নিজের row বা admin-কেই
-- read করতে দেয়। ফলে একজন সাধারণ buyer (নিজে owner/admin না) RLS-এর
-- আওতায় থেকে অন্য কারো product/shop row লিখিতভাবে SELECT করলে ফলাফল খালি
-- আসে — এটি অর্ডার সিস্টেমের বাইরের একটি বিদ্যমান সীমাবদ্ধতা, এই মাইগ্রেশনে
-- সেই পলিসি বদলানো হয়নি (স্কোপের বাইরে)। তার বদলে এখানে SECURITY DEFINER
-- ব্যবহার করে সরাসরি authoritative ডেটা পড়া হচ্ছে, এবং is_active/account_status
-- এর সমতুল্য নিয়ম ম্যানুয়ালি (নিচে) আবার যাচাই করা হচ্ছে — যাতে নিষ্ক্রিয়/ব্যান
-- হওয়া সেলারের পণ্য অর্ডার করা না যায়। auth.uid() একটি session-level GUC
-- read করে বলে SECURITY DEFINER-এর ভেতরেও এটি সবসময় প্রকৃত caller-কেই
-- ফেরত দেয় (current_user-এর মতো owner-এ পাল্টায় না) — তাই buyer শনাক্তকরণ
-- এখানে auth.uid()-এর উপরেই নির্ভরযোগ্যভাবে করা যায়।
create or replace function public.set_order_defaults()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product record;
  v_shop record;
  v_seller record;
  v_buyer record;
  v_discounted_price numeric(12, 2);
begin
  -- Order ID জেনারেট (ক্লায়েন্ট নিজে থেকে সেট করলেও ওভাররাইড হবে — সবসময়
  -- সার্ভার-জেনারেটেড ইউনিক আইডি ব্যবহার হয়)
  new.order_number := public.generate_order_number();

  -- Buyer শনাক্তকরণ — JWT context থাকলে (API/ফ্রন্টএন্ড থেকে করা যেকোনো
  -- কল) buyer_id জোর করে বর্তমান লগইন-করা ইউজারের সাথে মেলানো হয়, যাতে কেউ
  -- অন্য কারো নামে অর্ডার বসাতে না পারে। JWT না থাকলে (service_role/সরাসরি
  -- SQL/ব্যাকএন্ড স্ক্রিপ্ট থেকে করা trusted কল) ক্লায়েন্টের পাঠানো buyer_id
  -- ব্যবহার করা হয়।
  if auth.uid() is not null then
    new.buyer_id := auth.uid();
  end if;

  if new.buyer_id is null then
    raise exception 'অর্ডার করতে হলে লগইন করা আবশ্যক — buyer শনাক্ত করা যায়নি';
  end if;

  -- Product যাচাই + snapshot (দাম, নাম) — discount থাকলে সেটা হিসেব করে
  -- আসল বিক্রয়মূল্য (front-end getDiscountedPrice()-এর সাথে সামঞ্জস্যপূর্ণ) সেভ করা হয়
  select p.id, p.name, p.price, p.discount_type, p.discount_value, p.shop_id, p.is_active
  into v_product
  from public.products p
  where p.id = new.product_id;

  if v_product.id is null then
    raise exception 'পণ্যটি খুঁজে পাওয়া যায়নি — অর্ডার করা যাবে না';
  end if;

  -- Shop/Seller snapshot — product থেকেই নির্ভরযোগ্যভাবে বের করা হচ্ছে, ক্লায়েন্টের
  -- পাঠানো shop_id/seller_id বিশ্বাস করা হচ্ছে না
  select s.id, s.shop_name, s.owner_id, s.is_active
  into v_shop
  from public.shops s
  where s.id = v_product.shop_id;

  if v_shop.id is null then
    raise exception 'দোকানের তথ্য খুঁজে পাওয়া যায়নি — অর্ডার করা যাবে না';
  end if;

  select pr.account_status into v_seller
  from public.profiles pr
  where pr.id = v_shop.owner_id;

  -- নিষ্ক্রিয় পণ্য / নিষ্ক্রিয় দোকান / ব্যান-করা সেলার — Admin/Super Admin
  -- ছাড়া বাকি সবার জন্য ব্লক (0017-এর "deactivated seller content hidden"
  -- নীতির সাথে সামঞ্জস্যপূর্ণ, শুধু read-visibility না, order-creation লেভেলেও)
  if not public.is_admin_or_above()
     and (
       v_product.is_active is distinct from true
       or v_shop.is_active is distinct from true
       or v_seller.account_status is distinct from 'active'
     )
  then
    raise exception 'এই পণ্যটি বর্তমানে অর্ডারের জন্য উপলব্ধ নয়';
  end if;

  v_discounted_price := v_product.price;
  if coalesce(v_product.discount_type, 'none') = 'percentage' and v_product.discount_value > 0 then
    v_discounted_price := v_product.price - (v_product.price * least(v_product.discount_value, 100) / 100);
  elsif coalesce(v_product.discount_type, 'none') = 'fixed' and v_product.discount_value > 0 then
    v_discounted_price := v_product.price - v_product.discount_value;
  end if;
  v_discounted_price := greatest(0, round(v_discounted_price, 2));

  new.product_name := v_product.name;
  new.unit_price := v_discounted_price;
  new.shop_id := v_shop.id;
  new.shop_name := v_shop.shop_name;
  new.seller_id := v_shop.owner_id;

  -- Buyer-এর নাম/ফোন — প্রোফাইল থেকে ডিফল্ট, তবে buyer আলাদা ডেলিভারি
  -- নাম/ফোন দিয়ে থাকলে সেটা রাখা হয় (coalesce)
  select pr.full_name, pr.phone into v_buyer
  from public.profiles pr
  where pr.id = new.buyer_id;

  new.buyer_name := coalesce(nullif(trim(new.buyer_name), ''), v_buyer.full_name);
  new.buyer_phone := coalesce(nullif(trim(new.buyer_phone), ''), v_buyer.phone);

  -- সব নতুন অর্ডার সবসময় 'pending' দিয়ে শুরু হয়
  new.status := 'pending';
  new.created_at := now();
  new.updated_at := now();

  return new;
end;
$$;

drop trigger if exists trg_orders_set_defaults on public.orders;
create trigger trg_orders_set_defaults
  before insert on public.orders
  for each row execute procedure public.set_order_defaults();

-- ------------------------------------------------------------
-- 4. TRIGGER — UPDATE-এর সময়:
--    - শুধুমাত্র status কলাম পরিবর্তনযোগ্য (product/buyer/seller/price snapshot
--      অর্ডার হয়ে যাওয়ার পর অপরিবর্তনীয় — ইতিহাস হিসেবে অক্ষত থাকে)
--    - শুধুমাত্র Seller (নিজের অর্ডার) বা Admin/Super Admin status বদলাতে পারবেন
--    - updated_at স্বয়ংক্রিয়ভাবে আপডেট হয়
-- ------------------------------------------------------------
-- একই কারণে (উপরের নোট দ্রষ্টব্য) এটাও SECURITY DEFINER না — is_admin_or_above()
-- নিজেই SECURITY DEFINER, তাই caller-এর profiles read-privilege লাগে না।
create or replace function public.guard_order_update()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('service_role', 'postgres', 'supabase_admin') then
    new.updated_at := now();
    return new;
  end if;

  if not (auth.uid() = old.seller_id or public.is_admin_or_above()) then
    raise exception 'শুধুমাত্র Seller বা Admin অর্ডারের status পরিবর্তন করতে পারবেন';
  end if;

  if new.order_number is distinct from old.order_number
     or new.product_id is distinct from old.product_id
     or new.product_name is distinct from old.product_name
     or new.unit_price is distinct from old.unit_price
     or new.quantity is distinct from old.quantity
     or new.shop_id is distinct from old.shop_id
     or new.shop_name is distinct from old.shop_name
     or new.seller_id is distinct from old.seller_id
     or new.buyer_id is distinct from old.buyer_id
     or new.buyer_name is distinct from old.buyer_name
     or new.buyer_phone is distinct from old.buyer_phone
     or new.created_at is distinct from old.created_at
  then
    raise exception 'অর্ডারের status ছাড়া অন্য কোনো তথ্য পরিবর্তন করা যাবে না';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_orders_guard_update on public.orders;
create trigger trg_orders_guard_update
  before update on public.orders
  for each row execute procedure public.guard_order_update();

-- ------------------------------------------------------------
-- 5. RLS
-- ------------------------------------------------------------
alter table public.orders enable row level security;

-- SELECT — Buyer নিজের অর্ডার, Seller নিজের দোকানের অর্ডার, Admin/Super Admin সব দেখতে পারবেন
drop policy if exists "orders_select_buyer_seller_admin" on public.orders;
create policy "orders_select_buyer_seller_admin"
  on public.orders for select
  using (
    auth.uid() = buyer_id
    or auth.uid() = seller_id
    or public.is_admin_or_above()
  );

-- INSERT — লগইন-করা যেকোনো ইউজার (account_status = active) নিজের জন্য অর্ডার
-- করতে পারবেন। buyer_id ক্লায়েন্ট যা পাঠাক না কেন, ট্রিগার সবসময় auth.uid()
-- দিয়ে ওভাররাইড করে — তাই এই WITH CHECK মূলত একটা দ্বিতীয় সুরক্ষা স্তর।
drop policy if exists "orders_insert_own" on public.orders;
create policy "orders_insert_own"
  on public.orders for insert
  to authenticated
  with check (
    buyer_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.account_status = 'active'
    )
  );

-- UPDATE — শুধুমাত্র Seller (নিজের দোকানের অর্ডার) বা Admin/Super Admin
drop policy if exists "orders_update_seller_or_admin" on public.orders;
create policy "orders_update_seller_or_admin"
  on public.orders for update
  using (auth.uid() = seller_id or public.is_admin_or_above())
  with check (auth.uid() = seller_id or public.is_admin_or_above());

-- DELETE — এখনো কোনো পলিসি নেই, অর্থাৎ API দিয়ে কেউ অর্ডার ডিলিট করতে
-- পারবেন না (শুধু Supabase Dashboard/service_role থেকে সম্ভব)

grant select, insert, update on public.orders to authenticated;

-- ------------------------------------------------------------
-- যাচাই (রান করার পর, ঐচ্ছিক):
--   select order_number, product_name, quantity, unit_price, total_price,
--          shop_name, buyer_name, status
--   from public.orders order by created_at desc limit 5;
-- ============================================================
