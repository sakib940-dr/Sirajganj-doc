-- Seller Analytics dashboard — পারফরম্যান্স ইনডেক্স
-- এই মাইগ্রেশনটা 0010_product_analytics.sql-এর উপর নির্ভরশীল (view_count,
-- save_count, click_count, stock_quantity কলাম আগেই থাকতে হবে)।
-- Idempotent: বারবার রান করলেও সমস্যা নেই।
--
-- কেন দরকার:
-- Seller Analytics পেজ প্রতিবার লোডে ও প্রতিটি realtime আপডেটে
-- `products` টেবিল থেকে `shop_id = ?` দিয়ে ফিল্টার করে, এবং
-- Most Viewed / Most Saved বের করতে view_count ও save_count অনুযায়ী
-- সর্ট করে। নিচের ইনডেক্সগুলো ছাড়া এই কোয়েরিগুলো পণ্যের সংখ্যা
-- বাড়ার সাথে সাথে ধীর হয়ে যাবে (sequential scan)।

-- shop_id দিয়ে ফিল্টার করা সব সেলার-অ্যানালিটিক্স কোয়েরির মূল ভিত্তি
create index if not exists idx_products_shop_id
  on public.products (shop_id);

-- "Most Viewed Products" — shop_id দিয়ে ফিল্টার করে view_count দিয়ে সর্ট
create index if not exists idx_products_shop_view_count
  on public.products (shop_id, view_count desc);

-- "Most Saved Products" — shop_id দিয়ে ফিল্টার করে save_count দিয়ে সর্ট
create index if not exists idx_products_shop_save_count
  on public.products (shop_id, save_count desc);

-- Active vs Out-of-stock গণনা দ্রুত করতে (is_active ও stock_quantity
-- দুটোই সামারি কার্ডে গণনা করা হয়)
create index if not exists idx_products_shop_is_active
  on public.products (shop_id, is_active);

create index if not exists idx_products_shop_stock_quantity
  on public.products (shop_id, stock_quantity);
