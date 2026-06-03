-- Housekeeping after the mechanic-dispatch rework.
--  1. Stale enum: "ServiceType" is unused — service_requests.service_type is text. (0 deps.)
--  2. Redundant indexes: each is fully covered by a composite unique index whose leading
--     column is the same, so it only adds write overhead.
--  3. Live-tracking rows (order_locations / customer_locations) are ephemeral — only needed
--     while an order is active. Purge the rows for already-finished orders, and add a trigger
--     so they're cleaned up automatically when an order becomes completed/cancelled.

-- 1. Stale enum.
drop type if exists "ServiceType";

-- 2. Redundant indexes.
drop index if exists public.behavior_reports_request_idx;   -- covered by behavior_reports_unique_reporter_per_request
drop index if exists public.bids_service_request_id_idx;     -- covered by bids_service_request_id_provider_uid_key

-- 3a. Purge stale live-tracking rows for finished orders.
delete from public.order_locations ol
  using public.service_requests s
  where s.id = ol.service_request_id and s.status in ('completed','cancelled');
delete from public.customer_locations cl
  using public.service_requests s
  where s.id = cl.service_request_id and s.status in ('completed','cancelled');

-- 3b. Keep them clean going forward: drop the live location once the order finishes.
create or replace function public.cleanup_live_locations_on_terminal()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if NEW.status in ('completed','cancelled') and NEW.status is distinct from OLD.status then
    delete from public.order_locations    where service_request_id = NEW.id;
    delete from public.customer_locations where service_request_id = NEW.id;
  end if;
  return NEW;
end; $fn$;

drop trigger if exists trg_cleanup_live_locations on public.service_requests;
create trigger trg_cleanup_live_locations
  after update of status on public.service_requests
  for each row execute function public.cleanup_live_locations_on_terminal();
