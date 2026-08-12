-- ============================================================
-- Migration 0004 — CRITICAL FIX
-- prevent_self_role_change trigger আগে request_seller_status()
-- RPC-কেও ব্লক করে দিচ্ছিল, ফলে কেউ কখনো 'seller'/'pending' হতে
-- পারছিল না। এই মাইগ্রেশন সেটা ঠিক করে এবং আটকে থাকা ইউজারদের
-- অবস্থা মেরামত করে।
--
-- NOTE (আপডেট): এই ফিক্স এখন সরাসরি 0001_init.sql-এর মধ্যেই merge
-- করা হয়েছে, তাই নতুন (fresh) Supabase প্রজেক্টে শুধু 0001 রান
-- করলেই এই বাগ থাকবে না। এই ফাইলটি (0004) শুধু তখনই দরকার যদি
-- আপনার Supabase প্রজেক্টে আগে থেকেই পুরনো (bug-যুক্ত) 0001 রান করা
-- থাকে — এটি আবার রান করলে কোনো ক্ষতি নেই (idempotent), শুধু
-- পুরনো ডাটাবেসে থাকা bug ঠিক করে দেবে।
-- ============================================================

-- ------------------------------------------------------------
-- 1. request_seller_status() RPC — এখন একটা নিরাপদ session flag সেট
--    করে দেয়, যাতে trigger বুঝতে পারে এই আপডেট RPC থেকে আসছে
-- ------------------------------------------------------------
create or replace function public.request_seller_status()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('app.bypass_role_guard', 'true', true); -- শুধু বর্তমান transaction-এর জন্য
  update public.profiles
  set role = 'seller',
      seller_status = 'pending'
  where id = auth.uid()
    and seller_status = 'none';
end;
$$;

-- ------------------------------------------------------------
-- 2. Trigger আপডেট — উপরের flag চেক করবে, তাহলে RPC-কে block করবে না
--    (কিন্তু ব্রাউজার থেকে সরাসরি profiles.update({role: 'super_admin'})
--     করার চেষ্টা আগের মতোই ব্লক থাকবে — নিরাপত্তা অক্ষুণ্ণ)
-- ------------------------------------------------------------
create or replace function public.prevent_self_role_change()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() = old.id
     and not public.is_super_admin()
     and coalesce(current_setting('app.bypass_role_guard', true), 'false') <> 'true'
  then
    if new.role is distinct from old.role or new.seller_status is distinct from old.seller_status then
      raise exception 'role এবং seller_status নিজে পরিবর্তন করা যাবে না';
    end if;
  end if;
  return new;
end;
$$;

-- ------------------------------------------------------------
-- 3. মেরামত — যদি কেউ আগে Register করার সময় "সেলার হতে চাই" টিক
--    দিয়ে থাকে কিন্তু বাগের কারণে role/seller_status আপডেট হয়নি,
--    তাদের এখনো role='visitor' & seller_status='none' অবস্থায় আছে।
--    এই কমান্ডটা এমন কাউকে খুঁজে পেলে দেখাবে (এটা শুধু SELECT, কিছু বদলাবে না):
-- ------------------------------------------------------------
-- select id, email, full_name, role, seller_status, created_at
-- from public.profiles
-- order by created_at desc;

-- যদি উপরের লিস্টে এমন কাউকে দেখেন যে সেলার হতে চেয়েছিল কিন্তু
-- role='visitor' রয়ে গেছে, তাকে ম্যানুয়ালি pending করে দিতে চাইলে
-- (ইমেইল বসিয়ে) এটা রান করুন:
--
-- update public.profiles
-- set role = 'seller', seller_status = 'pending'
-- where email = 'sellers-email@example.com';
