-- APPLIED 2026-06-02 to project ipxwpxozreksmuiztwcy.
-- Realtime fix (copied from MbengkelIn): filtered UPDATE events require
-- REPLICA IDENTITY FULL so the subscription filter can match the changed row.
-- Without it, the `topups` settle UPDATE (the balance credit) never reaches the
-- client and the wallet balance doesn't update live. Same need for withdrawals,
-- service_requests (completion), and order_locations (live tracking).

alter table public.topups          replica identity full;
alter table public.withdrawals     replica identity full;
alter table public.order_locations replica identity full;
alter table public.bengkels        replica identity full;

-- service_requests: rebuild the realtime relation (columns were added after it
-- was first published) + full replica identity for filtered UPDATE delivery.
alter publication supabase_realtime drop table service_requests;
alter table public.service_requests replica identity full;
alter publication supabase_realtime add table service_requests;

-- Publish bengkels for live rating/availability (matches MbengkelIn).
do $$ begin
  if not exists (select 1 from pg_publication_tables
                 where pubname='supabase_realtime' and schemaname='public' and tablename='bengkels') then
    alter publication supabase_realtime add table public.bengkels;
  end if;
end $$;
