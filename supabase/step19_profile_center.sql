-- Step 19: Unified provider profile + phone visibility
-- Safe to run once on the existing Doctor V1 database.

alter table public.profiles
  add column if not exists phone_public boolean not null default false;

alter table public.shops
  add column if not exists phone_public boolean not null default true;

alter table public.shops
  add column if not exists whatsapp_public boolean not null default false;

alter table public.shops
  add column if not exists assistant_phone_public boolean not null default false;
