# supabase/schema — clean source-of-truth SQL

Generated from the LIVE database (project tednrjmhtusdglsembzu) via introspection.
This is a clean, comment-free, feature-grouped view of the backend. It REPLACES the
role of supabase/migrations/ for reading/understanding and for rebuilding from scratch.
It is NOT tracked by the Supabase migration CLI.

## Files
- schema.sql   : table generation only — enums, 14 tables, constraints, indexes, RLS policies, realtime publication.
- account.sql  : signup / role-guard / bengkel-upgrade triggers + user lookups.
- bidding.sql  : geo discovery, accept_bid, self-bid guard.
- orders.sql   : order lifecycle (complete / cancel / dispute / rate / auto-settle) + rating, cleanup, updated_at triggers.
- mechanics.sql: roster, invitations, resignations, assignment.
- payment.sql  : escrow/points/fee engine (handle_order_balance), top-up settle, withdrawals.
- admin.sql    : admin dashboard RPCs (disputes, revenue, bengkel status, listings).

## Apply order (mandatory — tables before functions)
1. schema.sql       (FIRST)
2. account.sql, bidding.sql, orders.sql, mechanics.sql, payment.sql, admin.sql (any order)

Each feature file starts with `set check_function_bodies = off;` so functions that
reference each other or tables never fail on creation order.

Apply via the Supabase SQL editor (paste in the order above) or psql:
    psql "$DATABASE_URL" -f schema.sql
    for f in account bidding orders mechanics payment admin; do psql "$DATABASE_URL" -f $f.sql; done

## Note
Table DDL here is reconstructed from introspection (faithful, but for a byte-exact
dump use `supabase db dump --schema public`). Functions/triggers/policies are verbatim
from the live DB with SQL comments stripped.
