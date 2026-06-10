-- Baseline for fresh projects: verbatim copy of supabase/schema/mechanics.sql
-- (introspected source of truth from project ipxwpxozreksmuiztwcy).
-- The pre-baseline migration trail (2026060[23]*) was retired after this
-- baseline replaced it; the old files remain available in git history.

set check_function_bodies = off;


CREATE OR REPLACE FUNCTION public.accept_mechanic_invite(invite_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.approve_mechanic_resignation(resignation_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_bengkel_id uuid;
    v_mechanic_id uuid;
BEGIN

    SELECT bengkel_id, mechanic_id INTO v_bengkel_id, v_mechanic_id
    FROM mechanic_resignations
    WHERE id = resignation_id AND status = 'pending';

    IF v_bengkel_id IS NULL THEN
        RAISE EXCEPTION 'Resignation request not found or already processed.';
    END IF;

    UPDATE mechanic_resignations SET status = 'approved' WHERE id = resignation_id;

    UPDATE bengkels SET mechanic_uids = array_remove(mechanic_uids, v_mechanic_id) WHERE id = v_bengkel_id;

    UPDATE users SET role = 'USER' WHERE id = v_mechanic_id;

    UPDATE service_requests SET mechanic_id = NULL
    WHERE mechanic_id = v_mechanic_id AND status IN ('pending', 'accepted', 'in_progress');
END;
$function$
;

CREATE OR REPLACE FUNCTION public.assign_mechanic(p_request_id uuid, p_mechanic_id uuid)
 RETURNS service_requests
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare sr public.service_requests; v_bengkel uuid; v_prev uuid;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if p_mechanic_id is null then raise exception 'Pilih mekanik untuk menugaskan order ini'; end if;

  select * into sr from public.service_requests where id = p_request_id for update;
  if not found then raise exception 'Order tidak ditemukan'; end if;
  v_prev := sr.mechanic_id;

  select id into v_bengkel from public.bengkels where id = sr.bengkel_id and provider_uid = auth.uid();
  if v_bengkel is null then raise exception 'Bukan bengkel Anda'; end if;
  if sr.status <> 'accepted' then raise exception 'Order tidak dapat ditugaskan'; end if;

  if not exists (
    select 1 from public.mechanic_registrations
    where bengkel_id = v_bengkel and mechanic_id = p_mechanic_id
      and status = 'Accepted'::"RegistrationStatus"
  ) then raise exception 'Mekanik bukan anggota bengkel Anda'; end if;

  if exists (
    select 1 from public.service_requests other
    where other.mechanic_id = p_mechanic_id
      and other.status = 'accepted'
      and other.id <> p_request_id
  ) then raise exception 'Mekanik sedang menangani order lain'; end if;

  update public.service_requests
    set mechanic_id = p_mechanic_id, assigned_at = now(), updated_at = now()
    where id = p_request_id;
  select * into sr from public.service_requests where id = p_request_id;

  perform realtime.send(
    jsonb_build_object('request_id', p_request_id::text, 'service_type', coalesce(sr.service_type, '')),
    'assigned',
    'mechanic:' || p_mechanic_id::text,
    false
  );

  if v_prev is not null and v_prev <> p_mechanic_id then
    perform realtime.send(
      jsonb_build_object('request_id', p_request_id::text, 'service_type', coalesce(sr.service_type, '')),
      'reassigned_away',
      'mechanic:' || v_prev::text,
      false
    );
  end if;

  return sr;
end; $function$
;

CREATE OR REPLACE FUNCTION public.available_mechanics(p_request_id uuid)
 RETURNS TABLE(mechanic_id uuid, mechanic_name text, busy boolean, is_current boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.bengkel_roster()
 RETURNS TABLE(registration_id uuid, mechanic_id uuid, mechanic_name text, mechanic_email text, status text, created_at timestamp with time zone)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select mr.id, mr.mechanic_id, u.name, au.email::text, mr.status::text, mr.created_at
  from public.mechanic_registrations mr
  join public.bengkels b on b.id = mr.bengkel_id and b.provider_uid = auth.uid()
  join public.users u on u.id = mr.mechanic_id
  left join auth.users au on au.id = mr.mechanic_id
  where mr.status in ('Pending'::"RegistrationStatus", 'Accepted'::"RegistrationStatus")
  order by mr.created_at desc;
$function$
;

CREATE OR REPLACE FUNCTION public.invite_mechanic(p_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end; $function$
;

CREATE OR REPLACE FUNCTION public.my_mechanic_invites()
 RETURNS TABLE(registration_id uuid, bengkel_id uuid, bengkel_name text, status text, created_at timestamp with time zone)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select mr.id, mr.bengkel_id, b.name, mr.status::text, mr.created_at
  from public.mechanic_registrations mr
  join public.bengkels b on b.id = mr.bengkel_id
  where mr.mechanic_id = auth.uid()
  order by mr.created_at desc;
$function$
;

CREATE OR REPLACE FUNCTION public.reject_mechanic_invite(invite_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    UPDATE mechanic_invitations
    SET status = 'rejected'
    WHERE id = invite_id AND mechanic_id = auth.uid() AND status = 'pending';
END;
$function$
;

CREATE OR REPLACE FUNCTION public.reject_mechanic_resignation(resignation_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    UPDATE mechanic_resignations
    SET status = 'rejected'
    WHERE id = resignation_id AND status = 'pending';
END;
$function$
;

CREATE OR REPLACE FUNCTION public.remove_mechanic(p_registration_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end; $function$
;

CREATE OR REPLACE FUNCTION public.respond_mechanic_invite(p_registration_id uuid, p_accept boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end; $function$
;
