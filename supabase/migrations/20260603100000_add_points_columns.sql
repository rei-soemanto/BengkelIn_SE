-- APPLIED 2026-06-03 to project ipxwpxozreksmuiztwcy.
-- The cloned MbengkelIn iOS has a loyalty-points feature: the order carries a
-- use_points flag and the customer's points balance lives on users. These columns
-- were missing from the combined schema, so creating an order failed with
-- "Could not find the 'use_points' column of 'service_requests' in the schema cache".
-- Add them (inert until points earning/spending is wired, but the order flow works).

alter table public.service_requests add column if not exists use_points boolean not null default false;
alter table public.users add column if not exists points integer not null default 0;
alter table public.users add column if not exists pending_points integer not null default 0;

-- Nudge PostgREST to reload its schema cache so the new columns are usable immediately.
notify pgrst, 'reload schema';
