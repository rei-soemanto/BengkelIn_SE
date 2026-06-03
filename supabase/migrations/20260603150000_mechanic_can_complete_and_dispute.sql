-- After removing bengkel "Self", the assigned MECHANIC is the handler who completes the job
-- and can report a kendala. Both RPCs previously authorized only the customer or the bengkel
-- provider, so the mechanic hit "Not authorized for this order". Authorize the assigned
-- mechanic as the handler side (the provider stays authorized too as a safety net).

create or replace function public.mark_order_completed(p_request_id uuid, p_completion_photo_url text default null)
returns public.service_requests
language plpgsql security definer set search_path = public as $fn$
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
    update public.service_requests set customer_completed = true where id = p_request_id;
  end if;
  if is_handler then
    if coalesce(p_completion_photo_url, sr.completion_photo_url) is null then
      raise exception 'Foto penyelesaian wajib dilampirkan';
    end if;
    update public.service_requests
      set provider_completed = true,
          completion_photo_url = coalesce(p_completion_photo_url, completion_photo_url)
      where id = p_request_id;
  end if;

  update public.service_requests
    set status = 'completed', completed_at = now()
    where id = p_request_id and customer_completed and provider_completed;

  select * into sr from public.service_requests where id = p_request_id;
  return sr;
end;
$fn$;

create or replace function public.open_dispute(p_request_id uuid, p_reason text, p_proof_url text default null::text)
returns public.service_requests
language plpgsql security definer set search_path to 'public' as $fn$
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
$fn$;

grant execute on function public.mark_order_completed(uuid, text) to authenticated;
grant execute on function public.open_dispute(uuid, text, text) to authenticated;
