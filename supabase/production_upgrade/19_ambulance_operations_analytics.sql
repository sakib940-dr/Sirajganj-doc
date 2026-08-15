-- ============================================================
-- Medical Operations Upgrade — STEP 09 / MIGRATION 19
-- AMBULANCE COUNT FIX + CONTACT/DIRECTION ANALYTICS
-- ============================================================

alter table public.ambulance_services
  add column if not exists call_click_count integer not null default 0,
  add column if not exists direction_click_count integer not null default 0;

alter table public.ambulance_services drop constraint if exists ambulance_call_click_count_check;
alter table public.ambulance_services add constraint ambulance_call_click_count_check check(call_click_count>=0);
alter table public.ambulance_services drop constraint if exists ambulance_direction_click_count_check;
alter table public.ambulance_services add constraint ambulance_direction_click_count_check check(direction_click_count>=0);

create or replace function public.increment_ambulance_call_click(p_ambulance_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.ambulance_services set call_click_count=call_click_count+1 where id=p_ambulance_id and is_verified=true;
end $$;
revoke all on function public.increment_ambulance_call_click(uuid) from public;
grant execute on function public.increment_ambulance_call_click(uuid) to anon,authenticated,service_role;

create or replace function public.increment_ambulance_direction_click(p_ambulance_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.ambulance_services set direction_click_count=direction_click_count+1 where id=p_ambulance_id and is_verified=true;
end $$;
revoke all on function public.increment_ambulance_direction_click(uuid) from public;
grant execute on function public.increment_ambulance_direction_click(uuid) to anon,authenticated,service_role;

create index if not exists idx_ambulance_available_verified on public.ambulance_services(is_available,is_verified,updated_at desc);

notify pgrst, 'reload schema';
