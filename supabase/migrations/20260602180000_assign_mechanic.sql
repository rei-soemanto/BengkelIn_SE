-- BengkelIn Phase 2 (Eugene): dispatch. Provider assigns an accepted job to a roster
-- mechanic or to "Self". The clone's active-working status is 'accepted' (in_progress is
-- unused), so assignment sets mechanic_id and KEEPS status='accepted' — "assigned & working"
-- = accepted + mechanic_id not null. This preserves the existing location-publish guard and
-- completion flow. Chat/tracking are then re-threaded to the mechanic via RLS below.
-- APPLIED 2026-06-02 to project ipxwpxozreksmuiztwcy.

create or replace function public.assign_mechanic(p_request_id uuid, p_mechanic_id uuid default null)
  returns public.service_requests language plpgsql security definer set search_path to 'public' as $fn$
declare sr public.service_requests; v_bengkel uuid; v_target uuid;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  select * into sr from public.service_requests where id = p_request_id for update;
  if not found then raise exception 'Order tidak ditemukan'; end if;

  select id into v_bengkel from public.bengkels where id = sr.bengkel_id and provider_uid = auth.uid();
  if v_bengkel is null then raise exception 'Bukan bengkel Anda'; end if;
  if sr.status <> 'accepted' then raise exception 'Order tidak dapat ditugaskan'; end if;

  if p_mechanic_id is null then
    v_target := auth.uid();                       -- "Self": provider does the work
  else
    if not exists (
      select 1 from public.mechanic_registrations
      where bengkel_id = v_bengkel and mechanic_id = p_mechanic_id
        and status = 'Accepted'::"RegistrationStatus"
    ) then raise exception 'Mekanik bukan anggota bengkel Anda'; end if;
    v_target := p_mechanic_id;
  end if;

  update public.service_requests set mechanic_id = v_target, updated_at = now() where id = p_request_id;
  select * into sr from public.service_requests where id = p_request_id;
  return sr;
end; $fn$;

revoke all on function public.assign_mechanic(uuid, uuid) from public, anon;
grant execute on function public.assign_mechanic(uuid, uuid) to authenticated;

-- Re-thread chat to the assigned mechanic: add `sr.mechanic_id = auth.uid()` everywhere the
-- policy currently allows only customer or bengkel-provider.
drop policy if exists "Participants view messages" on public.chat_messages;
create policy "Participants view messages" on public.chat_messages for select to authenticated
using (exists (
  select 1 from public.service_requests sr
  where sr.id = chat_messages.service_request_id
    and ( sr.customer_id = auth.uid()
       or sr.mechanic_id = auth.uid()
       or exists (select 1 from public.bengkels b where b.id = sr.bengkel_id and b.provider_uid = auth.uid()) )
));

drop policy if exists "Participants send messages" on public.chat_messages;
create policy "Participants send messages" on public.chat_messages for insert to authenticated
with check (
  sender_id = auth.uid() and exists (
    select 1 from public.service_requests sr
    where sr.id = chat_messages.service_request_id
      and sr.status = any (array['pending','accepted','in_progress'])
      and ( sr.customer_id = auth.uid()
         or sr.mechanic_id = auth.uid()
         or exists (select 1 from public.bengkels b where b.id = sr.bengkel_id and b.provider_uid = auth.uid()) )
  )
);

-- Re-thread live tracking: let the assigned mechanic read the customer's live location.
drop policy if exists "Order parties read customer location" on public.customer_locations;
create policy "Order parties read customer location" on public.customer_locations for select to authenticated
using (
  auth.uid() = customer_id
  or exists (
    select 1 from public.service_requests sr
    where sr.id = customer_locations.service_request_id
      and ( sr.mechanic_id = auth.uid()
         or exists (select 1 from public.bengkels b where b.id = sr.bengkel_id and b.provider_uid = auth.uid()) )
  )
);
