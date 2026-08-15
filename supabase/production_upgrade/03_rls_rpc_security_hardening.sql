-- ============================================================
-- Production Upgrade V2 — STEP 03: RLS / RPC / STORAGE HARDENING
-- Idempotent. Preserves the current UI contract while closing known leaks.
-- ============================================================

-- Runtime caller helper. SECURITY DEFINER functions must not trust `current_user`,
-- because it becomes the function owner. JWT role/uid distinguish app callers from
-- service-role/direct trusted maintenance sessions.
create or replace function public.is_trusted_backend_context()
returns boolean
language sql
stable
set search_path=public
as $$
  select coalesce(auth.role(),'')='service_role'
     or (auth.uid() is null and auth.role() is null);
$$;
revoke all on function public.is_trusted_backend_context() from public;
grant execute on function public.is_trusted_backend_context() to anon,authenticated,service_role;

-- --------------------------------------------------------------------------
-- 1) Role/account guard. Admin can review provider status, but only Super Admin
--    can change role/account_status. Providers cannot self-approve.
-- --------------------------------------------------------------------------
create or replace function public.prevent_self_role_change()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  -- Hard invariant: the last active Super Admin cannot disappear.
  if old.role='super_admin' and old.account_status='active'
     and (new.role is distinct from 'super_admin' or new.account_status is distinct from 'active')
     and public.count_super_admins() <= 1 then
    raise exception 'The last active Super Admin cannot be demoted or banned.';
  end if;

  -- SQL editor / service-role remains the emergency/bootstrap path.
  if current_user in ('service_role','postgres','supabase_admin') then return new; end if;

  -- App clients cannot create a second Super Admin through profile updates.
  if new.role='super_admin' and old.role is distinct from 'super_admin' then
    raise exception 'Creating/transferring the Super Admin must use the trusted admin/bootstrap path.';
  end if;

  if auth.uid()=old.id
     and not public.is_super_admin()
     and coalesce(current_setting('app.bypass_role_guard',true),'false') <> 'true'
     and (
       new.role is distinct from old.role
       or new.seller_status is distinct from old.seller_status
       or new.account_status is distinct from old.account_status
     ) then
    raise exception 'Role, provider verification status and account status cannot be changed by yourself.';
  end if;

  if (new.role is distinct from old.role or new.account_status is distinct from old.account_status)
     and not public.is_super_admin() then
    raise exception 'Only the Super Admin can change role/account status.';
  end if;
  return new;
end $$;

drop trigger if exists trg_prevent_self_role_change on public.profiles;
create trigger trg_prevent_self_role_change
  before update on public.profiles
  for each row execute procedure public.prevent_self_role_change();

-- Verification status cannot be changed by the applicant.
create or replace function public.prevent_self_verification_status_change()
returns trigger language plpgsql set search_path=public as $$
begin
  if auth.uid()=old.user_id and not public.is_admin_or_above()
     and new.status is distinct from old.status then
    raise exception 'Verification status can only be changed by an Admin.';
  end if;
  return new;
end $$;

drop trigger if exists trg_prevent_self_verification_status_change on public.seller_verifications;
create trigger trg_prevent_self_verification_status_change
  before update on public.seller_verifications
  for each row execute procedure public.prevent_self_verification_status_change();

-- --------------------------------------------------------------------------
-- 2) Safe provider-only doctor chooser. Do NOT expose full profiles publicly.
-- --------------------------------------------------------------------------
create or replace function public.list_approved_doctors_for_provider()
returns table(id uuid, full_name text)
language sql security definer set search_path=public stable as $$
  select p.id, p.full_name
  from public.profiles p
  where p.role='doctor'
    and p.seller_status='approved'
    and p.account_status='active'
    and (
      public.is_admin_or_above()
      or exists(
        select 1 from public.profiles caller
        where caller.id=auth.uid()
          and caller.role in ('doctor','hospital')
          and caller.seller_status='approved'
          and caller.account_status='active'
      )
    )
  order by p.full_name nulls last;
$$;
revoke all on function public.list_approved_doctors_for_provider() from public;
grant execute on function public.list_approved_doctors_for_provider() to authenticated, service_role;

-- --------------------------------------------------------------------------
-- 3) Canonical RLS: profiles / shops / products / verification.
-- --------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.shops enable row level security;
alter table public.products enable row level security;
alter table public.product_images enable row level security;
alter table public.shop_gallery enable row level security;
alter table public.categories enable row level security;
alter table public.seller_verifications enable row level security;
alter table public.appointments enable row level security;
alter table public.blood_requests enable row level security;
alter table public.ambulance_services enable row level security;

-- profiles: never expose the complete row to anonymous users.
drop policy if exists "profiles_select_own_or_admin" on public.profiles;
drop policy if exists "profiles_select_approved_doctors" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "profiles_update_admin" on public.profiles;
create policy "profiles_select_own_or_admin" on public.profiles for select
  using (id=auth.uid() or public.is_admin_or_above());
create policy "profiles_update_own" on public.profiles for update
  using (id=auth.uid()) with check (id=auth.uid());
create policy "profiles_update_admin" on public.profiles for update
  using (public.is_admin_or_above()) with check (public.is_admin_or_above());

-- Shops are public only when both the row and provider account are public.
drop policy if exists "shops_select_public_active" on public.shops;
drop policy if exists "shops_insert_approved_seller" on public.shops;
drop policy if exists "shops_insert_approved_provider" on public.shops;
drop policy if exists "shops_insert_provider_profile" on public.shops;
drop policy if exists "shops_update_own_or_admin" on public.shops;
drop policy if exists "shops_delete_admin" on public.shops;
create policy "shops_select_public_active" on public.shops for select using (
  (is_active=true and public.is_provider_account_public(owner_id))
  or owner_id=auth.uid()
  or public.is_admin_or_above()
);
-- Provider may save a draft chamber before verification; RLS hides it publicly.
create policy "shops_insert_provider_profile" on public.shops for insert with check (
  owner_id=auth.uid()
  and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role in ('doctor','hospital') and p.account_status='active')
);
create policy "shops_update_own_or_admin" on public.shops for update
  using (owner_id=auth.uid() or public.is_admin_or_above())
  with check (owner_id=auth.uid() or public.is_admin_or_above());
create policy "shops_delete_admin" on public.shops for delete using (public.is_admin_or_above());

-- Product/Doctor profile public visibility must validate BOTH doctor and provider.
drop policy if exists "products_select_public_active" on public.products;
drop policy if exists "products_insert_own_shop" on public.products;
drop policy if exists "products_insert_own_provider_shop" on public.products;
drop policy if exists "products_update_own_or_admin" on public.products;
drop policy if exists "products_delete_own_or_admin" on public.products;
create policy "products_select_public_active" on public.products for select using (
  (
    is_active=true
    and public.is_doctor_account_public(doctor_id)
    and exists(
      select 1 from public.shops s
      where s.id=shop_id and s.is_active=true and public.is_provider_account_public(s.owner_id)
    )
  )
  or public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
);
create policy "products_insert_own_provider_shop" on public.products for insert with check (
  exists(
    select 1 from public.shops s
    join public.profiles owner on owner.id=s.owner_id
    where s.id=shop_id and s.owner_id=auth.uid()
      and owner.role in ('doctor','hospital')
      and owner.seller_status='approved' and owner.account_status='active'
  )
  and public.is_doctor_account_public(doctor_id)
);
create policy "products_update_own_or_admin" on public.products for update using (
  public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
) with check (
  public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
);
create policy "products_delete_own_or_admin" on public.products for delete using (
  public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
);

-- Product images: public only for a public product; owner/admin can manage.
drop policy if exists "product_images_select" on public.product_images;
drop policy if exists "product_images_write_owner_or_admin" on public.product_images;
create policy "product_images_select" on public.product_images for select using (
  public.is_admin_or_above()
  or exists(
    select 1 from public.products pr join public.shops s on s.id=pr.shop_id
    where pr.id=product_id
      and (
        (pr.is_active=true and public.is_doctor_account_public(pr.doctor_id) and s.is_active=true and public.is_provider_account_public(s.owner_id))
        or s.owner_id=auth.uid()
      )
  )
);
create policy "product_images_write_owner_or_admin" on public.product_images for all using (
  public.is_admin_or_above()
  or exists(select 1 from public.products pr join public.shops s on s.id=pr.shop_id where pr.id=product_id and s.owner_id=auth.uid())
) with check (
  public.is_admin_or_above()
  or exists(select 1 from public.products pr join public.shops s on s.id=pr.shop_id where pr.id=product_id and s.owner_id=auth.uid())
);

-- Shop gallery follows the shop's provider visibility.
drop policy if exists "shop_gallery_select" on public.shop_gallery;
drop policy if exists "shop_gallery_write_owner_or_admin" on public.shop_gallery;
create policy "shop_gallery_select" on public.shop_gallery for select using (
  public.is_admin_or_above()
  or exists(
    select 1 from public.shops s where s.id=shop_id
      and ((s.is_active=true and public.is_provider_account_public(s.owner_id)) or s.owner_id=auth.uid())
  )
);
create policy "shop_gallery_write_owner_or_admin" on public.shop_gallery for all using (
  public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
) with check (
  public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
);

-- Categories: public read; admin write.
drop policy if exists "categories_select_all" on public.categories;
drop policy if exists "categories_write_admin" on public.categories;
create policy "categories_select_all" on public.categories for select using (true);
create policy "categories_write_admin" on public.categories for all
  using (public.is_admin_or_above()) with check (public.is_admin_or_above());

-- Verification: only applicant and admins can read; applicant can edit only pending.
drop policy if exists "seller_verifications_select_own_or_admin" on public.seller_verifications;
drop policy if exists "seller_verifications_insert_own" on public.seller_verifications;
drop policy if exists "seller_verifications_update_own_or_admin" on public.seller_verifications;
create policy "seller_verifications_select_own_or_admin" on public.seller_verifications for select
  using (user_id=auth.uid() or public.is_admin_or_above());
create policy "seller_verifications_insert_own" on public.seller_verifications for insert with check (
  user_id=auth.uid()
  and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role in ('doctor','hospital') and p.account_status='active')
);
create policy "seller_verifications_update_own_or_admin" on public.seller_verifications for update using (
  (user_id=auth.uid() and status='pending') or public.is_admin_or_above()
) with check (
  (user_id=auth.uid() and status='pending') or public.is_admin_or_above()
);

-- Appointment participants only. No client DELETE policy: cancellation is an update.
drop policy if exists "appointments_select_participant_or_admin" on public.appointments;
drop policy if exists "appointments_insert_patient" on public.appointments;
drop policy if exists "appointments_update_participant_or_admin" on public.appointments;
create policy "appointments_select_participant_or_admin" on public.appointments for select
  using (patient_id=auth.uid() or doctor_id=auth.uid() or public.is_admin_or_above());
create policy "appointments_insert_patient" on public.appointments for insert with check
  (patient_id=auth.uid());
create policy "appointments_update_participant_or_admin" on public.appointments for update
  using (patient_id=auth.uid() or doctor_id=auth.uid() or public.is_admin_or_above())
  with check (patient_id=auth.uid() or doctor_id=auth.uid() or public.is_admin_or_above());

-- Blood request participant policies.
drop policy if exists "blood_requests_select_participants" on public.blood_requests;
drop policy if exists "blood_requests_update_participants" on public.blood_requests;
drop policy if exists "blood_requests_delete_requester" on public.blood_requests;
create policy "blood_requests_select_participants" on public.blood_requests for select
  using (requester_id=auth.uid() or donor_id=auth.uid() or public.is_admin_or_above());
create policy "blood_requests_update_participants" on public.blood_requests for update
  using (requester_id=auth.uid() or donor_id=auth.uid() or public.is_admin_or_above())
  with check (requester_id=auth.uid() or donor_id=auth.uid() or public.is_admin_or_above());
create policy "blood_requests_delete_requester" on public.blood_requests for delete
  using (requester_id=auth.uid() or public.is_admin_or_above());

-- Blood requests: participants can see the row, but status transitions are role-scoped.
create or replace function public.guard_blood_request_update()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if public.is_trusted_backend_context() or public.is_admin_or_above() then
    new.updated_at:=now();
    return new;
  end if;
  if auth.uid() is null or auth.uid() not in (old.requester_id,old.donor_id) then
    raise exception 'You are not allowed to update this blood request.';
  end if;
  if new.requester_id<>old.requester_id or new.donor_id<>old.donor_id
     or new.blood_group is distinct from old.blood_group
     or new.patient_name is distinct from old.patient_name
     or new.patient_phone is distinct from old.patient_phone
     or new.needed_date is distinct from old.needed_date
     or new.needed_time is distinct from old.needed_time
     or new.reason is distinct from old.reason
     or new.hospital_name is distinct from old.hospital_name
     or new.location_text is distinct from old.location_text then
    raise exception 'Blood request details cannot be changed after submission.';
  end if;
  if auth.uid()=old.requester_id then
    if new.status is distinct from old.status and not (new.status='cancelled' and old.status in ('pending','accepted')) then
      raise exception 'Requester can only cancel an active request.';
    end if;
  elsif auth.uid()=old.donor_id then
    if new.status is distinct from old.status and not (
      (old.status='pending' and new.status in ('accepted','declined'))
      or (old.status='accepted' and new.status='completed')
    ) then
      raise exception 'Invalid donor status transition.';
    end if;
  end if;
  new.updated_at:=now();
  return new;
end $$;
drop trigger if exists trg_guard_blood_request_update on public.blood_requests;
create trigger trg_guard_blood_request_update before update on public.blood_requests
  for each row execute procedure public.guard_blood_request_update();

-- Public ambulance list only exposes admin-verified entries; Admin sees/manages all.
drop policy if exists "ambulance_public_read" on public.ambulance_services;
drop policy if exists "ambulance_admin_insert" on public.ambulance_services;
drop policy if exists "ambulance_admin_update" on public.ambulance_services;
drop policy if exists "ambulance_admin_delete" on public.ambulance_services;
create policy "ambulance_public_read" on public.ambulance_services for select
  using (is_verified=true or public.is_admin_or_above());
create policy "ambulance_admin_insert" on public.ambulance_services for insert
  with check (public.is_admin_or_above());
create policy "ambulance_admin_update" on public.ambulance_services for update
  using (public.is_admin_or_above()) with check (public.is_admin_or_above());
create policy "ambulance_admin_delete" on public.ambulance_services for delete
  using (public.is_admin_or_above());

-- --------------------------------------------------------------------------
-- 4) Storage: public presentation media remains public, writes are owner-folder
--    scoped. Verification evidence becomes PRIVATE.
-- --------------------------------------------------------------------------
insert into storage.buckets(id,name,public,file_size_limit) values
  ('shop-logos','shop-logos',true,1048576),
  ('shop-banners','shop-banners',true,1048576),
  ('shop-gallery','shop-gallery',true,1048576),
  ('product-images','product-images',true,1048576),
  ('user-avatars','user-avatars',true,1048576),
  ('site-assets','site-assets',true,1048576),
  ('seller-verification','seller-verification',false,1048576),
  ('verification-docs','verification-docs',false,1048576)
on conflict(id) do update set public=excluded.public, file_size_limit=excluded.file_size_limit;

-- Remove known historical broad policies before canonical policies are created.
drop policy if exists "public_read_marketplace_media" on storage.objects;
drop policy if exists "authenticated_upload_marketplace_media" on storage.objects;
drop policy if exists "authenticated_update_own_media" on storage.objects;
drop policy if exists "authenticated_delete_own_media" on storage.objects;
drop policy if exists "admin_manage_site_assets" on storage.objects;
drop policy if exists "public_read_user_avatars" on storage.objects;
drop policy if exists "authenticated_upload_own_avatar" on storage.objects;
drop policy if exists "authenticated_update_own_avatar" on storage.objects;
drop policy if exists "authenticated_delete_own_avatar" on storage.objects;
drop policy if exists "public_read_provider_shop_gallery" on storage.objects;
drop policy if exists "authenticated_upload_provider_shop_gallery" on storage.objects;
drop policy if exists "authenticated_update_provider_shop_gallery" on storage.objects;
drop policy if exists "authenticated_delete_provider_shop_gallery" on storage.objects;
drop policy if exists "public_read_provider_avatars" on storage.objects;
drop policy if exists "authenticated_upload_provider_avatars" on storage.objects;
drop policy if exists "authenticated_update_provider_avatars" on storage.objects;
drop policy if exists "authenticated_delete_provider_avatars" on storage.objects;
drop policy if exists "public_read_provider_verification" on storage.objects;
drop policy if exists "authenticated_upload_provider_verification" on storage.objects;
drop policy if exists "authenticated_update_provider_verification" on storage.objects;
drop policy if exists "authenticated_delete_provider_verification" on storage.objects;
drop policy if exists "public_read_seller_verification" on storage.objects;
drop policy if exists "authenticated_upload_seller_verification" on storage.objects;
drop policy if exists "authenticated_update_own_seller_verification" on storage.objects;
drop policy if exists "authenticated_delete_own_seller_verification" on storage.objects;

-- Clean canonical policy names too, making reruns safe.
drop policy if exists "media_public_read" on storage.objects;
drop policy if exists "media_owner_insert" on storage.objects;
drop policy if exists "media_owner_update" on storage.objects;
drop policy if exists "media_owner_delete" on storage.objects;
drop policy if exists "site_assets_admin_manage" on storage.objects;
drop policy if exists "verification_owner_admin_read" on storage.objects;
drop policy if exists "verification_owner_insert" on storage.objects;
drop policy if exists "verification_owner_update" on storage.objects;
drop policy if exists "verification_owner_delete" on storage.objects;

create policy "media_public_read" on storage.objects for select using (
  bucket_id in ('shop-logos','shop-banners','shop-gallery','product-images','user-avatars','site-assets')
);
create policy "media_owner_insert" on storage.objects for insert with check (
  bucket_id in ('shop-logos','shop-banners','shop-gallery','product-images','user-avatars')
  and auth.role()='authenticated'
  and (storage.foldername(name))[1]=auth.uid()::text
);
create policy "media_owner_update" on storage.objects for update using (
  bucket_id in ('shop-logos','shop-banners','shop-gallery','product-images','user-avatars')
  and (storage.foldername(name))[1]=auth.uid()::text
) with check (
  bucket_id in ('shop-logos','shop-banners','shop-gallery','product-images','user-avatars')
  and (storage.foldername(name))[1]=auth.uid()::text
);
create policy "media_owner_delete" on storage.objects for delete using (
  bucket_id in ('shop-logos','shop-banners','shop-gallery','product-images','user-avatars')
  and (storage.foldername(name))[1]=auth.uid()::text
);
create policy "site_assets_admin_manage" on storage.objects for all
  using (bucket_id='site-assets' and public.is_admin_or_above())
  with check (bucket_id='site-assets' and public.is_admin_or_above());

-- Private verification files: owner/admin may read; owner-folder writes only.
create policy "verification_owner_admin_read" on storage.objects for select using (
  bucket_id in ('seller-verification','verification-docs')
  and (
    (storage.foldername(name))[1]=auth.uid()::text
    or public.is_admin_or_above()
  )
);
create policy "verification_owner_insert" on storage.objects for insert with check (
  bucket_id in ('seller-verification','verification-docs')
  and auth.role()='authenticated'
  and (storage.foldername(name))[1]=auth.uid()::text
);
create policy "verification_owner_update" on storage.objects for update using (
  bucket_id in ('seller-verification','verification-docs')
  and ((storage.foldername(name))[1]=auth.uid()::text or public.is_admin_or_above())
) with check (
  bucket_id in ('seller-verification','verification-docs')
  and ((storage.foldername(name))[1]=auth.uid()::text or public.is_admin_or_above())
);
create policy "verification_owner_delete" on storage.objects for delete using (
  bucket_id in ('seller-verification','verification-docs')
  and ((storage.foldername(name))[1]=auth.uid()::text or public.is_admin_or_above())
);

notify pgrst, 'reload schema';
