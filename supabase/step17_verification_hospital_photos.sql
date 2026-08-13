-- Step 17: Doctor/Hospital verification + hospital profile photos
-- Safe to run after the previous V1 SQL migrations.

alter table public.seller_verifications
  add column if not exists verification_type text not null default 'bmdc';

alter table public.seller_verifications
  add column if not exists trade_license_no text;

alter table public.seller_verifications
  add column if not exists trade_license_url text;

-- Doctor NID is optional; only the front side is needed when BMDC online verification is unavailable.
-- Hospital can choose BMDC, Trade License, or NID as its verification proof.

alter table public.shops
  add column if not exists hospital_photo_urls text[] not null default '{}';

create index if not exists idx_seller_verifications_verification_type
  on public.seller_verifications (verification_type);

-- Re-create policies safely where older migrations may already contain them.
drop policy if exists "seller_verifications_select_own_or_admin" on public.seller_verifications;
create policy "seller_verifications_select_own_or_admin"
  on public.seller_verifications for select
  using (user_id = auth.uid() or public.is_super_admin());

drop policy if exists "seller_verifications_insert_own" on public.seller_verifications;
create policy "seller_verifications_insert_own"
  on public.seller_verifications for insert
  with check (user_id = auth.uid());

drop policy if exists "seller_verifications_update_own_or_admin" on public.seller_verifications;
create policy "seller_verifications_update_own_or_admin"
  on public.seller_verifications for update
  using (user_id = auth.uid() or public.is_super_admin())
  with check (user_id = auth.uid() or public.is_super_admin());
