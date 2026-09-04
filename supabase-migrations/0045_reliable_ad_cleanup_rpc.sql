-- ============================================================================
-- 0045: जाहिरात auto-cleanup आता खरंच सगळ्यांसाठी काम करेल.
--
-- मूळ प्रश्न: आधीचा cleanup कोड (js/ads.js मधला autoCleanupExpiredAds)
-- थेट टेबल्सवर delete/update करत होता — पण अनोळखी (anonymous) ग्राहकाच्या
-- ब्राउझरकडे campaigns/advertisements/ad_clicks/ad_impressions बदलण्याची RLS
-- परवानगीच नव्हती (फक्त owner/admin ला आहे). त्यामुळे बहुतांश भेटींमध्ये
-- (जे anonymous customers असतात) हा cleanup चालतच नव्हता — मुदत संपलेल्या
-- जाहिराती 'active' म्हणूनच अडकून राहायच्या.
--
-- फिक्स: सगळं काम आता एका SECURITY DEFINER RPC मध्ये — कोणीही (अनोळखी
-- ग्राहकासहित) कॉल करू शकतो, RLS बायपास करून पण फक्त वस्तुनिष्ठपणे मुदत
-- संपलेल्या (end_date < आज) कॅम्पेनवरच काम करतो.
-- ============================================================================

create or replace function public.cleanup_expired_ads()
returns table(ad_id uuid, media_url text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_campaign_ids uuid[];
begin
  select array_agg(id) into v_campaign_ids
  from public.campaigns
  where end_date is not null and end_date < current_date and status <> 'completed';

  if v_campaign_ids is null then
    return;
  end if;

  return query
  select ad.id, ad.media_url from public.advertisements ad where ad.campaign_id = any(v_campaign_ids);

  delete from public.ad_clicks where advertisement_id in (
    select id from public.advertisements where campaign_id = any(v_campaign_ids)
  );
  delete from public.ad_impressions where advertisement_id in (
    select id from public.advertisements where campaign_id = any(v_campaign_ids)
  );
  delete from public.advertisements where campaign_id = any(v_campaign_ids);
  update public.campaigns set status = 'completed' where id = any(v_campaign_ids);
end;
$$;

grant execute on function public.cleanup_expired_ads() to authenticated, anon;

-- ⚠️ आत्ताच सापडलेल्या ३ अडकलेल्या जाहिराती (ganesh fastival, arhammarketingme
-- x2) लगेच साफ करण्यासाठी, ही migration चालवल्यावर एकदा हे पण चालव:
--   select * from public.cleanup_expired_ads();
