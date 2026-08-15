-- ============================================================
-- Production Upgrade V2 — STEP 05: DOCTOR <-> PROVIDER MODEL
-- Keeps products/shops frontend-compatible while normalizing affiliations.
-- ============================================================

create table if not exists public.doctor_provider_links (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles(id) on delete cascade,
  provider_id uuid not null references public.shops(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  status text not null default 'approved',
  consultation_fee numeric(12,2),
  visiting_days text,
  visiting_time text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint doctor_provider_links_status_check check(status in ('pending','approved','rejected','inactive')),
  constraint doctor_provider_links_doctor_provider_unique unique(doctor_id,provider_id)
);

-- Historical Product = Doctor Profile rows become approved affiliations.
insert into public.doctor_provider_links(doctor_id,provider_id,product_id,status,consultation_fee,visiting_days,visiting_time)
select p.doctor_id,p.shop_id,p.id,'approved',coalesce(p.consultation_fee,p.price),p.visiting_days,p.visiting_time
from public.products p
join public.profiles d on d.id=p.doctor_id and d.role='doctor'
join public.shops s on s.id=p.shop_id
where p.doctor_id is not null and p.shop_id is not null
on conflict(doctor_id,provider_id) do update set
  product_id=excluded.product_id,
  consultation_fee=excluded.consultation_fee,
  visiting_days=excluded.visiting_days,
  visiting_time=excluded.visiting_time,
  updated_at=now();

-- Remove marketplace-era global one-profile restriction. Same doctor may appear at many providers.
drop index if exists public.ux_one_doctor_profile_per_owner;
do $$ begin
  if to_regclass('public.ux_products_doctor_shop') is null and not exists(
    select 1 from public.products where doctor_id is not null and shop_id is not null group by doctor_id,shop_id having count(*)>1
  ) then
    execute 'create unique index ux_products_doctor_shop on public.products(doctor_id,shop_id) where doctor_id is not null and shop_id is not null';
  end if;
end $$;
create index if not exists idx_doctor_provider_links_provider_status on public.doctor_provider_links(provider_id,status);
create index if not exists idx_doctor_provider_links_doctor_status on public.doctor_provider_links(doctor_id,status);

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
  if exists(select 1 from public.products x where x.doctor_id=new.doctor_id and x.shop_id=new.shop_id and x.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)) then
    raise exception 'This Doctor is already listed at this provider.';
  end if;
  return new;
end $$;

drop trigger if exists trg_set_product_doctor_id on public.products;
create trigger trg_set_product_doctor_id
  before insert or update of doctor_id,shop_id on public.products
  for each row execute procedure public.set_product_doctor_id();

create or replace function public.sync_product_doctor_provider_link()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.doctor_provider_links(
    doctor_id,provider_id,product_id,status,consultation_fee,visiting_days,visiting_time,updated_at
  ) values(
    new.doctor_id,new.shop_id,new.id,'approved',coalesce(new.consultation_fee,new.price),new.visiting_days,new.visiting_time,now()
  )
  on conflict(doctor_id,provider_id) do update set
    product_id=excluded.product_id,
    status=case when public.doctor_provider_links.status in ('rejected','inactive') then public.doctor_provider_links.status else 'approved' end,
    consultation_fee=excluded.consultation_fee,
    visiting_days=excluded.visiting_days,
    visiting_time=excluded.visiting_time,
    updated_at=now();
  return new;
end $$;

drop trigger if exists trg_sync_product_doctor_provider_link on public.products;
create trigger trg_sync_product_doctor_provider_link
  after insert or update of doctor_id,shop_id,consultation_fee,price,visiting_days,visiting_time on public.products
  for each row execute procedure public.sync_product_doctor_provider_link();

alter table public.doctor_provider_links enable row level security;
drop policy if exists "doctor_provider_links_public_read" on public.doctor_provider_links;
drop policy if exists "doctor_provider_links_participants" on public.doctor_provider_links;
drop policy if exists "doctor_provider_links_provider_manage" on public.doctor_provider_links;
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
create policy "doctor_provider_links_provider_manage" on public.doctor_provider_links for all using(
  exists(select 1 from public.shops s where s.id=provider_id and s.owner_id=auth.uid()) or public.is_admin_or_above()
) with check(
  exists(select 1 from public.shops s where s.id=provider_id and s.owner_id=auth.uid()) or public.is_admin_or_above()
);

notify pgrst, 'reload schema';
