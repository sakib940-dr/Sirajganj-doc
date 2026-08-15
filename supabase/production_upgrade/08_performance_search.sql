-- ============================================================
-- Production Upgrade V2 — STEP 08: PERFORMANCE / SEARCH
-- ============================================================
create extension if not exists pg_trgm;

create index if not exists idx_products_public_sort on public.products(is_active,view_count desc,created_at desc);
create index if not exists idx_products_shop_active on public.products(shop_id,is_active);
create index if not exists idx_products_category_active on public.products(category_id,is_active);
create index if not exists idx_products_doctor_active on public.products(doctor_id,is_active);
create index if not exists idx_products_name_trgm on public.products using gin(name gin_trgm_ops);
create index if not exists idx_products_name_bn_trgm on public.products using gin(name_bn gin_trgm_ops);
create index if not exists idx_products_name_en_trgm on public.products using gin(name_en gin_trgm_ops);
create index if not exists idx_products_keywords_trgm on public.products using gin(search_keywords gin_trgm_ops);
create index if not exists idx_categories_name_trgm on public.categories using gin(name gin_trgm_ops);
create index if not exists idx_shops_area_active on public.shops(district,upazila,is_active);
create index if not exists idx_profiles_provider_state on public.profiles(role,seller_status,account_status);
create index if not exists idx_appointments_doctor_date_status on public.appointments(doctor_id,appointment_date,status);
create index if not exists idx_appointments_patient_date on public.appointments(patient_id,appointment_date desc);

-- Preserve the existing analytics counters used by the public Product/Doctor cards.
create or replace function public.increment_product_view(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  update public.products set view_count=greatest(coalesce(view_count,0),0)+1
  where id=p_product_id and is_active=true;
end;
$$;
revoke all on function public.increment_product_view(uuid) from public;
grant execute on function public.increment_product_view(uuid) to anon,authenticated,service_role;

create or replace function public.increment_product_order_click(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  update public.products set click_count=greatest(coalesce(click_count,0),0)+1
  where id=p_product_id and is_active=true;
end;
$$;
revoke all on function public.increment_product_order_click(uuid) from public;
grant execute on function public.increment_product_order_click(uuid) to anon,authenticated,service_role;

-- Canonicalize the existing Super Admin analytics contract so drift cannot break the dashboard.
create or replace function public.super_admin_analytics_summary()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare result jsonb;
begin
  if not public.is_super_admin() then raise exception 'শুধুমাত্র Super Admin এই তথ্য দেখতে পারবেন'; end if;
  select jsonb_build_object(
    'totals',jsonb_build_object(
      'total_users',(select count(*) from public.profiles),
      'total_unverified_seller_applications',(select count(*) from public.seller_verifications where status='pending'),
      'total_verified_sellers',(select count(*) from public.seller_verifications where status='approved'),
      'total_products',(select count(*) from public.products),
      'total_product_views',(select coalesce(sum(view_count),0) from public.products)
    ),
    'top_sellers',(select coalesce(jsonb_agg(t),'[]'::jsonb) from (
      select s.id as shop_id,s.shop_name,s.slug,s.logo_url,coalesce(sum(p.click_count),0) as total_order_clicks
      from public.shops s join public.products p on p.shop_id=s.id
      group by s.id,s.shop_name,s.slug,s.logo_url
      having coalesce(sum(p.click_count),0)>0
      order by total_order_clicks desc,s.shop_name asc limit 10
    ) t),
    'top_viewed_products',(select coalesce(jsonb_agg(t),'[]'::jsonb) from (
      select p.id,p.name,p.slug,p.thumbnail_url,p.view_count,s.shop_name
      from public.products p join public.shops s on s.id=p.shop_id
      where p.view_count>0 order by p.view_count desc,p.name asc limit 10
    ) t),
    'top_saved_products',(select coalesce(jsonb_agg(t),'[]'::jsonb) from (
      select p.id,p.name,p.slug,p.thumbnail_url,p.save_count,s.shop_name
      from public.products p join public.shops s on s.id=p.shop_id
      where p.save_count>0 order by p.save_count desc,p.name asc limit 10
    ) t),
    'top_categories',(select coalesce(jsonb_agg(t),'[]'::jsonb) from (
      select c.id,c.name,c.slug,count(p.id) as product_count,coalesce(sum(p.view_count),0) as total_views
      from public.categories c join public.products p on p.category_id=c.id
      group by c.id,c.name,c.slug having count(p.id)>0
      order by product_count desc,total_views desc limit 10
    ) t),
    'growth',jsonb_build_object(
      'daily',jsonb_build_object(
        'new_users',(select count(*) from public.profiles where created_at>=now()-interval '1 day'),
        'new_seller_applications',(select count(*) from public.seller_verifications where created_at>=now()-interval '1 day'),
        'new_products',(select count(*) from public.products where created_at>=now()-interval '1 day')
      ),
      'weekly',jsonb_build_object(
        'new_users',(select count(*) from public.profiles where created_at>=now()-interval '7 days'),
        'new_seller_applications',(select count(*) from public.seller_verifications where created_at>=now()-interval '7 days'),
        'new_products',(select count(*) from public.products where created_at>=now()-interval '7 days')
      ),
      'monthly',jsonb_build_object(
        'new_users',(select count(*) from public.profiles where created_at>=now()-interval '30 days'),
        'new_seller_applications',(select count(*) from public.seller_verifications where created_at>=now()-interval '30 days'),
        'new_products',(select count(*) from public.products where created_at>=now()-interval '30 days')
      )
    )
  ) into result;
  return result;
end;
$$;
revoke all on function public.super_admin_analytics_summary() from public;
grant execute on function public.super_admin_analytics_summary() to authenticated,service_role;

create or replace function public.search_doctors_catalog(
  p_terms text[] default null,
  p_district text default null,
  p_upazila text default null,
  p_section text default 'popular',
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language sql stable security definer set search_path=public as $$
with filtered as (
  select p.*,s.shop_name,s.chamber_name,s.slug as shop_slug,s.whatsapp_number,s.phone as shop_phone,
    s.address as shop_address,s.district,s.upazila,s.google_map_link,s.facebook_link,s.messenger_link,
    s.visiting_days as shop_visiting_days,s.visiting_time as shop_visiting_time,s.consultation_fee as shop_consultation_fee,
    s.latitude,s.longitude,s.location_visibility,c.name as category_name,c.slug as category_slug
  from public.products p
  join public.shops s on s.id=p.shop_id
  left join public.categories c on c.id=p.category_id
  where p.is_active=true and s.is_active=true
    and public.is_doctor_account_public(p.doctor_id)
    and public.is_provider_account_public(s.owner_id)
    and (p_district is null or btrim(p_district)='' or s.district=p_district)
    and (p_upazila is null or btrim(p_upazila)='' or s.upazila=p_upazila)
    and (
      p_terms is null or cardinality(p_terms)=0 or exists(
        select 1 from unnest(p_terms) t where nullif(btrim(t),'') is not null and (
          p.name ilike '%'||t||'%' or coalesce(p.description,'') ilike '%'||t||'%'
          or coalesce(p.name_bn,'') ilike '%'||t||'%' or coalesce(p.name_en,'') ilike '%'||t||'%'
          or coalesce(p.search_keywords,'') ilike '%'||t||'%' or coalesce(c.name,'') ilike '%'||t||'%'
        )
      )
    )
), total as (select count(*)::integer n from filtered), paged as (
  select * from filtered
  order by case when p_section='latest' then created_at end desc nulls last,
           case when p_section<>'latest' then view_count end desc nulls last,
           created_at desc
  limit greatest(1,least(coalesce(p_limit,20),100)) offset greatest(coalesce(p_offset,0),0)
), items as (
  select coalesce(jsonb_agg(
    (to_jsonb(paged) - array['shop_name','chamber_name','shop_slug','whatsapp_number','shop_phone','shop_address','district','upazila','google_map_link','facebook_link','messenger_link','shop_visiting_days','shop_visiting_time','shop_consultation_fee','latitude','longitude','location_visibility','category_name','category_slug']::text[])
    || jsonb_build_object(
      'shops',jsonb_build_object('shop_name',shop_name,'chamber_name',chamber_name,'slug',shop_slug,'whatsapp_number',whatsapp_number,'phone',shop_phone,'address',shop_address,'district',district,'upazila',upazila,'google_map_link',google_map_link,'facebook_link',facebook_link,'messenger_link',messenger_link,'visiting_days',shop_visiting_days,'visiting_time',shop_visiting_time,'consultation_fee',shop_consultation_fee,'latitude',latitude,'longitude',longitude,'location_visibility',location_visibility),
      'categories',case when category_name is null then null else jsonb_build_object('name',category_name,'slug',category_slug) end
    ) order by case when p_section='latest' then created_at end desc nulls last,case when p_section<>'latest' then view_count end desc nulls last,created_at desc
  ),'[]'::jsonb) v from paged
)
select jsonb_build_object('items',items.v,'total',total.n) from items cross join total;
$$;

revoke all on function public.search_doctors_catalog(text[],text,text,text,integer,integer) from public;
grant execute on function public.search_doctors_catalog(text[],text,text,text,integer,integer) to anon,authenticated,service_role;

notify pgrst, 'reload schema';
