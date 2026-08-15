-- ============================================================
-- Medical Operations Upgrade — STEP 03 / MIGRATION 13
-- HOSPITAL <-> DOCTOR INVITATION / ACCEPTANCE FLOW
-- ============================================================

alter table public.doctor_provider_links
  add column if not exists invited_by uuid references public.profiles(id) on delete set null,
  add column if not exists invitation_message text,
  add column if not exists responded_at timestamptz,
  add column if not exists inactive_at timestamptz;

-- Existing approved relationships remain valid. New hospital relationships must start pending.
create or replace function public.guard_doctor_provider_link_change()
returns trigger
language plpgsql
set search_path=public
as $$
declare
  v_owner uuid;
  v_owner_role text;
  v_owner_status text;
  v_owner_account text;
begin
  if current_user in ('service_role','postgres','supabase_admin') or public.is_admin_or_above() then
    return new;
  end if;

  if tg_op='INSERT' then
    select s.owner_id,p.role,p.seller_status,p.account_status into v_owner,v_owner_role,v_owner_status,v_owner_account
    from public.shops s join public.profiles p on p.id=s.owner_id
    where s.id=new.provider_id;
    if v_owner is null then raise exception 'Provider not found.'; end if;
    if auth.uid()=v_owner and v_owner_role='hospital' then
      if v_owner_status<>'approved' or v_owner_account<>'active' then raise exception 'Approved active Hospital account required.'; end if;
      if new.status<>'pending' then raise exception 'Hospital invitations must start as pending.'; end if;
      new.invited_by:=auth.uid();
    elsif auth.uid()=v_owner and v_owner_role='doctor' and new.doctor_id=auth.uid() then
      new.status:='approved';
      new.responded_at:=coalesce(new.responded_at,now());
    else
      raise exception 'You cannot create this Doctor affiliation.';
    end if;
    return new;
  end if;

  select s.owner_id,p.role into v_owner,v_owner_role
  from public.shops s join public.profiles p on p.id=s.owner_id
  where s.id=old.provider_id;
  if v_owner is null then raise exception 'Provider not found.'; end if;

  if new.doctor_id is distinct from old.doctor_id or new.provider_id is distinct from old.provider_id then
    raise exception 'Doctor/provider identity cannot be changed.';
  end if;

  if auth.uid()=old.doctor_id then
    if old.status='pending' and new.status in ('approved','rejected') then
      new.responded_at:=now();
      return new;
    end if;
    if old.status='approved' and new.status='inactive' then
      new.inactive_at:=now();
      return new;
    end if;
    if new.status is not distinct from old.status then return new; end if;
    raise exception 'Doctor can only accept/reject a pending invitation or leave an approved affiliation.';
  end if;

  if auth.uid()=v_owner then
    if old.status in ('rejected','inactive') and new.status='pending' then
      new.invited_by:=auth.uid(); new.responded_at:=null; new.inactive_at:=null;
      return new;
    end if;
    if old.status='approved' and new.status='inactive' then
      new.inactive_at:=now();
      return new;
    end if;
    if new.status is not distinct from old.status then return new; end if;
    raise exception 'Provider cannot approve its own Doctor invitation.';
  end if;

  raise exception 'You cannot update this Doctor affiliation.';
end $$;

drop trigger if exists trg_guard_doctor_provider_link_change on public.doctor_provider_links;
create trigger trg_guard_doctor_provider_link_change
  before insert or update on public.doctor_provider_links
  for each row execute procedure public.guard_doctor_provider_link_change();

-- Tighten table policies. Approval is a Doctor decision, not a Hospital decision.
drop policy if exists "doctor_provider_links_public_read" on public.doctor_provider_links;
drop policy if exists "doctor_provider_links_participants" on public.doctor_provider_links;
drop policy if exists "doctor_provider_links_provider_manage" on public.doctor_provider_links;
drop policy if exists "doctor_provider_links_admin_all" on public.doctor_provider_links;
drop policy if exists "doctor_provider_links_participant_insert" on public.doctor_provider_links;
drop policy if exists "doctor_provider_links_participant_update" on public.doctor_provider_links;
create policy "doctor_provider_links_public_read" on public.doctor_provider_links for select using(
  status='approved'
  and public.is_doctor_account_public(doctor_id)
  and exists(select 1 from public.shops s where s.id=provider_id and s.is_active=true and public.is_provider_account_public(s.owner_id))
);
create policy "doctor_provider_links_participants" on public.doctor_provider_links for select using(
  doctor_id=auth.uid()
  or exists(select 1 from public.shops s where s.id=provider_id and s.owner_id=auth.uid())
  or public.is_admin_or_above()
);
create policy "doctor_provider_links_participant_insert" on public.doctor_provider_links for insert with check(
  public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=provider_id and s.owner_id=auth.uid())
);
create policy "doctor_provider_links_participant_update" on public.doctor_provider_links for update using(
  public.is_admin_or_above()
  or doctor_id=auth.uid()
  or exists(select 1 from public.shops s where s.id=provider_id and s.owner_id=auth.uid())
) with check(
  public.is_admin_or_above()
  or doctor_id=auth.uid()
  or exists(select 1 from public.shops s where s.id=provider_id and s.owner_id=auth.uid())
);
create policy "doctor_provider_links_admin_all" on public.doctor_provider_links for delete using(public.is_admin_or_above());

-- Product/Doctor listing now requires an accepted affiliation at Hospital-owned providers.
-- Public visibility also enforces the accepted affiliation, so historical/disabled
-- Hospital rows cannot remain visible merely because products.is_active=true.
drop policy if exists "products_select_public_active" on public.products;
create policy "products_select_public_active" on public.products for select using (
  (
    is_active=true
    and public.is_doctor_account_public(doctor_id)
    and exists(
      select 1
      from public.shops s
      join public.profiles owner on owner.id=s.owner_id
      where s.id=shop_id and s.is_active=true and public.is_provider_account_public(s.owner_id)
        and (
          (owner.role='doctor' and owner.id=doctor_id)
          or (
            owner.role='hospital'
            and exists(select 1 from public.doctor_provider_links l
                       where l.doctor_id=products.doctor_id and l.provider_id=products.shop_id and l.status='approved')
          )
        )
    )
  )
  or public.is_admin_or_above()
  or exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
);

create or replace function public.set_product_doctor_id()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_owner uuid;
  v_owner_role text;
begin
  select s.owner_id,p.role into v_owner,v_owner_role
  from public.shops s join public.profiles p on p.id=s.owner_id
  where s.id=new.shop_id;

  if v_owner is null then raise exception 'A valid Chamber/Hospital is required.'; end if;
  if new.doctor_id is null and v_owner_role='doctor' then new.doctor_id:=v_owner; end if;
  if new.doctor_id is null then raise exception 'ডাক্তারের প্রোফাইলের জন্য ডাক্তার নির্বাচন করতে হবে।'; end if;

  if not exists(select 1 from public.profiles p where p.id=new.doctor_id and p.role='doctor' and p.seller_status='approved' and p.account_status='active') then
    raise exception 'শুধু অনুমোদিত ডাক্তার অ্যাকাউন্টকে Doctor Profile হিসেবে যোগ করা যাবে।';
  end if;
  if not exists(select 1 from public.profiles p where p.id=v_owner and p.role in ('doctor','hospital') and p.seller_status='approved' and p.account_status='active') then
    raise exception 'অনুমোদিত চেম্বার/হাসপাতাল প্রয়োজন।';
  end if;
  if v_owner_role='doctor' and new.doctor_id<>v_owner then
    raise exception 'A Doctor-owned chamber can only publish its owner Doctor profile.';
  end if;
  if v_owner_role='hospital' and not exists(
    select 1 from public.doctor_provider_links l
    where l.doctor_id=new.doctor_id and l.provider_id=new.shop_id and l.status='approved'
  ) then
    raise exception 'Doctor must accept the Hospital invitation before the profile can be published.';
  end if;
  if exists(select 1 from public.products x where x.doctor_id=new.doctor_id and x.shop_id=new.shop_id and x.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)) then
    raise exception 'This Doctor is already listed at this provider.';
  end if;
  return new;
end $$;

create or replace function public.sync_product_doctor_provider_link()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_owner_role text;
begin
  select p.role into v_owner_role from public.shops s join public.profiles p on p.id=s.owner_id where s.id=new.shop_id;
  if v_owner_role='doctor' then
    insert into public.doctor_provider_links(
      doctor_id,provider_id,product_id,status,consultation_fee,visiting_days,visiting_time,responded_at,updated_at
    ) values(
      new.doctor_id,new.shop_id,new.id,'approved',coalesce(new.consultation_fee,new.price),new.visiting_days,new.visiting_time,now(),now()
    ) on conflict(doctor_id,provider_id) do update set
      product_id=excluded.product_id,status='approved',consultation_fee=excluded.consultation_fee,
      visiting_days=excluded.visiting_days,visiting_time=excluded.visiting_time,updated_at=now();
  else
    update public.doctor_provider_links set
      product_id=new.id,
      consultation_fee=coalesce(new.consultation_fee,new.price),
      visiting_days=new.visiting_days,
      visiting_time=new.visiting_time,
      updated_at=now()
    where doctor_id=new.doctor_id and provider_id=new.shop_id and status='approved';
  end if;
  return new;
end $$;

create or replace function public.invite_doctor_to_provider(p_doctor_id uuid,p_message text default null)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare v_shop uuid; v_role text; v_provider_status text; v_account_status text; v_id uuid; v_status text;
begin
  if auth.uid() is null then raise exception 'Login required.'; end if;
  select s.id,p.role,p.seller_status,p.account_status into v_shop,v_role,v_provider_status,v_account_status from public.shops s join public.profiles p on p.id=s.owner_id where s.owner_id=auth.uid();
  if v_shop is null or v_role<>'hospital' or v_provider_status<>'approved' or v_account_status<>'active' then raise exception 'Approved active Hospital/Chamber account required.'; end if;
  if not exists(select 1 from public.profiles where id=p_doctor_id and role='doctor' and seller_status='approved' and account_status='active') then
    raise exception 'Approved active Doctor not found.';
  end if;
  select id,status into v_id,v_status from public.doctor_provider_links where doctor_id=p_doctor_id and provider_id=v_shop;
  if v_status='approved' then return v_id; end if;
  if v_id is null then
    insert into public.doctor_provider_links(doctor_id,provider_id,status,invited_by,invitation_message,created_at,updated_at)
    values(p_doctor_id,v_shop,'pending',auth.uid(),nullif(btrim(p_message),''),now(),now()) returning id into v_id;
  else
    update public.doctor_provider_links set status='pending',invited_by=auth.uid(),invitation_message=nullif(btrim(p_message),''),responded_at=null,inactive_at=null,updated_at=now()
    where id=v_id;
  end if;
  return v_id;
end $$;
revoke all on function public.invite_doctor_to_provider(uuid,text) from public;
grant execute on function public.invite_doctor_to_provider(uuid,text) to authenticated,service_role;

create or replace function public.respond_doctor_provider_invitation(p_link_id uuid,p_accept boolean)
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  if auth.uid() is null then raise exception 'Login required.'; end if;
  update public.doctor_provider_links
  set status=case when p_accept then 'approved' else 'rejected' end,responded_at=now(),updated_at=now()
  where id=p_link_id and doctor_id=auth.uid() and status='pending';
  if not found then raise exception 'Pending invitation not found.'; end if;
end $$;
revoke all on function public.respond_doctor_provider_invitation(uuid,boolean) from public;
grant execute on function public.respond_doctor_provider_invitation(uuid,boolean) to authenticated,service_role;

create or replace function public.leave_doctor_provider_affiliation(p_link_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'Login required.'; end if;
  update public.doctor_provider_links set status='inactive',inactive_at=now(),updated_at=now()
  where id=p_link_id and status='approved'
    and (doctor_id=auth.uid() or exists(select 1 from public.shops s where s.id=provider_id and s.owner_id=auth.uid()));
  if not found then raise exception 'Active affiliation not found.'; end if;
end $$;
revoke all on function public.leave_doctor_provider_affiliation(uuid) from public;
grant execute on function public.leave_doctor_provider_affiliation(uuid) to authenticated,service_role;

create or replace function public.list_my_provider_invitations()
returns table(link_id uuid,provider_id uuid,provider_name text,status text,invitation_message text,created_at timestamptz,responded_at timestamptz)
language sql stable security definer set search_path=public as $$
  select l.id,l.provider_id,coalesce(s.chamber_name,s.shop_name),l.status,l.invitation_message,l.created_at,l.responded_at
  from public.doctor_provider_links l join public.shops s on s.id=l.provider_id
  where l.doctor_id=auth.uid()
  order by case l.status when 'pending' then 0 when 'approved' then 1 else 2 end,l.updated_at desc;
$$;
revoke all on function public.list_my_provider_invitations() from public;
grant execute on function public.list_my_provider_invitations() to authenticated,service_role;

create or replace function public.list_provider_doctor_links()
returns table(link_id uuid,doctor_id uuid,doctor_name text,status text,invitation_message text,created_at timestamptz,responded_at timestamptz,product_id uuid)
language plpgsql stable security definer set search_path=public as $$
declare v_shop uuid;
begin
  select id into v_shop from public.shops where owner_id=auth.uid();
  if v_shop is null then return; end if;
  return query
    select l.id,l.doctor_id,p.full_name,l.status,l.invitation_message,l.created_at,l.responded_at,l.product_id
    from public.doctor_provider_links l join public.profiles p on p.id=l.doctor_id
    where l.provider_id=v_shop order by case l.status when 'pending' then 0 when 'approved' then 1 else 2 end,l.updated_at desc;
end $$;
revoke all on function public.list_provider_doctor_links() from public;
grant execute on function public.list_provider_doctor_links() to authenticated,service_role;

create or replace function public.search_invitable_doctors_for_provider(p_query text default null,p_limit integer default 50)
returns table(id uuid,full_name text,phone text,existing_status text)
language plpgsql stable security definer set search_path=public as $$
declare v_shop uuid; v_role text; v_provider_status text; v_account_status text;
begin
  select s.id,p.role,p.seller_status,p.account_status into v_shop,v_role,v_provider_status,v_account_status from public.shops s join public.profiles p on p.id=s.owner_id where s.owner_id=auth.uid();
  if v_shop is null or v_role<>'hospital' or v_provider_status<>'approved' or v_account_status<>'active' then return; end if;
  return query
  select d.id,d.full_name,d.phone,l.status
  from public.profiles d
  left join public.doctor_provider_links l on l.doctor_id=d.id and l.provider_id=v_shop
  where d.role='doctor' and d.seller_status='approved' and d.account_status='active'
    and (p_query is null or btrim(p_query)='' or coalesce(d.full_name,'') ilike '%'||p_query||'%' or coalesce(d.phone,'') ilike '%'||p_query||'%')
  order by d.full_name nulls last limit greatest(1,least(coalesce(p_limit,50),100));
end $$;
revoke all on function public.search_invitable_doctors_for_provider(text,integer) from public;
grant execute on function public.search_invitable_doctors_for_provider(text,integer) to authenticated,service_role;

-- Existing ProductEdit caller: now returns only Doctors who accepted this provider.
create or replace function public.list_approved_doctors_for_provider()
returns table(id uuid, full_name text)
language plpgsql stable security definer set search_path=public as $$
declare v_shop uuid; v_role text;
begin
  select s.id,p.role into v_shop,v_role from public.shops s join public.profiles p on p.id=s.owner_id where s.owner_id=auth.uid();
  if v_shop is null then return; end if;
  if v_role='doctor' then
    return query select p.id,p.full_name from public.profiles p where p.id=auth.uid() and p.role='doctor' and p.seller_status='approved';
  else
    return query
    select p.id,p.full_name from public.doctor_provider_links l join public.profiles p on p.id=l.doctor_id
    where l.provider_id=v_shop and l.status='approved' and p.role='doctor' and p.seller_status='approved' and p.account_status='active'
    order by p.full_name nulls last;
  end if;
end $$;
revoke all on function public.list_approved_doctors_for_provider() from public;
grant execute on function public.list_approved_doctors_for_provider() to authenticated,service_role;

create index if not exists idx_doctor_provider_links_pending_doctor on public.doctor_provider_links(doctor_id,status,updated_at desc);
create index if not exists idx_doctor_provider_links_provider_updated on public.doctor_provider_links(provider_id,status,updated_at desc);

notify pgrst, 'reload schema';
