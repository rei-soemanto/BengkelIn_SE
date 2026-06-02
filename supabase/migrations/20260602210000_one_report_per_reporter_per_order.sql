-- Enforce: a given reporter may report a given order at most once.
--
-- Each order party (customer and provider/mechanic) can still file their OWN
-- report on the order — this only blocks the SAME user reporting the SAME
-- order twice. Enforcement is a unique index, not an RLS check: RLS
-- `with check (not exists ...)` is racy (two concurrent inserts both pass the
-- check and both commit), whereas a unique index is atomic. The existing
-- "Order parties insert reports" RLS policy still governs WHO may insert.
--
-- The pre-existing non-unique behavior_reports_request_idx is left in place
-- for service_request_id lookups.
create unique index if not exists behavior_reports_unique_reporter_per_request
  on public.behavior_reports (service_request_id, reporter_id);
