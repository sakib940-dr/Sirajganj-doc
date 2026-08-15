-- ============================================================
-- Production Upgrade V2 — STEP 09: DATA CONSISTENCY / HEALTH CONTRACT
-- ============================================================

-- Re-run safe backfills after all relationship/appointment migrations.
insert into public.doctor_provider_links(doctor_id,provider_id,product_id,status,consultation_fee,visiting_days,visiting_time)
select p.doctor_id,p.shop_id,p.id,'approved',coalesce(p.consultation_fee,p.price),p.visiting_days,p.visiting_time
from public.products p join public.profiles d on d.id=p.doctor_id and d.role='doctor'
where p.doctor_id is not null and p.shop_id is not null
on conflict(doctor_id,provider_id) do update set
  product_id=excluded.product_id,
  consultation_fee=excluded.consultation_fee,
  visiting_days=excluded.visiting_days,
  visiting_time=excluded.visiting_time,
  updated_at=now();

update public.products set consultation_fee=price where consultation_fee is null and price is not null;
update public.products set profile_photo_url=thumbnail_url where profile_photo_url is null and thumbnail_url is not null;
update public.appointments
set appointment_start=((appointment_date::text||' '||appointment_time)::timestamp at time zone 'Asia/Dhaka')
where appointment_start is null and appointment_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$';

-- A compact privileged health check used before/after deploys.
create or replace function public.get_backend_integrity_summary()
returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare v jsonb;
begin
  if not public.is_admin_or_above() and not public.is_trusted_backend_context() then
    raise exception 'Admin access required.';
  end if;
  select jsonb_build_object(
    'orphan_products_without_doctor', (select count(*) from public.products p left join public.profiles d on d.id=p.doctor_id where p.doctor_id is null or d.id is null),
    'orphan_products_without_shop', (select count(*) from public.products p left join public.shops s on s.id=p.shop_id where p.shop_id is null or s.id is null),
    'missing_affiliation_links', (select count(*) from public.products p where p.doctor_id is not null and p.shop_id is not null and not exists(select 1 from public.doctor_provider_links l where l.doctor_id=p.doctor_id and l.provider_id=p.shop_id)),
    'duplicate_doctor_provider_products', (select count(*) from (select doctor_id,shop_id from public.products where doctor_id is not null and shop_id is not null group by doctor_id,shop_id having count(*)>1) d),
    'appointments_with_invalid_doctor', (select count(*) from public.appointments a left join public.profiles d on d.id=a.doctor_id where d.id is null or d.role<>'doctor'),
    'approved_provider_rows', (select count(*) from public.profiles where role in ('doctor','hospital') and seller_status='approved' and account_status='active'),
    'generated_at', now()
  ) into v;
  return v;
end $$;
revoke all on function public.get_backend_integrity_summary() from public;
grant execute on function public.get_backend_integrity_summary() to authenticated,service_role;

notify pgrst, 'reload schema';
