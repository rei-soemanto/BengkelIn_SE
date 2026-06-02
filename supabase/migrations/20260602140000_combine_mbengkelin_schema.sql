-- ============================================================================
-- Phase 0 — Combine MbengkelIn backend into BengkelIn: SCHEMA
-- (columns, tables, RLS, realtime, storage buckets). Money/logic functions
-- live in the companion 20260602141000 migration.
--
-- Ported from MbengkelIn. Values/strings copied verbatim (Indonesian kept).
-- ONLY adaptation: status codes use BengkelIn's lowercase vocabulary
-- (pending/accepted/in_progress/completed/cancelled), and money columns are
-- numeric (estimated_price) — the existing BengkelIn app depends on these.
-- ============================================================================

-- service_requests: completion/proof/rating + order-display columns
alter table public.service_requests
  add column if not exists customer_completed  boolean not null default false,
  add column if not exists provider_completed  boolean not null default false,
  add column if not exists completion_photo_url text,
  add column if not exists completed_at         timestamptz,
  add column if not exists rating               int,
  add column if not exists review               text,
  add column if not exists tire_count           int not null default 1,
  add column if not exists photo_urls           jsonb not null default '[]'::jsonb,
  add column if not exists vehicle_info         text;

do $do$ begin
  if not exists (select 1 from pg_constraint where conname = 'service_requests_rating_range') then
    alter table public.service_requests
      add constraint service_requests_rating_range check (rating is null or (rating between 1 and 5));
  end if;
end $do$;

-- users: payout bank details
alter table public.users
  add column if not exists bank_name           text,
  add column if not exists bank_account_number text,
  add column if not exists bank_account_name   text;

-- topups (balance top-ups via Midtrans Snap)
create table if not exists public.topups (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    order_id text not null unique,
    gross_amount double precision not null,
    status text not null default 'pending',
    payment_type text,
    redirect_url text,
    snap_token text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create index if not exists topups_user_id_idx on public.topups (user_id);
alter table public.topups enable row level security;
drop policy if exists "topups_select_own" on public.topups;
create policy "topups_select_own" on public.topups
    for select using (auth.uid() = user_id);

-- withdrawals (provider payouts)
create table if not exists public.withdrawals (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    amount double precision not null,
    bank_name text,
    bank_account_number text,
    bank_account_name text,
    status text not null default 'pending',
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create index if not exists withdrawals_user_id_idx on public.withdrawals (user_id);
alter table public.withdrawals enable row level security;
drop policy if exists "withdrawals_select_own" on public.withdrawals;
create policy "withdrawals_select_own" on public.withdrawals
    for select using (auth.uid() = user_id);

-- chat_messages (customer ↔ assigned bengkel provider)
create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  service_request_id uuid not null references public.service_requests(id) on delete cascade,
  sender_id uuid not null references public.users(id),
  content text,
  image_url text,
  created_at timestamptz not null default now(),
  constraint chat_messages_content_or_image check (content is not null or image_url is not null)
);
create index if not exists chat_messages_request_idx on public.chat_messages(service_request_id, created_at);
alter table public.chat_messages enable row level security;

drop policy if exists "Participants view messages" on public.chat_messages;
create policy "Participants view messages" on public.chat_messages
for select using (
  exists (select 1 from public.service_requests sr
    where sr.id = chat_messages.service_request_id
      and (sr.customer_id = auth.uid()
        or exists (select 1 from public.bengkels b where b.id = sr.bengkel_id and b.provider_uid = auth.uid())))
);

drop policy if exists "Participants send messages" on public.chat_messages;
create policy "Participants send messages" on public.chat_messages
for insert with check (
  sender_id = auth.uid()
  and exists (select 1 from public.service_requests sr
    where sr.id = chat_messages.service_request_id
      and sr.status in ('pending','accepted','in_progress')   -- (MbengkelIn: 'To Do','On Progress')
      and (sr.customer_id = auth.uid()
        or exists (select 1 from public.bengkels b where b.id = sr.bengkel_id and b.provider_uid = auth.uid())))
);

-- order_locations (assigned provider's live location)
create table if not exists public.order_locations (
  service_request_id uuid primary key references public.service_requests(id) on delete cascade,
  provider_uid uuid not null references public.users(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  updated_at timestamptz not null default now()
);
alter table public.order_locations enable row level security;
drop policy if exists "Providers insert their order location" on public.order_locations;
create policy "Providers insert their order location" on public.order_locations
  for insert with check (auth.uid() = provider_uid);
drop policy if exists "Providers update their order location" on public.order_locations;
create policy "Providers update their order location" on public.order_locations
  for update using (auth.uid() = provider_uid) with check (auth.uid() = provider_uid);
drop policy if exists "Order parties read live location" on public.order_locations;
create policy "Order parties read live location" on public.order_locations
  for select using (
    auth.uid() = provider_uid
    or exists (select 1 from public.service_requests sr
      where sr.id = order_locations.service_request_id and sr.customer_id = auth.uid())
  );

-- customer_locations (customer's live location)
create table if not exists public.customer_locations (
  service_request_id uuid primary key references public.service_requests(id) on delete cascade,
  customer_id uuid not null references public.users(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  updated_at timestamptz not null default now()
);
alter table public.customer_locations enable row level security;
drop policy if exists "Customers insert their order location" on public.customer_locations;
create policy "Customers insert their order location" on public.customer_locations
  for insert with check (auth.uid() = customer_id);
drop policy if exists "Customers update their order location" on public.customer_locations;
create policy "Customers update their order location" on public.customer_locations
  for update using (auth.uid() = customer_id) with check (auth.uid() = customer_id);
drop policy if exists "Order parties read customer location" on public.customer_locations;
create policy "Order parties read customer location" on public.customer_locations
  for select using (
    auth.uid() = customer_id
    or exists (select 1 from public.service_requests sr
      join public.bengkels b on b.id = sr.bengkel_id
      where sr.id = customer_locations.service_request_id and b.provider_uid = auth.uid())
  );
alter table public.customer_locations replica identity full;

-- order_disputes (in-progress cancellation under review; inserts via open_dispute RPC only)
create table if not exists public.order_disputes (
  id uuid primary key default gen_random_uuid(),
  service_request_id uuid not null references public.service_requests(id) on delete cascade,
  initiated_by uuid not null references public.users(id),
  initiator_role text not null check (initiator_role in ('customer','provider')),
  reason text not null,
  proof_url text,
  status text not null default 'pending' check (status in ('pending','refunded','paid')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index if not exists order_disputes_request_idx on public.order_disputes(service_request_id);
alter table public.order_disputes enable row level security;
drop policy if exists "Order parties view disputes" on public.order_disputes;
create policy "Order parties view disputes" on public.order_disputes
  for select using (
    auth.uid() = initiated_by
    or exists (select 1 from public.service_requests sr
      where sr.id = order_disputes.service_request_id and sr.customer_id = auth.uid())
    or exists (select 1 from public.service_requests sr
      join public.bengkels b on b.id = sr.bengkel_id
      where sr.id = order_disputes.service_request_id and b.provider_uid = auth.uid())
  );

-- behavior_reports (post-order conduct reports)
create table if not exists public.behavior_reports (
  id uuid primary key default gen_random_uuid(),
  service_request_id uuid not null references public.service_requests(id) on delete cascade,
  reporter_id uuid not null references public.users(id) on delete cascade,
  reason text not null,
  created_at timestamptz not null default now()
);
create index if not exists behavior_reports_request_idx on public.behavior_reports(service_request_id);
alter table public.behavior_reports enable row level security;
drop policy if exists "Order parties insert reports" on public.behavior_reports;
create policy "Order parties insert reports" on public.behavior_reports
  for insert with check (
    auth.uid() = reporter_id
    and (exists (select 1 from public.service_requests sr
          where sr.id = service_request_id and sr.customer_id = auth.uid())
      or exists (select 1 from public.service_requests sr
          join public.bengkels b on b.id = sr.bengkel_id
          where sr.id = service_request_id and b.provider_uid = auth.uid()))
  );
drop policy if exists "Reporters view own reports" on public.behavior_reports;
create policy "Reporters view own reports" on public.behavior_reports
  for select using (auth.uid() = reporter_id);

-- Storage buckets: chat images + order/completion photos
insert into storage.buckets (id, name, public) values ('chat-images', 'chat-images', true)
  on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('order-photos', 'order-photos', true)
  on conflict (id) do nothing;
drop policy if exists "Auth upload chat images" on storage.objects;
create policy "Auth upload chat images" on storage.objects
  for insert to authenticated with check (bucket_id = 'chat-images');
drop policy if exists "Public read chat images" on storage.objects;
create policy "Public read chat images" on storage.objects
  for select using (bucket_id = 'chat-images');
drop policy if exists "Auth upload order photos" on storage.objects;
create policy "Auth upload order photos" on storage.objects
  for insert to authenticated with check (bucket_id = 'order-photos');
drop policy if exists "Public read order photos" on storage.objects;
create policy "Public read order photos" on storage.objects
  for select using (bucket_id = 'order-photos');

-- Realtime publications (idempotent) for the new live tables
do $do$ begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='chat_messages') then
    alter publication supabase_realtime add table public.chat_messages; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='order_locations') then
    alter publication supabase_realtime add table public.order_locations; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='customer_locations') then
    alter publication supabase_realtime add table public.customer_locations; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='topups') then
    alter publication supabase_realtime add table public.topups; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='withdrawals') then
    alter publication supabase_realtime add table public.withdrawals; end if;
end $do$;
