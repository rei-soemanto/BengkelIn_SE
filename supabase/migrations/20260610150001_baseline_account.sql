-- Baseline for fresh projects: verbatim copy of supabase/schema/account.sql
-- (introspected source of truth from project ipxwpxozreksmuiztwcy).
-- The pre-baseline migration trail (2026060[23]*) was retired after this
-- baseline replaced it; the old files remain available in git history.

set check_function_bodies = off;


CREATE OR REPLACE FUNCTION public.approve_bengkel_and_upgrade_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
    if NEW.status = 'Verified' and OLD.status != 'Verified' then
        update public.users
        set role = 'PROVIDER'
        where id = NEW.provider_uid and role <> 'ADMIN';
    end if;
    return NEW;
end;
$function$
;

CREATE TRIGGER on_bengkel_approved AFTER UPDATE ON public.bengkels FOR EACH ROW EXECUTE FUNCTION approve_bengkel_and_upgrade_user();

CREATE OR REPLACE FUNCTION public.downgrade_user_on_bengkel_delete()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    UPDATE public.users
    SET role = 'USER'
    WHERE id = OLD.provider_uid;
    RETURN OLD;
END;
$function$
;

CREATE TRIGGER on_bengkel_deleted AFTER DELETE ON public.bengkels FOR EACH ROW EXECUTE FUNCTION downgrade_user_on_bengkel_delete();

CREATE OR REPLACE FUNCTION public.get_my_bengkel()
 RETURNS SETOF bengkels
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT * FROM bengkels
  WHERE auth.uid() = ANY(mechanic_uids)
  LIMIT 1;
$function$
;

CREATE OR REPLACE FUNCTION public.get_user_by_email(search_email text)
 RETURNS TABLE(user_id uuid, user_name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT u.id, u.name
  FROM auth.users au
  JOIN public.users u ON u.id = au.id
  WHERE au.email = search_email;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    INSERT INTO public.users (id, name, balance)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'name', 'Unknown User'),
        0.0
    );
    RETURN new;
END;
$function$
;

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();

CREATE OR REPLACE FUNCTION public.prevent_unauthorized_role_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  if new.role is distinct from old.role
     and current_user in ('authenticated', 'anon') then
    raise exception 'Mengubah role pengguna tidak diizinkan.';
  end if;
  return new;
end;
$function$
;

CREATE TRIGGER prevent_role_change BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION prevent_unauthorized_role_change();
