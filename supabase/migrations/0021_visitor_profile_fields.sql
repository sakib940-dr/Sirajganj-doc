-- ============================================================
-- 0021: Visitor Profile — gender ও avatar_url যোগ + avatar storage bucket
-- ============================================================
-- উদ্দেশ্য: নতুন "প্রোফাইল" পেজে ইউজার নিজের নাম, ফোন, জেন্ডার এবং
-- প্রোফাইল ছবি (avatar) সেট করতে পারবে। বিদ্যমান profiles টেবিলের
-- structure/RLS/trigger-এ কোনো ভাঙচুর হয় না — শুধু দুটো nullable কলাম
-- এবং একটি নতুন storage bucket যোগ করা হচ্ছে। বিদ্যমান
-- "profiles_update_own" পলিসি (auth.uid() = id) স্বয়ংক্রিয়ভাবেই এই
-- নতুন কলাম দুটোতেও প্রযোজ্য হবে — role/seller_status ছাড়া অন্য কোনো
-- কলাম সেলফ-আপডেট ব্লক করা নেই।

alter table public.profiles
  add column if not exists gender text check (gender in ('male', 'female', 'other')),
  add column if not exists avatar_url text;

-- ------------------------------------------------------------
-- Storage bucket: user-avatars (folder-per-user কনভেনশন: <user_id>/filename.jpg)
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('user-avatars', 'user-avatars', true)
on conflict (id) do nothing;

create policy "public_read_user_avatars"
  on storage.objects for select
  using (bucket_id = 'user-avatars');

create policy "authenticated_upload_own_avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'user-avatars'
    and auth.role() = 'authenticated'
  );

create policy "authenticated_update_own_avatar"
  on storage.objects for update
  using (
    bucket_id = 'user-avatars'
    and auth.role() = 'authenticated'
  );

create policy "authenticated_delete_own_avatar"
  on storage.objects for delete
  using (
    bucket_id = 'user-avatars'
    and auth.role() = 'authenticated'
  );
