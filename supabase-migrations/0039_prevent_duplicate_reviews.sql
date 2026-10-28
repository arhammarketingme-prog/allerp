-- ============================================================================
-- 0039: एकाच युजरने एकाच प्रॉडक्टला एकापेक्षा जास्त वेळा रिव्ह्यू देऊ नये.
--
-- आधी डुप्लिकेट रेकॉर्ड्स असतील तर हटवण्याआधी सर्वात नवीन रिव्ह्यूच ठेवा
-- (जुने डुप्लिकेट्स काढून टाकतो, मग constraint लावतो).
-- ============================================================================

delete from public.reviews r
where exists (
  select 1 from public.reviews r2
  where r2.business_product_id = r.business_product_id
    and r2.reviewer_user_id = r.reviewer_user_id
    and r2.created_at > r.created_at
);

alter table public.reviews
  add constraint reviews_one_per_user_per_product
  unique (business_product_id, reviewer_user_id);
