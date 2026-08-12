-- ============================================================
-- Product Analytics: Views, Saves, Order-Button Clicks
-- এই মাইগ্রেশনটি Supabase SQL Editor-এ রান করতে হবে (idempotent, নতুন ও
-- বিদ্যমান উভয় প্রজেক্টেই নিরাপদ)।
--
-- কী যোগ হচ্ছে:
--   - products.view_count  : পণ্যের পেজ কতবার দেখা হয়েছে
--   - products.save_count  : কতজন ভিজিটর/সেলার পণ্যটি সেভ করেছেন
--   - products.click_count : "অর্ডার করুন" বাটনে কতবার ক্লিক হয়েছে
--     (WhatsApp / Facebook Page-Messenger এ সেলারের সাথে যোগাযোগ করতে)
--   - product_saves টেবিল  : কোন লগইন ইউজার কোন পণ্য সেভ করেছেন (toggle-able)
--   - increment_product_view() / increment_product_order_click() RPC:
--     visitor/anon সহ যে কেউ কল করতে পারবে, কিন্তু শুধুমাত্র নির্দিষ্ট
--     কাউন্টার কলামটাই atomic ভাবে বাড়বে — SECURITY DEFINER দিয়ে সুরক্ষিত,
--     products টেবিলে সরাসরি update permission না দিয়েই এটা সম্ভব হচ্ছে।
--   - products টেবিলকে Supabase Realtime publication-এ যোগ করা হচ্ছে, যাতে
--     Seller Dashboard-এর Analytics পেজ নতুন view/save/click near-real-time
--     দেখতে পারে (polling ছাড়াই)।
-- ============================================================

-- ------------------------------------------------------------
-- 1. COUNTER COLUMNS
-- ------------------------------------------------------------
alter table public.products
  add column if not exists view_count integer not null default 0,
  add column if not exists save_count integer not null default 0,
  add column if not exists click_count integer not null default 0;

alter table public.products drop constraint if exists products_view_count_check;
alter table public.products add constraint products_view_count_check check (view_count >= 0);

alter table public.products drop constraint if exists products_save_count_check;
alter table public.products add constraint products_save_count_check check (save_count >= 0);

alter table public.products drop constraint if exists products_click_count_check;
alter table public.products add constraint products_click_count_check check (click_count >= 0);

-- ------------------------------------------------------------
-- 2. product_saves — কে কোন পণ্য সেভ করেছেন (শুধুমাত্র লগইন ইউজার)
-- ------------------------------------------------------------
create table if not exists public.product_saves (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (product_id, user_id)
);
create index if not exists idx_product_saves_product on public.product_saves (product_id);
create index if not exists idx_product_saves_user on public.product_saves (user_id);

alter table public.product_saves enable row level security;

drop policy if exists "product_saves_select_own" on public.product_saves;
create policy "product_saves_select_own"
  on public.product_saves for select
  using (user_id = auth.uid() or public.is_super_admin());

drop policy if exists "product_saves_insert_own" on public.product_saves;
create policy "product_saves_insert_own"
  on public.product_saves for insert
  with check (user_id = auth.uid());

drop policy if exists "product_saves_delete_own" on public.product_saves;
create policy "product_saves_delete_own"
  on public.product_saves for delete
  using (user_id = auth.uid());

-- save/unsave হলে products.save_count স্বয়ংক্রিয়ভাবে (atomic) আপডেট হবে
create or replace function public.handle_product_save_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.products set save_count = save_count + 1 where id = new.product_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.products set save_count = greatest(save_count - 1, 0) where id = old.product_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_product_save_insert on public.product_saves;
create trigger trg_product_save_insert
  after insert on public.product_saves
  for each row execute procedure public.handle_product_save_change();

drop trigger if exists trg_product_save_delete on public.product_saves;
create trigger trg_product_save_delete
  after delete on public.product_saves
  for each row execute procedure public.handle_product_save_change();

-- ------------------------------------------------------------
-- 3. RPC — view / order-click কাউন্ট বাড়ানো (visitor/anon সহ যে কেউ কল করতে
--    পারবে, কিন্তু শুধু নির্দিষ্ট কাউন্টার কলামই বাড়বে, নিষ্ক্রিয় পণ্যে নয়)
-- ------------------------------------------------------------
create or replace function public.increment_product_view(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.products
  set view_count = view_count + 1
  where id = p_product_id and is_active = true;
end;
$$;

create or replace function public.increment_product_order_click(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.products
  set click_count = click_count + 1
  where id = p_product_id and is_active = true;
end;
$$;

grant execute on function public.increment_product_view(uuid) to anon, authenticated;
grant execute on function public.increment_product_order_click(uuid) to anon, authenticated;

-- ------------------------------------------------------------
-- 4. REALTIME — Seller Analytics পেজ near-real-time আপডেট পাওয়ার জন্য
--    products টেবিলকে supabase_realtime publication-এ যোগ করা হচ্ছে
--    (আগে থেকে যোগ করা থাকলে চুপচাপ স্কিপ করবে, error দেবে না)
-- ------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'products'
  ) then
    alter publication supabase_realtime add table public.products;
  end if;
end $$;
