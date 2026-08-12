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
