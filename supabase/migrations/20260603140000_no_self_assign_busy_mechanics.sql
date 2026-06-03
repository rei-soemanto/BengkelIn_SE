-- BengkelIn: drop bengkel "Self" assignment. An accepted order must be dispatched to a
-- roster MECHANIC (the provider only monitors + manages). Adds a busy guard (a mechanic
-- can't hold two active orders at once) and supports reassignment ("change mechanic on the
-- go"). Also makes the bengkel provider VIEW-ONLY in chat: they can read the mechanic <->
-- customer thread but can no longer send.

-- 1. assign_mechanic: require a real mechanic (no more Self), enforce roster membership,
--    reject a mechanic already busy on another active order, and allow reassignment.
-- Drop the old (uuid, uuid default null) signature first — Postgres can't strip the default
-- via create-or-replace.
drop function if exists public.assign_mechanic(uuid, uuid);
create or replace function public.assign_mechanic(p_request_id uuid, p_mechanic_id uuid)
  returns public.service_requests language plpgsql security definer set search_path to 'public' as $fn$
declare sr public.service_requests; v_bengkel uuid;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if p_mechanic_id is null then raise exception 'Pilih mekanik untuk menugaskan order ini'; end if;

  select * into sr from public.service_requests where id = p_request_id for update;
  if not found then raise exception 'Order tidak ditemukan'; end if;

  select id into v_bengkel from public.bengkels where id = sr.bengkel_id and provider_uid = auth.uid();
  if v_bengkel is null then raise exception 'Bukan bengkel Anda'; end if;
  if sr.status <> 'accepted' then raise exception 'Order tidak dapat ditugaskan'; end if;

  if not exists (
    select 1 from public.mechanic_registrations
    where bengkel_id = v_bengkel and mechanic_id = p_mechanic_id
      and status = 'Accepted'::"RegistrationStatus"
  ) then raise exception 'Mekanik bukan anggota bengkel Anda'; end if;

  -- Busy guard: the mechanic must not already be working another active order. Excludes
  -- THIS order so re-selecting the current mechanic is a harmless no-op.
  if exists (
    select 1 from public.service_requests other
    where other.mechanic_id = p_mechanic_id
      and other.status = 'accepted'
      and other.id <> p_request_id
  ) then raise exception 'Mekanik sedang menangani order lain'; end if;

  update public.service_requests set mechanic_id = p_mechanic_id, updated_at = now() where id = p_request_id;
  select * into sr from public.service_requests where id = p_request_id;
  return sr;
end; $fn$;

revoke all on function public.assign_mechanic(uuid, uuid) from public, anon;
grant execute on function public.assign_mechanic(uuid, uuid) to authenticated;

-- 2. available_mechanics: now takes the order id so the picker can flag mechanics that are
--    busy on another order and mark the one currently assigned to THIS order.
drop function if exists public.available_mechanics();
create or replace function public.available_mechanics(p_request_id uuid)
  returns table(mechanic_id uuid, mechanic_name text, busy boolean, is_current boolean)
  language sql security definer set search_path to 'public' as $fn$
  select mr.mechanic_id,
         u.name,
         exists (
           select 1 from public.service_requests other
           where other.mechanic_id = mr.mechanic_id
             and other.status = 'accepted'
             and other.id <> p_request_id
         ) as busy,
         exists (
           select 1 from public.service_requests cur
           where cur.id = p_request_id and cur.mechanic_id = mr.mechanic_id
         ) as is_current
  from public.mechanic_registrations mr
  join public.bengkels b on b.id = mr.bengkel_id and b.provider_uid = auth.uid()
  join public.users u on u.id = mr.mechanic_id
  where mr.status = 'Accepted'::"RegistrationStatus"
  order by is_current desc, busy, u.name;
$fn$;

revoke all on function public.available_mechanics(uuid) from public, anon;
grant execute on function public.available_mechanics(uuid) to authenticated;

-- 3. Chat: the bengkel provider becomes VIEW-ONLY. The view policy still lets the provider
--    read the thread; the send policy now allows only the customer and the assigned mechanic.
drop policy if exists "Participants send messages" on public.chat_messages;
create policy "Participants send messages" on public.chat_messages for insert to authenticated
with check (
  sender_id = auth.uid() and exists (
    select 1 from public.service_requests sr
    where sr.id = chat_messages.service_request_id
      and sr.status = any (array['pending','accepted','in_progress'])
      and ( sr.customer_id = auth.uid()
         or sr.mechanic_id = auth.uid() )
  )
);
