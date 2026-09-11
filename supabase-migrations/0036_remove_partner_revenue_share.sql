-- ============================================================================
-- 0036: Remove Partner / Revenue-Share system completely.
--
-- Reason: ALL ERP V2 architecture decision — the platform will not run any
-- commission/revenue-sharing program (partner payouts, developer-app-ads
-- share, or platform-earnings-from-campaign-budget reports). The ONLY
-- referral mechanism kept is a plain customer/business referral CODE for
-- attribution — no entity, no payout, no money changes hands or is tracked
-- here.
--
-- ⚠️ BEFORE RUNNING THIS ON PRODUCTION:
--   1. In Supabase SQL Editor, export current data first (safety checkpoint):
--        select * from public.partners;
--        select * from public.revenue_share_rules;
--        select * from public.revenue_shares;
--      (Table > Export as CSV, or copy query results.) If these are empty
--      or contain no real/live data, you can proceed directly.
--   2. This migration is irreversible once applied — tables are dropped.
-- ============================================================================

-- 1) Drop RLS policies that depended on partner attribution
drop policy if exists businesses_partner_read on public.businesses;
drop policy if exists advertisers_partner_read on public.advertisers;

-- 2) Drop the revenue-share calculation function
drop function if exists public.calculate_revenue_shares(date, date);

-- 3) Drop partner-linked FK columns (the old attribution mechanism)
alter table public.businesses  drop column if exists referred_by_partner_id;
alter table public.advertisers drop column if exists referred_by_partner_id;

-- 4) Add the plain, no-entity referral code column that js/referral.js
--    already expects (pure text attribution, no FK, no partner/money link)
alter table public.businesses  add column if not exists referred_by_code text;
alter table public.advertisers add column if not exists referred_by_code text;

-- 5) Drop the revenue-share / partner tables (in dependency order)
drop table if exists public.revenue_shares;
drop table if exists public.revenue_share_rules;
drop table if exists public.partners;

-- ============================================================================
-- Result: no partner entity, no commission tables, no revenue-share RPC.
-- Customer/business referral now works purely via businesses.referred_by_code
-- and advertisers.referred_by_code, set by js/referral.js's
-- attachReferralCode() — attribution only, never money.
-- ============================================================================
