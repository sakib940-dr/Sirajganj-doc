-- ============================================================
-- Production Upgrade V2 — STEP 10: FINAL STRUCTURAL VERIFICATION
-- ============================================================

create table if not exists public.backend_schema_versions (
  version text primary key,
  applied_at timestamptz not null default now(),
  notes text
);

-- Structural assertions only. Existing business data is not required to be perfect.
do $$
declare rls_ok boolean;
begin
  if to_regclass('public.doctor_provider_links') is null then raise exception '[STEP10] doctor_provider_links missing'; end if;
  if to_regclass('public.doctor_schedules') is null then raise exception '[STEP10] doctor_schedules missing'; end if;
  if to_regclass('public.admin_audit_logs') is null then raise exception '[STEP10] admin_audit_logs missing'; end if;
  if to_regprocedure('public.search_nearby_doctors(text,text,double precision,double precision,double precision,integer,integer)') is null then raise exception '[STEP10] nearby Doctor RPC missing'; end if;
  if to_regprocedure('public.search_nearby_ambulances(double precision,double precision,double precision,integer,integer)') is null then raise exception '[STEP10] nearby Ambulance RPC missing'; end if;
  if to_regprocedure('public.search_doctors_catalog(text[],text,text,text,integer,integer)') is null then raise exception '[STEP10] Doctor catalog RPC missing'; end if;
  if to_regprocedure('public.get_doctor_available_slots(uuid,uuid,date)') is null then raise exception '[STEP10] appointment slot RPC missing'; end if;
  if to_regprocedure('public.list_approved_doctors_for_provider()') is null then raise exception '[STEP10] provider Doctor chooser RPC missing'; end if;
  if to_regprocedure('public.search_blood_donors(text,double precision,double precision,integer)') is null then raise exception '[STEP10] Blood Bank search RPC missing'; end if;
  if to_regprocedure('public.create_blood_request(uuid,text,text,text,date,text,text,text,text)') is null then raise exception '[STEP10] Blood request RPC missing'; end if;
  if to_regprocedure('public.increment_product_view(uuid)') is null then raise exception '[STEP10] Product view counter RPC missing'; end if;
  if to_regprocedure('public.increment_product_order_click(uuid)') is null then raise exception '[STEP10] Product click counter RPC missing'; end if;
  if to_regprocedure('public.super_admin_analytics_summary()') is null then raise exception '[STEP10] Super Admin analytics RPC missing'; end if;
  if exists(select 1 from public.profiles where role not in ('patient','doctor','hospital','admin','super_admin')) then raise exception '[STEP10] unsupported profile role remains'; end if;

  select bool_and(c.relrowsecurity) into rls_ok
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in ('profiles','shops','products','seller_verifications','appointments','doctor_provider_links','doctor_schedules','ambulance_services');
  if coalesce(rls_ok,false)=false then raise exception '[STEP10] RLS is not enabled on every protected core table'; end if;

  if exists(select 1 from storage.buckets where id in ('seller-verification','verification-docs') and public=true) then
    raise exception '[STEP10] verification document bucket is unexpectedly public';
  end if;

  if public.count_super_admins()=0 then
    raise warning '[STEP10] No active Super Admin found. Keep a trusted bootstrap/service-role path available.';
  end if;
end $$;

insert into public.backend_schema_versions(version,notes)
values('doctor-v1-backend-v10','Canonical schema, RLS, location RPCs, doctor-provider links, appointment integrity, audit, performance and service/data consistency')
on conflict(version) do update set applied_at=now(),notes=excluded.notes;

create or replace function public.get_backend_schema_version()
returns text language sql stable security definer set search_path=public as $$
  select version from public.backend_schema_versions order by applied_at desc limit 1;
$$;
revoke all on function public.get_backend_schema_version() from public;
grant execute on function public.get_backend_schema_version() to authenticated,service_role;

notify pgrst, 'reload schema';
