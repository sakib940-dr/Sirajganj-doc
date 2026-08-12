-- ============================================================
-- Super Admin Lockout Fix
-- এই মাইগ্রেশনটি Supabase SQL Editor-এ রান করতে হবে (idempotent, নতুন ও
-- বিদ্যমান উভয় প্রজেক্টেই নিরাপদ)।
--
-- সমাধান করা সমস্যা:
--   0006_role_and_admin_update.sql প্রতিটি পুরনো 'super_admin'-কে
--   'admin'-এ রূপান্তর করেছিল, এবং নতুন Super Admin ম্যানুয়ালি SQL চালিয়ে
--   বানানোর কথা ছিল। যদি সেই ধাপটি বাদ পড়ে (বা কেউ ভুলে যায়), তাহলে
--   সিস্টেমে কোনো Super Admin থাকে না — এবং শুধুমাত্র Super Admin-ই নতুন
--   Super Admin বানাতে পারে বলে, সিস্টেম স্থায়ীভাবে লক হয়ে যায় (কেউই আর
--   role পরিবর্তন করতে পারে না)।
--
-- এই মাইগ্রেশন যা করে:
--   ১. স্বয়ংক্রিয়ভাবে সিস্টেম পরীক্ষা করে — যদি বর্তমানে কোনো Super Admin
--      না থাকে, তাহলে সবচেয়ে পুরনো (প্রথম তৈরি হওয়া) 'admin' ইউজারকে
--      আবার 'super_admin'-এ উন্নীত করে দেয় (এটাই আসলে আগের প্রকৃত Super
--      Admin হওয়ার সম্ভাবনা সবচেয়ে বেশি)। যদি কোনো 'admin'-ও না থাকে,
--      কিছু পরিবর্তন করা হয় না (অনুমান করে কাউকে তুলে দেওয়া নিরাপদ না)।
--      এই ধাপটি প্রকৃতিগতভাবেই idempotent — একবার অন্তত ১ জন Super Admin
--      হয়ে গেলে, পরের বার এই মাইগ্রেশন আবার রান করলেও কিছু বদলাবে না।
--   ২. স্থায়ীভাবে একটি গার্ড যোগ করে: এখন থেকে কোনো অ্যাকশনই (role
--      পরিবর্তন হোক বা ব্যান) শেষ অবশিষ্ট Super Admin-কে সরাতে পারবে না —
--      ফলে ভবিষ্যতে এই লকআউট আর কখনো ঘটবে না।
--
-- বিদ্যমান ডেটা, টেবিল স্ট্রাকচার, RLS পলিসি বা অন্য কোনো ফিচার এখানে
-- পরিবর্তন করা হয়নি।
-- ============================================================

-- ------------------------------------------------------------
-- ১. Auto-heal: সিস্টেমে কোনো Super Admin না থাকলে, সবচেয়ে পুরনো Admin-কে
--    Super Admin-এ উন্নীত করা হচ্ছে।
-- ------------------------------------------------------------
do $$
declare
  candidate_id uuid;
begin
  if not exists (select 1 from public.profiles where role = 'super_admin') then
    select id into candidate_id
    from public.profiles
    where role = 'admin'
    order by created_at asc
    limit 1;

    if candidate_id is not null then
      update public.profiles set role = 'super_admin' where id = candidate_id;
    end if;
  end if;
end $$;

-- ------------------------------------------------------------
-- ২. HELPER — বর্তমানে কতজন Super Admin আছে
-- ------------------------------------------------------------
create or replace function public.count_super_admins()
returns int
language sql
security definer
set search_path = public
stable
as $$
  select count(*)::int from public.profiles where role = 'super_admin';
$$;

-- ------------------------------------------------------------
-- ৩. prevent_self_role_change() আপডেট — শেষ Super Admin-কে role/ban
--    পরিবর্তনের মাধ্যমে সরানো স্থায়ীভাবে ব্লক করা হচ্ছে (bypass ছাড়াই,
--    যাতে ভুলবশতও সিস্টেম আর কখনো লক না হয়ে যায়)।
-- ------------------------------------------------------------
create or replace function public.prevent_self_role_change()
returns trigger
language plpgsql
as $$
begin
  -- সিস্টেমে অন্তত ১ জন Super Admin সবসময় থাকতেই হবে — এই চেক কোনো
  -- bypass ছাড়াই সবার জন্য (service_role/postgres সহ) প্রযোজ্য, কারণ এটা
  -- একটা hard invariant, permission check না।
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

  -- Edge Function / service_role থেকে হওয়া পরিবর্তন এবং Supabase Dashboard
  -- SQL Editor থেকে সরাসরি রান করা কমান্ড (postgres/supabase_admin) সবসময়
  -- অনুমোদিত — নাহলে প্রথম Super Admin বানানোর SQL-ই ব্লক হয়ে যাবে
  -- (bootstrapping সমস্যা)। উপরের ২টি হার্ড-ইনভ্যারিয়েন্ট চেক অবশ্য এর
  -- আগেই রান হয়ে গেছে, তাই এই bypass দিয়ে শেষ Super Admin সরানো যাবে না।
  if current_user in ('service_role', 'postgres', 'supabase_admin') then
    return new;
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

-- trigger আগে থেকেই profiles টেবিলে attach করা আছে (0001-এ তৈরি) — শুধু
-- function replace করলেই যথেষ্ট, trigger পুনরায় তৈরির দরকার নেই।

-- ============================================================
-- রান করার পর: `select role, email, created_at from public.profiles
-- where role = 'super_admin';` চালিয়ে নিশ্চিত করুন অন্তত ১ জন Super Admin
-- আছে। যদি কোনো 'admin' ইউজারই আগে না থেকে থাকে (তাই auto-heal কাউকে
-- খুঁজে না পায়), README-এর ধাপ ৫ অনুসরণ করে ম্যানুয়ালি একজনকে বানিয়ে নিন।
-- ============================================================
