-- ============================================================
-- Medical Operations Upgrade — STEP 02 / MIGRATION 12
-- SINGLE PROVIDER VERIFICATION DECISION PATH
-- ============================================================


alter table public.seller_verifications drop constraint if exists seller_verifications_status_check;
alter table public.seller_verifications add constraint seller_verifications_status_check
  check (status in ('pending','under_review','approved','rejected'));

-- Applicants may only submit a pending application. They cannot forge admin review fields.
create or replace function public.enforce_provider_verification_submission()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if auth.uid()=new.user_id and not public.is_admin_or_above() then
    if tg_op='INSERT' then
      if exists(
        select 1 from public.seller_verifications sv
        where sv.user_id=auth.uid() and sv.status in ('pending','under_review')
      ) then
        raise exception 'An active verification application already exists.';
      end if;
      new.status:='pending';
      new.admin_note:=null;
    else
      if new.status is distinct from old.status then
        raise exception 'Verification status can only be changed by an Admin.';
      end if;
      if new.admin_note is distinct from old.admin_note then
        raise exception 'Admin review notes cannot be changed by the applicant.';
      end if;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_prevent_self_verification_status_change on public.seller_verifications;
drop trigger if exists trg_enforce_provider_verification_submission on public.seller_verifications;
create trigger trg_enforce_provider_verification_submission
  before insert or update on public.seller_verifications
  for each row execute procedure public.enforce_provider_verification_submission();

drop policy if exists "seller_verifications_insert_own" on public.seller_verifications;
create policy "seller_verifications_insert_own" on public.seller_verifications for insert with check (
  user_id=auth.uid()
  and status='pending'
  and admin_note is null
  and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role in ('doctor','hospital') and p.account_status='active')
);

-- Direct REST updates to profiles.seller_status are no longer a valid approval path.
create or replace function public.guard_provider_status_direct_write()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  if new.seller_status is not distinct from old.seller_status then return new; end if;
  if current_user in ('service_role','postgres','supabase_admin') then return new; end if;
  if coalesce(current_setting('app.bypass_role_guard',true),'false')='true' then return new; end if;
  raise exception 'Provider status must be changed through the verification workflow.';
end $$;
drop trigger if exists trg_guard_provider_status_direct_write on public.profiles;
create trigger trg_guard_provider_status_direct_write
  before update of seller_status on public.profiles
  for each row execute procedure public.guard_provider_status_direct_write();

create or replace function public.review_provider_verification(
  p_verification_id uuid,
  p_status text,
  p_admin_note text default null
)
returns public.seller_verifications
language plpgsql
security definer
set search_path=public
as $$
declare v public.seller_verifications;
begin
  if not public.is_admin_or_above() and not public.is_trusted_backend_context() then
    raise exception 'Admin access required.';
  end if;
  if p_status not in ('under_review','approved','rejected') then
    raise exception 'Invalid verification review status.';
  end if;

  select * into v from public.seller_verifications where id=p_verification_id for update;
  if v.id is null then raise exception 'Verification application not found.'; end if;

  if p_status='under_review' and v.status<>'pending' then
    raise exception 'Only a pending application can move to Under Review.';
  end if;
  if p_status in ('approved','rejected') and v.status<>'under_review' then
    raise exception 'Application must be Under Review before a final decision.';
  end if;
  if p_status='rejected' and nullif(btrim(coalesce(p_admin_note,'')),'') is null then
    raise exception 'Rejection reason is required.';
  end if;

  update public.seller_verifications
  set status=p_status,admin_note=case when p_status='under_review' then null else nullif(btrim(p_admin_note),'') end,updated_at=now()
  where id=p_verification_id
  returning * into v;
  return v;
end $$;
revoke all on function public.review_provider_verification(uuid,text,text) from public;
grant execute on function public.review_provider_verification(uuid,text,text) to authenticated,service_role;

-- Make sure verification decisions still synchronize profile status.
create or replace function public.sync_provider_verification_status()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status in ('approved','rejected') then
    perform set_config('app.bypass_role_guard','true',true);
    update public.profiles
      set seller_status=new.status
      where id=new.user_id and role in ('doctor','hospital');
  elsif new.status in ('pending','under_review') then
    perform set_config('app.bypass_role_guard','true',true);
    update public.profiles
      set seller_status='pending'
      where id=new.user_id and role in ('doctor','hospital') and seller_status<>'approved';
  end if;
  return new;
end $$;

notify pgrst, 'reload schema';
