-- Credit earned points to the customer's USABLE balance on completion, instead
-- of holding them in pending_points until the next order. Removes the
-- promote-on-next-order step from handle_order_balance() and migrates any
-- already-stranded pending points into the usable balance.
--
-- Only the INSERT branch (promotion removed) and the completion branch (points
-- credited directly via `points - v_used + v_earned`) change; every other
-- branch is identical to 20260603120000.

create or replace function public.handle_order_balance()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
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
$function$;

update public.users set points = points + pending_points, pending_points = 0 where pending_points > 0;