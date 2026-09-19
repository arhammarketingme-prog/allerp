-- ============================================================================
-- 0005: Mobile Shop starter catalog + retroactive sync mechanism.
-- Why "sync" is needed: create_business() copies the starter catalog that
-- exists AT THE MOMENT of creation. A business created before its vertical's
-- catalog was seeded (like the mobile-shop test business) ends up with zero
-- products. sync_starter_catalog() lets an owner pull in anything added since.
-- ============================================================================

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

-- ----------------------------------------------------------------------------
-- sync_starter_catalog: pulls in any industry_products the caller's business
-- doesn't already have (matched via industry_product_id), stock=0, inactive —
-- exactly like the initial copy in create_business(), just re-runnable.
-- ----------------------------------------------------------------------------
create or replace function public.sync_starter_catalog(p_business_id uuid)
returns integer
language plpgsql
security definer
as $$
declare
  v_business public.businesses;
  v_added integer;
begin
  if not public.is_business_member(p_business_id) then
    raise exception 'Not authorized for this business';
  end if;

  select * into v_business from public.businesses where id = p_business_id;

  insert into public.business_products (
    business_id, industry_product_id, category_id, name, brand, description,
    unit, selling_price, image_url, image_source, image_license, stock, is_active
  )
  select
    p_business_id, ip.id, ip.category_id, ip.name_en, ip.brand, ip.description,
    ip.unit, coalesce(ip.suggested_price, 0), ip.image_url, ip.image_source, ip.image_license,
    0, false
  from public.industry_products ip
  where ip.business_type_id = v_business.business_type_id
    and ip.id not in (
      select industry_product_id from public.business_products
      where business_id = p_business_id and industry_product_id is not null
    );

  get diagnostics v_added = row_count;

  insert into public.audit_logs (actor_user_id, business_id, action, entity_type, after_data)
  values (auth.uid(), p_business_id, 'catalog.sync', 'business_products', jsonb_build_object('added', v_added));

  return v_added;
end;
$$;

grant execute on function public.sync_starter_catalog(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- add_custom_product: the "+ Add New Product" flow (spec section 6) — a
-- seller-authored product not tied to any industry_products template.
-- ----------------------------------------------------------------------------
create or replace function public.add_custom_product(
  p_business_id uuid,
  p_name text,
  p_unit text,
  p_selling_price numeric,
  p_stock numeric default 0,
  p_purchase_price numeric default null,
  p_brand text default null,
  p_description text default null,
  p_sku text default null,
  p_image_url text default null
)
returns public.business_products
language plpgsql
security definer
as $$
declare
  v_product public.business_products;
begin
  if not public.is_business_member(p_business_id) then
    raise exception 'Not authorized for this business';
  end if;

  insert into public.business_products (
    business_id, name, unit, selling_price, purchase_price, brand, description, sku, image_url,
    stock, is_active
  )
  values (
    p_business_id, p_name, p_unit, p_selling_price, p_purchase_price, p_brand, p_description, p_sku, p_image_url,
    0, p_stock > 0
  )
  returning * into v_product;

  if p_stock != 0 then
    insert into public.inventory_movements (business_id, business_product_id, change_qty, reason, created_by)
    values (p_business_id, v_product.id, p_stock, 'purchase', auth.uid());
    select * into v_product from public.business_products where id = v_product.id;
  end if;

  insert into public.audit_logs (actor_user_id, business_id, action, entity_type, entity_id, after_data)
  values (auth.uid(), p_business_id, 'product.create', 'business_product', v_product.id, to_jsonb(v_product));

  return v_product;
end;
$$;

grant execute on function public.add_custom_product(uuid, text, text, numeric, numeric, numeric, text, text, text, text) to authenticated;
