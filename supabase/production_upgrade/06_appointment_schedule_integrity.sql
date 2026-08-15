-- ============================================================
-- Production Upgrade V2 — STEP 06: APPOINTMENT / SCHEDULE INTEGRITY
-- Backward compatible with appointment_date + appointment_time.
-- ============================================================

alter table public.appointments
  add column if not exists appointment_start timestamptz,
  add column if not exists duration_minutes integer not null default 30,
  add column if not exists cancellation_reason text;

alter table public.appointments drop constraint if exists appointments_duration_minutes_check;
alter table public.appointments add constraint appointments_duration_minutes_check check(duration_minutes between 5 and 240);

create table if not exists public.doctor_schedules (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  day_of_week integer not null check(day_of_week between 0 and 6),
  start_time time not null,
  end_time time not null,
  slot_duration_minutes integer not null default 30 check(slot_duration_minutes between 5 and 240),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint doctor_schedules_time_check check(end_time>start_time),
  constraint doctor_schedules_unique_window unique(doctor_id,shop_id,day_of_week,start_time,end_time)
);

create table if not exists public.doctor_schedule_exceptions (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.profiles(id) on delete cascade,
  shop_id uuid references public.shops(id) on delete cascade,
  exception_date date not null,
  is_available boolean not null default false,
  note text,
  created_at timestamptz not null default now(),
  constraint doctor_schedule_exceptions_unique unique(doctor_id,shop_id,exception_date)
);

create index if not exists idx_doctor_schedules_lookup on public.doctor_schedules(doctor_id,shop_id,day_of_week,is_active);
create index if not exists idx_schedule_exceptions_lookup on public.doctor_schedule_exceptions(doctor_id,shop_id,exception_date);
create index if not exists idx_appointments_doctor_start on public.appointments(doctor_id,appointment_start,status) where appointment_start is not null;
create index if not exists idx_appointments_shop_date on public.appointments(shop_id,appointment_date,status);

create or replace function public.is_appointment_provider_owner(p_shop_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select p_shop_id is not null and exists(select 1 from public.shops s where s.id=p_shop_id and s.owner_id=auth.uid());
$$;

create or replace function public.set_appointment_defaults()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  d record; pat record; ch record; v_time time; v_has_schedule boolean;
begin
  if auth.uid() is not null and not public.is_trusted_backend_context() then
    new.patient_id:=auth.uid();
  end if;
  if new.patient_id is null then raise exception 'Patient login is required.'; end if;
  select p.id,p.full_name,p.phone into pat from public.profiles p where p.id=new.patient_id and p.account_status='active';
  if pat.id is null then raise exception 'Patient profile not found.'; end if;
  select p.id,p.full_name into d from public.profiles p
    where p.id=new.doctor_id and p.role='doctor' and p.seller_status='approved' and p.account_status='active';
  if d.id is null then raise exception 'Doctor is not approved/active.'; end if;

  if new.product_id is not null then
    select s.id,s.shop_name,pr.doctor_id into ch
    from public.products pr join public.shops s on s.id=pr.shop_id
    where pr.id=new.product_id and pr.is_active=true and s.is_active=true
      and public.is_provider_account_public(s.owner_id);
    if ch.id is null or ch.doctor_id is distinct from new.doctor_id then raise exception 'Invalid Doctor profile.'; end if;
    new.shop_id:=ch.id;
    new.chamber_name:=coalesce(new.chamber_name,ch.shop_name);
  elsif new.shop_id is not null then
    select s.id,s.shop_name into ch from public.shops s
    where s.id=new.shop_id and s.is_active=true and public.is_provider_account_public(s.owner_id)
      and exists(select 1 from public.doctor_provider_links l where l.provider_id=s.id and l.doctor_id=new.doctor_id and l.status='approved');
    if ch.id is null then raise exception 'Invalid doctor/chamber affiliation.'; end if;
    new.chamber_name:=coalesce(new.chamber_name,ch.shop_name);
  end if;

  if new.appointment_time is not null and btrim(new.appointment_time) ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
    v_time:=new.appointment_time::time;
    new.appointment_start:=((new.appointment_date::text||' '||new.appointment_time)::timestamp at time zone 'Asia/Dhaka');
  end if;

  if new.appointment_start is not null and new.shop_id is not null then
    if exists(select 1 from public.doctor_schedule_exceptions e where e.doctor_id=new.doctor_id
      and (e.shop_id is null or e.shop_id=new.shop_id) and e.exception_date=new.appointment_date and e.is_available=false) then
      raise exception 'Doctor is unavailable on this date.';
    end if;
    select exists(select 1 from public.doctor_schedules ds where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true)
      into v_has_schedule;
    if v_has_schedule and not exists(
      select 1 from public.doctor_schedules ds
      where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true
        and ds.day_of_week=extract(dow from new.appointment_date)::integer
        and v_time>=ds.start_time
        and (v_time + make_interval(mins=>coalesce(new.duration_minutes,ds.slot_duration_minutes)))<=ds.end_time
    ) then raise exception 'Selected time is outside the Doctor schedule.'; end if;

    perform pg_advisory_xact_lock(hashtextextended(new.doctor_id::text||'|'||new.appointment_start::text,0));
    if exists(select 1 from public.appointments a where a.doctor_id=new.doctor_id
      and a.appointment_start=new.appointment_start and a.status in ('pending','confirmed','rescheduled')) then
      raise exception 'This appointment slot is already booked.';
    end if;
  end if;

  new.appointment_number:='APT-'||to_char(now(),'YYYYMMDD')||'-'||lpad(nextval('public.appointment_number_seq')::text,5,'0');
  new.doctor_name:=d.full_name;
  new.patient_name:=coalesce(nullif(trim(new.patient_name),''),pat.full_name);
  new.patient_phone:=coalesce(nullif(trim(new.patient_phone),''),pat.phone);
  new.status:='pending'; new.created_at:=now(); new.updated_at:=now();
  return new;
end $$;

drop trigger if exists trg_appointments_set_defaults on public.appointments;
create trigger trg_appointments_set_defaults before insert on public.appointments for each row execute procedure public.set_appointment_defaults();

create or replace function public.guard_appointment_update()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_provider boolean; v_time time; v_has_schedule boolean;
begin
  if public.is_trusted_backend_context() then new.updated_at:=now(); return new; end if;
  v_provider:=public.is_appointment_provider_owner(old.shop_id);
  if not (auth.uid()=old.doctor_id or auth.uid()=old.patient_id or v_provider or public.is_admin_or_above()) then
    raise exception 'You are not allowed to update this appointment.';
  end if;
  if new.doctor_id<>old.doctor_id or new.patient_id<>old.patient_id or new.product_id is distinct from old.product_id or new.shop_id is distinct from old.shop_id then
    raise exception 'Appointment ownership cannot be changed.';
  end if;
  if new.doctor_name is distinct from old.doctor_name or new.patient_name is distinct from old.patient_name
     or new.patient_phone is distinct from old.patient_phone or new.chamber_name is distinct from old.chamber_name
     or new.appointment_number is distinct from old.appointment_number then
    raise exception 'Appointment identity fields cannot be changed.';
  end if;

  if auth.uid()=old.patient_id and not public.is_admin_or_above() then
    if new.status is distinct from old.status and not (new.status='cancelled' and old.status in ('pending','confirmed','rescheduled')) then
      raise exception 'Patient can only cancel an active appointment.';
    end if;
    if new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time
       or new.duration_minutes is distinct from old.duration_minutes or new.doctor_note is distinct from old.doctor_note then
      raise exception 'Patient cannot change the Doctor schedule or Doctor note.';
    end if;
  end if;

  if (auth.uid()=old.doctor_id or v_provider) and not public.is_admin_or_above()
     and new.status not in ('confirmed','cancelled','completed','rescheduled','pending') then
    raise exception 'Invalid appointment status.';
  end if;

  if (new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time)
     and new.appointment_time is not null and btrim(new.appointment_time) ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
    v_time:=new.appointment_time::time;
    new.appointment_start:=((new.appointment_date::text||' '||new.appointment_time)::timestamp at time zone 'Asia/Dhaka');
  end if;

  if not public.is_admin_or_above() and (auth.uid()=old.doctor_id or v_provider)
     and (new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time)
     and new.appointment_start is not null and new.shop_id is not null then
    if exists(select 1 from public.doctor_schedule_exceptions e where e.doctor_id=new.doctor_id
      and (e.shop_id is null or e.shop_id=new.shop_id) and e.exception_date=new.appointment_date and e.is_available=false) then
      raise exception 'Doctor is unavailable on this date.';
    end if;
    select exists(select 1 from public.doctor_schedules ds where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true)
      into v_has_schedule;
    if v_has_schedule and not exists(
      select 1 from public.doctor_schedules ds
      where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true
        and ds.day_of_week=extract(dow from new.appointment_date)::integer
        and v_time>=ds.start_time
        and (v_time + make_interval(mins=>coalesce(new.duration_minutes,ds.slot_duration_minutes)))<=ds.end_time
    ) then raise exception 'Selected time is outside the Doctor schedule.'; end if;
  end if;

  if new.status in ('pending','confirmed','rescheduled') and new.appointment_start is not null then
    perform pg_advisory_xact_lock(hashtextextended(new.doctor_id::text||'|'||new.appointment_start::text,0));
    if exists(select 1 from public.appointments a where a.id<>old.id and a.doctor_id=new.doctor_id
      and a.appointment_start=new.appointment_start and a.status in ('pending','confirmed','rescheduled')) then
      raise exception 'This appointment slot is already booked.';
    end if;
  end if;

  new.updated_at:=now(); return new;
end $$;
drop trigger if exists trg_guard_appointment_update on public.appointments;
create trigger trg_guard_appointment_update before update on public.appointments for each row execute procedure public.guard_appointment_update();

alter table public.appointments enable row level security;
drop policy if exists "appointments_select_participant_or_admin" on public.appointments;
drop policy if exists "appointments_update_participant_or_admin" on public.appointments;
create policy "appointments_select_participant_or_admin" on public.appointments for select using(
  patient_id=auth.uid() or doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above()
);
create policy "appointments_update_participant_or_admin" on public.appointments for update using(
  patient_id=auth.uid() or doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above()
) with check(
  patient_id=auth.uid() or doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above()
);

alter table public.doctor_schedules enable row level security;
alter table public.doctor_schedule_exceptions enable row level security;
drop policy if exists "doctor_schedules_public_read" on public.doctor_schedules;
drop policy if exists "doctor_schedules_manage" on public.doctor_schedules;
create policy "doctor_schedules_public_read" on public.doctor_schedules for select using(is_active=true or doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above());
create policy "doctor_schedules_manage" on public.doctor_schedules for all using(doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above()) with check(doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above());
drop policy if exists "doctor_schedule_exceptions_public_read" on public.doctor_schedule_exceptions;
drop policy if exists "doctor_schedule_exceptions_manage" on public.doctor_schedule_exceptions;
create policy "doctor_schedule_exceptions_public_read" on public.doctor_schedule_exceptions for select using(doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above());
create policy "doctor_schedule_exceptions_manage" on public.doctor_schedule_exceptions for all using(doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above()) with check(doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id) or public.is_admin_or_above());

create or replace function public.get_doctor_available_slots(p_doctor_id uuid,p_shop_id uuid,p_date date)
returns table(slot_time text)
language sql stable security definer set search_path=public as $$
  with schedule as (
    select ds.start_time,ds.end_time,ds.slot_duration_minutes
    from public.doctor_schedules ds
    where ds.doctor_id=p_doctor_id and ds.shop_id=p_shop_id and ds.is_active=true
      and ds.day_of_week=extract(dow from p_date)::integer
      and not exists(select 1 from public.doctor_schedule_exceptions e where e.doctor_id=p_doctor_id
        and (e.shop_id is null or e.shop_id=p_shop_id) and e.exception_date=p_date and e.is_available=false)
  ), slots as (
    select gs::time as t, s.slot_duration_minutes
    from schedule s cross join lateral generate_series(
      p_date+s.start_time,
      p_date+(s.end_time-make_interval(mins=>s.slot_duration_minutes)),
      make_interval(mins=>s.slot_duration_minutes)
    ) gs
  )
  select to_char(slots.t,'HH24:MI')
  from slots
  where public.is_doctor_account_public(p_doctor_id)
    and exists(select 1 from public.doctor_provider_links l where l.doctor_id=p_doctor_id and l.provider_id=p_shop_id and l.status='approved')
    and not exists(select 1 from public.appointments a where a.doctor_id=p_doctor_id and a.shop_id=p_shop_id
      and a.appointment_date=p_date and a.appointment_time=to_char(slots.t,'HH24:MI') and a.status in ('pending','confirmed','rescheduled'))
  order by slots.t;
$$;
revoke all on function public.get_doctor_available_slots(uuid,uuid,date) from public;
grant execute on function public.get_doctor_available_slots(uuid,uuid,date) to anon,authenticated,service_role;

notify pgrst, 'reload schema';
