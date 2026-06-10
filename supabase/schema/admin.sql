set check_function_bodies = off;


CREATE OR REPLACE FUNCTION public.admin_list_disputes()
 RETURNS TABLE(source text, id uuid, status text, reason text, proof_url text, initiator_role text, initiator_name text, created_at timestamp with time zone, resolved_at timestamp with time zone, service_request_id uuid, service_type text, description text, price bigint, order_status text, order_created_at timestamp with time zone, customer_id uuid, customer_name text, customer_email text, bengkel_id uuid, bengkel_name text, bengkel_address text, provider_uid uuid, provider_name text, provider_email text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.role = 'ADMIN'
  ) then
    raise exception 'Tidak memiliki akses admin.' using errcode = '42501';
  end if;

  return query
  select * from (
    select 'dispute'::text as source, d.id, d.status, d.reason, d.proof_url,
           d.initiator_role, iu.name as initiator_name, d.created_at, d.resolved_at,
           sr.id as service_request_id, sr.service_type, sr.description, sr.price,
           sr.status as order_status, sr.created_at as order_created_at,
           sr.customer_id, cu.name as customer_name, cau.email::text as customer_email,
           b.id as bengkel_id, b.name as bengkel_name, b.address as bengkel_address,
           b.provider_uid, pu.name as provider_name, pau.email::text as provider_email
    from public.order_disputes d
    join public.service_requests sr on sr.id = d.service_request_id
    left join public.users iu on iu.id = d.initiated_by
    left join public.users cu on cu.id = sr.customer_id
    left join auth.users cau on cau.id = sr.customer_id
    left join public.bengkels b on b.id = sr.bengkel_id
    left join public.users pu on pu.id = b.provider_uid
    left join auth.users pau on pau.id = b.provider_uid

    union all

    select 'behavior'::text as source, br.id, br.status, br.reason, null::text,
           case when br.reporter_id = sr.customer_id then 'customer'
                when br.reporter_id = b.provider_uid then 'provider'
                else 'customer' end as initiator_role,
           ru.name as initiator_name, br.created_at, br.resolved_at,
           sr.id as service_request_id, sr.service_type, sr.description, sr.price,
           sr.status as order_status, sr.created_at as order_created_at,
           sr.customer_id, cu.name as customer_name, cau.email::text as customer_email,
           b.id as bengkel_id, b.name as bengkel_name, b.address as bengkel_address,
           b.provider_uid, pu.name as provider_name, pau.email::text as provider_email
    from public.behavior_reports br
    join public.service_requests sr on sr.id = br.service_request_id
    left join public.users ru on ru.id = br.reporter_id
    left join public.users cu on cu.id = sr.customer_id
    left join auth.users cau on cau.id = sr.customer_id
    left join public.bengkels b on b.id = sr.bengkel_id
    left join public.users pu on pu.id = b.provider_uid
    left join auth.users pau on pau.id = b.provider_uid
  ) q
  order by
    case when q.status = 'pending' then 0 else 1 end,
    q.created_at desc;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_list_pending_bengkels()
 RETURNS TABLE(id uuid, provider_uid uuid, name text, address text, latitude double precision, longitude double precision, status "BengkelStatus", created_at timestamp with time zone, requester_name text, requester_email text, requester_phone text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.role = 'ADMIN'
  ) then
    raise exception 'Tidak memiliki akses admin.' using errcode = '42501';
  end if;

  return query
  select b.id, b.provider_uid, b.name, b.address, b.latitude, b.longitude,
         b.status, b.created_at,
         pu.name,
         au.email::text,
         (au.raw_user_meta_data ->> 'phone_number')
  from public.bengkels b
  left join public.users pu on pu.id = b.provider_uid
  left join auth.users au on au.id = b.provider_uid
  where b.status = 'Pending'
  order by b.created_at asc nulls last;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_list_verified_bengkels()
 RETURNS TABLE(id uuid, provider_uid uuid, name text, address text, latitude double precision, longitude double precision, created_at timestamp with time zone, average_rating double precision, total_reviews integer, provider_name text, provider_email text, provider_phone text, mechanics jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.role = 'ADMIN'
  ) then
    raise exception 'Tidak memiliki akses admin.' using errcode = '42501';
  end if;

  return query
  select b.id, b.provider_uid, b.name, b.address, b.latitude, b.longitude,
         b.created_at, b.average_rating, b.total_reviews,
         pu.name,
         pau.email::text,
         (pau.raw_user_meta_data ->> 'phone_number'),
         coalesce(
           (
             select jsonb_agg(
               jsonb_build_object(
                 'id', mr.mechanic_id,
                 'name', mu.name,
                 'email', mau.email::text,
                 'phone', (mau.raw_user_meta_data ->> 'phone_number')
               )
               order by mu.name
             )
             from public.mechanic_registrations mr
             left join public.users mu on mu.id = mr.mechanic_id
             left join auth.users mau on mau.id = mr.mechanic_id
             where mr.bengkel_id = b.id and mr.status = 'Accepted'
           ),
           '[]'::jsonb
         )
  from public.bengkels b
  left join public.users pu on pu.id = b.provider_uid
  left join auth.users pau on pau.id = b.provider_uid
  where b.status = 'Verified'
  order by b.name asc;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_list_withdrawals()
 RETURNS TABLE(id uuid, user_id uuid, user_name text, user_email text, amount double precision, bank_name text, bank_account_number text, bank_account_name text, status text, notes text, created_at timestamp with time zone, updated_at timestamp with time zone, user_balance double precision)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.role = 'ADMIN'
  ) then
    raise exception 'Tidak memiliki akses admin.' using errcode = '42501';
  end if;

  return query
  select w.id, w.user_id, wu.name, wau.email::text,
         w.amount, w.bank_name, w.bank_account_number, w.bank_account_name,
         w.status, w.notes, w.created_at, w.updated_at, wu.balance
  from public.withdrawals w
  left join public.users wu on wu.id = w.user_id
  left join auth.users wau on wau.id = w.user_id
  order by
    case when w.status = 'pending' then 0 else 1 end,
    w.created_at desc;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_resolve_dispute(p_dispute_id uuid, p_refund boolean, p_source text DEFAULT 'dispute'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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

  if p_source = 'behavior' then
    select status, service_request_id into v_status, v_sr_id
    from public.behavior_reports where id = p_dispute_id for update;
  else
    select status, service_request_id into v_status, v_sr_id
    from public.order_disputes where id = p_dispute_id for update;
  end if;

  if v_sr_id is null then raise exception 'Komplain tidak ditemukan.'; end if;
  if v_status <> 'pending' then raise exception 'Komplain ini sudah diselesaikan.'; end if;

  select sr.customer_id, coalesce(sr.price, 0), b.provider_uid
  into v_customer, v_price, v_provider
  from public.service_requests sr
  left join public.bengkels b on b.id = sr.bengkel_id
  where sr.id = v_sr_id;

  if p_source = 'behavior' then
    if not p_refund and v_provider is not null and v_price > 0 then
      update public.users set balance = balance - v_price where id = v_customer;
      update public.users set balance = balance + v_price where id = v_provider;
    end if;
    update public.behavior_reports
    set status = case when p_refund then 'refunded' else 'paid' end, resolved_at = now()
    where id = p_dispute_id;
  else
    if p_refund then
      if v_price > 0 then
        update public.users set balance = balance + v_price where id = v_customer;
      end if;
    else
      if v_provider is not null and v_price > 0 then
        update public.users set balance = balance + v_price where id = v_provider;
      end if;
    end if;
    update public.order_disputes
    set status = case when p_refund then 'refunded' else 'paid' end, resolved_at = now()
    where id = p_dispute_id;
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_revenue_summary()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.admin_set_bengkel_status(p_bengkel_id uuid, p_status "BengkelStatus")
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

  select status::text into v_status
  from public.bengkels
  where id = p_bengkel_id
  for update;

  if not found then
    raise exception 'Bengkel tidak ditemukan.';
  end if;

  if v_status <> 'Pending' then
    raise exception 'Bengkel ini sudah diproses sebelumnya (status saat ini: %).', v_status;
  end if;

  update public.bengkels
  set status = p_status
  where id = p_bengkel_id;
end;
$function$
;
