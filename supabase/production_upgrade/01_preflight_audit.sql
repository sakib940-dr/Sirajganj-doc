-- ============================================================
-- Production Upgrade V2 — STEP 01: PRE-FLIGHT DATABASE AUDIT
-- READ-ONLY: this file intentionally makes no persistent schema/data changes.
-- Safe to run more than once.
--
-- Purpose:
--   1) Show whether the objects expected by the current Doctor Platform repo
--      exist in the target Supabase database.
--   2) Show RLS status for core public tables.
--   3) Show security mode/search_path for security-sensitive RPCs.
--   4) Surface current policies/triggers so Step 02+ can be compared against
--      the real production database before mutations are applied.
--
-- IMPORTANT: Do not treat this file as a schema migration. It is a diagnostic
-- first step in the final 10-step production upgrade chain.
-- ============================================================

-- A. Core table inventory ---------------------------------------------------
with expected(table_name) as (
  values
    ('profiles'),
    ('shops'),
    ('categories'),
    ('products'),
    ('product_images'),
    ('shop_gallery'),
    ('banners'),
    ('site_settings'),
    ('product_saves'),
    ('shop_saves'),
    ('social_links'),
    ('announcements'),
    ('search_synonyms'),
    ('seller_verifications'),
    ('orders'),
    ('appointments'),
    ('blood_requests'),
    ('ambulance_services')
)
select
  'table'::text as check_type,
  e.table_name as object_name,
  case when to_regclass(format('public.%I', e.table_name)) is not null
       then 'present' else 'MISSING' end as status
from expected e
order by e.table_name;

-- B. RLS status for existing public tables --------------------------------
with expected(table_name) as (
  values
    ('profiles'),('shops'),('categories'),('products'),('product_images'),
    ('shop_gallery'),('banners'),('site_settings'),('product_saves'),
    ('shop_saves'),('social_links'),('announcements'),('search_synonyms'),
    ('seller_verifications'),('orders'),('appointments'),('blood_requests'),
    ('ambulance_services')
)
select
  'rls'::text as check_type,
  e.table_name as object_name,
  case
    when c.oid is null then 'table-missing'
    when c.relrowsecurity then 'enabled'
    else 'DISABLED'
  end as status
from expected e
left join pg_namespace n on n.nspname='public'
left join pg_class c on c.relnamespace=n.oid
  and c.relname=e.table_name and c.relkind in ('r','p')
order by e.table_name;

-- C. Critical column inventory ---------------------------------------------
with expected(table_name, column_name) as (
  values
    ('profiles','role'),
    ('profiles','seller_status'),
    ('profiles','account_status'),
    ('profiles','location_latitude'),
    ('profiles','location_longitude'),
    ('profiles','blood_group'),
    ('profiles','blood_donor_volunteer'),
    ('shops','owner_id'),
    ('shops','latitude'),
    ('shops','longitude'),
    ('products','doctor_id'),
    ('appointments','doctor_id'),
    ('appointments','patient_id'),
    ('appointments','appointment_date'),
    ('appointments','appointment_time'),
    ('ambulance_services','latitude'),
    ('ambulance_services','longitude')
)
select
  'column'::text as check_type,
  format('%s.%s', e.table_name, e.column_name) as object_name,
  case when c.column_name is not null then 'present' else 'MISSING' end as status
from expected e
left join information_schema.columns c
  on c.table_schema='public'
 and c.table_name=e.table_name
 and c.column_name=e.column_name
order by e.table_name, e.column_name;

-- D. Security-sensitive RPC posture ----------------------------------------
-- proconfig is shown so fixed search_path can be verified for SECURITY DEFINER.
with wanted(proname) as (
  values
    ('handle_new_user'),
    ('request_seller_status'),
    ('is_admin_or_above'),
    ('is_super_admin'),
    ('prevent_self_role_change'),
    ('is_doctor_account_public'),
    ('is_provider_account_public'),
    ('set_appointment_defaults'),
    ('guard_appointment_update'),
    ('distance_km'),
    ('search_blood_donors'),
    ('create_blood_request')
)
select
  'function'::text as check_type,
  w.proname as object_name,
  case
    when p.oid is null then 'missing'
    when p.prosecdef then 'security-definer'
    else 'security-invoker'
  end as security_mode,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  coalesce(array_to_string(p.proconfig, ', '), '(no fixed config)') as function_config
from wanted w
left join pg_namespace n on n.nspname='public'
left join pg_proc p on p.pronamespace=n.oid and p.proname=w.proname
order by w.proname, identity_arguments;

-- E. Current RLS policy inventory ------------------------------------------
select
  'policy'::text as check_type,
  schemaname || '.' || tablename as object_name,
  policyname,
  cmd,
  roles,
  permissive,
  qual,
  with_check
from pg_policies
where schemaname='public'
  and tablename in (
    'profiles','shops','products','product_images','shop_gallery',
    'seller_verifications','appointments','blood_requests','ambulance_services'
  )
order by tablename, policyname;

-- F. Trigger inventory on core domain tables -------------------------------
select
  'trigger'::text as check_type,
  event_object_table as object_name,
  trigger_name,
  action_timing,
  event_manipulation,
  action_statement
from information_schema.triggers
where trigger_schema='public'
  and event_object_table in (
    'profiles','shops','products','seller_verifications','appointments'
  )
order by event_object_table, trigger_name, event_manipulation;

-- G. Current profile role/status distribution ------------------------------
-- Dynamic SQL keeps the audit runnable even if profiles is unexpectedly absent.
do $$
declare
  r record;
begin
  if to_regclass('public.profiles') is null then
    raise notice '[STEP01] public.profiles is missing; role/status distribution skipped.';
    return;
  end if;

  raise notice '[STEP01] profiles role / seller_status / account_status distribution:';
  for r in execute $q$
    select
      coalesce(role,'(null)') as role,
      coalesce(seller_status,'(null)') as seller_status,
      coalesce(account_status,'(null)') as account_status,
      count(*)::bigint as row_count
    from public.profiles
    group by role, seller_status, account_status
    order by role, seller_status, account_status
  $q$
  loop
    raise notice '  role=%, seller_status=%, account_status=%, count=%',
      r.role, r.seller_status, r.account_status, r.row_count;
  end loop;
end $$;
