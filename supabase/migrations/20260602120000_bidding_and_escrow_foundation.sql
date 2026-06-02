-- ============================================================================
-- Bidding + escrow foundation for BengkelIn  (Marketplace tier — Eugene)
--
-- APPLIED 2026-06-02 to project ipxwpxozreksmuiztwcy (verified against the live
-- schema first). Aligned to reality: order status is lowercase text;
-- service_requests.estimated_price is `numeric`; service_type is a Postgres enum
-- (cast ::text); money mirrors `users.balance` (double precision).
--
-- Additive & backward-compatible: bengkel_id made nullable for bidding broadcast.
-- Stops at the Money-tier seam — HOLD/SETTLE/REFUND of balances are Bryan's
-- triggers (see CONTRACTS.md); accept_bid here only GATES on available balance.
-- ============================================================================

-- 1. Escrow balance columns (columns only; movement logic = Money tier).
alter table public.users
  add column if not exists held_balance    double precision not null default 0,
  add column if not exists pending_balance double precision not null default 0;

-- 2. Allow a broadcast order with no bengkel yet.
alter table public.service_requests
  alter column bengkel_id drop not null;

-- 3. Bids table (price numeric to match service_requests.estimated_price).
create table if not exists public.bids (
  id                 uuid primary key default gen_random_uuid(),
  service_request_id uuid not null references public.service_requests(id) on delete cascade,
  provider_uid       uuid not null references public.users(id)            on delete cascade,
  bengkel_id         uuid not null references public.bengkels(id)         on delete cascade,
  price              numeric not null,
  notes              text,
  status             text not null default 'pending', -- pending/accepted/rejected/autorejected/expired
  created_at         timestamptz not null default now(),
  unique (service_request_id, provider_uid)
);
alter table public.bids enable row level security;
create index if not exists bids_service_request_id_idx on public.bids(service_request_id);
create index if not exists bids_provider_uid_idx       on public.bids(provider_uid);

-- 4. RLS (additive to the existing customer/bengkel/mechanic policies).
drop policy if exists "Authenticated can view open service requests" on public.service_requests;
create policy "Authenticated can view open service requests"
  on public.service_requests for select to authenticated
  using (status = 'pending' and bengkel_id is null);

drop policy if exists "Providers insert own bids" on public.bids;
create policy "Providers insert own bids"
  on public.bids for insert to authenticated
  with check (auth.uid() = provider_uid);

drop policy if exists "Providers view own bids" on public.bids;
create policy "Providers view own bids"
  on public.bids for select to authenticated
  using (auth.uid() = provider_uid);

drop policy if exists "Customers view bids on their requests" on public.bids;
create policy "Customers view bids on their requests"
  on public.bids for select to authenticated
  using (exists (select 1 from public.service_requests sr
                 where sr.id = bids.service_request_id and sr.customer_id = auth.uid()));

drop policy if exists "Providers update own bids" on public.bids;
create policy "Providers update own bids"
  on public.bids for update to authenticated
  using (auth.uid() = provider_uid) with check (auth.uid() = provider_uid);

drop policy if exists "Customers update bids on their requests" on public.bids;
create policy "Customers update bids on their requests"
  on public.bids for update to authenticated
  using (exists (select 1 from public.service_requests sr
                 where sr.id = bids.service_request_id and sr.customer_id = auth.uid()))
  with check (exists (select 1 from public.service_requests sr
                 where sr.id = bids.service_request_id and sr.customer_id = auth.uid()));

-- 5. Self-bid guard.
create or replace function public.reject_self_bid()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if exists (select 1 from public.service_requests sr
             where sr.id = new.service_request_id and sr.customer_id = new.provider_uid) then
    raise exception 'Tidak dapat menawar order sendiri';
  end if;
  return new;
end;
$fn$;
drop trigger if exists trg_reject_self_bid on public.bids;
create trigger trg_reject_self_bid before insert or update on public.bids
  for each row execute function public.reject_self_bid();

-- 6. Geospatial discovery RPCs (Haversine, metres). service_type cast ::text (enum).
create or replace function public.nearby_service_requests(
  p_lat double precision, p_lon double precision, p_radius_m double precision default 5000)
returns table (
  id uuid, customer_id uuid, customer_name text, service_type text, description text,
  is_emergency boolean, latitude double precision, longitude double precision,
  estimated_price numeric, status text, created_at timestamptz, distance_m double precision)
language sql security definer set search_path = public as $fn$
  select sr.id, sr.customer_id, u.name, sr.service_type::text, sr.description, sr.is_emergency,
         sr.latitude, sr.longitude, sr.estimated_price, sr.status, sr.created_at,
         6371000 * 2 * asin(sqrt(power(sin(radians(sr.latitude - p_lat)/2),2) +
           cos(radians(p_lat))*cos(radians(sr.latitude))*power(sin(radians(sr.longitude - p_lon)/2),2))) as distance_m
  from public.service_requests sr
  join public.users u on u.id = sr.customer_id
  where sr.bengkel_id is null
    and sr.status = 'pending'
    and sr.latitude is not null and sr.longitude is not null
    and 6371000 * 2 * asin(sqrt(power(sin(radians(sr.latitude - p_lat)/2),2) +
          cos(radians(p_lat))*cos(radians(sr.latitude))*power(sin(radians(sr.longitude - p_lon)/2),2))) <= p_radius_m
  order by distance_m asc;
$fn$;

create or replace function public.nearby_bengkels(
  p_lat double precision, p_lon double precision, p_radius_m double precision default 5000)
returns table (
  id uuid, provider_uid uuid, name text, address text, latitude double precision,
  longitude double precision, average_rating double precision, total_reviews integer,
  offered_services jsonb, distance_m double precision)
language sql security definer set search_path = public as $fn$
  select b.id, b.provider_uid, b.name, b.address, b.latitude, b.longitude,
         b.average_rating, b.total_reviews, b.offered_services,
         6371000 * 2 * asin(sqrt(power(sin(radians(b.latitude - p_lat)/2),2) +
           cos(radians(p_lat))*cos(radians(b.latitude))*power(sin(radians(b.longitude - p_lon)/2),2))) as distance_m
  from public.bengkels b
  where b.status::text = 'Verified'
    and 6371000 * 2 * asin(sqrt(power(sin(radians(b.latitude - p_lat)/2),2) +
          cos(radians(p_lat))*cos(radians(b.latitude))*power(sin(radians(b.longitude - p_lon)/2),2))) <= p_radius_m
  order by distance_m asc;
$fn$;
revoke all on function public.nearby_service_requests(double precision,double precision,double precision) from public;
revoke all on function public.nearby_bengkels(double precision,double precision,double precision)         from public;
grant execute on function public.nearby_service_requests(double precision,double precision,double precision) to authenticated;
grant execute on function public.nearby_bengkels(double precision,double precision,double precision)         to authenticated;

-- 7. accept_bid — atomic, balance-gated. Money MOVEMENT stays in the Money tier;
--    this only gates on available balance and assigns the winning bengkel + price.
create or replace function public.accept_bid(p_bid_id uuid)
returns public.service_requests
language plpgsql security definer set search_path = public as $fn$
declare
  v_bid       public.bids;
  sr          public.service_requests;
  v_available numeric;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  select * into v_bid from public.bids where id = p_bid_id;
  if not found then raise exception 'Bid not found'; end if;

  select * into sr from public.service_requests where id = v_bid.service_request_id for update;
  if not found then raise exception 'Order not found'; end if;
  if sr.customer_id <> auth.uid() then raise exception 'Not authorized for this order'; end if;
  if sr.status <> 'pending' or sr.bengkel_id is not null then raise exception 'Order no longer open'; end if;

  select (coalesce(balance,0) - coalesce(held_balance,0))::numeric into v_available
    from public.users where id = sr.customer_id;
  if v_available is null or v_available < v_bid.price then
    raise exception 'Saldo tidak cukup';
  end if;

  update public.bids set status = 'accepted' where id = v_bid.id;
  update public.bids set status = 'autorejected'
    where service_request_id = v_bid.service_request_id and id <> v_bid.id;

  update public.service_requests
    set status = 'accepted', bengkel_id = v_bid.bengkel_id, estimated_price = v_bid.price, updated_at = now()
    where id = sr.id;

  select * into sr from public.service_requests where id = sr.id;
  return sr;
end;
$fn$;
grant execute on function public.accept_bid(uuid) to authenticated;

-- 8. Realtime publication (idempotent).
do $do$ begin
  if not exists (select 1 from pg_publication_tables
                 where pubname='supabase_realtime' and schemaname='public' and tablename='bids') then
    alter publication supabase_realtime add table public.bids;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname='supabase_realtime' and schemaname='public' and tablename='service_requests') then
    alter publication supabase_realtime add table public.service_requests;
  end if;
end $do$;

-- 9. Harden grants: SECURITY DEFINER functions must not be callable by anon.
--    (CREATE OR REPLACE preserves the default PUBLIC grant, so revoke explicitly.)
revoke execute on function public.accept_bid(uuid) from public, anon;
revoke execute on function public.nearby_service_requests(double precision,double precision,double precision) from public, anon;
revoke execute on function public.nearby_bengkels(double precision,double precision,double precision) from public, anon;
revoke execute on function public.reject_self_bid() from public, anon, authenticated; -- trigger only
grant execute on function public.accept_bid(uuid) to authenticated;
