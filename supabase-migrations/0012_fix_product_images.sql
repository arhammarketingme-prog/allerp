-- ============================================================================
-- 0012: Fix broken/missing product images.
-- Root cause: starter catalog rows were seeded with placeholder PATHS
-- (/starter-images/...) that were never backed by real uploaded files.
--
-- Fix: point every starter product at a free, copyright-safe generated
-- image via placehold.co (no signup, no cost, no copyright risk — it just
-- renders the product name as text on a colored box). This is a real,
-- always-working image URL, not a broken path. Swap these for real product
-- photos later; nothing else needs to change since it's just a URL.
-- ============================================================================

update public.industry_products ip
set image_url = 'https://placehold.co/400x400/' || colors.hex || '/FFFFFF?text=' ||
  replace(replace(ip.name_en, ' ', '+'), '&', 'and')
from (
  select bt.id as business_type_id,
    case bt.slug
      when 'grocery' then 'ff6b35'
      when 'electronics' then '2874f0'
      when 'mobile-shop' then '6c5ce7'
      when 'clothing' then 'e84393'
      when 'hardware' then '636e72'
      when 'restaurant' then 'e17055'
      when 'medical-store' then '00b894'
      when 'contractor' then 'fdcb6e'
      when 'furniture' then '8B5A2B'
      when 'real-estate' then '0984e3'
      else '95a5a6'
    end as hex
  from public.business_types bt
) colors
where ip.business_type_id = colors.business_type_id;

-- Also fix images already copied into existing businesses' live products
-- (business_products.image_url was copied at creation time, before this fix).
update public.business_products bp
set image_url = ip.image_url
from public.industry_products ip
where bp.industry_product_id = ip.id
  and (bp.image_url is null or bp.image_url like '/starter-images/%');
