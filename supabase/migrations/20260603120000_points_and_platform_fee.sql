-- ============================================================================
-- Points (loyalty) + 10% developer transaction fee.
--
-- Replaces the (never-implemented) voucher concept with:
--   * a 10% platform commission taken from the provider's payout on completion
--     (customer pays the agreed price; bengkel receives 90%; platform keeps 10%),
--   * a customer points system: earn floor(2% * price) per completed order,
--     redeemable 1 point = Rp1; opt-in per order; points earned on an order are
--     "pending" and only become usable on the customer's NEXT order.
--
-- Money settlement still lives in handle_order_balance() on service_requests.
-- This migration rewrites that trigger (preserving every existing branch incl.
-- the dispute-freeze cancel logic from 20260602200000) and records each
-- completed order's economics into platform_revenue for the admin dashboard.
--
-- price/bids.price are bigint (see 20260602160000). Points are integers.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Schema: points columns + per-order point snapshot + platform revenue ledger
-- ---------------------------------------------------------------------------
alter table public.users
  add column if not exists points         int not null default 0,
  add column if not exists pending_points int not null default 0;

alter table public.service_requests
  add column if not exists use_points   boolean not null default false,
  add column if not exists points_used  int not null default 0,
  add column if not exists points_earned int not null default 0;

create table if not exists public.platform_revenue (
  id                 uuid primary key default gen_random_uuid(),
  service_request_id uuid not null unique references public.service_requests(id) on delete cascade,
  gross_amount       numeric not null,
  fee_amount         numeric not null,
  points_redeemed    int not null default 0,
  points_earned      int not null default 0,
  net_revenue        numeric not null,
  created_at         timestamptz not null default now()
);
create index if not exists platform_revenue_created_idx on public.platform_revenue (created_at);

alter table public.platform_revenue enable row level security;
drop policy if exists "Admins read platform revenue" on public.platform_revenue;
create policy "Admins read platform revenue" on public.platform_revenue
  for select using (
    exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'ADMIN')
  );

-- ---------------------------------------------------------------------------
-- Rewrite handle_order_balance():
--   * INSERT: hold full price AND convert the customer's pending points to
--     usable points ("earned points become usable on the next order").
--   * completion: split the provider payout 90/10, redeem points (if opted in),
--     otherwise earn floor(2%); snapshot points onto the row; record revenue.
--   * every other branch is unchanged from 20260602200000 (incl. dispute freeze).
-- ---------------------------------------------------------------------------
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
    -- Promote previously-earned (pending) points to usable on a new order.
    update public.users
      set points = points + pending_points, pending_points = 0
      where id = NEW.customer_id and pending_points > 0;
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

  -- completion: settle with 90/10 split + points redemption / earning.
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

    -- Customer pays price minus redeemed points; release the full hold.
    update public.users
      set balance = balance - (coalesce(NEW.price,0) - v_used),
          held_balance = greatest(0, held_balance - coalesce(NEW.price,0)),
          points = points - v_used,
          pending_points = pending_points + v_earned
      where id = NEW.customer_id;

    -- Provider receives 90% of the price; release the pending lien.
    select provider_uid into prov from public.bengkels where id = NEW.bengkel_id;
    if prov is not null then
      update public.users
        set balance = balance + round(coalesce(NEW.price,0) * 0.90),
            pending_balance = greatest(0, pending_balance - coalesce(NEW.price,0))
        where id = prov;
    end if;

    -- Snapshot the point economics onto the order for in-app display.
    update public.service_requests
      set points_used = v_used, points_earned = v_earned
      where id = NEW.id;

    -- Record developer revenue (net = fee minus platform-funded point redemption).
    insert into public.platform_revenue
      (service_request_id, gross_amount, fee_amount, points_redeemed, points_earned, net_revenue)
      values (NEW.id, coalesce(NEW.price,0), v_fee, v_used, v_earned, v_fee - v_used)
      on conflict (service_request_id) do nothing;
  end if;

  if NEW.status = 'cancelled' and OLD.status <> 'cancelled' then
    if exists (select 1 from public.order_disputes d where d.service_request_id = NEW.id and d.status = 'pending') then
      -- Disputed cancel: FREEZE the escrow until admin_resolve_dispute() runs.
      null;
    else
      -- Clean cancel: release the holds.
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
-- admin_revenue_summary: totals + last-30-day daily series for the admin
-- dashboard. ADMIN-guarded (mirrors admin_resolve_dispute).
-- ---------------------------------------------------------------------------
create or replace function public.admin_revenue_summary()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_result jsonb;
begin
  if not exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'ADMIN') then
    raise exception 'Tidak memiliki akses admin.' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'total_net',             coalesce(sum(net_revenue), 0),
    'total_fee',             coalesce(sum(fee_amount), 0),
    'total_points_redeemed', coalesce(sum(points_redeemed), 0),
    'order_count',           count(*),
    'series', coalesce((
      select jsonb_agg(row_to_json(d) order by d.date)
      from (
        select to_char(date_trunc('day', created_at), 'YYYY-MM-DD') as date,
               sum(net_revenue) as net,
               sum(fee_amount)  as fee
        from public.platform_revenue
        where created_at >= now() - interval '30 days'
        group by date_trunc('day', created_at)
      ) d
    ), '[]'::jsonb)
  )
  into v_result
  from public.platform_revenue;

  return v_result;
end;
$function$;

revoke all on function public.handle_order_balance() from public, anon, authenticated;  -- trigger only
revoke all on function public.admin_revenue_summary() from public, anon;
grant execute on function public.admin_revenue_summary() to authenticated;
