-- ============================================================================
-- 0021: Ad Monetization Engine via UPI & Payment Verifications
-- Adds UPI payment references, verification status, and monetization rules
-- ============================================================================

alter table public.campaigns 
  add column if not exists payment_status text default 'pending' check (payment_status in ('pending', 'paid', 'verified', 'failed')),
  add column if not exists payment_mode text default 'UPI',
  add column if not exists utr_number text,
  add column if not exists payment_screenshot_url text,
  add column if not exists impressions_budget integer default 1000,
  add column if not exists impressions_served integer default 0;

-- Allow advertisers to update their own campaign payment references
drop policy if exists campaigns_payment_update on public.campaigns;
create policy campaigns_payment_update on public.campaigns
  for update using (
    exists (
      select 1 from public.advertisers a 
      where a.id = advertiser_id and a.user_id = auth.uid()
    ) or public.is_admin()
  );

-- Admins can view and verify all campaign payments
grant select, update on public.campaigns to authenticated, anon;
