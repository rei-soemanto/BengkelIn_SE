-- BengkelIn Phase 2 (Bryan): mechanic roster (UC8) on the existing mechanic_registrations
-- table. Roster membership links a USER (mechanic) to a bengkel. Money/rating stay at
-- the bengkel level (locked decision) — this layer is purely operational.
-- RegistrationStatus enum values: Pending, Rejected, Accepted.
-- APPLIED 2026-06-02 to project ipxwpxozreksmuiztwcy.

-- RLS: reads allowed for the two stakeholders; all writes go through SECURITY DEFINER RPCs.
alter table public.mechanic_registrations enable row level security;

drop policy if exists mr_select_mechanic on public.mechanic_registrations;
create policy mr_select_mechanic on public.mechanic_registrations
  for select to authenticated using (mechanic_id = auth.uid());

drop policy if exists mr_select_provider on public.mechanic_registrations;
create policy mr_select_provider on public.mechanic_registrations
  for select to authenticated
  using (bengkel_id in (select id from public.bengkels where provider_uid = auth.uid()));

-- Provider invites a mechanic by email. Validates ownership, existence, no dup link.
create or replace function public.invite_mechanic(p_email text)
  returns void language plpgsql security definer set search_path to 'public' as $fn$
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

  if exists (
    select 1 from public.mechanic_registrations
    where bengkel_id = v_bengkel and mechanic_id = v_target
      and status in ('Pending'::"RegistrationStatus", 'Accepted'::"RegistrationStatus")
  ) then raise exception 'Mekanik sudah diundang atau terhubung'; end if;

  insert into public.mechanic_registrations (bengkel_id, mechanic_id, status)
  values (v_bengkel, v_target, 'Pending'::"RegistrationStatus");
end; $fn$;

-- Mechanic accepts/rejects a pending invitation. Accept promotes a plain USER to MECHANIC.
create or replace function public.respond_mechanic_invite(p_registration_id uuid, p_accept boolean)
  returns void language plpgsql security definer set search_path to 'public' as $fn$
declare v_reg public.mechanic_registrations;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
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
end; $fn$;

-- Provider removes a roster member (soft = Rejected). Demotes them to USER if no other
-- accepted membership remains.
create or replace function public.remove_mechanic(p_registration_id uuid)
  returns void language plpgsql security definer set search_path to 'public' as $fn$
declare v_reg public.mechanic_registrations; v_mech uuid;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  select * into v_reg from public.mechanic_registrations where id = p_registration_id;
  if not found then raise exception 'Data tidak ditemukan'; end if;
  if not exists (select 1 from public.bengkels where id = v_reg.bengkel_id and provider_uid = auth.uid()) then
    raise exception 'Bukan bengkel Anda'; end if;

  v_mech := v_reg.mechanic_id;
  update public.mechanic_registrations set status = 'Rejected'::"RegistrationStatus" where id = p_registration_id;

  if not exists (
    select 1 from public.mechanic_registrations
    where mechanic_id = v_mech and status = 'Accepted'::"RegistrationStatus"
  ) then
    update public.users set role = 'USER' where id = v_mech and role = 'MECHANIC';
  end if;
end; $fn$;

-- Provider-side roster read (pending + accepted), with mechanic name + email.
create or replace function public.bengkel_roster()
  returns table(registration_id uuid, mechanic_id uuid, mechanic_name text, mechanic_email text, status text, created_at timestamptz)
  language sql security definer set search_path to 'public' as $fn$
  select mr.id, mr.mechanic_id, u.name, au.email::text, mr.status::text, mr.created_at
  from public.mechanic_registrations mr
  join public.bengkels b on b.id = mr.bengkel_id and b.provider_uid = auth.uid()
  join public.users u on u.id = mr.mechanic_id
  left join auth.users au on au.id = mr.mechanic_id
  where mr.status in ('Pending'::"RegistrationStatus", 'Accepted'::"RegistrationStatus")
  order by mr.created_at desc;
$fn$;

-- Mechanic-side invite inbox (any state), with bengkel name.
create or replace function public.my_mechanic_invites()
  returns table(registration_id uuid, bengkel_id uuid, bengkel_name text, status text, created_at timestamptz)
  language sql security definer set search_path to 'public' as $fn$
  select mr.id, mr.bengkel_id, b.name, mr.status::text, mr.created_at
  from public.mechanic_registrations mr
  join public.bengkels b on b.id = mr.bengkel_id
  where mr.mechanic_id = auth.uid()
  order by mr.created_at desc;
$fn$;

-- SEAM read consumed by Eugene's assignment picker: accepted mechanics for caller's bengkel.
create or replace function public.available_mechanics()
  returns table(mechanic_id uuid, mechanic_name text)
  language sql security definer set search_path to 'public' as $fn$
  select mr.mechanic_id, u.name
  from public.mechanic_registrations mr
  join public.bengkels b on b.id = mr.bengkel_id and b.provider_uid = auth.uid()
  join public.users u on u.id = mr.mechanic_id
  where mr.status = 'Accepted'::"RegistrationStatus"
  order by u.name;
$fn$;

revoke all on function public.invite_mechanic(text) from public, anon;
revoke all on function public.respond_mechanic_invite(uuid, boolean) from public, anon;
revoke all on function public.remove_mechanic(uuid) from public, anon;
revoke all on function public.bengkel_roster() from public, anon;
revoke all on function public.my_mechanic_invites() from public, anon;
revoke all on function public.available_mechanics() from public, anon;
grant execute on function public.invite_mechanic(text) to authenticated;
grant execute on function public.respond_mechanic_invite(uuid, boolean) to authenticated;
grant execute on function public.remove_mechanic(uuid) to authenticated;
grant execute on function public.bengkel_roster() to authenticated;
grant execute on function public.my_mechanic_invites() to authenticated;
grant execute on function public.available_mechanics() to authenticated;
