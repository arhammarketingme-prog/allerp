-- ============================================================================
-- 0040: Advertising integrity fixes — impressions_served/budget was never
-- enforced (ads kept serving free after paid budget exhausted), and
-- ad_clicks had zero duplicate/fraud protection (insert with check (true)).
-- ============================================================================

-- 1) session_key on ad_clicks — needed to dedupe repeat clicks from the
--    same browser session within a short window (best-effort fraud check;
--    a determined bad actor can still clear storage, but this stops the
--    common case of accidental/rapid duplicate clicks inflating spend).
alter table public.ad_clicks add column if not exists session_key text;
create index if not exists idx_ad_clicks_dedup on public.ad_clicks(advertisement_id, session_key, created_at);

-- 2) RPC: record an impression AND atomically bump campaigns.impressions_served.
--    Returns true if this campaign still has budget remaining (frontend can
--    stop offering this ad once false).
create or replace function public.record_ad_impression(p_advertisement_id uuid, p_placement text default 'unknown')
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_campaign_id uuid;
  v_served int;
  v_budget int;
begin
  insert into public.ad_impressions (advertisement_id, placement) values (p_advertisement_id, p_placement);

  update public.campaigns c
    set impressions_served = c.impressions_served + 1
    from public.advertisements ad
    where ad.id = p_advertisement_id and ad.campaign_id = c.id
    returning c.impressions_served, c.impressions_budget into v_served, v_budget;

  return coalesce(v_served < v_budget, true);
end;
$$;

grant execute on function public.record_ad_impression(uuid, text) to authenticated, anon;

-- 3) RPC: record a click only if this session hasn't already clicked this
--    ad in the last 30 minutes — real duplicate-click protection.
create or replace function public.record_ad_click(p_advertisement_id uuid, p_session_key text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recent_click boolean;
begin
  select exists (
    select 1 from public.ad_clicks
    where advertisement_id = p_advertisement_id
      and session_key = p_session_key
      and created_at > now() - interval '30 minutes'
  ) into v_recent_click;

  if v_recent_click then
    return false; -- डुप्लिकेट क्लिक — नोंदवलं नाही
  end if;

  insert into public.ad_clicks (advertisement_id, session_key) values (p_advertisement_id, p_session_key);
  return true;
end;
$$;

grant execute on function public.record_ad_click(uuid, text) to authenticated, anon;

-- 4) थेट insert आता बंद — फक्त वरची RPCs (SECURITY DEFINER असल्याने RLS
--    बायपास करून) impression/click नोंदवू शकतात. आधी दोन्ही टेबल्सवर
--    `insert with check (true)` होतं — म्हणजे कोणीही स्क्रिप्टने खोट्या
--    impressions टाकून प्रतिस्पर्ध्याचं बजेट (impressions_served) झपाट्याने
--    संपवू शकत होता, किंवा क्लिक-फ्रॉड करू शकत होता.
drop policy if exists ad_clicks_insert_any on public.ad_clicks;
create policy ad_clicks_insert_any on public.ad_clicks for insert with check (false);

drop policy if exists ad_impressions_insert_any on public.ad_impressions;
create policy ad_impressions_insert_any on public.ad_impressions for insert with check (false);

-- 5) View: फक्त बजेट शिल्लक असलेल्या जाहिराती (impressions_served < budget)
create or replace view public.eligible_advertisements as
select ad.id, ad.ad_type, ad.placement, ad.media_url, ad.target_url,
       ad.frequency_cap_per_user_per_day,
       c.id as campaign_id, c.status, c.end_date, c.advertiser_id,
       c.impressions_served, c.impressions_budget
from public.advertisements ad
join public.campaigns c on c.id = ad.campaign_id
join public.advertisers a on a.id = c.advertiser_id
where ad.is_active = true
  and c.status = 'active'
  and c.payment_status = 'verified'
  and a.is_verified = true
  and c.impressions_served < c.impressions_budget
  and (c.end_date is null or c.end_date >= current_date);

grant select on public.eligible_advertisements to authenticated, anon;

-- 6) Least-privilege hardening: campaigns table had a blanket
--    `grant update to anon` from migration 0021 that RLS already made
--    unreachable (anon never owns an advertiser row) — remove the
--    unnecessary table-level grant so a future RLS bug can't expose it.
revoke update on public.campaigns from anon;

-- ============================================================================
-- Frontend must switch to: eligible_advertisements view (instead of the raw
-- advertisements+campaigns join), record_ad_impression() RPC, and
-- record_ad_click(adId, sessionKey) RPC. See js/ads.js changes.
-- ============================================================================
