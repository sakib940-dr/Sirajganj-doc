-- ============================================================
-- Medical Operations Upgrade — STEP 10 / MIGRATION 20
-- MODERN ADMIN/SUPER ADMIN MEDICAL ANALYTICS
-- ============================================================

-- Supporting indexes for period growth cards/charts.
create index if not exists idx_profiles_created_at on public.profiles(created_at);
create index if not exists idx_profiles_role_created_at on public.profiles(role,created_at);
create index if not exists idx_appointments_created_at on public.appointments(created_at);
create index if not exists idx_appointments_status_date on public.appointments(status,appointment_date);
create index if not exists idx_blood_requests_created_at on public.blood_requests(created_at);
create index if not exists idx_seller_verifications_status_created on public.seller_verifications(status,created_at);

create or replace function public.admin_medical_analytics(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_days integer:=least(greatest(coalesce(p_days,30),7),365);
  v_today date:=(now() at time zone 'Asia/Dhaka')::date;
  v_start date:=v_today-(least(greatest(coalesce(p_days,30),7),365)-1);
  v_prev_start date:=v_today-(least(greatest(coalesce(p_days,30),7),365)*2-1);
  v_prev_end date:=v_today-least(greatest(coalesce(p_days,30),7),365);
  v_result jsonb;
begin
  if not public.is_admin_or_above() and not public.is_trusted_backend_context() then
    raise exception 'Admin access required.';
  end if;

  with days as (
    select generate_series(v_start,v_today,interval '1 day')::date as d
  ), daily as (
    select d.d,
      (select count(*) from public.profiles p where (p.created_at at time zone 'Asia/Dhaka')::date=d.d)::integer as new_users,
      (select count(*) from public.profiles p where p.role='doctor' and (p.created_at at time zone 'Asia/Dhaka')::date=d.d)::integer as new_doctors,
      (select count(*) from public.appointments a where (a.created_at at time zone 'Asia/Dhaka')::date=d.d)::integer as appointments,
      (select count(*) from public.blood_requests b where (b.created_at at time zone 'Asia/Dhaka')::date=d.d)::integer as blood_requests
    from days d
  ), appointment_status as (
    select s.status, count(a.id)::integer as value
    from (values('pending'),('confirmed'),('completed'),('cancelled'),('rescheduled'),('no_show')) s(status)
    left join public.appointments a on a.status=s.status
    group by s.status
  ), blood_groups as (
    select g.blood_group, count(p.id)::integer as value
    from (values('A+'),('A-'),('B+'),('B-'),('AB+'),('AB-'),('O+'),('O-')) g(blood_group)
    left join public.profiles p on p.blood_group=g.blood_group and p.role='patient' and p.blood_donor_volunteer=true and p.blood_is_available=true and p.account_status='active'
    group by g.blood_group
  )
  select jsonb_build_object(
    'period_days',v_days,
    'totals',jsonb_build_object(
      'users',(select count(*) from public.profiles),
      'patients',(select count(*) from public.profiles where role='patient'),
      'doctors',(select count(*) from public.profiles where role='doctor'),
      'approved_doctors',(select count(*) from public.profiles where role='doctor' and seller_status='approved' and account_status='active'),
      'hospitals',(select count(*) from public.profiles where role='hospital'),
      'approved_hospitals',(select count(*) from public.profiles where role='hospital' and seller_status='approved' and account_status='active'),
      'pending_verifications',(select count(*) from public.seller_verifications where status in ('pending','under_review')),
      'appointments_today',(select count(*) from public.appointments where appointment_date=v_today),
      'appointments_pending',(select count(*) from public.appointments where status='pending'),
      'appointments_completed',(select count(*) from public.appointments where status='completed'),
      'active_donors',(select count(*) from public.profiles where role='patient' and blood_donor_volunteer=true and blood_is_available=true and account_status='active'),
      'pending_blood_requests',(select count(*) from public.blood_requests where status='pending'),
      'ambulances',(select count(*) from public.ambulance_services),
      'available_ambulances',(select count(*) from public.ambulance_services where is_verified=true and is_available=true),
      'users_with_location',(select count(*) from public.user_last_locations)
    ),
    'growth',jsonb_build_object(
      'users_current',(select count(*) from public.profiles where (created_at at time zone 'Asia/Dhaka')::date>=v_start),
      'users_previous',(select count(*) from public.profiles where (created_at at time zone 'Asia/Dhaka')::date>=v_prev_start and (created_at at time zone 'Asia/Dhaka')::date<v_start),
      'doctors_current',(select count(*) from public.profiles where role='doctor' and (created_at at time zone 'Asia/Dhaka')::date>=v_start),
      'doctors_previous',(select count(*) from public.profiles where role='doctor' and (created_at at time zone 'Asia/Dhaka')::date>=v_prev_start and (created_at at time zone 'Asia/Dhaka')::date<v_start),
      'appointments_current',(select count(*) from public.appointments where (created_at at time zone 'Asia/Dhaka')::date>=v_start),
      'appointments_previous',(select count(*) from public.appointments where (created_at at time zone 'Asia/Dhaka')::date>=v_prev_start and (created_at at time zone 'Asia/Dhaka')::date<v_start),
      'blood_requests_current',(select count(*) from public.blood_requests where (created_at at time zone 'Asia/Dhaka')::date>=v_start),
      'blood_requests_previous',(select count(*) from public.blood_requests where (created_at at time zone 'Asia/Dhaka')::date>=v_prev_start and (created_at at time zone 'Asia/Dhaka')::date<v_start)
    ),
    'daily',(select coalesce(jsonb_agg(jsonb_build_object('date',d,'new_users',new_users,'new_doctors',new_doctors,'appointments',appointments,'blood_requests',blood_requests) order by d),'[]'::jsonb) from daily),
    'appointment_status',(select coalesce(jsonb_agg(jsonb_build_object('status',status,'value',value) order by status),'[]'::jsonb) from appointment_status),
    'blood_groups',(select coalesce(jsonb_agg(jsonb_build_object('blood_group',blood_group,'value',value) order by blood_group),'[]'::jsonb) from blood_groups),
    'ambulance_engagement',jsonb_build_object(
      'call_clicks',(select coalesce(sum(call_click_count),0) from public.ambulance_services),
      'direction_clicks',(select coalesce(sum(direction_click_count),0) from public.ambulance_services)
    ),
    'generated_at',now()
  ) into v_result;
  return v_result;
end $$;
revoke all on function public.admin_medical_analytics(integer) from public;
grant execute on function public.admin_medical_analytics(integer) to authenticated,service_role;

-- Final assertions for the first 10 medical-operation steps.
do $$
begin
  if to_regclass('public.user_last_locations') is null then raise exception '[MEDICAL STEP10] user_last_locations missing'; end if;
  if to_regclass('public.appointment_status_history') is null then raise exception '[MEDICAL STEP10] appointment_status_history missing'; end if;
  if to_regclass('public.notifications') is null then raise exception '[MEDICAL STEP10] notifications missing'; end if;
  if to_regprocedure('public.review_provider_verification(uuid,text,text)') is null then raise exception '[MEDICAL STEP10] review_provider_verification missing'; end if;
  if to_regprocedure('public.invite_doctor_to_provider(uuid,text)') is null then raise exception '[MEDICAL STEP10] invite_doctor_to_provider missing'; end if;
  if to_regprocedure('public.respond_doctor_provider_invitation(uuid,boolean)') is null then raise exception '[MEDICAL STEP10] invitation response missing'; end if;
  if to_regprocedure('public.save_doctor_schedule_day(uuid,uuid,integer,boolean,time without time zone,time without time zone,integer,time without time zone,time without time zone)') is null then raise exception '[MEDICAL STEP10] atomic schedule save missing'; end if;
  if to_regprocedure('public.get_doctor_available_slots(uuid,uuid,date)') is null then raise exception '[MEDICAL STEP10] available slot RPC missing'; end if;
  if to_regprocedure('public.create_blood_request(uuid,text,text,text,date,text,text,text,text)') is null then raise exception '[MEDICAL STEP10] blood request RPC missing'; end if;
  if to_regprocedure('public.admin_list_blood_requests(integer)') is null then raise exception '[MEDICAL STEP10] blood request admin list missing'; end if;
  if to_regprocedure('public.admin_list_blood_donors(text,text,text,text,boolean,integer,integer)') is null then raise exception '[MEDICAL STEP10] donor admin list missing'; end if;
  if to_regprocedure('public.admin_medical_analytics(integer)') is null then raise exception '[MEDICAL STEP10] medical analytics missing'; end if;
  if exists(select 1 from public.profiles where location_latitude is not null or location_longitude is not null) then
    raise exception '[MEDICAL STEP10] exact user coordinates remain in profiles';
  end if;
end $$;

insert into public.backend_schema_versions(version,notes)
values('doctor-v1-medical-ops-first10','Super Admin location, unified verification, Doctor invitations, schedules, appointment lifecycle, blood donor/request operations, ambulance analytics and modern Admin dashboard')
on conflict(version) do update set applied_at=now(),notes=excluded.notes;

notify pgrst, 'reload schema';
