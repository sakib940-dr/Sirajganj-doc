-- ============================================================
-- Super Admin CMS — Social Links & Announcement Bar
-- Run this in Supabase SQL Editor (or via `supabase db push`)
--
-- এই মাইগ্রেশনটি সম্পূর্ণরূপে সংযোজনমূলক (additive) — বিদ্যমান কোনো টেবিল,
-- কলাম, পলিসি পরিবর্তন বা মোছা হয় না। তাই আগের সব ফিচার (products, shops,
-- banners, site_settings ইত্যাদি) আগের মতোই কাজ করবে।
--
-- বাকি CMS ফিল্ডগুলো (লোগো, সাইটের নাম, মটো, হিরো সেকশন, About Us,
-- Contact Info, Privacy Policy, Terms & Conditions, Footer Content,
-- SEO মেটা, Favicon) বিদ্যমান key-value `public.site_settings` টেবিলেই
-- সংরক্ষিত হয় (0001_init.sql এ ইতিমধ্যে তৈরি), নতুন কোনো টেবিল দরকার নেই।
-- ============================================================

-- ------------------------------------------------------------
-- 1. social_links — একাধিক সোশ্যাল মিডিয়া লিংক (Add/Edit/Delete)
-- ------------------------------------------------------------
create table if not exists public.social_links (
  id uuid primary key default gen_random_uuid(),
  platform text not null,        -- যেমন: facebook, instagram, youtube, whatsapp, tiktok, custom
  label text,                    -- কাস্টম প্ল্যাটফর্মের জন্য ঐচ্ছিক ডিসপ্লে নাম
  url text not null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_social_links_sort on public.social_links (sort_order);

-- ------------------------------------------------------------
-- 2. announcements — নোটিশ / অ্যানাউন্সমেন্ট বার (Add/Edit/Delete)
-- ------------------------------------------------------------
create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  message text not null,
  link_text text,
  link_url text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_announcements_sort on public.announcements (sort_order);

-- ------------------------------------------------------------
-- 3. updated_at অটো-আপডেট ট্রিগার (দুই টেবিলের জন্যই)
-- ------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_social_links_updated_at on public.social_links;
create trigger trg_social_links_updated_at
  before update on public.social_links
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_announcements_updated_at on public.announcements;
create trigger trg_announcements_updated_at
  before update on public.announcements
  for each row execute procedure public.set_updated_at();

-- ------------------------------------------------------------
-- 4. RLS ENABLE
-- ------------------------------------------------------------
alter table public.social_links enable row level security;
alter table public.announcements enable row level security;

-- ------------------------------------------------------------
-- 5. POLICIES — social_links
--    সবাই সক্রিয় লিংক দেখতে পাবে (পাবলিক ফুটার/হেডারে ব্যবহারের জন্য),
--    কিন্তু শুধু Super Admin অ্যাড/এডিট/ডিলিট করতে পারবে।
-- ------------------------------------------------------------
drop policy if exists "social_links_select_active_or_admin" on public.social_links;
create policy "social_links_select_active_or_admin"
  on public.social_links for select
  using (is_active = true or public.is_super_admin());

drop policy if exists "social_links_write_admin" on public.social_links;
create policy "social_links_write_admin"
  on public.social_links for all
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- ------------------------------------------------------------
-- 6. POLICIES — announcements
-- ------------------------------------------------------------
drop policy if exists "announcements_select_active_or_admin" on public.announcements;
create policy "announcements_select_active_or_admin"
  on public.announcements for select
  using (is_active = true or public.is_super_admin());

drop policy if exists "announcements_write_admin" on public.announcements;
create policy "announcements_write_admin"
  on public.announcements for all
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- ------------------------------------------------------------
-- 7. site_settings — নতুন CMS কী-গুলোর জন্য কোনো স্কিমা পরিবর্তন লাগে না
--    (key/value টেবিল), তবে ডকুমেন্টেশনের জন্য প্রত্যাশিত key list:
--
--    site_name, site_motto, site_logo_url, site_favicon_url,
--    hero_title, hero_subtitle, hero_image_url, hero_button_text, hero_button_link,
--    about_us_content,
--    contact_phone, contact_email, contact_whatsapp, footer_address, contact_map_link,
--    privacy_policy_content, terms_conditions_content,
--    footer_content, footer_copyright,
--    seo_meta_title, seo_meta_description, seo_meta_keywords
--
--    এগুলো অ্যাডমিন CMS প্যানেল থেকে upsert (key, value) আকারে সংরক্ষিত হবে।
-- ------------------------------------------------------------
