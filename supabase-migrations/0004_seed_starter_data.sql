-- ============================================================================
-- SEED DATA — demonstrates the pattern for all 100+ verticals.
-- This migration ships business_types for the 10 first-priority verticals
-- (spec section 39) plus a full 20-item starter catalog for Grocery and a
-- 15-item catalog for Electronics, enough to exercise every acceptance test
-- in section 43 end-to-end. Extending to 100+ products x 100+ verticals is a
-- data-entry/content task, not an architecture task — same INSERT pattern,
-- run per vertical (ideally via an admin CSV importer, see README).
--
-- Images: every image_url below is a placeholder path (/starter-images/...)
-- pointing at square-cropped, license-tagged illustrations to be generated/
-- sourced separately per rule #4 (no copyrighted marketplace images). Swap
-- these for real licensed/AI-generated asset URLs before going live.
-- ============================================================================

insert into public.business_types (slug, name_en, name_mr, category, sort_order) values
  ('grocery', 'Grocery / Kirana', 'किराणा दुकान', 'retail', 1),
  ('electronics', 'Electronics', 'इलेक्ट्रॉनिक्स', 'retail', 2),
  ('clothing', 'Clothing', 'कापड दुकान', 'retail', 3),
  ('hardware', 'Hardware', 'हार्डवेअर', 'retail', 4),
  ('restaurant', 'Restaurant', 'रेस्टॉरंट', 'food', 5),
  ('medical-store', 'Medical Store', 'मेडिकल स्टोअर', 'healthcare', 6),
  ('contractor', 'Contractor', 'कंत्राटदार', 'services', 7),
  ('furniture', 'Furniture', 'फर्निचर', 'retail', 8),
  ('mobile-shop', 'Mobile Shop', 'मोबाईल शॉप', 'retail', 9),
  ('real-estate', 'Real Estate / Property Dealer', 'रिअल इस्टेट', 'services', 10);

-- ---- Grocery starter catalog (20 of target 100+) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Rice (1kg)', 'तांदूळ (१ किलो)', 'kg', 60, '/starter-images/grocery/rice.png'),
  ('Wheat Flour (1kg)', 'गहू पीठ (१ किलो)', 'kg', 45, '/starter-images/grocery/wheat-flour.png'),
  ('Sugar (1kg)', 'साखर (१ किलो)', 'kg', 44, '/starter-images/grocery/sugar.png'),
  ('Salt (1kg)', 'मीठ (१ किलो)', 'kg', 20, '/starter-images/grocery/salt.png'),
  ('Cooking Oil (1L)', 'खाद्यतेल (१ लिटर)', 'L', 140, '/starter-images/grocery/oil.png'),
  ('Tea Powder (250g)', 'चहा पावडर (२५० ग्रॅम)', 'pack', 90, '/starter-images/grocery/tea.png'),
  ('Coffee (100g)', 'कॉफी (१०० ग्रॅम)', 'pack', 120, '/starter-images/grocery/coffee.png'),
  ('Biscuits (Pack)', 'बिस्कीट पॅक', 'pack', 25, '/starter-images/grocery/biscuits.png'),
  ('Turmeric Powder (100g)', 'हळद पावडर (१०० ग्रॅम)', 'pack', 35, '/starter-images/grocery/turmeric.png'),
  ('Red Chilli Powder (100g)', 'तिखट (१०० ग्रॅम)', 'pack', 40, '/starter-images/grocery/chilli.png'),
  ('Bathing Soap', 'अंघोळीचा साबण', 'pcs', 35, '/starter-images/grocery/soap.png'),
  ('Shampoo (200ml)', 'शॅम्पू (२०० मिली)', 'bottle', 110, '/starter-images/grocery/shampoo.png'),
  ('Toothpaste (100g)', 'टूथपेस्ट (१०० ग्रॅम)', 'tube', 55, '/starter-images/grocery/toothpaste.png'),
  ('Detergent Powder (1kg)', 'डिटर्जंट पावडर (१ किलो)', 'kg', 95, '/starter-images/grocery/detergent.png'),
  ('Milk (500ml)', 'दूध (५०० मिली)', 'packet', 28, '/starter-images/grocery/milk.png'),
  ('Curd (200g)', 'दही (२०० ग्रॅम)', 'cup', 22, '/starter-images/grocery/curd.png'),
  ('Namkeen Snacks (Pack)', 'नमकीन पॅक', 'pack', 30, '/starter-images/grocery/namkeen.png'),
  ('Toor Dal (1kg)', 'तूर डाळ (१ किलो)', 'kg', 130, '/starter-images/grocery/toor-dal.png'),
  ('Match Box', 'काडेपेटी', 'pcs', 2, '/starter-images/grocery/matchbox.png'),
  ('Agarbatti Pack', 'उदबत्ती पॅक', 'pack', 30, '/starter-images/grocery/agarbatti.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'grocery';

-- ---- Electronics starter catalog (15 of target 100+) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('LED Bulb 9W', 'एलईडी बल्ब ९W', 'pcs', 90, '/starter-images/electronics/led-bulb.png'),
  ('Extension Board (4 socket)', 'एक्सटेंशन बोर्ड', 'pcs', 350, '/starter-images/electronics/extension-board.png'),
  ('USB Cable Type-C', 'यूएसबी केबल टाइप-सी', 'pcs', 150, '/starter-images/electronics/usb-cable.png'),
  ('Mobile Charger 20W', 'मोबाईल चार्जर २०W', 'pcs', 400, '/starter-images/electronics/charger.png'),
  ('Table Fan', 'टेबल फॅन', 'pcs', 900, '/starter-images/electronics/table-fan.png'),
  ('Ceiling Fan', 'सीलिंग फॅन', 'pcs', 1500, '/starter-images/electronics/ceiling-fan.png'),
  ('Electric Iron', 'इस्त्री', 'pcs', 750, '/starter-images/electronics/iron.png'),
  ('Wired Earphones', 'इअरफोन्स', 'pcs', 250, '/starter-images/electronics/earphones.png'),
  ('Bluetooth Speaker', 'ब्लूटूथ स्पीकर', 'pcs', 1200, '/starter-images/electronics/speaker.png'),
  ('Power Bank 10000mAh', 'पॉवर बँक १०,०००mAh', 'pcs', 1100, '/starter-images/electronics/powerbank.png'),
  ('Switch Board 6A', 'स्विच बोर्ड ६A', 'pcs', 60, '/starter-images/electronics/switch-board.png'),
  ('LED Tube Light 20W', 'एलईडी ट्यूब लाईट २०W', 'pcs', 220, '/starter-images/electronics/tube-light.png'),
  ('Multimeter', 'मल्टीमीटर', 'pcs', 450, '/starter-images/electronics/multimeter.png'),
  ('Extension Wire (10m)', 'वायर (१० मीटर)', 'roll', 500, '/starter-images/electronics/wire-roll.png'),
  ('Inverter Battery', 'इन्व्हर्टर बॅटरी', 'pcs', 8500, '/starter-images/electronics/inverter-battery.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'electronics';

-- ---- Core ERP modules referenced by default_modules on business_types ----
insert into public.erp_modules (code, name, is_core) values
  ('inventory', 'Inventory', true),
  ('sales', 'Sales / POS', true),
  ('purchase', 'Purchase', true),
  ('customers', 'Customers', true),
  ('suppliers', 'Suppliers', false),
  ('orders', 'Orders', true),
  ('reports', 'Reports', true),
  ('marketplace', 'Marketplace', true),
  ('advertising', 'Advertising', false),
  ('ai_assistant', 'AI Assistant', false),
  ('gst_billing', 'GST Billing', false),
  ('table_management', 'Table Management', false)
on conflict (code) do nothing;
