-- ============================================================================
-- 0011: Saved delivery info on profile — so returning customers don't have
-- to retype phone/name/address every checkout. Pure DB columns, no cost.
-- ============================================================================

alter table public.users add column if not exists saved_phone text;
alter table public.users add column if not exists saved_address text;
