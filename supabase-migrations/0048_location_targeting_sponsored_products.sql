-- ============================================================================
-- 0048: Advertising — Location Targeting + खरे Sponsored Products
--
-- सापडलेले गॅप्स:
--   1. campaigns.target_location स्कीमामध्ये होता, पण advertiser तो भरूच
--      शकत नव्हता आणि जाहिरात दाखवताना कधीच वापरला जात नव्हता — targeting
--      फक्त नावालाच होतं.
--   2. advertisements मध्ये कुठलाही specific business_product शी लिंक
--      करायला कॉलमच नव्हता — म्हणजे 'sponsored_product' प्रकार निवडता
--      येत असला तरी प्रत्यक्षात कुठलं प्रॉडक्ट दाखवायचं हे सांगताच येत
--      नव्हतं.
--   3. ⚠️ वेगळा bug: advertiser.html मध्ये "ऑडिओ"/"पोस्टर" निवडलं की
--      insert चुपचाप FAIL व्हायचा — कारण हे व्हॅल्यूज DB च्या check
--      constraint मध्ये बसतच नव्हते.
-- ============================================================================

-- 1) ad_type constraint रुंद करणे (audio जोडणे, poster चं mapping आधीच
--    frontend मध्ये 'banner' केलं जाईल)
alter table public.advertisements drop constraint if exists advertisements_ad_type_check;
alter table public.advertisements add constraint advertisements_ad_type_check
  check (ad_type in ('banner','image','video','audio','sponsored_product','sponsored_business','native'));

-- 2) कुठलं प्रॉडक्ट sponsor केलं आहे ते जोडण्यासाठी कॉलम
alter table public.advertisements add column if not exists sponsored_business_product_id uuid
  references public.business_products(id) on delete cascade;

-- 3) eligible_advertisements व्ह्यूमध्ये target_location + sponsored product जोडणे
create or replace view public.eligible_advertisements as
select ad.id, ad.ad_type, ad.placement, ad.media_url, ad.target_url,
       ad.frequency_cap_per_user_per_day, ad.sponsored_business_product_id,
       c.id as campaign_id, c.status, c.end_date, c.advertiser_id, c.target_location,
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

-- 4) खरं Sponsored Products व्ह्यू — पूर्ण प्रॉडक्ट माहितीसकट, search/grid
--    मध्ये थेट दाखवण्यासाठी तयार
create or replace view public.eligible_sponsored_products as
select ea.id as advertisement_id, ea.campaign_id, ea.target_location,
       bp.id as business_product_id, bp.name, bp.image_url, bp.selling_price,
       bp.unit, bp.business_id, b.name as business_name, b.city as business_city
from public.eligible_advertisements ea
join public.business_products bp on bp.id = ea.sponsored_business_product_id
join public.businesses b on b.id = bp.business_id
where ea.ad_type = 'sponsored_product' and bp.is_active = true and bp.stock > 0;

grant select on public.eligible_sponsored_products to authenticated, anon;
