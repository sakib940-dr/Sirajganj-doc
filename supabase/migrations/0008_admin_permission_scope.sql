-- ============================================================
-- Admin Permission Scope Update
-- এই মাইগ্রেশনটি Supabase SQL Editor-এ রান করতে হবে (idempotent, নতুন ও
-- বিদ্যমান উভয় প্রজেক্টেই নিরাপদ)।
--
-- কী পরিবর্তন হচ্ছে (শুধু এই দুইটা টেবিলের write policy):
--   - banners       : এখন থেকে শুধুমাত্র Super Admin ব্যানার
--                      যোগ/এডিট/মুছতে পারবেন (আগে Admin-ও পারতো)।
--   - site_settings : এখন থেকে শুধুমাত্র Super Admin সাইট সেটিংস
--                      পরিবর্তন করতে পারবেন (আগে Admin-ও পারতো)।
--
-- Admin-এর বাকি সব permission অপরিবর্তিত থাকছে — সেলার ম্যানেজমেন্ট
-- (প্রোফাইল দেখা, active/deactivate), সেলার ভেরিফিকেশন, ক্যাটাগরি এবং
-- পণ্য ম্যানেজমেন্ট — এসবের কোনো পলিসি এখানে বদলানো হয়নি।
--
-- (SELECT policy অপরিবর্তিত আছে — banners/site_settings public read
-- আগের মতোই কাজ করবে, শুধু write/all অ্যাক্সেসটাই সংকুচিত হলো।)
-- ============================================================

-- banners — শুধুমাত্র Super Admin write করতে পারবেন
drop policy if exists "banners_write_admin" on public.banners;
create policy "banners_write_admin"
  on public.banners for all
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- site_settings — শুধুমাত্র Super Admin write করতে পারবেন
drop policy if exists "site_settings_write_admin" on public.site_settings;
create policy "site_settings_write_admin"
  on public.site_settings for all
  using (public.is_super_admin())
  with check (public.is_super_admin());
