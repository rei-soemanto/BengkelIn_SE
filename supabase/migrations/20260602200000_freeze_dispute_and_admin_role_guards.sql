-- Bug fixes (2026-06-02):
--
-- BUG 1 — Cancelling an in-progress order deducted the customer's saldo.
--   open_dispute() used to do `balance -= price` the moment a customer cancelled,
--   so a cancelled ("dibatalkan") order still charged the customer. Product
--   decision: a cancel is a DISPUTE FROZEN FOR ADMIN REVIEW — no immediate charge
--   and no immediate refund; the money stays locked (as the existing held_balance /
--   pending_balance escrow liens) until admin_resolve_dispute() settles it.
--   Fix = three coordinated changes that leave `balance` untouched on cancel:
--     1. open_dispute(): stop deducting balance.
--     2. handle_order_balance() cancel branch: FREEZE (don't release) the holds when
--        a pending dispute row exists for the order; otherwise release as before
--        (a clean give-up of a still-searching order).
--     3. admin_resolve_dispute(): settle from the frozen liens — refund releases the
--        customer hold (balance untouched => customer whole); pay-provider executes
--        the real transfer (identical to a normal completion settlement).
--
-- BUG 2 & 3 — An ADMIN account must be a customer-only account on mobile: it may not
--   register a bengkel, be invited as a mechanic, or accept a mechanic invitation.
--   Server-authoritative guards added (client UI is gated separately in ProfileView).

-- ---------------------------------------------------------------------------
-- BUG 1.1 — open_dispute: no longer charges the customer on cancel.
-- ---------------------------------------------------------------------------
create or replace function public.open_dispute(p_request_id uuid, p_reason text, p_proof_url text default null::text)
returns service_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare sr public.service_requests; is_customer boolean; is_provider boolean; v_role text;
begin
  select * into sr from public.service_requests where id = p_request_id for update;
  if not found then raise exception 'Order not found'; end if;
  is_customer := (sr.customer_id = auth.uid());
  is_provider := exists (select 1 from public.bengkels b where b.id = sr.bengkel_id and b.provider_uid = auth.uid());
  if not (is_customer or is_provider) then raise exception 'Not authorized for this order'; end if;
  if sr.status not in ('accepted','in_progress') then raise exception 'Order is not in progress'; end if;
  if coalesce(btrim(p_reason), '') = '' then raise exception 'A reason is required'; end if;
  v_role := case when is_customer then 'customer' else 'provider' end;

  -- Record the dispute (status 'pending') BEFORE flipping the order, so the
  -- balance trigger sees it and freezes the escrow instead of releasing it.
  insert into public.order_disputes (service_request_id, initiated_by, initiator_role, reason, proof_url, status)
    values (p_request_id, auth.uid(), v_role, btrim(p_reason), p_proof_url, 'pending');

  update public.service_requests set status = 'cancelled', updated_at = now() where id = p_request_id;

  -- NO balance deduction here. The money stays frozen in held_balance /
  -- pending_balance until admin_resolve_dispute() settles it.

  select * into sr from public.service_requests where id = p_request_id;
  return sr;
end;
$function$;

-- ---------------------------------------------------------------------------
-- BUG 1.2 — escrow trigger: freeze (don't release) on a disputed cancel.
-- Only the 'cancelled' branch changed; every other branch is byte-for-byte the
-- previous behavior (hold on create, move-to-pending on accept, settle on complete).
-- ---------------------------------------------------------------------------
create or replace function public.handle_order_balance()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
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
    if exists (select 1 from public.order_disputes d where d.service_request_id = NEW.id and d.status = 'pending') then
      -- Disputed cancel: FREEZE. Leave the customer's held_balance and the
      -- provider's pending_balance in place until admin_resolve_dispute() runs.
      -- No money moves; the customer is not charged.
      null;
    else
      -- Clean cancel (e.g. giving up a still-searching order): release the holds.
      update public.users set held_balance = greatest(0, held_balance - coalesce(OLD.price,0)) where id = NEW.customer_id;
      if OLD.status in ('accepted','in_progress') then
        select provider_uid into prov from public.bengkels where id = OLD.bengkel_id;
        if prov is not null then update public.users set pending_balance = greatest(0, pending_balance - coalesce(OLD.price,0)) where id = prov; end if;
      end if;
    end if;
  end if;

  return NEW;
end;
$function$;

-- ---------------------------------------------------------------------------
-- BUG 1.3 — admin_resolve_dispute: settle from the frozen liens.
--   refund      => release customer hold + drop provider pending (balance untouched
--                  => customer fully whole, provider gets nothing).
--   pay provider => debit customer balance + release hold; credit provider balance +
--                  drop pending (identical to a normal completion settlement).
-- ---------------------------------------------------------------------------
create or replace function public.admin_resolve_dispute(p_dispute_id uuid, p_refund boolean)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_status text;
  v_sr_id uuid;
  v_customer uuid;
  v_provider uuid;
  v_price double precision;
begin
  if not exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.role = 'ADMIN'
  ) then
    raise exception 'Tidak memiliki akses admin.' using errcode = '42501';
  end if;

  select status, service_request_id into v_status, v_sr_id
  from public.order_disputes where id = p_dispute_id for update;

  if v_sr_id is null then raise exception 'Komplain tidak ditemukan.'; end if;
  if v_status <> 'pending' then raise exception 'Komplain ini sudah diselesaikan.'; end if;

  select sr.customer_id, coalesce(sr.price, 0), b.provider_uid
  into v_customer, v_price, v_provider
  from public.service_requests sr
  left join public.bengkels b on b.id = sr.bengkel_id
  where sr.id = v_sr_id;

  if p_refund then
    -- Customer made whole: drop the frozen hold; balance was never charged.
    if v_price > 0 then
      update public.users set held_balance = greatest(0, held_balance - v_price) where id = v_customer;
      if v_provider is not null then
        update public.users set pending_balance = greatest(0, pending_balance - v_price) where id = v_provider;
      end if;
    end if;
    update public.order_disputes set status = 'refunded', resolved_at = now() where id = p_dispute_id;
  else
    -- Pay provider: execute the real transfer (mirrors a normal completion).
    if v_price > 0 then
      update public.users set balance = greatest(0, balance - v_price), held_balance = greatest(0, held_balance - v_price) where id = v_customer;
      if v_provider is not null then
        update public.users set balance = balance + v_price, pending_balance = greatest(0, pending_balance - v_price) where id = v_provider;
      end if;
    end if;
    update public.order_disputes set status = 'paid', resolved_at = now() where id = p_dispute_id;
  end if;
end;
$function$;

-- ---------------------------------------------------------------------------
-- BUG 2 — an ADMIN cannot be invited as / become a mechanic.
-- ---------------------------------------------------------------------------

-- 2.1 Provider inviting a mechanic by email may not target an ADMIN account.
create or replace function public.invite_mechanic(p_email text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_bengkel uuid; v_target uuid;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  select id into v_bengkel from public.bengkels where provider_uid = auth.uid() limit 1;
  if v_bengkel is null then raise exception 'Anda belum memiliki bengkel'; end if;

  select id into v_target from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if v_target is null then raise exception 'Pengguna dengan email tersebut tidak ditemukan'; end if;
  if v_target = auth.uid() then raise exception 'Tidak dapat mengundang diri sendiri'; end if;
  if not exists (select 1 from public.users where id = v_target) then
    raise exception 'Pengguna dengan email tersebut tidak ditemukan'; end if;
  if exists (select 1 from public.users where id = v_target and role = 'ADMIN') then
    raise exception 'Akun admin tidak dapat diundang sebagai mekanik'; end if;

  if exists (
    select 1 from public.mechanic_registrations
    where bengkel_id = v_bengkel and mechanic_id = v_target
      and status in ('Pending'::"RegistrationStatus", 'Accepted'::"RegistrationStatus")
  ) then raise exception 'Mekanik sudah diundang atau terhubung'; end if;

  insert into public.mechanic_registrations (bengkel_id, mechanic_id, status)
  values (v_bengkel, v_target, 'Pending'::"RegistrationStatus");
end; $function$;

-- 2.2 An ADMIN cannot accept a mechanic invitation (the live accept path).
create or replace function public.respond_mechanic_invite(p_registration_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_reg public.mechanic_registrations;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if exists (select 1 from public.users where id = auth.uid() and role = 'ADMIN') then
    raise exception 'Akun admin tidak dapat menjadi mekanik'; end if;
  select * into v_reg from public.mechanic_registrations where id = p_registration_id;
  if not found then raise exception 'Undangan tidak ditemukan'; end if;
  if v_reg.mechanic_id <> auth.uid() then raise exception 'Bukan undangan Anda'; end if;
  if v_reg.status <> 'Pending'::"RegistrationStatus" then raise exception 'Undangan sudah direspons'; end if;

  if p_accept then
    update public.mechanic_registrations set status = 'Accepted'::"RegistrationStatus" where id = p_registration_id;
    update public.users set role = 'MECHANIC' where id = auth.uid() and role = 'USER';
  else
    update public.mechanic_registrations set status = 'Rejected'::"RegistrationStatus" where id = p_registration_id;
  end if;
end; $function$;

-- 2.3 Legacy accept path (mechanic_invitations) — unused by the app but still
-- callable; harden it too so it can never upgrade an ADMIN to MECHANIC.
create or replace function public.accept_mechanic_invite(invite_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
    v_bengkel_id uuid;
    v_mechanic_id uuid;
begin
    select bengkel_id, mechanic_id into v_bengkel_id, v_mechanic_id
    from mechanic_invitations
    where id = invite_id and status = 'pending' and mechanic_id = auth.uid();

    if v_bengkel_id is null then
        raise exception 'Invalid or unauthorized invitation.';
    end if;
    if exists (select 1 from public.users where id = v_mechanic_id and role = 'ADMIN') then
        raise exception 'Akun admin tidak dapat menjadi mekanik';
    end if;

    update mechanic_invitations set status = 'accepted' where id = invite_id;
    update users set role = 'MECHANIC' where id = v_mechanic_id and role <> 'ADMIN';
    update bengkels
    set mechanic_uids = array_append(coalesce(mechanic_uids, '{}'::uuid[]), v_mechanic_id)
    where id = v_bengkel_id
    and not (coalesce(mechanic_uids, '{}'::uuid[]) @> array[v_mechanic_id]);
end;
$function$;

-- 2.4 Defense in depth: bengkel verification must not upgrade an ADMIN to PROVIDER.
create or replace function public.approve_bengkel_and_upgrade_user()
returns trigger
language plpgsql
security definer
as $function$
begin
    if NEW.status = 'Verified' and OLD.status != 'Verified' then
        update public.users
        set role = 'PROVIDER'
        where id = NEW.provider_uid and role <> 'ADMIN';
    end if;
    return NEW;
end;
$function$;

-- ---------------------------------------------------------------------------
-- BUG 3 — an ADMIN cannot register a bengkel (server-authoritative).
-- Restrictive policy ANDs with the existing permissive "Providers can manage
-- their own bengkels" policy: every insert must ALSO satisfy this check.
-- ---------------------------------------------------------------------------
drop policy if exists "Admins cannot register bengkels" on public.bengkels;
create policy "Admins cannot register bengkels"
  on public.bengkels
  as restrictive
  for insert
  to authenticated
  with check ((select role from public.users where id = auth.uid()) is distinct from 'ADMIN');
