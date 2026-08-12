-- ------------------------------------------------------------
-- সেলার ভেরিফিকেশন — আবেদনের ইতিহাস সংরক্ষণ + ব্যবসা-সংক্রান্ত প্রশ্ন
-- ------------------------------------------------------------
-- এই মাইগ্রেশনে যা পরিবর্তন হচ্ছে:
--
--   ১. seller_verifications.user_id থেকে UNIQUE constraint সরানো হচ্ছে,
--      যাতে একজন সেলারের একাধিক (পূর্ববর্তী + বর্তমান) আবেদন সংরক্ষিত থাকতে
--      পারে। আগে upsert(onConflict: user_id) দিয়ে প্রতিটি নতুন সাবমিশন
--      পুরনোটাকে ওভাররাইট করে ফেলত — এখন থেকে প্রতিটি নতুন আবেদন একটি নতুন
--      সারি (row) হিসেবে insert হবে এবং পুরনো আবেদন অপরিবর্তিত থেকে যাবে।
--
--   ২. নতুন ব্যবসা-সংক্রান্ত প্রশ্নের কলাম যোগ করা হচ্ছে (সবই ঐচ্ছিক/nullable,
--      বিদ্যমান কোনো ডেটা প্রভাবিত হয় না)।
--
--   ৩. RLS পলিসি আপডেট করা হচ্ছে:
--      - INSERT: সেলার তখনই নতুন আবেদন জমা দিতে পারবে যখন তার কোনো
--        "pending" আবেদন বিদ্যমান নেই (একসাথে একাধিক pending আবেদন আটকানো)।
--      - UPDATE: সেলার শুধুমাত্র নিজের "pending" অবস্থায় থাকা আবেদন এডিট
--        করতে পারবে — একবার Admin অনুমোদন/প্রত্যাখ্যান করলে সেটি ইতিহাস
--        হিসেবে লক হয়ে যাবে এবং সেলার আর তা পরিবর্তন করতে পারবে না।
--        Admin/Super Admin সবসময় আপডেট করতে পারবেন (status/admin_note সেট
--        করার জন্য)।
--      - DELETE: কোনো পলিসি তৈরি করা হচ্ছে না — অর্থাৎ RLS ডিফল্টভাবে সব
--        ডিলিট আটকে দেবে (সেলার নিজের জমা দেওয়া তথ্য/ছবি কখনো ডিলিট করতে
--        পারবে না, এবং সাধারণ ক্লায়েন্ট থেকে পুরনো আবেদনও মোছা যাবে না)।
--
-- Idempotent: বারবার রান করলেও সমস্যা নেই।

-- ১. UNIQUE constraint সরানো (একই ইউজারের একাধিক আবেদন রাখার জন্য)
alter table public.seller_verifications
  drop constraint if exists seller_verifications_user_id_key;

-- user_id দিয়ে খোঁজার জন্য ইনডেক্স আগে থেকেই আছে (idx_seller_verifications_user),
-- তাই আলাদা করে নতুন ইনডেক্সের দরকার নেই।

-- ২. ব্যবসা-সংক্রান্ত নতুন প্রশ্নের কলাম
alter table public.seller_verifications
  add column if not exists business_type text,
  add column if not exists product_type text,
  add column if not exists avg_monthly_sales_bdt numeric,
  add column if not exists sales_channel text,
  add column if not exists sells_via_facebook_page boolean,
  add column if not exists uses_other_ecommerce_platform boolean,
  add column if not exists other_ecommerce_platform_name text,
  add column if not exists monthly_sales_target_bdt numeric;

-- ৩. INSERT পলিসি — নিজের জন্য, এবং তখনই যখন কোনো pending আবেদন বিদ্যমান নেই
drop policy if exists "seller_verifications_insert_own" on public.seller_verifications;
create policy "seller_verifications_insert_own"
  on public.seller_verifications for insert
  with check (
    user_id = auth.uid()
    and not exists (
      select 1 from public.seller_verifications sv
      where sv.user_id = auth.uid() and sv.status = 'pending'
    )
  );

-- ৪. UPDATE পলিসি — সেলার শুধু নিজের pending আবেদন এডিট করতে পারবে,
--    Admin/Super Admin সবসময় করতে পারবেন
drop policy if exists "seller_verifications_update_own_or_admin" on public.seller_verifications;
create policy "seller_verifications_update_own_or_admin"
  on public.seller_verifications for update
  using (
    (user_id = auth.uid() and status = 'pending')
    or public.is_admin_or_above()
  )
  with check (
    (user_id = auth.uid() and status = 'pending')
    or public.is_admin_or_above()
  );
