-- Ratings are stars-only now. Drop the free-text review column and the rate_order p_review
-- parameter. (No rows currently carry a review; no index/policy/trigger references it.)

drop function if exists public.rate_order(uuid, int, text);
alter table public.service_requests drop column if exists review;

create or replace function public.rate_order(p_request_id uuid, p_rating int)
returns public.service_requests
language plpgsql security definer set search_path = public as $fn$
declare sr public.service_requests;
begin
  if p_rating < 1 or p_rating > 5 then raise exception 'Rating must be between 1 and 5'; end if;
  update public.service_requests
    set rating = p_rating
    where id = p_request_id and customer_id = auth.uid() and status = 'completed' and rating is null
    returning * into sr;
  if not found then raise exception 'Order cannot be rated'; end if;
  return sr;
end;
$fn$;

revoke all on function public.rate_order(uuid, int) from public, anon;
grant execute on function public.rate_order(uuid, int) to authenticated;
