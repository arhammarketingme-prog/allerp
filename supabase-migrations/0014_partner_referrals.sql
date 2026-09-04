-- ============================================================================
-- 0014: Partner referral tracking. A partner shares a link like
-- index.html?ref=CODE — whoever signs up through it and later creates a
-- business or registers as an advertiser gets attributed to that partner.
-- ============================================================================

alter table public.businesses add column if not exists referred_by_partner_id uuid references public.partners(id);
alter table public.advertisers add column if not exists referred_by_partner_id uuid references public.advertisers(id);
-- fix: advertisers should reference partners, not itself
alter table public.advertisers drop constraint if exists advertisers_referred_by_partner_id_fkey;
alter table public.advertisers add constraint advertisers_referred_by_partner_id_fkey
  foreign key (referred_by_partner_id) references public.partners(id);

-- Let a partner see (read-only) the businesses/advertisers they referred —
-- without exposing those tenants' private data beyond name/verification.
create policy businesses_partner_read on public.businesses
  for select using (
    referred_by_partner_id in (select id from public.partners where user_id = auth.uid())
  );

create policy advertisers_partner_read on public.advertisers
  for select using (
    referred_by_partner_id in (select id from public.partners where user_id = auth.uid())
  );
