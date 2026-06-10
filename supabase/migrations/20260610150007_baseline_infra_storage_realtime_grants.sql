-- Baseline infrastructure for fresh projects: everything the live database had
-- that introspection (supabase/schema/) does not capture — storage buckets and
-- policies, the realtime publication + replica identity, and function grants.
--
-- Sources: storage + realtime sections of 20260602140000/20260602150000,
-- grants rewritten against the FINAL function signatures in supabase/schema/
-- (signatures evolved across the old trail, e.g. rate_order lost its text arg).
-- The avatars bucket existed only via the old project's dashboard (no migration);
-- its policies here are reconstructed: public read, owners manage their own
-- {uid}/* folder.

-- ============================================================
-- 1. Storage buckets + policies
-- ============================================================
insert into storage.buckets (id, name, public) values ('chat-images', 'chat-images', true)
  on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('order-photos', 'order-photos', true)
  on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true)
  on conflict (id) do nothing;

drop policy if exists "Auth upload chat images" on storage.objects;
create policy "Auth upload chat images" on storage.objects
  for insert to authenticated with check (bucket_id = 'chat-images');
drop policy if exists "Public read chat images" on storage.objects;
create policy "Public read chat images" on storage.objects
  for select using (bucket_id = 'chat-images');

drop policy if exists "Auth upload order photos" on storage.objects;
create policy "Auth upload order photos" on storage.objects
  for insert to authenticated with check (bucket_id = 'order-photos');
drop policy if exists "Public read order photos" on storage.objects;
create policy "Public read order photos" on storage.objects
  for select using (bucket_id = 'order-photos');

drop policy if exists "Public read avatars" on storage.objects;
create policy "Public read avatars" on storage.objects
  for select using (bucket_id = 'avatars');
drop policy if exists "Users upload own avatar" on storage.objects;
create policy "Users upload own avatar" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Users update own avatar" on storage.objects;
create policy "Users update own avatar" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Users delete own avatar" on storage.objects;
create policy "Users delete own avatar" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- ============================================================
-- 2. Realtime: publish every table the iOS app subscribes to,
--    REPLICA IDENTITY FULL so filtered UPDATE events match.
-- ============================================================
do $do$
declare t text;
begin
  foreach t in array array[
    'service_requests', 'bids', 'chat_messages', 'order_locations',
    'customer_locations', 'topups', 'withdrawals', 'bengkels'
  ] loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
    execute format('alter table public.%I replica identity full', t);
  end loop;
end $do$;

-- ============================================================
-- 3. Function grants (security invariant: money-crediting paths
--    are never client-callable)
-- ============================================================

-- 3a. Strip the default PUBLIC/anon grant from every app function.
do $do$
declare fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
  loop
    execute format('revoke all on function %s from public, anon', fn.sig);
  end loop;
end $do$;

-- 3b. Trigger-only / definer-internal: not callable by clients at all.
revoke all on function public.handle_order_balance() from public, anon, authenticated;
revoke all on function public.recompute_bengkel_rating() from public, anon, authenticated;
revoke all on function public.reject_self_bid() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.approve_bengkel_and_upgrade_user() from public, anon, authenticated;
revoke all on function public.downgrade_user_on_bengkel_delete() from public, anon, authenticated;
revoke all on function public.prevent_unauthorized_role_change() from public, anon, authenticated;
revoke all on function public.cleanup_live_locations_on_terminal() from public, anon, authenticated;
revoke all on function public.update_updated_at_column() from public, anon, authenticated;
revoke all on function public.auto_settle_stale_completions() from public, anon, authenticated;
revoke all on function public.increment_user_balance(uuid, double precision) from public, anon, authenticated;

-- 3c. Money-admin RPCs: service_role ONLY.
revoke all on function public.settle_topup(text, text, text) from public, anon, authenticated;
revoke all on function public.reject_withdrawal(uuid) from public, anon, authenticated;
grant execute on function public.settle_topup(text, text, text) to service_role;
grant execute on function public.reject_withdrawal(uuid) to service_role;

-- 3d. User-facing RPCs: authenticated only.
grant execute on function public.accept_bid(uuid) to authenticated;
grant execute on function public.cancel_order(uuid) to authenticated;
grant execute on function public.open_dispute(uuid, text, text) to authenticated;
grant execute on function public.rate_order(uuid, integer) to authenticated;
grant execute on function public.mark_order_completed(uuid, text) to authenticated;
grant execute on function public.request_withdrawal(double precision) to authenticated;
grant execute on function public.nearby_service_requests(double precision, double precision, double precision) to authenticated;
grant execute on function public.nearby_bengkels(double precision, double precision, double precision) to authenticated;
grant execute on function public.invite_mechanic(text) to authenticated;
grant execute on function public.respond_mechanic_invite(uuid, boolean) to authenticated;
grant execute on function public.remove_mechanic(uuid) to authenticated;
grant execute on function public.bengkel_roster() to authenticated;
grant execute on function public.my_mechanic_invites() to authenticated;
grant execute on function public.available_mechanics(uuid) to authenticated;
grant execute on function public.assign_mechanic(uuid, uuid) to authenticated;
grant execute on function public.get_my_bengkel() to authenticated;
grant execute on function public.get_user_by_email(text) to authenticated;
grant execute on function public.accept_mechanic_invite(uuid) to authenticated;
grant execute on function public.reject_mechanic_invite(uuid) to authenticated;
grant execute on function public.approve_mechanic_resignation(uuid) to authenticated;
grant execute on function public.reject_mechanic_resignation(uuid) to authenticated;

-- 3e. Admin dashboard RPCs: authenticated + internal role guards
--     (the guards live inside the function bodies, per the old trail).
grant execute on function public.admin_list_disputes() to authenticated;
grant execute on function public.admin_resolve_dispute(uuid, boolean, text) to authenticated;
grant execute on function public.admin_list_pending_bengkels() to authenticated;
grant execute on function public.admin_list_verified_bengkels() to authenticated;
grant execute on function public.admin_set_bengkel_status(uuid, "BengkelStatus") to authenticated;
grant execute on function public.admin_list_withdrawals() to authenticated;
grant execute on function public.admin_approve_withdrawal(uuid) to authenticated;
grant execute on function public.admin_reject_withdrawal(uuid) to authenticated;
grant execute on function public.admin_revenue_summary() to authenticated;
