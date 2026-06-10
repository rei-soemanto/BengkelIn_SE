-- Baseline for fresh projects: verbatim copy of supabase/schema/payment.sql
-- (introspected source of truth from project ipxwpxozreksmuiztwcy).
-- The pre-baseline migration trail (2026060[23]*) was retired after this
-- baseline replaced it; the old files remain available in git history.

set check_function_bodies = off;


CREATE OR REPLACE FUNCTION public.admin_approve_withdrawal(p_withdrawal_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_status text;
begin
  if not exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.role = 'ADMIN'
  ) then
    raise exception 'Tidak memiliki akses admin.' using errcode = '42501';
  end if;

  select status into v_status from public.withdrawals where id = p_withdrawal_id for update;
  if v_status is null then raise exception 'Permintaan penarikan tidak ditemukan.'; end if;
  if v_status <> 'pending' then raise exception 'Hanya permintaan yang menunggu yang dapat disetujui.'; end if;

  update public.withdrawals set status = 'approved', updated_at = now() where id = p_withdrawal_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_reject_withdrawal(p_withdrawal_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_user_id uuid; v_amount double precision; v_status text;
begin
  if not exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.role = 'ADMIN'
  ) then
    raise exception 'Tidak memiliki akses admin.' using errcode = '42501';
  end if;

  select user_id, amount, status into v_user_id, v_amount, v_status
  from public.withdrawals where id = p_withdrawal_id for update;
  if v_user_id is null then raise exception 'Permintaan penarikan tidak ditemukan.'; end if;
  if v_status <> 'pending' then raise exception 'Hanya permintaan yang menunggu yang dapat ditolak.'; end if;

  update public.users set balance = balance + v_amount where id = v_user_id;
  update public.withdrawals set status = 'rejected', updated_at = now() where id = p_withdrawal_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_order_balance()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  prov uuid;
  v_points int;
  v_used int;
  v_earned int;
  v_fee numeric;
begin
  if (TG_OP = 'INSERT') then
    if NEW.status = 'pending' and NEW.price is not null then
      update public.users set held_balance = held_balance + NEW.price where id = NEW.customer_id;
    end if;
    return NEW;
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
    if NEW.use_points then
      select coalesce(points,0) into v_points from public.users where id = NEW.customer_id;
      v_used := least(coalesce(v_points,0), coalesce(NEW.price,0))::int;
      v_earned := 0;
    else
      v_used := 0;
      v_earned := floor(coalesce(NEW.price,0) * 0.02)::int;
    end if;
    v_fee := round(coalesce(NEW.price,0) * 0.10);

    update public.users
      set balance = balance - (coalesce(NEW.price,0) - v_used),
          held_balance = greatest(0, held_balance - coalesce(NEW.price,0)),
          points = points - v_used + v_earned
      where id = NEW.customer_id;

    select provider_uid into prov from public.bengkels where id = NEW.bengkel_id;
    if prov is not null then
      update public.users
        set balance = balance + round(coalesce(NEW.price,0) * 0.90),
            pending_balance = greatest(0, pending_balance - coalesce(NEW.price,0))
        where id = prov;
    end if;

    update public.service_requests
      set points_used = v_used, points_earned = v_earned
      where id = NEW.id;

    insert into public.platform_revenue
      (service_request_id, gross_amount, fee_amount, points_redeemed, points_earned, net_revenue)
      values (NEW.id, coalesce(NEW.price,0), v_fee, v_used, v_earned, v_fee - v_used)
      on conflict (service_request_id) do nothing;
  end if;

  if NEW.status = 'cancelled' and OLD.status <> 'cancelled' then
    if exists (select 1 from public.order_disputes d where d.service_request_id = NEW.id and d.status = 'pending') then
      null;
    else
      update public.users set held_balance = greatest(0, held_balance - coalesce(OLD.price,0)) where id = NEW.customer_id;
      if OLD.status in ('accepted','in_progress') then
        select provider_uid into prov from public.bengkels where id = OLD.bengkel_id;
        if prov is not null then update public.users set pending_balance = greatest(0, pending_balance - coalesce(OLD.price,0)) where id = prov; end if;
      end if;
    end if;
  end if;

  return NEW;
end;
$function$
;

CREATE TRIGGER trg_handle_order_balance AFTER INSERT OR DELETE OR UPDATE ON public.service_requests FOR EACH ROW EXECUTE FUNCTION handle_order_balance();

CREATE OR REPLACE FUNCTION public.increment_user_balance(p_user_id uuid, p_amount double precision)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    update public.users set balance = balance + p_amount where id = p_user_id;
$function$
;

CREATE OR REPLACE FUNCTION public.reject_withdrawal(p_withdrawal_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_user_id uuid; v_amount double precision; v_status text;
begin
  select user_id, amount, status into v_user_id, v_amount, v_status
    from public.withdrawals where id = p_withdrawal_id for update;
  if v_user_id is null then raise exception 'Withdrawal not found'; end if;
  if v_status <> 'pending' then raise exception 'Only pending withdrawals can be rejected'; end if;
  update public.users set balance = balance + v_amount where id = v_user_id;
  update public.withdrawals set status = 'rejected', updated_at = now() where id = p_withdrawal_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.request_withdrawal(p_amount double precision)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); v_balance double precision; v_held double precision;
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
    values (v_uid, p_amount, v_bank_name, v_bank_account_number, v_bank_account_name, 'pending') returning id into v_id;
  return v_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.settle_topup(p_order_id text, p_status text, p_payment_type text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_topup public.topups;
begin
  select * into v_topup from public.topups where order_id = p_order_id for update;
  if not found then raise exception 'Top-up not found'; end if;
  if v_topup.status = 'success' then return; end if;
  if p_status = 'success' then perform public.increment_user_balance(v_topup.user_id, v_topup.gross_amount); end if;
  update public.topups set status = p_status, payment_type = coalesce(p_payment_type, payment_type), updated_at = now()
    where order_id = p_order_id;
end;
$function$
;
