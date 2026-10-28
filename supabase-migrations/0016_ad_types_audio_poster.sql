-- ============================================================================
-- 0016: Expand supported ad creative types to audio and poster (banner,
-- image, video, native, sponsored_product, sponsored_business already existed).
-- ============================================================================

alter table public.advertisements drop constraint if exists advertisements_ad_type_check;
alter table public.advertisements add constraint advertisements_ad_type_check
  check (ad_type in ('banner', 'image', 'video', 'audio', 'poster', 'sponsored_product', 'sponsored_business', 'native'));
