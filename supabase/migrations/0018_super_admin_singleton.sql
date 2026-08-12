-- ============================================================
-- Super Admin Singleton Enforcement
-- এই মাইগ্রেশনটি Supabase SQL Editor-এ রান করতে হবে (idempotent, নতুন ও
-- বিদ্যমান উভয় প্রজেক্টেই নিরাপদ)।
--
-- প্রেক্ষাপট: 0007_super_admin_lockout_fix.sql ইতিমধ্যে নিশ্চিত করে যে
-- সিস্টেম থেকে *শেষ* Super Admin-কে কখনো সরানো/ডিমোট করা যায় না (অন্তত ১
-- জন সবসময় থাকবেন)। কিন্তু এতদিন প্রযুক্তিগতভাবে বিদ্যমান Super Admin
-- (via role-change UI) অন্য কোনো ইউজারকে দ্বিতীয় Super Admin বানাতে
-- পারতেন। এই মাইগ্রেশন সেটা বন্ধ করে — এখন থেকে সিস্টেমে সবসময় ঠিক ১ জনই
-- (exactly one) Super Admin থাকবেন, তার বেশি না।
--
-- এই মাইগ্রেশন যা করে:
--   - prevent_self_role_change() ফাংশনে একটি নতুন হার্ড-ইনভ্যারিয়েন্ট চেক
--     যোগ করা হলো: কোনো authenticated অ্যাপ-অ্যাকশন (Super Admin নিজে সহ)
--     আর কাউকে role = 'super_admin'-এ প্রমোট করতে পারবে না।
--   - bootstrap flow (README ধাপ ৫ — Supabase SQL Editor থেকে প্রথম Super
--     Admin ম্যানুয়ালি বানানো, postgres/supabase_admin/service_role
--     হিসেবে) অপরিবর্তিত থাকছে — সেই bypass আগে থেকেই বিদ্যমান এবং এই
--     নতুন চেকের আগেই রান হয়।
--   - যে row-টা ইতিমধ্যে super_admin, সেটাকে আবার super_admin সেট করলে
--     (no-op / অন্য কলাম আপডেট) কোনো সমস্যা হয় না — শুধু *নতুন* কাউকে
--     super_admin বানানো ব্লক করা হচ্ছে।
--   - শেষ Super Admin-কে ডিমোট/ব্যান করা যাবে না — এই সুরক্ষা (0007-এ
--     যোগ হওয়া) অপরিবর্তিত থাকছে, ফলে মিলিয়ে সিস্টেমে সবসময় ঠিক ১ জনই
--     Super Admin থাকবেন — বেশিও না, কমও না।
--
-- বিদ্যমান ডেটা, টেবিল স্ট্রাকচার, RLS পলিসি বা অন্য কোনো ফিচার এখানে
-- পরিবর্তন করা হয়নি।
-- ============================================================

create or replace function public.prevent_self_role_change()
returns trigger
language plpgsql
as $$
begin
  -- Edge Function / service_role থেকে হওয়া পরিবর্তন এবং Supabase Dashboard
  -- SQL Editor থেকে সরাসরি রান করা কমান্ড (postgres/supabase_admin) সবসময়
  -- অনুমোদিত — নাহলে প্রথম Super Admin বানানোর SQL-ই ব্লক হয়ে যাবে
  -- (bootstrapping সমস্যা)।
  if current_user in ('service_role', 'postgres', 'supabase_admin') then
    return new;
  end if;

  -- ============================================================
  -- NEW: সিস্টেমে সবসময় ঠিক ১ জনই (exactly one) Super Admin থাকবেন —
  -- অ্যাপের ভেতর থেকে (Super Admin নিজে সহ) আর কাউকে নতুন করে
  -- super_admin-এ প্রমোট করা যাবে না। ইতিমধ্যে super_admin এমন row-এ কোনো
  -- no-op আপডেট (role অপরিবর্তিত রেখে অন্য কলাম বদলানো) প্রভাবিত হয় না।
  -- ============================================================
  if new.role = 'super_admin' and old.role is distinct from 'super_admin' then
    raise exception 'সিস্টেমে সবসময় ঠিক একজনই সর্বোচ্চ-পর্যায়ের Admin থাকবেন — নতুন কাউকে এই লেভেলে উন্নীত করা যাবে না।';
  end if;

  -- সিস্টেমে অন্তত ১ জন Super Admin সবসময় থাকতেই হবে — এই চেক কোনো
  -- bypass ছাড়াই সবার জন্য (service_role/postgres সহ) প্রযোজ্য, কারণ এটা
  -- একটা hard invariant, permission check না। (0007 থেকে অপরিবর্তিত)
  if old.role = 'super_admin'
     and new.role is distinct from 'super_admin'
     and public.count_super_admins() <= 1
  then
    raise exception 'সিস্টেমে অন্তত একজন Super Admin থাকতেই হবে — শেষ Super Admin-এর role পরিবর্তন করা যাবে না।';
  end if;

  if old.role = 'super_admin'
     and new.account_status = 'banned'
     and old.account_status is distinct from 'banned'
     and public.count_super_admins() <= 1
  then
    raise exception 'সিস্টেমে অন্তত একজন Super Admin থাকতেই হবে — শেষ Super Admin-কে ব্যান করা যাবে না।';
  end if;

  -- নিজের role/seller_status/account_status নিজে বদলানো ব্লক (Super Admin ও RPC bypass বাদে)
  if auth.uid() = old.id
     and not public.is_super_admin()
     and coalesce(current_setting('app.bypass_role_guard', true), 'false') <> 'true'
  then
    if new.role is distinct from old.role
       or new.seller_status is distinct from old.seller_status
       or new.account_status is distinct from old.account_status
    then
      raise exception 'role, seller_status এবং account_status নিজে পরিবর্তন করা যাবে না';
    end if;
  end if;

  -- role বা account_status বদলানো (যে কারো জন্যই) — শুধুমাত্র Super Admin পারবেন
  if (new.role is distinct from old.role or new.account_status is distinct from old.account_status)
     and not public.is_super_admin()
  then
    raise exception 'শুধুমাত্র Super Admin ইউজার role বা account status পরিবর্তন করতে পারবেন।';
  end if;

  return new;
end;
$$;

-- trigger আগে থেকেই profiles টেবিলে attach করা আছে — শুধু function replace
-- করলেই যথেষ্ট, trigger পুনরায় তৈরির দরকার নেই।

-- ============================================================
-- রান করার পর যাচাই করুন:
--   select count(*) from public.profiles where role = 'super_admin';
-- ফলাফল অবশ্যই ১ হতে হবে।
-- ============================================================
