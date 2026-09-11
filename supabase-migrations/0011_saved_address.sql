-- ============================================================================
-- 0011: Saved delivery info on the user's own profile — so checkout can
-- pre-fill name/phone/address next time instead of retyping every order.
-- ============================================================================

alter table public.users add column if not exists default_phone text;
alter table public.users add column if not exists default_address text;
