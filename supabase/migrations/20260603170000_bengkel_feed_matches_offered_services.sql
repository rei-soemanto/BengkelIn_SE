-- A bengkel should only see / be notified of / bid on orders for a service it actually
-- offers. The feed + arrived-order modal both derive from nearby_service_requests, so filter
-- there: keep an order only if the caller's bengkel has a matching ACTIVE offered_service.
-- A bengkel with no services (e.g. "Bengkel Eugene", offered_services = []) now matches nothing.

create or replace function public.nearby_service_requests(p_lat double precision, p_lon double precision, p_radius_m double precision default 5000)
 returns table(id uuid, customer_id uuid, customer_name text, service_type text, description text, is_emergency boolean, latitude double precision, longitude double precision, price bigint, status text, created_at timestamptz, distance_m double precision)
 language sql security definer set search_path to 'public' as $fn$
  select sr.id, sr.customer_id, u.name, sr.service_type::text, sr.description, sr.is_emergency,
         sr.latitude, sr.longitude, sr.price, sr.status, sr.created_at,
         6371000 * 2 * asin(sqrt(power(sin(radians(sr.latitude - p_lat)/2),2) + cos(radians(p_lat))*cos(radians(sr.latitude))*power(sin(radians(sr.longitude - p_lon)/2),2))) as distance_m
  from public.service_requests sr join public.users u on u.id = sr.customer_id
  where sr.bengkel_id is null and sr.status = 'pending' and sr.latitude is not null and sr.longitude is not null
    and sr.customer_id <> auth.uid()
    and 6371000 * 2 * asin(sqrt(power(sin(radians(sr.latitude - p_lat)/2),2) + cos(radians(p_lat))*cos(radians(sr.latitude))*power(sin(radians(sr.longitude - p_lon)/2),2))) <= p_radius_m
    and exists (
      select 1 from public.bengkels b
      cross join lateral jsonb_array_elements(b.offered_services) svc
      where b.provider_uid = auth.uid()
        and (svc->>'service_type') = sr.service_type::text
        and coalesce((svc->>'is_active')::boolean, true)
    )
  order by distance_m asc;
$fn$;

-- Defense-in-depth: reject a bid on an order whose service the bengkel doesn't offer.
drop policy if exists "Providers insert own bids" on public.bids;
create policy "Providers insert own bids" on public.bids for insert to authenticated
  with check (
    auth.uid() = provider_uid
    and exists (
      select 1 from public.service_requests sr
      join public.bengkels b on b.id = bids.bengkel_id and b.provider_uid = auth.uid()
      cross join lateral jsonb_array_elements(b.offered_services) svc
      where sr.id = bids.service_request_id
        and (svc->>'service_type') = sr.service_type::text
        and coalesce((svc->>'is_active')::boolean, true)
    )
  );
