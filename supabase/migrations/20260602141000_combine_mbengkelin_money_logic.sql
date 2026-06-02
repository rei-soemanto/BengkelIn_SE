-- ============================================================================
-- Phase 0 — Combine MbengkelIn backend into BengkelIn: MONEY / LOGIC
-- Ported from MbengkelIn (final versions: unwind-on-cancel balance trigger,
-- photo-guard completion, available-balance withdrawal, idempotent topup).
-- Strings copied verbatim. Status remapped to BengkelIn lowercase, price ->
-- numeric `estimated_price`. Mapping: To Do=pending, On Progress=accepted
-- (BengkelIn also has in_progress once a mechanic is assigned), Done=completed.
-- ============================================================================

-- Internal balance credit (definer-only; not client-callable)
create or replace function public.increment_user_balance(p_user_id uuid, p_amount double precision)
returns void language sql security definer set search_path = public as $$
    update public.users set balance = balance + p_amount where id = p_user_id;
$$;

-- Escrow state machine on service_requests (hold / move-to-pending / settle / unwind)
create or replace function public.handle_order_balance()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare prov uuid;
begin
  if (TG_OP = 'INSERT') then
    if NEW.status = 'pending' and NEW.estimated_price is not null then
      update public.users set held_balance = held_balance + NEW.estimated_price where id = NEW.customer_id;
    end if;
    return NEW;
  end if;

  if (TG_OP = 'DELETE') then
    if OLD.estimated_price is not null and OLD.status in ('pending','accepted','in_progress') then
      update public.users set held_balance = greatest(0, held_balance - OLD.estimated_price) where id = OLD.customer_id;
      if OLD.status in ('accepted','in_progress') then
        select provider_uid into prov from public.bengkels where id = OLD.bengkel_id;
        if prov is not null then
          update public.users set pending_balance = greatest(0, pending_balance - OLD.estimated_price) where id = prov;
        end if;
      end if;
    end if;
    return OLD;
  end if;

  -- price changed while still searching (pending -> pending)
  if OLD.status = 'pending' and NEW.status = 'pending'
     and coalesce(NEW.estimated_price,0) <> coalesce(OLD.estimated_price,0) then
    update public.users
      set held_balance = greatest(0, held_balance + coalesce(NEW.estimated_price,0) - coalesce(OLD.estimated_price,0))
      where id = NEW.customer_id;
  end if;

  -- accepted: pending -> accepted (bid accepted; money moves into bengkel pending)
  if OLD.status = 'pending' and NEW.status = 'accepted' then
    if coalesce(NEW.estimated_price,0) <> coalesce(OLD.estimated_price,0) then
      update public.users
        set held_balance = greatest(0, held_balance + coalesce(NEW.estimated_price,0) - coalesce(OLD.estimated_price,0))
        where id = NEW.customer_id;
    end if;
    select provider_uid into prov from public.bengkels where id = NEW.bengkel_id;
    if prov is not null then
      update public.users set pending_balance = pending_balance + coalesce(NEW.estimated_price,0) where id = prov;
    end if;
  end if;

  -- completed: accepted/in_progress -> completed (settle both sides)
  if OLD.status in ('accepted','in_progress') and NEW.status = 'completed' then
    update public.users
      set balance = balance - coalesce(NEW.estimated_price,0),
          held_balance = greatest(0, held_balance - coalesce(NEW.estimated_price,0))
      where id = NEW.customer_id;
    select provider_uid into prov from public.bengkels where id = NEW.bengkel_id;
    if prov is not null then
      update public.users
        set balance = balance + coalesce(NEW.estimated_price,0),
            pending_balance = greatest(0, pending_balance - coalesce(NEW.estimated_price,0))
        where id = prov;
    end if;
  end if;

  -- cancelled (from any prior state): unwind reservations, charge nobody.
  if NEW.status = 'cancelled' and OLD.status <> 'cancelled' then
    update public.users set held_balance = greatest(0, held_balance - coalesce(OLD.estimated_price,0)) where id = NEW.customer_id;
    if OLD.status in ('accepted','in_progress') then
      select provider_uid into prov from public.bengkels where id = OLD.bengkel_id;
      if prov is not null then
        update public.users set pending_balance = greatest(0, pending_balance - coalesce(OLD.estimated_price,0)) where id = prov;
      end if;
    end if;
  end if;

  return NEW;
end;
$fn$;
drop trigger if exists trg_handle_order_balance on public.service_requests;
create trigger trg_handle_order_balance
  after insert or update or delete on public.service_requests
  for each row execute function public.handle_order_balance();

-- accept_bid: free THIS order's own hold before the affordability check, so the
-- escrow trigger (which already holds the broadcast price) doesn't double-count.
create or replace function public.accept_bid(p_bid_id uuid)
returns public.service_requests
language plpgsql security definer set search_path = public as $fn$
declare v_bid public.bids; sr public.service_requests; v_available numeric;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  select * into v_bid from public.bids where id = p_bid_id;
  if not found then raise exception 'Bid not found'; end if;
  select * into sr from public.service_requests where id = v_bid.service_request_id for update;
  if not found then raise exception 'Order not found'; end if;
  if sr.customer_id <> auth.uid() then raise exception 'Not authorized for this order'; end if;
  if sr.status <> 'pending' or sr.bengkel_id is not null then raise exception 'Order no longer open'; end if;

  select (coalesce(balance,0) - coalesce(held_balance,0) + coalesce(sr.estimated_price,0))::numeric
    into v_available from public.users where id = sr.customer_id;
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

-- Idempotent top-up settlement (topups.status is plain text in BengkelIn)
create or replace function public.settle_topup(p_order_id text, p_status text, p_payment_type text default null)
returns void language plpgsql security definer set search_path = public as $fn$
declare v_topup public.topups;
begin
  select * into v_topup from public.topups where order_id = p_order_id for update;
  if not found then raise exception 'Top-up not found'; end if;
  if v_topup.status = 'success' then return; end if;          -- never double-credit
  if p_status = 'success' then
    perform public.increment_user_balance(v_topup.user_id, v_topup.gross_amount);
  end if;
  update public.topups
    set status = p_status, payment_type = coalesce(p_payment_type, payment_type), updated_at = now()
    where order_id = p_order_id;
end;
$fn$;

-- Withdrawal request backed by AVAILABLE balance (balance - held_balance)
create or replace function public.request_withdrawal(p_amount double precision)
returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_uid uuid := auth.uid();
  v_balance double precision; v_held double precision;
  v_bank_name text; v_bank_account_number text; v_bank_account_name text; v_id uuid;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  if p_amount < 10000 then raise exception 'Minimum withdrawal is Rp10.000'; end if;
  select balance, held_balance, bank_name, bank_account_number, bank_account_name
    into v_balance, v_held, v_bank_name, v_bank_account_number, v_bank_account_name
    from public.users where id = v_uid for update;
  if v_bank_account_number is null or v_bank_account_number = '' then raise exception 'Bank account is not set'; end if;
  if (v_balance - coalesce(v_held, 0)) < p_amount then raise exception 'Insufficient balance'; end if;
  update public.users set balance = balance - p_amount where id = v_uid;
  insert into public.withdrawals (user_id, amount, bank_name, bank_account_number, bank_account_name, status)
    values (v_uid, p_amount, v_bank_name, v_bank_account_number, v_bank_account_name, 'pending')
    returning id into v_id;
  return v_id;
end;
$fn$;

create or replace function public.reject_withdrawal(p_withdrawal_id uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare v_user_id uuid; v_amount double precision; v_status text;
begin
  select user_id, amount, status into v_user_id, v_amount, v_status
    from public.withdrawals where id = p_withdrawal_id for update;
  if v_user_id is null then raise exception 'Withdrawal not found'; end if;
  if v_status <> 'pending' then raise exception 'Only pending withdrawals can be rejected'; end if;
  update public.users set balance = balance + v_amount where id = v_user_id;
  update public.withdrawals set status = 'rejected', updated_at = now() where id = p_withdrawal_id;
end;
$fn$;

-- Dual-confirm completion with mandatory provider proof photo
drop function if exists public.mark_order_completed(uuid);
create or replace function public.mark_order_completed(p_request_id uuid, p_completion_photo_url text default null)
returns public.service_requests
language plpgsql security definer set search_path = public as $fn$
declare sr public.service_requests; is_customer boolean; is_provider boolean;
begin
  select * into sr from public.service_requests where id = p_request_id;
  if not found then raise exception 'Order not found'; end if;
  is_customer := (sr.customer_id = auth.uid());
  is_provider := exists (select 1 from public.bengkels b where b.id = sr.bengkel_id and b.provider_uid = auth.uid());
  if not (is_customer or is_provider) then raise exception 'Not authorized for this order'; end if;
  if sr.status not in ('accepted','in_progress') then raise exception 'Order is not in progress'; end if;

  if is_customer then
    update public.service_requests set customer_completed = true where id = p_request_id;
  end if;
  if is_provider then
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

-- Write-once rating (after completed), with bengkel rating recompute trigger
create or replace function public.rate_order(p_request_id uuid, p_rating int, p_review text default null)
returns public.service_requests
language plpgsql security definer set search_path = public as $fn$
declare sr public.service_requests;
begin
  if p_rating < 1 or p_rating > 5 then raise exception 'Rating must be between 1 and 5'; end if;
  update public.service_requests
    set rating = p_rating, review = p_review
    where id = p_request_id and customer_id = auth.uid() and status = 'completed' and rating is null
    returning * into sr;
  if not found then raise exception 'Order cannot be rated'; end if;
  return sr;
end;
$fn$;

create or replace function public.recompute_bengkel_rating()
returns trigger language plpgsql security definer set search_path = public as $fn$
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
$fn$;
drop trigger if exists trg_recompute_bengkel_rating on public.service_requests;
create trigger trg_recompute_bengkel_rating
  after insert or update of rating or delete on public.service_requests
  for each row execute function public.recompute_bengkel_rating();

-- Dispute an in-progress order (records reason/proof, cancels -> trigger unwinds)
create or replace function public.open_dispute(p_request_id uuid, p_reason text, p_proof_url text default null)
returns public.service_requests
language plpgsql security definer set search_path = public as $fn$
declare sr public.service_requests; is_customer boolean; is_provider boolean; v_role text;
begin
  select * into sr from public.service_requests where id = p_request_id;
  if not found then raise exception 'Order not found'; end if;
  is_customer := (sr.customer_id = auth.uid());
  is_provider := exists (select 1 from public.bengkels b where b.id = sr.bengkel_id and b.provider_uid = auth.uid());
  if not (is_customer or is_provider) then raise exception 'Not authorized for this order'; end if;
  if sr.status not in ('accepted','in_progress') then raise exception 'Order is not in progress'; end if;
  if coalesce(btrim(p_reason), '') = '' then raise exception 'A reason is required'; end if;
  v_role := case when is_customer then 'customer' else 'provider' end;
  insert into public.order_disputes (service_request_id, initiated_by, initiator_role, reason, proof_url)
    values (p_request_id, auth.uid(), v_role, btrim(p_reason), p_proof_url);
  update public.service_requests set status = 'cancelled', updated_at = now() where id = p_request_id;
  select * into sr from public.service_requests where id = p_request_id;
  return sr;
end;
$fn$;

-- Grants (mirror MbengkelIn's hardening: keep definer functions off anon)
revoke all on function public.increment_user_balance(uuid, double precision) from public, anon, authenticated;
revoke all on function public.handle_order_balance() from public, anon, authenticated;     -- trigger only
revoke all on function public.recompute_bengkel_rating() from public, anon, authenticated;  -- trigger only
-- Money-admin RPCs: service_role ONLY (Supabase auto-grants new funcs to
-- `authenticated`, so revoke it explicitly — a signed-in user must not be able to
-- credit their own balance via settle_topup or refund via reject_withdrawal).
revoke all on function public.settle_topup(text, text, text) from public, anon, authenticated;
revoke all on function public.reject_withdrawal(uuid) from public, anon, authenticated;
grant execute on function public.settle_topup(text, text, text) to service_role;
grant execute on function public.reject_withdrawal(uuid) to service_role;
-- User-facing RPCs: authenticated only (drop the default anon grant).
revoke all on function public.request_withdrawal(double precision) from public, anon;
revoke all on function public.mark_order_completed(uuid, text) from public, anon;
revoke all on function public.rate_order(uuid, int, text) from public, anon;
revoke all on function public.open_dispute(uuid, text, text) from public, anon;
grant execute on function public.accept_bid(uuid) to authenticated;
grant execute on function public.request_withdrawal(double precision) to authenticated;
grant execute on function public.mark_order_completed(uuid, text) to authenticated;
grant execute on function public.rate_order(uuid, int, text) to authenticated;
grant execute on function public.open_dispute(uuid, text, text) to authenticated;
