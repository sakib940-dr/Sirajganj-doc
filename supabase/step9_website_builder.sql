-- ============================================================
-- SIRAJGANJ DOCTOR V1 — STEP 9
-- Website Builder + Bangla Directions
-- Run ONCE after Step 8.
-- ============================================================

alter table public.shops
  add column if not exists website_config jsonb not null default '{}'::jsonb;

-- Safe defaults for existing chambers/hospitals.
update public.shops
set website_config = jsonb_build_object(
  'enabled', true,
  'hero_title', coalesce(shop_name, 'চেম্বার / হাসপাতাল'),
  'hero_subtitle', 'সিরাজগঞ্জের রোগীদের জন্য বিশ্বস্ত চিকিৎসা সেবা',
  'about_title', 'আমাদের সম্পর্কে',
  'contact_title', 'যোগাযোগ ও দিকনির্দেশনা',
  'show_doctors', true,
  'show_gallery', true,
  'show_about', true,
  'cta_text', 'অ্যাপয়েন্টমেন্ট নিন'
)
where website_config = '{}'::jsonb;

-- Existing public shop SELECT policy already exposes active provider-owned shops.
-- Owner/admin update permissions remain unchanged.
