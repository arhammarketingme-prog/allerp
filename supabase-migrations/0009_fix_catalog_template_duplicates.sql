-- ============================================================================
-- 0009: Fix the ACTUAL root cause — duplicate rows inside industry_products
-- itself (the master starter-catalog template), not just inside individual
-- businesses. If migration 0005 (or any seed file) ran twice, every mobile-
-- shop item ended up as two separate template rows with two different ids
-- but the same name — so every NEW business created after that copied BOTH,
-- and no per-business constraint could catch it (they're genuinely different
-- industry_product_id values).
-- ============================================================================

-- STEP 1 — clear out the entire Mobile Shop template catalog completely.
delete from public.industry_products
where business_type_id = (select id from public.business_types where slug = 'mobile-shop');

-- STEP 2 — permanently prevent this from ever happening again, for every
-- vertical, not just mobile-shop: the same product name can't be seeded
-- twice into the same business_type's template.
create unique index if not exists industry_products_unique_name_per_type
  on public.industry_products (business_type_id, name_en);

-- STEP 3 — re-insert the Mobile Shop starter catalog cleanly, once.
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Smartphone (Entry-level)', 'स्मार्टफोन (एंट्री-लेव्हल)', 'pcs', 8000, '/starter-images/mobile-shop/phone-entry.png'),
  ('Smartphone (Mid-range)', 'स्मार्टफोन (मिड-रेंज)', 'pcs', 15000, '/starter-images/mobile-shop/phone-mid.png'),
  ('Screen Guard (Tempered Glass)', 'स्क्रीन गार्ड', 'pcs', 150, '/starter-images/mobile-shop/screen-guard.png'),
  ('Mobile Back Cover', 'मोबाईल कव्हर', 'pcs', 200, '/starter-images/mobile-shop/back-cover.png'),
  ('Charger (Original)', 'चार्जर (ओरिजिनल)', 'pcs', 500, '/starter-images/mobile-shop/charger.png'),
  ('Charging Cable', 'चार्जिंग केबल', 'pcs', 150, '/starter-images/mobile-shop/cable.png'),
  ('Earphones (Wired)', 'इअरफोन्स', 'pcs', 250, '/starter-images/mobile-shop/earphones.png'),
  ('Bluetooth Earbuds', 'ब्लूटूथ इअरबड्स', 'pcs', 1500, '/starter-images/mobile-shop/earbuds.png'),
  ('Power Bank 10000mAh', 'पॉवर बँक', 'pcs', 1100, '/starter-images/mobile-shop/powerbank.png'),
  ('Memory Card 32GB', 'मेमरी कार्ड ३२GB', 'pcs', 350, '/starter-images/mobile-shop/memory-card.png'),
  ('SIM Card', 'सिम कार्ड', 'pcs', 20, '/starter-images/mobile-shop/sim.png'),
  ('Mobile Stand/Holder', 'मोबाईल स्टँड', 'pcs', 150, '/starter-images/mobile-shop/stand.png'),
  ('Bluetooth Speaker', 'ब्लूटूथ स्पीकर', 'pcs', 1200, '/starter-images/mobile-shop/speaker.png'),
  ('Screen Repair Service', 'स्क्रीन रिपेअर सर्व्हिस', 'service', 800, '/starter-images/mobile-shop/repair.png'),
  ('Battery Replacement Service', 'बॅटरी बदलणे सर्व्हिस', 'service', 600, '/starter-images/mobile-shop/battery-service.png'),
  ('Mobile Recharge/Data Pack', 'मोबाईल रिचार्ज', 'pcs', 199, '/starter-images/mobile-shop/recharge.png'),
  ('USB OTG Adapter', 'OTG अ‍ॅडॉप्टर', 'pcs', 100, '/starter-images/mobile-shop/otg.png'),
  ('Selfie Stick', 'सेल्फी स्टिक', 'pcs', 250, '/starter-images/mobile-shop/selfie-stick.png'),
  ('Car Mobile Holder', 'कार मोबाईल होल्डर', 'pcs', 300, '/starter-images/mobile-shop/car-holder.png'),
  ('Mobile Cleaning Kit', 'मोबाईल क्लीनिंग किट', 'pcs', 120, '/starter-images/mobile-shop/cleaning-kit.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'mobile-shop';

-- STEP 4 — sanity check: also dedupe every OTHER vertical's template, in
-- case the same double-run affected them too. Keeps the oldest row per
-- (business_type_id, name_en), deletes newer duplicates. Any business that
-- already copied a now-deleted duplicate row keeps what it has — this only
-- cleans the template, not existing businesses (use 0008's logic for that
-- if a specific business still shows doubles).
do $$
declare
  r record;
  v_keep_id uuid;
begin
  for r in
    select business_type_id, name_en
    from public.industry_products
    group by business_type_id, name_en
    having count(*) > 1
  loop
    select id into v_keep_id
    from public.industry_products
    where business_type_id = r.business_type_id and name_en = r.name_en
    order by created_at asc
    limit 1;

    delete from public.industry_products
    where business_type_id = r.business_type_id and name_en = r.name_en and id != v_keep_id;
  end loop;
end $$;
