-- ============================================================
-- Medical Operations Upgrade — STEP 08 / MIGRATION 18
-- BLOOD SEARCH / REQUEST LIFECYCLE / ANTI-SPAM / AUDIT
-- ============================================================

create sequence if not exists public.blood_request_number_seq;
alter table public.blood_requests
  add column if not exists request_number text,
  add column if not exists completed_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists donor_response_note text,
  add column if not exists donor_contact_phone text;

-- Backfill stable request numbers for historical rows.
update public.blood_requests
set request_number='BR-'||to_char(created_at,'YYYYMMDD')||'-'||substr(replace(id::text,'-',''),1,8)
where request_number is null;
create unique index if not exists ux_blood_requests_request_number on public.blood_requests(request_number) where request_number is not null;
update public.blood_requests b
set donor_contact_phone=p.phone
from public.profiles p
where p.id=b.donor_id and b.status in ('accepted','completed')
  and b.donor_contact_phone is null and nullif(btrim(coalesce(p.phone,'')),'') is not null;
create index if not exists idx_blood_requests_donor_status_created on public.blood_requests(donor_id,status,created_at desc);
create index if not exists idx_blood_requests_requester_status_created on public.blood_requests(requester_id,status,created_at desc);

-- Keep legacy signature for frontend compatibility, but identity comes from auth.uid()/profiles.
create or replace function public.create_blood_request(
  p_donor_id uuid,
  p_blood_group text,
  p_patient_name text,
  p_patient_phone text,
  p_needed_date date,
  p_needed_time text,
  p_reason text,
  p_hospital_name text,
  p_location_text text
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare v_id uuid; v_patient record;
begin
  if auth.uid() is null then raise exception 'লগইন করতে হবে'; end if;
  select id,full_name,phone,role,account_status into v_patient from public.profiles where id=auth.uid();
  if v_patient.id is null or v_patient.role<>'patient' or v_patient.account_status<>'active' then
    raise exception 'সক্রিয় রোগী অ্যাকাউন্ট প্রয়োজন।';
  end if;
  if nullif(btrim(coalesce(v_patient.phone,'')),'') is null then
    raise exception 'রক্তের অনুরোধ পাঠাতে আগে আপনার প্রোফাইলে ফোন নম্বর যোগ করুন।';
  end if;
  if nullif(btrim(coalesce(p_reason,'')),'') is null then raise exception 'রক্তের প্রয়োজনের কারণ লিখুন।'; end if;
  if p_needed_date is not null and p_needed_date<(now() at time zone 'Asia/Dhaka')::date then raise exception 'প্রয়োজনের তারিখ অতীত হতে পারে না।'; end if;
  if not exists(
    select 1 from public.profiles
    where id=p_donor_id and role='patient' and blood_donor_volunteer=true
      and blood_is_available=true and blood_accept_requests=true
      and nullif(btrim(coalesce(phone,'')),'') is not null
      and blood_group=p_blood_group and account_status='active'
  ) then
    raise exception 'এই ব্যক্তি বর্তমানে রক্তের অনুরোধ গ্রহণ করছেন না।';
  end if;
  if p_donor_id=auth.uid() then raise exception 'নিজেকে রক্তের অনুরোধ পাঠানো যাবে না।'; end if;

  -- Prevent duplicate/spam requests to the same donor while an active request already exists recently.
  if exists(
    select 1 from public.blood_requests
    where requester_id=auth.uid() and donor_id=p_donor_id and blood_group=p_blood_group
      and status in ('pending','accepted')
      and created_at>now()-interval '6 hours'
  ) then
    raise exception 'এই রক্তদাতাকে ইতিমধ্যে সাম্প্রতিক একটি সক্রিয় অনুরোধ পাঠানো হয়েছে।';
  end if;

  insert into public.blood_requests(
    request_number,requester_id,donor_id,blood_group,patient_name,patient_phone,needed_date,needed_time,reason,hospital_name,location_text
  ) values(
    'BR-'||to_char(now(),'YYYYMMDD')||'-'||lpad(nextval('public.blood_request_number_seq')::text,5,'0'),
    auth.uid(),p_donor_id,p_blood_group,coalesce(v_patient.full_name,'রোগী'),v_patient.phone,p_needed_date,p_needed_time,btrim(p_reason),
    nullif(btrim(p_hospital_name),''),nullif(btrim(p_location_text),'')
  ) returning id into v_id;
  perform public.push_notification(p_donor_id,'blood_request_new','নতুন রক্তের অনুরোধ',
    coalesce(v_patient.full_name,'একজন রোগী')||' আপনার '||p_blood_group||' রক্তের জন্য অনুরোধ পাঠিয়েছেন।','blood_request',v_id);
  return v_id;
end;
$$;
revoke all on function public.create_blood_request(uuid,text,text,text,date,text,text,text,text) from public;
grant execute on function public.create_blood_request(uuid,text,text,text,date,text,text,text,text) to authenticated,service_role;

create or replace function public.guard_blood_request_update()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare v_donor_phone text;
begin
  -- Donor contact is server-managed and is disclosed to this requester only after acceptance.
  new.donor_contact_phone:=old.donor_contact_phone;
  if new.status='accepted' and old.status<>'accepted' then
    select phone into v_donor_phone from public.profiles where id=old.donor_id and blood_donor_volunteer=true;
    if nullif(btrim(coalesce(v_donor_phone,'')),'') is null then
      raise exception 'রক্তদাতার প্রোফাইলে যোগাযোগের ফোন নম্বর নেই।';
    end if;
    new.donor_contact_phone:=v_donor_phone;
  end if;

  if public.is_trusted_backend_context() or public.is_admin_or_above() then
    if new.status='completed' and old.status<>'completed' then new.completed_at:=now(); end if;
    if new.status='cancelled' and old.status<>'cancelled' then new.cancelled_at:=now(); end if;
    new.updated_at:=now(); return new;
  end if;
  if auth.uid() is null or auth.uid() not in (old.requester_id,old.donor_id) then
    raise exception 'You are not allowed to update this blood request.';
  end if;
  if new.requester_id<>old.requester_id or new.donor_id<>old.donor_id
     or new.blood_group is distinct from old.blood_group
     or new.patient_name is distinct from old.patient_name
     or new.patient_phone is distinct from old.patient_phone
     or new.needed_date is distinct from old.needed_date
     or new.needed_time is distinct from old.needed_time
     or new.reason is distinct from old.reason
     or new.hospital_name is distinct from old.hospital_name
     or new.location_text is distinct from old.location_text
     or new.request_number is distinct from old.request_number then
    raise exception 'Blood request details cannot be changed after submission.';
  end if;
  if auth.uid()=old.requester_id then
    if new.status is distinct from old.status and not (new.status='cancelled' and old.status in ('pending','accepted')) then
      raise exception 'Requester can only cancel an active request.';
    end if;
    if new.donor_response_note is distinct from old.donor_response_note then raise exception 'Requester cannot edit donor response note.'; end if;
  elsif auth.uid()=old.donor_id then
    if new.status is distinct from old.status and not (
      (old.status='pending' and new.status in ('accepted','declined'))
      or (old.status='accepted' and new.status='completed')
    ) then
      raise exception 'Invalid donor status transition.';
    end if;
  end if;
  if new.status='completed' and old.status<>'completed' then new.completed_at:=now(); end if;
  if new.status='cancelled' and old.status<>'cancelled' then new.cancelled_at:=now(); end if;
  new.updated_at:=now();
  return new;
end $$;

create or replace function public.notify_blood_request_change()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='UPDATE' and new.status is distinct from old.status then
    if auth.uid()=new.donor_id or new.status in ('accepted','declined','completed') then
      perform public.push_notification(new.requester_id,'blood_request_update','রক্তের অনুরোধ আপডেট',
        'আপনার '||new.blood_group||' রক্তের অনুরোধের অবস্থা: '||new.status,'blood_request',new.id);
    elsif auth.uid()=new.requester_id and new.status='cancelled' then
      perform public.push_notification(new.donor_id,'blood_request_cancelled','রক্তের অনুরোধ বাতিল',
        'রোগী রক্তের অনুরোধটি বাতিল করেছেন।','blood_request',new.id);
    end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_notify_blood_request_change on public.blood_requests;
create trigger trg_notify_blood_request_change after update on public.blood_requests
  for each row execute procedure public.notify_blood_request_change();

create or replace function public.admin_list_blood_requests(p_limit integer default 300)
returns table(
  id uuid, request_number text, requester_id uuid, donor_id uuid,
  requester_name text, requester_phone text, donor_name text, donor_phone text,
  blood_group text, needed_date date, needed_time text, reason text,
  hospital_name text, location_text text, status text, donor_response_note text,
  donor_contact_phone text, created_at timestamptz, updated_at timestamptz,
  completed_at timestamptz, cancelled_at timestamptz
)
language plpgsql stable security definer set search_path=public as $$
begin
  if not public.is_admin_or_above() and not public.is_trusted_backend_context() then
    raise exception 'Admin access required.';
  end if;
  return query
  select b.id,b.request_number,b.requester_id,b.donor_id,
         coalesce(r.full_name,b.patient_name),coalesce(r.phone,b.patient_phone),
         d.full_name,d.phone,b.blood_group,b.needed_date,b.needed_time,b.reason,
         b.hospital_name,b.location_text,b.status,b.donor_response_note,b.donor_contact_phone,
         b.created_at,b.updated_at,b.completed_at,b.cancelled_at
  from public.blood_requests b
  left join public.profiles r on r.id=b.requester_id
  left join public.profiles d on d.id=b.donor_id
  order by b.created_at desc
  limit greatest(1,least(coalesce(p_limit,300),1000));
end $$;
revoke all on function public.admin_list_blood_requests(integer) from public;
grant execute on function public.admin_list_blood_requests(integer) to authenticated,service_role;

create or replace function public.admin_blood_request_summary()
returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
  if not public.is_admin_or_above() and not public.is_trusted_backend_context() then raise exception 'Admin access required.'; end if;
  return jsonb_build_object(
    'total',(select count(*) from public.blood_requests),
    'pending',(select count(*) from public.blood_requests where status='pending'),
    'accepted',(select count(*) from public.blood_requests where status='accepted'),
    'completed',(select count(*) from public.blood_requests where status='completed'),
    'cancelled',(select count(*) from public.blood_requests where status='cancelled'),
    'declined',(select count(*) from public.blood_requests where status='declined')
  );
end $$;
revoke all on function public.admin_blood_request_summary() from public;
grant execute on function public.admin_blood_request_summary() to authenticated,service_role;

notify pgrst, 'reload schema';
