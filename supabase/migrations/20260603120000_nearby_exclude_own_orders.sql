-- APPLIED 2026-06-03 to project ipxwpxozreksmuiztwcy.
-- A bengkel must not see / be notified of / bid on its OWN order (a provider who also
-- placed an order as a customer). The bengkel feed and the arrived-order modal both
-- derive from nearby_service_requests, so exclude orders created by the caller.
-- SECURITY DEFINER does not change auth.uid() (it's read from the request JWT), so this
-- is the requesting bengkel's own uid. (placeBid in the bidding edge fn already rejects
-- self-bids as a backstop.)
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
  order by distance_m asc;
$fn$;
