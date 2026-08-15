-- ============================================================
-- Medical Operations Upgrade — STEP 04 / MIGRATION 14
-- STRUCTURED DOCTOR SCHEDULE / BREAK / EXCEPTION MANAGEMENT
-- ============================================================

alter table public.doctor_schedules
  add column if not exists break_start_time time,
  add column if not exists break_end_time time;

alter table public.doctor_schedules drop constraint if exists doctor_schedules_break_check;
alter table public.doctor_schedules add constraint doctor_schedules_break_check check(
  (break_start_time is null and break_end_time is null)
  or (break_start_time is not null and break_end_time is not null and break_end_time>break_start_time and break_start_time>=start_time and break_end_time<=end_time)
);

-- Hospital may manage a Doctor schedule only after the Doctor accepted affiliation.
drop policy if exists "doctor_schedules_public_read" on public.doctor_schedules;
drop policy if exists "doctor_schedules_manage" on public.doctor_schedules;
create policy "doctor_schedules_public_read" on public.doctor_schedules for select using(
  (is_active=true and exists(select 1 from public.doctor_provider_links l where l.doctor_id=doctor_schedules.doctor_id and l.provider_id=doctor_schedules.shop_id and l.status='approved'))
  or doctor_schedules.doctor_id=auth.uid()
  or public.is_admin_or_above()
  or (public.is_appointment_provider_owner(shop_id) and exists(select 1 from public.doctor_provider_links l where l.doctor_id=doctor_schedules.doctor_id and l.provider_id=doctor_schedules.shop_id and l.status='approved'))
);
create policy "doctor_schedules_manage" on public.doctor_schedules for all using(
  public.is_admin_or_above()
  or (
    exists(select 1 from public.doctor_provider_links l where l.doctor_id=doctor_schedules.doctor_id and l.provider_id=doctor_schedules.shop_id and l.status='approved')
    and (doctor_schedules.doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id))
  )
) with check(
  public.is_admin_or_above()
  or (
    exists(select 1 from public.doctor_provider_links l where l.doctor_id=doctor_schedules.doctor_id and l.provider_id=doctor_schedules.shop_id and l.status='approved')
    and (doctor_schedules.doctor_id=auth.uid() or public.is_appointment_provider_owner(shop_id))
  )
);

-- Exceptions follow the same accepted-affiliation requirement for Hospital users.
drop policy if exists "doctor_schedule_exceptions_public_read" on public.doctor_schedule_exceptions;
drop policy if exists "doctor_schedule_exceptions_manage" on public.doctor_schedule_exceptions;
create policy "doctor_schedule_exceptions_public_read" on public.doctor_schedule_exceptions for select using(
  doctor_schedule_exceptions.doctor_id=auth.uid() or public.is_admin_or_above()
  or (doctor_schedule_exceptions.shop_id is not null and public.is_appointment_provider_owner(doctor_schedule_exceptions.shop_id)
      and exists(select 1 from public.doctor_provider_links l where l.doctor_id=doctor_schedule_exceptions.doctor_id and l.provider_id=doctor_schedule_exceptions.shop_id and l.status='approved'))
);
create policy "doctor_schedule_exceptions_manage" on public.doctor_schedule_exceptions for all using(
  public.is_admin_or_above()
  or (
    doctor_schedule_exceptions.shop_id is not null
    and exists(select 1 from public.doctor_provider_links l where l.doctor_id=doctor_schedule_exceptions.doctor_id and l.provider_id=doctor_schedule_exceptions.shop_id and l.status='approved')
    and (doctor_schedule_exceptions.doctor_id=auth.uid() or public.is_appointment_provider_owner(doctor_schedule_exceptions.shop_id))
  )
) with check(
  public.is_admin_or_above()
  or (
    doctor_schedule_exceptions.shop_id is not null
    and exists(select 1 from public.doctor_provider_links l where l.doctor_id=doctor_schedule_exceptions.doctor_id and l.provider_id=doctor_schedule_exceptions.shop_id and l.status='approved')
    and (doctor_schedule_exceptions.doctor_id=auth.uid() or public.is_appointment_provider_owner(doctor_schedule_exceptions.shop_id))
  )
);

-- Atomic day-level schedule save. Avoids the UI delete-then-insert gap and re-checks authorization server-side.
create or replace function public.save_doctor_schedule_day(
  p_doctor_id uuid,
  p_shop_id uuid,
  p_day_of_week integer,
  p_enabled boolean,
  p_start_time time default null,
  p_end_time time default null,
  p_slot_duration_minutes integer default 30,
  p_break_start_time time default null,
  p_break_end_time time default null
)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare v_allowed boolean:=false;
begin
  if auth.uid() is null then raise exception 'Login required.'; end if;
  if p_day_of_week not between 0 and 6 then raise exception 'Invalid day of week.'; end if;
  if coalesce(p_slot_duration_minutes,30) not between 5 and 240 then raise exception 'Invalid slot duration.'; end if;

  v_allowed:=public.is_admin_or_above()
    or (
      exists(select 1 from public.doctor_provider_links l
             where l.doctor_id=p_doctor_id and l.provider_id=p_shop_id and l.status='approved')
      and (p_doctor_id=auth.uid() or public.is_appointment_provider_owner(p_shop_id))
    );
  if not v_allowed then raise exception 'You cannot manage this Doctor schedule.'; end if;

  if p_enabled then
    if p_start_time is null or p_end_time is null or p_end_time<=p_start_time then
      raise exception 'Valid schedule start/end time is required.';
    end if;
    if (p_break_start_time is null) <> (p_break_end_time is null) then
      raise exception 'Both break start and end are required.';
    end if;
    if p_break_start_time is not null and (
      p_break_end_time<=p_break_start_time or p_break_start_time<p_start_time or p_break_end_time>p_end_time
    ) then raise exception 'Invalid break period.'; end if;
  end if;

  delete from public.doctor_schedules
  where doctor_id=p_doctor_id and shop_id=p_shop_id and day_of_week=p_day_of_week;

  if p_enabled then
    insert into public.doctor_schedules(
      doctor_id,shop_id,day_of_week,start_time,end_time,slot_duration_minutes,
      break_start_time,break_end_time,is_active,updated_at
    ) values(
      p_doctor_id,p_shop_id,p_day_of_week,p_start_time,p_end_time,coalesce(p_slot_duration_minutes,30),
      p_break_start_time,p_break_end_time,true,now()
    );
  end if;
end $$;
revoke all on function public.save_doctor_schedule_day(uuid,uuid,integer,boolean,time,time,integer,time,time) from public;
grant execute on function public.save_doctor_schedule_day(uuid,uuid,integer,boolean,time,time,integer,time,time) to authenticated,service_role;

create or replace function public.get_doctor_available_slots(p_doctor_id uuid,p_shop_id uuid,p_date date)
returns table(slot_time text)
language sql stable security definer set search_path=public as $$
  with schedule as (
    select ds.start_time,ds.end_time,ds.slot_duration_minutes,ds.break_start_time,ds.break_end_time
    from public.doctor_schedules ds
    where ds.doctor_id=p_doctor_id and ds.shop_id=p_shop_id and ds.is_active=true
      and ds.day_of_week=extract(dow from p_date)::integer
      and not exists(select 1 from public.doctor_schedule_exceptions e where e.doctor_id=p_doctor_id
        and (e.shop_id is null or e.shop_id=p_shop_id) and e.exception_date=p_date and e.is_available=false)
  ), slots as (
    select gs as slot_start,
           (gs at time zone 'Asia/Dhaka')::time as t,
           s.slot_duration_minutes,s.break_start_time,s.break_end_time
    from schedule s cross join lateral generate_series(
      (p_date+s.start_time) at time zone 'Asia/Dhaka',
      (p_date+(s.end_time-make_interval(mins=>s.slot_duration_minutes))) at time zone 'Asia/Dhaka',
      make_interval(mins=>s.slot_duration_minutes)
    ) gs
  )
  select to_char(slots.t,'HH24:MI')
  from slots
  where public.is_doctor_account_public(p_doctor_id)
    and exists(select 1 from public.doctor_provider_links l where l.doctor_id=p_doctor_id and l.provider_id=p_shop_id and l.status='approved')
    and not (
      slots.break_start_time is not null and slots.break_end_time is not null
      and slots.t < slots.break_end_time
      and (slots.t + make_interval(mins=>slots.slot_duration_minutes)) > slots.break_start_time
    )
    and not exists(
      select 1 from public.appointments a
      where a.doctor_id=p_doctor_id
        and a.status in ('pending','confirmed','rescheduled')
        and a.appointment_start is not null
        and a.appointment_start < slots.slot_start + make_interval(mins=>slots.slot_duration_minutes)
        and a.appointment_start + make_interval(mins=>coalesce(a.duration_minutes,30)) > slots.slot_start
    )
  order by slots.t;
$$;
revoke all on function public.get_doctor_available_slots(uuid,uuid,date) from public;
grant execute on function public.get_doctor_available_slots(uuid,uuid,date) to anon,authenticated,service_role;

create or replace function public.has_doctor_schedule(p_doctor_id uuid,p_shop_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.doctor_schedules ds
    where ds.doctor_id=p_doctor_id and ds.shop_id=p_shop_id and ds.is_active=true
  ) and exists(
    select 1 from public.doctor_provider_links l
    where l.doctor_id=p_doctor_id and l.provider_id=p_shop_id and l.status='approved'
  );
$$;
revoke all on function public.has_doctor_schedule(uuid,uuid) from public;
grant execute on function public.has_doctor_schedule(uuid,uuid) to anon,authenticated,service_role;

create index if not exists idx_doctor_schedules_provider_day on public.doctor_schedules(shop_id,doctor_id,day_of_week,is_active);

notify pgrst, 'reload schema';
