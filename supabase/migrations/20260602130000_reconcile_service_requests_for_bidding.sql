-- APPLIED 2026-06-02 to project ipxwpxozreksmuiztwcy.
-- S3 reconciliation so a bidding broadcast can be created and decoded.

-- 1. vehicle_id: the Swift ServiceRequest model references it but the column was
--    missing (would break inserts/decodes). Add nullable FK to vehicles.
alter table public.service_requests
  add column if not exists vehicle_id uuid references public.vehicles(id);

-- 2. service_type was a single-value Postgres enum ('BanGembos') that does not
--    match BengkelIn's service vocabulary. Convert to free text (0 rows -> safe).
alter table public.service_requests
  alter column service_type type text using service_type::text;
