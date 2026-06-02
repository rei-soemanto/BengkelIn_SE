-- APPLIED 2026-06-02 to project ipxwpxozreksmuiztwcy.
-- The wholesale MbengkelIn iOS clone expects service_requests.`price` (bigint)
-- and bids.price (bigint). Rename + retype, and re-point the 3 functions that
-- referenced estimated_price. (Stale test bengkel/order/bid rows were cleared
-- separately so the cloned Bengkel/offered_services shape decodes cleanly.)

alter table public.service_requests rename column estimated_price to price;
alter table public.service_requests alter column price type bigint using round(price)::bigint;
alter table public.bids alter column price type bigint using round(price)::bigint;

create or replace function public.accept_bid(p_bid_id uuid) returns service_requests
 language plpgsql security definer set search_path to 'public' as $fn$
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
  update public.bids set status = 'accepted' where id = v_bid.id;
  update public.bids set status = 'autorejected' where service_request_id = v_bid.service_request_id and id <> v_bid.id;
  update public.service_requests set status = 'accepted', bengkel_id = v_bid.bengkel_id, price = v_bid.price, updated_at = now() where id = sr.id;
  select * into sr from public.service_requests where id = sr.id;
  return sr;
end; $fn$;

create or replace function public.handle_order_balance() returns trigger
 language plpgsql security definer set search_path to 'public' as $fn$
declare prov uuid;
begin
  if (TG_OP = 'INSERT') then
    if NEW.status = 'pending' and NEW.price is not null then
      update public.users set held_balance = held_balance + NEW.price where id = NEW.customer_id;
    end if; return NEW;
  end if;
  if (TG_OP = 'DELETE') then
    if OLD.price is not null and OLD.status in ('pending','accepted','in_progress') then
      update public.users set held_balance = greatest(0, held_balance - OLD.price) where id = OLD.customer_id;
      if OLD.status in ('accepted','in_progress') then
        select provider_uid into prov from public.bengkels where id = OLD.bengkel_id;
        if prov is not null then update public.users set pending_balance = greatest(0, pending_balance - OLD.price) where id = prov; end if;
      end if;
    end if; return OLD;
  end if;
  if OLD.status = 'pending' and NEW.status = 'pending' and coalesce(NEW.price,0) <> coalesce(OLD.price,0) then
    update public.users set held_balance = greatest(0, held_balance + coalesce(NEW.price,0) - coalesce(OLD.price,0)) where id = NEW.customer_id;
  end if;
  if OLD.status = 'pending' and NEW.status = 'accepted' then
    if coalesce(NEW.price,0) <> coalesce(OLD.price,0) then
      update public.users set held_balance = greatest(0, held_balance + coalesce(NEW.price,0) - coalesce(OLD.price,0)) where id = NEW.customer_id;
    end if;
    select provider_uid into prov from public.bengkels where id = NEW.bengkel_id;
    if prov is not null then update public.users set pending_balance = pending_balance + coalesce(NEW.price,0) where id = prov; end if;
  end if;
  if OLD.status in ('accepted','in_progress') and NEW.status = 'completed' then
    update public.users set balance = balance - coalesce(NEW.price,0), held_balance = greatest(0, held_balance - coalesce(NEW.price,0)) where id = NEW.customer_id;
    select provider_uid into prov from public.bengkels where id = NEW.bengkel_id;
    if prov is not null then update public.users set balance = balance + coalesce(NEW.price,0), pending_balance = greatest(0, pending_balance - coalesce(NEW.price,0)) where id = prov; end if;
  end if;
  if NEW.status = 'cancelled' and OLD.status <> 'cancelled' then
    update public.users set held_balance = greatest(0, held_balance - coalesce(OLD.price,0)) where id = NEW.customer_id;
    if OLD.status in ('accepted','in_progress') then
      select provider_uid into prov from public.bengkels where id = OLD.bengkel_id;
      if prov is not null then update public.users set pending_balance = greatest(0, pending_balance - coalesce(OLD.price,0)) where id = prov; end if;
    end if;
  end if;
  return NEW;
end; $fn$;

drop function if exists public.nearby_service_requests(double precision, double precision, double precision);
create function public.nearby_service_requests(p_lat double precision, p_lon double precision, p_radius_m double precision default 5000)
 returns table(id uuid, customer_id uuid, customer_name text, service_type text, description text, is_emergency boolean, latitude double precision, longitude double precision, price bigint, status text, created_at timestamptz, distance_m double precision)
 language sql security definer set search_path to 'public' as $fn$
  select sr.id, sr.customer_id, u.name, sr.service_type::text, sr.description, sr.is_emergency,
         sr.latitude, sr.longitude, sr.price, sr.status, sr.created_at,
         6371000 * 2 * asin(sqrt(power(sin(radians(sr.latitude - p_lat)/2),2) + cos(radians(p_lat))*cos(radians(sr.latitude))*power(sin(radians(sr.longitude - p_lon)/2),2))) as distance_m
  from public.service_requests sr join public.users u on u.id = sr.customer_id
  where sr.bengkel_id is null and sr.status = 'pending' and sr.latitude is not null and sr.longitude is not null
    and 6371000 * 2 * asin(sqrt(power(sin(radians(sr.latitude - p_lat)/2),2) + cos(radians(p_lat))*cos(radians(sr.latitude))*power(sin(radians(sr.longitude - p_lon)/2),2))) <= p_radius_m
  order by distance_m asc;
$fn$;
revoke all on function public.nearby_service_requests(double precision,double precision,double precision) from public, anon;
grant execute on function public.nearby_service_requests(double precision,double precision,double precision) to authenticated;
