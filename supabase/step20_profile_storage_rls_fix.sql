-- Step 20: Profile center schema + storage + provider RLS fix
-- Run once on the EXISTING Doctor V1 Supabase project.
-- Safe/idempotent.

-- 1) Profiles: fields used by the unified profile center.
alter table public.profiles
  add column if not exists address text,
  add column if not exists phone_public boolean not null default false,
  add column if not exists avatar_url text;

-- 2) Shop/provider fields used by the unified profile center.
alter table public.shops
  add column if not exists chamber_name text,
  add column if not exists chamber_type text,
  add column if not exists district text,
  add column if not exists upazila text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists visiting_days text,
  add column if not exists visiting_time text,
  add column if not exists consultation_fee numeric(12,2),
  add column if not exists assistant_phone text,
  add column if not exists hospital_photo_urls text[] not null default '{}',
  add column if not exists phone_public boolean not null default true,
  add column if not exists whatsapp_public boolean not null default false,
  add column if not exists assistant_phone_public boolean not null default false;

-- 3) Verification fields used by the compact Doctor/Hospital verification form.
alter table public.seller_verifications
  add column if not exists verification_type text,
  add column if not exists bmdc_registration_no text,
  add column if not exists bmdc_document_url text,
  add column if not exists trade_license_no text,
  add column if not exists trade_license_url text;

-- 4) The old marketplace policy required seller_status='approved'.
--    Doctors/hospitals must be able to create/save their profile/chamber
--    BEFORE verification is approved. Public visibility can still be
--    controlled separately by is_active / approved status.
drop policy if exists "shops_insert_approved_seller" on public.shops;
drop policy if exists "shops_insert_approved_provider" on public.shops;
drop policy if exists "shops_insert_provider_profile" on public.shops;

create policy "shops_insert_provider_profile"
  on public.shops for insert
  with check (
    owner_id = auth.uid()
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role in ('doctor','hospital')
        and coalesce(p.account_status, 'active') = 'active'
    )
  );

drop policy if exists "shops_update_own_or_admin" on public.shops;
create policy "shops_update_own_or_admin"
  on public.shops for update
  using (owner_id = auth.uid() or public.is_super_admin())
  with check (owner_id = auth.uid() or public.is_super_admin());

-- 5) Storage: use the already-existing shop-gallery bucket for hospital/chamber
--    photos. Do NOT create/use a new shop-gallery bucket.
insert into storage.buckets (id, name, public)
values ('shop-gallery', 'shop-gallery', true)
on conflict (id) do update set public = true;

drop policy if exists "public_read_provider_shop_gallery" on storage.objects;
create policy "public_read_provider_shop_gallery"
  on storage.objects for select
  using (bucket_id = 'shop-gallery');

drop policy if exists "authenticated_upload_provider_shop_gallery" on storage.objects;
create policy "authenticated_upload_provider_shop_gallery"
  on storage.objects for insert
  with check (
    bucket_id = 'shop-gallery'
    and auth.role() = 'authenticated'
  );

drop policy if exists "authenticated_update_provider_shop_gallery" on storage.objects;
create policy "authenticated_update_provider_shop_gallery"
  on storage.objects for update
  using (
    bucket_id = 'shop-gallery'
    and auth.role() = 'authenticated'
  )
  with check (
    bucket_id = 'shop-gallery'
    and auth.role() = 'authenticated'
  );

drop policy if exists "authenticated_delete_provider_shop_gallery" on storage.objects;
create policy "authenticated_delete_provider_shop_gallery"
  on storage.objects for delete
  using (
    bucket_id = 'shop-gallery'
    and auth.role() = 'authenticated'
  );

-- 6) Keep avatar bucket available too.
insert into storage.buckets (id, name, public)
values ('user-avatars', 'user-avatars', true)
on conflict (id) do update set public = true;

drop policy if exists "public_read_provider_avatars" on storage.objects;
create policy "public_read_provider_avatars"
  on storage.objects for select
  using (bucket_id = 'user-avatars');

drop policy if exists "authenticated_upload_provider_avatars" on storage.objects;
create policy "authenticated_upload_provider_avatars"
  on storage.objects for insert
  with check (bucket_id = 'user-avatars' and auth.role() = 'authenticated');

drop policy if exists "authenticated_update_provider_avatars" on storage.objects;
create policy "authenticated_update_provider_avatars"
  on storage.objects for update
  using (bucket_id = 'user-avatars' and auth.role() = 'authenticated')
  with check (bucket_id = 'user-avatars' and auth.role() = 'authenticated');

drop policy if exists "authenticated_delete_provider_avatars" on storage.objects;
create policy "authenticated_delete_provider_avatars"
  on storage.objects for delete
  using (bucket_id = 'user-avatars' and auth.role() = 'authenticated');

-- 7) Verification storage bucket must exist for Doctor/Hospital proof uploads.
insert into storage.buckets (id, name, public)
values ('seller-verification', 'seller-verification', true)
on conflict (id) do update set public = true;

drop policy if exists "public_read_provider_verification" on storage.objects;
create policy "public_read_provider_verification"
  on storage.objects for select
  using (bucket_id = 'seller-verification');

drop policy if exists "authenticated_upload_provider_verification" on storage.objects;
create policy "authenticated_upload_provider_verification"
  on storage.objects for insert
  with check (bucket_id = 'seller-verification' and auth.role() = 'authenticated');

drop policy if exists "authenticated_update_provider_verification" on storage.objects;
create policy "authenticated_update_provider_verification"
  on storage.objects for update
  using (bucket_id = 'seller-verification' and auth.role() = 'authenticated')
  with check (bucket_id = 'seller-verification' and auth.role() = 'authenticated');

drop policy if exists "authenticated_delete_provider_verification" on storage.objects;
create policy "authenticated_delete_provider_verification"
  on storage.objects for delete
  using (bucket_id = 'seller-verification' and auth.role() = 'authenticated');

-- Refresh PostgREST schema cache.
notify pgrst, 'reload schema';
