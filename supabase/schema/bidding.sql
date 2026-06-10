set check_function_bodies = off;


CREATE OR REPLACE FUNCTION public.accept_bid(p_bid_id uuid)
 RETURNS service_requests
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_bid public.bids; sr public.service_requests; v_available numeric;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  select * into v_bid from public.bids where id = p_bid_id;
  if not found then raise exception 'Bid not found'; end if;
  select * into sr from public.service_requests where id = v_bid.service_request_id for update;
  if not found then raise exception 'Order not found'; end if;
  if sr.customer_id <> auth.uid() then raise exception 'Not authorized for this order'; end if;
  if sr.status <> 'pending' or sr.bengkel_id is not null then raise exception 'Order no longer open'; end if;
  select (coalesce(balance,0) - coalesce(held_balance,0) + coalesce(sr.price,0))::numeric
    into v_available from public.users where id = sr.customer_id;
  if v_available is null or v_available < v_bid.price then raise exception 'Saldo tidak cukup'; end if;
  update public.bids set status = 'Accepted' where id = v_bid.id;
  update public.bids set status = 'AutoRejected' where service_request_id = v_bid.service_request_id and id <> v_bid.id;
  update public.service_requests set status = 'accepted', bengkel_id = v_bid.bengkel_id, price = v_bid.price, updated_at = now() where id = sr.id;
  select * into sr from public.service_requests where id = sr.id;
  return sr;
end; $function$
;

CREATE OR REPLACE FUNCTION public.nearby_bengkels(p_lat double precision, p_lon double precision, p_radius_m double precision DEFAULT 5000)
 RETURNS TABLE(id uuid, provider_uid uuid, name text, address text, latitude double precision, longitude double precision, average_rating double precision, total_reviews integer, offered_services jsonb, distance_m double precision)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select b.id, b.provider_uid, b.name, b.address, b.latitude, b.longitude,
         b.average_rating, b.total_reviews, b.offered_services,
         6371000 * 2 * asin(sqrt(power(sin(radians(b.latitude - p_lat)/2),2) +
           cos(radians(p_lat))*cos(radians(b.latitude))*power(sin(radians(b.longitude - p_lon)/2),2))) as distance_m
  from public.bengkels b
  where b.status::text = 'Verified'
    and 6371000 * 2 * asin(sqrt(power(sin(radians(b.latitude - p_lat)/2),2) +
          cos(radians(p_lat))*cos(radians(b.latitude))*power(sin(radians(b.longitude - p_lon)/2),2))) <= p_radius_m
  order by distance_m asc;
$function$
;

CREATE OR REPLACE FUNCTION public.nearby_service_requests(p_lat double precision, p_lon double precision, p_radius_m double precision DEFAULT 5000)
 RETURNS TABLE(id uuid, customer_id uuid, customer_name text, service_type text, description text, is_emergency boolean, latitude double precision, longitude double precision, price bigint, status text, created_at timestamp with time zone, distance_m double precision)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.reject_self_bid()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if exists (select 1 from public.service_requests sr
             where sr.id = new.service_request_id and sr.customer_id = new.provider_uid) then
    raise exception 'Tidak dapat menawar order sendiri';
  end if;
  return new;
end;
$function$
;

CREATE TRIGGER trg_reject_self_bid BEFORE INSERT OR UPDATE ON public.bids FOR EACH ROW EXECUTE FUNCTION reject_self_bid();
