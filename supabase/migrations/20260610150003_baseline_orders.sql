-- Baseline for fresh projects: verbatim copy of supabase/schema/orders.sql
-- (introspected source of truth from project ipxwpxozreksmuiztwcy).
-- The pre-baseline migration trail (2026060[23]*) was retired after this
-- baseline replaced it; the old files remain available in git history.

set check_function_bodies = off;


CREATE OR REPLACE FUNCTION public.auto_settle_stale_completions()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_count int;
begin
  with stale as (
    select sr.id
    from public.service_requests sr
    where sr.status in ('accepted','in_progress')
      and (sr.customer_completed <> sr.provider_completed)
      and sr.first_completed_at is not null
      and sr.first_completed_at < now() - interval '24 hours'
      and not exists (
        select 1 from public.order_disputes d
        where d.service_request_id = sr.id and d.status = 'pending'
      )
  )
  update public.service_requests sr
    set customer_completed = true,
        provider_completed = true,
        status = 'completed',
        completed_at = now()
  from stale
  where sr.id = stale.id
    and sr.status in ('accepted','in_progress');
  get diagnostics v_count = row_count;
  return v_count;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.cancel_order(p_request_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare sr public.service_requests;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  select * into sr from public.service_requests where id = p_request_id for update;
  if not found then raise exception 'Pesanan tidak ditemukan'; end if;
  if sr.customer_id <> auth.uid() then raise exception 'Bukan pesanan Anda'; end if;
  if sr.status <> 'pending' then raise exception 'Pesanan tidak dapat dibatalkan'; end if;

  update public.service_requests set status = 'cancelled', updated_at = now() where id = p_request_id;
  update public.bids set status = 'AutoRejected'
    where service_request_id = p_request_id and status = 'Pending';
end;
$function$
;

CREATE OR REPLACE FUNCTION public.cleanup_live_locations_on_terminal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if NEW.status in ('completed','cancelled') and NEW.status is distinct from OLD.status then
    delete from public.order_locations    where service_request_id = NEW.id;
    delete from public.customer_locations where service_request_id = NEW.id;
  end if;
  return NEW;
end; $function$
;

CREATE TRIGGER trg_cleanup_live_locations AFTER UPDATE OF status ON public.service_requests FOR EACH ROW EXECUTE FUNCTION cleanup_live_locations_on_terminal();

CREATE OR REPLACE FUNCTION public.mark_order_completed(p_request_id uuid, p_completion_photo_url text DEFAULT NULL::text)
 RETURNS service_requests
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare sr public.service_requests; is_customer boolean; is_handler boolean;
begin
  select * into sr from public.service_requests where id = p_request_id;
  if not found then raise exception 'Order not found'; end if;
  is_customer := (sr.customer_id = auth.uid());
  is_handler := (sr.mechanic_id = auth.uid())
             or exists (select 1 from public.bengkels b where b.id = sr.bengkel_id and b.provider_uid = auth.uid());
  if not (is_customer or is_handler) then raise exception 'Not authorized for this order'; end if;
  if sr.status not in ('accepted','in_progress') then raise exception 'Order is not in progress'; end if;

  if is_customer then
    update public.service_requests
      set customer_completed = true,
          first_completed_at = coalesce(first_completed_at, now())
      where id = p_request_id;
  end if;
  if is_handler then
    if coalesce(p_completion_photo_url, sr.completion_photo_url) is null then
      raise exception 'Foto penyelesaian wajib dilampirkan';
    end if;
    update public.service_requests
      set provider_completed = true,
          completion_photo_url = coalesce(p_completion_photo_url, completion_photo_url),
          first_completed_at = coalesce(first_completed_at, now())
      where id = p_request_id;
  end if;

  update public.service_requests
    set status = 'completed', completed_at = now()
    where id = p_request_id and customer_completed and provider_completed;

  select * into sr from public.service_requests where id = p_request_id;
  return sr;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.open_dispute(p_request_id uuid, p_reason text, p_proof_url text DEFAULT NULL::text)
 RETURNS service_requests
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare sr public.service_requests; is_customer boolean; is_handler boolean; v_role text;
begin
  select * into sr from public.service_requests where id = p_request_id for update;
  if not found then raise exception 'Order not found'; end if;
  is_customer := (sr.customer_id = auth.uid());
  is_handler := (sr.mechanic_id = auth.uid())
             or exists (select 1 from public.bengkels b where b.id = sr.bengkel_id and b.provider_uid = auth.uid());
  if not (is_customer or is_handler) then raise exception 'Not authorized for this order'; end if;
  if sr.status not in ('accepted','in_progress') then raise exception 'Order is not in progress'; end if;
  if coalesce(btrim(p_reason), '') = '' then raise exception 'A reason is required'; end if;
  v_role := case when is_customer then 'customer' else 'provider' end;

  insert into public.order_disputes (service_request_id, initiated_by, initiator_role, reason, proof_url, status)
    values (p_request_id, auth.uid(), v_role, btrim(p_reason), p_proof_url, 'pending');

  update public.service_requests set status = 'cancelled', updated_at = now() where id = p_request_id;

  select * into sr from public.service_requests where id = p_request_id;
  return sr;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rate_order(p_request_id uuid, p_rating integer)
 RETURNS service_requests
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.recompute_bengkel_rating()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare target_bengkel uuid;
begin
  target_bengkel := coalesce(new.bengkel_id, old.bengkel_id);
  if target_bengkel is null then return coalesce(new, old); end if;
  update public.bengkels b
    set average_rating = coalesce(agg.avg_rating, 0), total_reviews = coalesce(agg.cnt, 0)
    from (select avg(rating)::float8 as avg_rating, count(rating) as cnt
          from public.service_requests where bengkel_id = target_bengkel and rating is not null) agg
    where b.id = target_bengkel;
  return coalesce(new, old);
end;
$function$
;

CREATE TRIGGER trg_recompute_bengkel_rating AFTER INSERT OR DELETE OR UPDATE OF rating ON public.service_requests FOR EACH ROW EXECUTE FUNCTION recompute_bengkel_rating();

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
   NEW.updated_at = now();
   RETURN NEW;
END;
$function$
;

CREATE TRIGGER update_service_requests_updated_at BEFORE UPDATE ON public.service_requests FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
