-- ============================================================
-- Medical Operations Upgrade — STEP 05 / MIGRATION 15
-- COMPLETE APPOINTMENT LIFECYCLE + HISTORY + NOTIFICATION FOUNDATION
-- ============================================================

alter table public.appointments
  add column if not exists reschedule_reason text,
  add column if not exists completed_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists no_show_at timestamptz;

alter table public.appointments drop constraint if exists appointments_status_check;
alter table public.appointments add constraint appointments_status_check
  check (status in ('pending','confirmed','cancelled','completed','rescheduled','no_show'));

-- Bring valid legacy appointment times into the structured conflict engine before new bookings start.
update public.appointments
set appointment_time=btrim(appointment_time),
    appointment_start=((appointment_date::text||' '||btrim(appointment_time))::timestamp at time zone 'Asia/Dhaka')
where appointment_start is null
  and appointment_date is not null
  and nullif(btrim(coalesce(appointment_time,'')),'') is not null
  and btrim(appointment_time) ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$';

create table if not exists public.appointment_status_history (
  id uuid primary key default gen_random_uuid(),
  appointment_id uuid not null references public.appointments(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  old_status text,
  new_status text not null,
  old_date date,
  new_date date,
  old_time text,
  new_time text,
  note text,
  created_at timestamptz not null default now()
);
create index if not exists idx_appointment_history_appointment on public.appointment_status_history(appointment_id,created_at desc);

alter table public.appointment_status_history enable row level security;
drop policy if exists "appointment_history_participant_read" on public.appointment_status_history;
create policy "appointment_history_participant_read" on public.appointment_status_history for select using(
  public.is_admin_or_above() or exists(
    select 1 from public.appointments a where a.id=appointment_id and (
      a.patient_id=auth.uid() or a.doctor_id=auth.uid() or public.is_appointment_provider_owner(a.shop_id)
    )
  )
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  message text,
  entity_type text,
  entity_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_notifications_user_unread on public.notifications(user_id,is_read,created_at desc);
alter table public.notifications enable row level security;
drop policy if exists "notifications_own_read" on public.notifications;
drop policy if exists "notifications_own_update" on public.notifications;
create policy "notifications_own_read" on public.notifications for select using(user_id=auth.uid() or public.is_admin_or_above());
create policy "notifications_own_update" on public.notifications for update using(user_id=auth.uid()) with check(user_id=auth.uid());

create or replace function public.push_notification(p_user_id uuid,p_type text,p_title text,p_message text default null,p_entity_type text default null,p_entity_id uuid default null)
returns void language plpgsql security definer set search_path=public as $$
begin
  if p_user_id is null then return; end if;
  insert into public.notifications(user_id,type,title,message,entity_type,entity_id)
  values(p_user_id,p_type,p_title,p_message,p_entity_type,p_entity_id);
end $$;
revoke all on function public.push_notification(uuid,text,text,text,text,uuid) from public;
grant execute on function public.push_notification(uuid,text,text,text,text,uuid) to service_role;

-- Re-validate insert bookings, including schedule breaks.
create or replace function public.set_appointment_defaults()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  d record; pat record; ch record; v_time time; v_has_schedule boolean; v_duration integer; v_schedule_start time;
begin
  if auth.uid() is not null and not public.is_trusted_backend_context() then
    new.patient_id:=auth.uid();
  end if;
  if new.patient_id is null then raise exception 'Patient login is required.'; end if;
  select p.id,p.full_name,p.phone,p.role into pat from public.profiles p where p.id=new.patient_id and p.account_status='active';
  if pat.id is null or pat.role<>'patient' then raise exception 'Active Patient profile required.'; end if;
  if nullif(btrim(coalesce(pat.phone,'')),'') is null then raise exception 'অ্যাপয়েন্টমেন্ট নিতে আগে আপনার প্রোফাইলে ফোন নম্বর যোগ করুন।'; end if;
  select p.id,p.full_name into d from public.profiles p
    where p.id=new.doctor_id and p.role='doctor' and p.seller_status='approved' and p.account_status='active';
  if d.id is null then raise exception 'Doctor is not approved/active.'; end if;
  if new.appointment_date is null or new.appointment_date < (now() at time zone 'Asia/Dhaka')::date then
    raise exception 'Appointment date cannot be in the past.';
  end if;

  if new.product_id is null then
    raise exception 'A published Doctor profile is required for an appointment.';
  end if;

  if new.product_id is not null then
    select s.id,s.shop_name,pr.doctor_id into ch
    from public.products pr join public.shops s on s.id=pr.shop_id
    where pr.id=new.product_id and pr.is_active=true and s.is_active=true
      and public.is_provider_account_public(s.owner_id)
      and exists(select 1 from public.doctor_provider_links l where l.provider_id=s.id and l.doctor_id=pr.doctor_id and l.status='approved');
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

  if new.shop_id is null then
    raise exception 'A valid Hospital/Chamber is required for an appointment.';
  end if;

  if new.shop_id is not null then
    select exists(select 1 from public.doctor_schedules ds where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true)
      into v_has_schedule;
    if v_has_schedule and (new.appointment_time is null or btrim(new.appointment_time) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$') then
      raise exception 'An available appointment slot is required for this Doctor.';
    end if;
  end if;

  if nullif(btrim(coalesce(new.appointment_time,'')),'') is not null then
    if btrim(new.appointment_time) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
      raise exception 'Appointment time must use HH:MM format.';
    end if;
    new.appointment_time:=btrim(new.appointment_time);
    v_time:=new.appointment_time::time;
    new.appointment_start:=((new.appointment_date::text||' '||new.appointment_time)::timestamp at time zone 'Asia/Dhaka');
    if new.appointment_start < now() then raise exception 'Appointment time cannot be in the past.'; end if;
  else
    new.appointment_time:=null;
    new.appointment_start:=null;
  end if;

  if new.appointment_start is not null and new.shop_id is not null then
    if exists(select 1 from public.doctor_schedule_exceptions e where e.doctor_id=new.doctor_id
      and (e.shop_id is null or e.shop_id=new.shop_id) and e.exception_date=new.appointment_date and e.is_available=false) then
      raise exception 'Doctor is unavailable on this date.';
    end if;
    select exists(select 1 from public.doctor_schedules ds where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true)
      into v_has_schedule;
    if v_has_schedule then
      select ds.slot_duration_minutes,ds.start_time into v_duration,v_schedule_start
      from public.doctor_schedules ds
      where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true
        and ds.day_of_week=extract(dow from new.appointment_date)::integer
        and v_time>=ds.start_time
        and (v_time + make_interval(mins=>ds.slot_duration_minutes))<=ds.end_time
        and mod(floor(extract(epoch from (v_time-ds.start_time))/60)::integer,ds.slot_duration_minutes)=0
      order by ds.start_time limit 1;
      if v_duration is null then raise exception 'Please select a valid available Doctor slot.'; end if;
      new.duration_minutes:=v_duration;
      if exists(
        select 1 from public.doctor_schedules ds
        where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true
          and ds.day_of_week=extract(dow from new.appointment_date)::integer
          and ds.break_start_time is not null and ds.break_end_time is not null
          and v_time < ds.break_end_time
          and (v_time + make_interval(mins=>v_duration)) > ds.break_start_time
      ) then raise exception 'Selected time is inside the Doctor break period.'; end if;
    end if;

    perform pg_advisory_xact_lock(hashtextextended(new.doctor_id::text||'|'||new.appointment_date::text,0));
    if exists(select 1 from public.appointments a where a.doctor_id=new.doctor_id
      and a.status in ('pending','confirmed','rescheduled') and a.appointment_start is not null
      and a.appointment_start < new.appointment_start + make_interval(mins=>coalesce(new.duration_minutes,30))
      and a.appointment_start + make_interval(mins=>coalesce(a.duration_minutes,30)) > new.appointment_start) then
      raise exception 'This appointment time overlaps another active booking.';
    end if;
  end if;

  new.appointment_number:='APT-'||to_char(now(),'YYYYMMDD')||'-'||lpad(nextval('public.appointment_number_seq')::text,5,'0');
  new.doctor_name:=d.full_name;
  new.patient_name:=pat.full_name;
  new.patient_phone:=pat.phone;
  new.status:='pending'; new.created_at:=now(); new.updated_at:=now();
  return new;
end $$;

create or replace function public.guard_appointment_update()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_provider boolean; v_time time; v_has_schedule boolean; v_duration integer; v_schedule_start time;
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
     or new.appointment_number is distinct from old.appointment_number
     or new.created_at is distinct from old.created_at then
    raise exception 'Appointment identity fields cannot be changed.';
  end if;

  -- Server owns derived timestamps. Ignore direct client attempts to forge them.
  new.appointment_start:=old.appointment_start;
  new.completed_at:=old.completed_at;
  new.cancelled_at:=old.cancelled_at;
  new.no_show_at:=old.no_show_at;

  if auth.uid()=old.patient_id and not public.is_admin_or_above() then
    if new.status is distinct from old.status and not (new.status='cancelled' and old.status in ('pending','confirmed','rescheduled')) then
      raise exception 'Patient can only cancel an active appointment.';
    end if;
    if new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time
       or new.duration_minutes is distinct from old.duration_minutes or new.doctor_note is distinct from old.doctor_note
       or new.reschedule_reason is distinct from old.reschedule_reason then
      raise exception 'Patient cannot change the Doctor schedule or Doctor note.';
    end if;
    if new.status='cancelled' and old.status<>'cancelled' and nullif(btrim(coalesce(new.cancellation_reason,'')),'') is null then
      raise exception 'Cancellation reason is required.';
    end if;
    if new.status<>'cancelled' and new.cancellation_reason is distinct from old.cancellation_reason then
      raise exception 'Cancellation reason can only be set while cancelling an appointment.';
    end if;
  end if;

  if (auth.uid()=old.doctor_id or v_provider) and not public.is_admin_or_above() then
    if new.duration_minutes is distinct from old.duration_minutes
       and not (new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time) then
      raise exception 'Appointment duration is controlled by the Doctor schedule.';
    end if;
    if new.status is distinct from old.status then
      if old.status='pending' and new.status not in ('confirmed','cancelled','rescheduled') then
        raise exception 'Pending appointment can only be confirmed, cancelled or rescheduled.';
      elsif old.status='confirmed' and new.status not in ('completed','cancelled','rescheduled','no_show') then
        raise exception 'Confirmed appointment can only be completed, cancelled, rescheduled or marked no-show.';
      elsif old.status='rescheduled' and new.status not in ('confirmed','completed','cancelled','rescheduled','no_show') then
        raise exception 'Invalid rescheduled appointment transition.';
      elsif old.status in ('completed','cancelled','no_show') then
        raise exception 'Final appointment status cannot be reopened.';
      end if;
    end if;
    if new.status='cancelled' and old.status<>'cancelled' and nullif(btrim(coalesce(new.cancellation_reason,'')),'') is null then
      raise exception 'Cancellation reason is required.';
    end if;
  end if;

  if (new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time) then
    if new.appointment_date is null or new.appointment_date < (now() at time zone 'Asia/Dhaka')::date then
      raise exception 'Appointment date cannot be in the past.';
    end if;
    if nullif(btrim(coalesce(new.appointment_time,'')),'') is null then
      new.appointment_time:=null;
      new.appointment_start:=null;
      v_time:=null;
    else
      if btrim(new.appointment_time) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
        raise exception 'Appointment time must use HH:MM format.';
      end if;
      new.appointment_time:=btrim(new.appointment_time);
      v_time:=new.appointment_time::time;
      new.appointment_start:=((new.appointment_date::text||' '||new.appointment_time)::timestamp at time zone 'Asia/Dhaka');
      if new.appointment_start < now() then raise exception 'Appointment time cannot be in the past.'; end if;
    end if;
    if (auth.uid()=old.doctor_id or v_provider) and not public.is_admin_or_above() then
      new.status:='rescheduled';
      if nullif(btrim(coalesce(new.reschedule_reason,'')),'') is null then new.reschedule_reason:='Provider rescheduled'; end if;
    end if;
  else
    -- Recompute the derived start even when a client tries to submit it directly.
    if nullif(btrim(coalesce(new.appointment_time,'')),'') is not null then
      new.appointment_start:=((new.appointment_date::text||' '||btrim(new.appointment_time))::timestamp at time zone 'Asia/Dhaka');
      v_time:=btrim(new.appointment_time)::time;
    else
      new.appointment_start:=null;
      v_time:=null;
    end if;
  end if;

  if not public.is_admin_or_above() and (auth.uid()=old.doctor_id or v_provider)
     and (new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time)
     and new.shop_id is not null then
    if exists(select 1 from public.doctor_schedule_exceptions e where e.doctor_id=new.doctor_id
      and (e.shop_id is null or e.shop_id=new.shop_id) and e.exception_date=new.appointment_date and e.is_available=false) then
      raise exception 'Doctor is unavailable on this date.';
    end if;
    select exists(select 1 from public.doctor_schedules ds where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true)
      into v_has_schedule;
    if v_has_schedule then
      if new.appointment_start is null or v_time is null then
        raise exception 'An available appointment slot is required for this Doctor.';
      end if;
      v_duration:=null; v_schedule_start:=null;
      select ds.slot_duration_minutes,ds.start_time into v_duration,v_schedule_start
      from public.doctor_schedules ds
      where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true
        and ds.day_of_week=extract(dow from new.appointment_date)::integer
        and v_time>=ds.start_time
        and (v_time + make_interval(mins=>ds.slot_duration_minutes))<=ds.end_time
        and mod(floor(extract(epoch from (v_time-ds.start_time))/60)::integer,ds.slot_duration_minutes)=0
      order by ds.start_time limit 1;
      if v_duration is null then raise exception 'Please select a valid available Doctor slot.'; end if;
      new.duration_minutes:=v_duration;
      if exists(
        select 1 from public.doctor_schedules ds
        where ds.doctor_id=new.doctor_id and ds.shop_id=new.shop_id and ds.is_active=true
          and ds.day_of_week=extract(dow from new.appointment_date)::integer
          and ds.break_start_time is not null and ds.break_end_time is not null
          and v_time < ds.break_end_time
          and (v_time + make_interval(mins=>v_duration)) > ds.break_start_time
      ) then raise exception 'Selected time is inside the Doctor break period.'; end if;
    end if;
  end if;

  if new.status in ('pending','confirmed','rescheduled') and new.appointment_start is not null then
    perform pg_advisory_xact_lock(hashtextextended(new.doctor_id::text||'|'||new.appointment_date::text,0));
    if exists(select 1 from public.appointments a where a.id<>old.id and a.doctor_id=new.doctor_id
      and a.status in ('pending','confirmed','rescheduled') and a.appointment_start is not null
      and a.appointment_start < new.appointment_start + make_interval(mins=>coalesce(new.duration_minutes,30))
      and a.appointment_start + make_interval(mins=>coalesce(a.duration_minutes,30)) > new.appointment_start) then
      raise exception 'This appointment time overlaps another active booking.';
    end if;
  end if;

  if not public.is_admin_or_above() and new.status in ('completed','no_show') and old.status is distinct from new.status
     and new.appointment_start is not null and new.appointment_start>now() then
    raise exception 'Future appointment cannot be completed or marked no-show.';
  end if;
  if new.status='completed' and old.status<>'completed' then new.completed_at:=now(); end if;
  if new.status='cancelled' and old.status<>'cancelled' then new.cancelled_at:=now(); end if;
  if new.status='no_show' and old.status<>'no_show' then new.no_show_at:=now(); end if;
  new.updated_at:=now(); return new;
end $$;

create or replace function public.record_appointment_history_and_notify()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_owner uuid;
begin
  if tg_op='INSERT' then
    insert into public.appointment_status_history(appointment_id,actor_id,new_status,new_date,new_time,note)
    values(new.id,auth.uid(),new.status,new.appointment_date,new.appointment_time,'Appointment created');
    perform public.push_notification(new.doctor_id,'appointment_new','নতুন অ্যাপয়েন্টমেন্ট অনুরোধ',coalesce(new.patient_name,'একজন রোগী')||' অ্যাপয়েন্টমেন্ট অনুরোধ পাঠিয়েছেন।','appointment',new.id);
    if new.shop_id is not null then
      select owner_id into v_owner from public.shops where id=new.shop_id;
      if v_owner is not null and v_owner<>new.doctor_id then
        perform public.push_notification(v_owner,'appointment_new','নতুন অ্যাপয়েন্টমেন্ট অনুরোধ',coalesce(new.patient_name,'একজন রোগী')||' অ্যাপয়েন্টমেন্ট অনুরোধ পাঠিয়েছেন।','appointment',new.id);
      end if;
    end if;
  elsif new.status is distinct from old.status or new.appointment_date is distinct from old.appointment_date or new.appointment_time is distinct from old.appointment_time then
    insert into public.appointment_status_history(appointment_id,actor_id,old_status,new_status,old_date,new_date,old_time,new_time,note)
    values(new.id,auth.uid(),old.status,new.status,old.appointment_date,new.appointment_date,old.appointment_time,new.appointment_time,
      coalesce(new.cancellation_reason,new.reschedule_reason,new.doctor_note));
    perform public.push_notification(new.patient_id,'appointment_update','অ্যাপয়েন্টমেন্ট আপডেট হয়েছে',
      'আপনার অ্যাপয়েন্টমেন্টের অবস্থা: '||new.status||case when new.appointment_time is not null then ' • '||new.appointment_date::text||' '||new.appointment_time else '' end,
      'appointment',new.id);
  end if;
  return new;
end $$;
drop trigger if exists trg_record_appointment_history_notify on public.appointments;
create trigger trg_record_appointment_history_notify
  after insert or update on public.appointments
  for each row execute procedure public.record_appointment_history_and_notify();

notify pgrst, 'reload schema';
