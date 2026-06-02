-- APPLIED 2026-06-02 to project ipxwpxozreksmuiztwcy.
-- Bug: incoming bids showed raw "pending" on the customer side with no accept/reject
-- buttons. Cause: bid statuses were written lowercase, but the customer bid card
-- (BidReceivedCard) is case-sensitive and only renders actions for status == "Pending".
-- Fix: write capitalized bid statuses (Pending/Accepted/Rejected/Expired/AutoRejected).
-- The bidding edge function's placeBid was fixed separately (now inserts "Pending").
-- NOTE: service_requests.status stays lowercase — that is the order vocabulary and is
-- consumed lowercase throughout the app. Only bid status is capitalized.

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
  update public.bids set status = 'Accepted' where id = v_bid.id;
  update public.bids set status = 'AutoRejected' where service_request_id = v_bid.service_request_id and id <> v_bid.id;
  update public.service_requests set status = 'accepted', bengkel_id = v_bid.bengkel_id, price = v_bid.price, updated_at = now() where id = sr.id;
  select * into sr from public.service_requests where id = sr.id;
  return sr;
end; $fn$;

-- Normalize any existing lowercase bid rows left from the old function/edge fn.
update public.bids set status = 'Pending' where status = 'pending';
update public.bids set status = 'Accepted' where status = 'accepted';
update public.bids set status = 'AutoRejected' where status = 'autorejected';
update public.bids set status = 'Rejected' where status = 'rejected';
update public.bids set status = 'Expired' where status = 'expired';
