-- Voucher feature was replaced by the points system; these tables are orphaned
-- (no code, functions, views, or external FKs reference them). Drop child first.
DROP TABLE IF EXISTS public.user_vouchers;
DROP TABLE IF EXISTS public.vouchers;
