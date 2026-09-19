-- ============================================================================
-- 0007: Starter catalogs for the remaining first-priority verticals.
-- With this, all 10 priority business_types have a real starter catalog
-- BEFORE anyone can select them — so create_business() alone is always
-- enough. The "Sync Starter Catalog" button becomes a safety net for future
-- vertical launches, never a required step for these 10.
-- ============================================================================

-- ---- Clothing (18 items) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Men''s Shirt', 'पुरुषांचा शर्ट', 'pcs', 500, '/starter-images/clothing/mens-shirt.png'),
  ('Men''s T-Shirt', 'पुरुषांचा टी-शर्ट', 'pcs', 350, '/starter-images/clothing/mens-tshirt.png'),
  ('Men''s Jeans', 'पुरुषांची जीन्स', 'pcs', 900, '/starter-images/clothing/mens-jeans.png'),
  ('Men''s Formal Trousers', 'पुरुषांची फॉर्मल पँट', 'pcs', 750, '/starter-images/clothing/mens-trousers.png'),
  ('Women''s Kurti', 'महिलांचा कुर्ती', 'pcs', 600, '/starter-images/clothing/kurti.png'),
  ('Women''s Saree', 'महिलांची साडी', 'pcs', 1500, '/starter-images/clothing/saree.png'),
  ('Women''s Leggings', 'महिलांची लेगिंग्स', 'pcs', 300, '/starter-images/clothing/leggings.png'),
  ('Women''s Salwar Suit', 'महिलांचा सलवार सूट', 'pcs', 1100, '/starter-images/clothing/salwar.png'),
  ('Kids T-Shirt', 'मुलांचा टी-शर्ट', 'pcs', 250, '/starter-images/clothing/kids-tshirt.png'),
  ('Kids Frock', 'मुलींचा फ्रॉक', 'pcs', 450, '/starter-images/clothing/frock.png'),
  ('School Uniform Set', 'शाळेचा गणवेश', 'set', 700, '/starter-images/clothing/uniform.png'),
  ('Innerwear (Pack)', 'इनरवेअर पॅक', 'pack', 300, '/starter-images/clothing/innerwear.png'),
  ('Socks (Pair)', 'मोजे जोडी', 'pair', 100, '/starter-images/clothing/socks.png'),
  ('Belt', 'बेल्ट', 'pcs', 350, '/starter-images/clothing/belt.png'),
  ('Handkerchief (Pack)', 'रुमाल पॅक', 'pack', 100, '/starter-images/clothing/handkerchief.png'),
  ('Winter Jacket', 'हिवाळी जॅकेट', 'pcs', 1400, '/starter-images/clothing/jacket.png'),
  ('Nightwear Set', 'नाईटवेअर सेट', 'set', 500, '/starter-images/clothing/nightwear.png'),
  ('Dupatta', 'दुपट्टा', 'pcs', 300, '/starter-images/clothing/dupatta.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'clothing';

-- ---- Hardware (18 items) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Cement Bag (50kg)', 'सिमेंट बॅग', 'bag', 400, '/starter-images/hardware/cement.png'),
  ('Steel Rod (per kg)', 'सळई (प्रति किलो)', 'kg', 70, '/starter-images/hardware/steel-rod.png'),
  ('Hammer', 'हातोडा', 'pcs', 250, '/starter-images/hardware/hammer.png'),
  ('Screwdriver Set', 'स्क्रूड्रायव्हर सेट', 'set', 300, '/starter-images/hardware/screwdriver.png'),
  ('Nails (1kg)', 'खिळे (१ किलो)', 'kg', 120, '/starter-images/hardware/nails.png'),
  ('Screws (Pack)', 'स्क्रू पॅक', 'pack', 80, '/starter-images/hardware/screws.png'),
  ('Paint (1L)', 'रंग (१ लिटर)', 'L', 350, '/starter-images/hardware/paint.png'),
  ('Paint Brush', 'रंगाचा ब्रश', 'pcs', 60, '/starter-images/hardware/brush.png'),
  ('PVC Pipe (per foot)', 'पीव्हीसी पाईप (प्रति फूट)', 'ft', 25, '/starter-images/hardware/pvc-pipe.png'),
  ('Tap/Faucet', 'नळ', 'pcs', 200, '/starter-images/hardware/tap.png'),
  ('Door Lock', 'दाराचं कुलूप', 'pcs', 450, '/starter-images/hardware/lock.png'),
  ('Hinges (Pair)', 'बिजागरी जोडी', 'pair', 80, '/starter-images/hardware/hinges.png'),
  ('Measuring Tape', 'मापन टेप', 'pcs', 150, '/starter-images/hardware/tape.png'),
  ('Wire Mesh (per sq ft)', 'जाळी (प्रति चौ. फूट)', 'sqft', 40, '/starter-images/hardware/wire-mesh.png'),
  ('Sandpaper', 'सँडपेपर', 'pcs', 20, '/starter-images/hardware/sandpaper.png'),
  ('Bucket (Plastic)', 'प्लास्टिक बादली', 'pcs', 150, '/starter-images/hardware/bucket.png'),
  ('Rope (per meter)', 'दोरी (प्रति मीटर)', 'm', 15, '/starter-images/hardware/rope.png'),
  ('Adhesive/Fevicol', 'फेविकॉल', 'pcs', 90, '/starter-images/hardware/adhesive.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'hardware';

-- ---- Restaurant (16 items) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Veg Thali', 'व्हेज थाळी', 'plate', 130, '/starter-images/restaurant/veg-thali.png'),
  ('Paneer Butter Masala', 'पनीर बटर मसाला', 'plate', 180, '/starter-images/restaurant/paneer-butter-masala.png'),
  ('Chicken Curry', 'चिकन करी', 'plate', 220, '/starter-images/restaurant/chicken-curry.png'),
  ('Plain Rice', 'साधा भात', 'plate', 60, '/starter-images/restaurant/rice.png'),
  ('Roti (per piece)', 'रोटी (प्रति नग)', 'pcs', 15, '/starter-images/restaurant/roti.png'),
  ('Dal Fry', 'डाळ फ्राय', 'bowl', 80, '/starter-images/restaurant/dal-fry.png'),
  ('Masala Dosa', 'मसाला डोसा', 'plate', 90, '/starter-images/restaurant/dosa.png'),
  ('Idli (Plate)', 'इडली प्लेट', 'plate', 60, '/starter-images/restaurant/idli.png'),
  ('Vada Pav', 'वडा पाव', 'pcs', 20, '/starter-images/restaurant/vada-pav.png'),
  ('Misal Pav', 'मिसळ पाव', 'plate', 70, '/starter-images/restaurant/misal.png'),
  ('Pav Bhaji', 'पाव भाजी', 'plate', 100, '/starter-images/restaurant/pav-bhaji.png'),
  ('Tea (Cup)', 'चहा', 'cup', 15, '/starter-images/restaurant/tea.png'),
  ('Coffee (Cup)', 'कॉफी', 'cup', 25, '/starter-images/restaurant/coffee.png'),
  ('Cold Drink (Bottle)', 'कोल्ड ड्रिंक', 'bottle', 40, '/starter-images/restaurant/cold-drink.png'),
  ('Gulab Jamun (Plate)', 'गुलाब जामून', 'plate', 60, '/starter-images/restaurant/gulab-jamun.png'),
  ('Papad', 'पापड', 'pcs', 15, '/starter-images/restaurant/papad.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'restaurant';

-- ---- Medical Store (18 items — generic categories only, no brand/Rx claims) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Paracetamol Tablets (Strip)', 'पॅरासिटामॉल गोळ्या', 'strip', 20, '/starter-images/medical/paracetamol.png'),
  ('Antacid Tablets (Strip)', 'अँटासिड गोळ्या', 'strip', 25, '/starter-images/medical/antacid.png'),
  ('ORS Sachet', 'ओआरएस पाकीट', 'pcs', 20, '/starter-images/medical/ors.png'),
  ('Cotton Roll', 'कापूस रोल', 'pcs', 40, '/starter-images/medical/cotton.png'),
  ('Bandage Roll', 'बँडेज रोल', 'pcs', 30, '/starter-images/medical/bandage.png'),
  ('Antiseptic Liquid (100ml)', 'अँटीसेप्टिक लिक्विड', 'bottle', 60, '/starter-images/medical/antiseptic.png'),
  ('Hand Sanitizer (100ml)', 'हँड सॅनिटायझर', 'bottle', 60, '/starter-images/medical/sanitizer.png'),
  ('Face Mask (Pack of 5)', 'मास्क पॅक', 'pack', 50, '/starter-images/medical/mask.png'),
  ('Thermometer', 'थर्मामीटर', 'pcs', 150, '/starter-images/medical/thermometer.png'),
  ('BP Monitor', 'बीपी मॉनिटर', 'pcs', 1500, '/starter-images/medical/bp-monitor.png'),
  ('Glucometer Strips', 'ग्लुकोमीटर स्ट्रिप्स', 'pack', 400, '/starter-images/medical/glucometer.png'),
  ('Multivitamin Tablets (Strip)', 'मल्टीविटॅमिन गोळ्या', 'strip', 100, '/starter-images/medical/multivitamin.png'),
  ('Cough Syrup (100ml)', 'खोकल्याचं औषध', 'bottle', 90, '/starter-images/medical/cough-syrup.png'),
  ('Pain Relief Spray', 'पेन रिलीफ स्प्रे', 'bottle', 180, '/starter-images/medical/pain-spray.png'),
  ('Baby Diapers (Pack)', 'बेबी डायपर पॅक', 'pack', 300, '/starter-images/medical/diapers.png'),
  ('Sanitary Pads (Pack)', 'सॅनिटरी पॅड्स', 'pack', 60, '/starter-images/medical/sanitary-pads.png'),
  ('Surgical Gloves (Pair)', 'सर्जिकल ग्लोव्ह्ज जोडी', 'pair', 20, '/starter-images/medical/gloves.png'),
  ('Weighing Scale', 'वजन काटा', 'pcs', 500, '/starter-images/medical/weighing-scale.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'medical-store';

-- ---- Contractor (15 items — services + materials) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Site Visit / Consultation', 'साईट व्हिजिट / सल्ला', 'visit', 500, '/starter-images/contractor/site-visit.png'),
  ('Masonry Work (per sq ft)', 'गवंडी काम (प्रति चौ. फूट)', 'sqft', 60, '/starter-images/contractor/masonry.png'),
  ('Plastering (per sq ft)', 'प्लास्टरिंग (प्रति चौ. फूट)', 'sqft', 35, '/starter-images/contractor/plastering.png'),
  ('Tile Fitting (per sq ft)', 'टाईल फिटिंग (प्रति चौ. फूट)', 'sqft', 40, '/starter-images/contractor/tiling.png'),
  ('Painting Work (per sq ft)', 'रंगकाम (प्रति चौ. फूट)', 'sqft', 18, '/starter-images/contractor/painting.png'),
  ('Electrical Wiring (per point)', 'इलेक्ट्रिकल वायरिंग (प्रति पॉइंट)', 'point', 350, '/starter-images/contractor/wiring.png'),
  ('Plumbing Work (per point)', 'प्लंबिंग काम (प्रति पॉइंट)', 'point', 400, '/starter-images/contractor/plumbing.png'),
  ('False Ceiling (per sq ft)', 'फॉल्स सीलिंग (प्रति चौ. फूट)', 'sqft', 80, '/starter-images/contractor/false-ceiling.png'),
  ('Waterproofing (per sq ft)', 'वॉटरप्रूफिंग (प्रति चौ. फूट)', 'sqft', 45, '/starter-images/contractor/waterproofing.png'),
  ('Demolition Work (per sq ft)', 'तोडफोड काम (प्रति चौ. फूट)', 'sqft', 25, '/starter-images/contractor/demolition.png'),
  ('Labour (per day)', 'मजूर (प्रति दिवस)', 'day', 600, '/starter-images/contractor/labour.png'),
  ('Sand (per brass)', 'वाळू (प्रति ब्रास)', 'brass', 3500, '/starter-images/contractor/sand.png'),
  ('Bricks (per 1000)', 'विटा (प्रति १०००)', 'unit1000', 6000, '/starter-images/contractor/bricks.png'),
  ('Scaffolding Rental (per day)', 'बांधकाम मचाण भाडे (प्रति दिवस)', 'day', 300, '/starter-images/contractor/scaffolding.png'),
  ('Site Cleaning', 'साईट साफसफाई', 'visit', 1000, '/starter-images/contractor/cleaning.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'contractor';

-- ---- Furniture (16 items) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Wooden Dining Table (4-seater)', 'लाकडी डायनिंग टेबल', 'pcs', 12000, '/starter-images/furniture/dining-table.png'),
  ('Dining Chair', 'डायनिंग चेअर', 'pcs', 2000, '/starter-images/furniture/dining-chair.png'),
  ('Sofa Set (3-seater)', 'सोफा सेट', 'set', 20000, '/starter-images/furniture/sofa.png'),
  ('Double Bed', 'डबल बेड', 'pcs', 15000, '/starter-images/furniture/bed.png'),
  ('Mattress', 'गादी', 'pcs', 6000, '/starter-images/furniture/mattress.png'),
  ('Wardrobe/Cupboard', 'कपाट', 'pcs', 18000, '/starter-images/furniture/wardrobe.png'),
  ('Study Table', 'अभ्यासाचं टेबल', 'pcs', 4500, '/starter-images/furniture/study-table.png'),
  ('Office Chair', 'ऑफिस चेअर', 'pcs', 3500, '/starter-images/furniture/office-chair.png'),
  ('Bookshelf', 'बुकशेल्फ', 'pcs', 5000, '/starter-images/furniture/bookshelf.png'),
  ('TV Unit/Stand', 'टीव्ही युनिट', 'pcs', 6000, '/starter-images/furniture/tv-unit.png'),
  ('Shoe Rack', 'शू रॅक', 'pcs', 2000, '/starter-images/furniture/shoe-rack.png'),
  ('Plastic Chair', 'प्लास्टिक खुर्ची', 'pcs', 500, '/starter-images/furniture/plastic-chair.png'),
  ('Folding Table', 'फोल्डिंग टेबल', 'pcs', 1800, '/starter-images/furniture/folding-table.png'),
  ('Kids Study Set', 'मुलांचा अभ्यास सेट', 'set', 5500, '/starter-images/furniture/kids-study.png'),
  ('Dressing Table', 'ड्रेसिंग टेबल', 'pcs', 7000, '/starter-images/furniture/dressing-table.png'),
  ('Recliner Chair', 'रिक्लायनर चेअर', 'pcs', 9000, '/starter-images/furniture/recliner.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'furniture';

-- ---- Real Estate / Property Dealer (12 service-oriented listings) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('1 BHK Flat — Resale Listing', '१ बीएचके फ्लॅट — रीसेल', 'listing', 0, '/starter-images/real-estate/1bhk.png'),
  ('2 BHK Flat — Resale Listing', '२ बीएचके फ्लॅट — रीसेल', 'listing', 0, '/starter-images/real-estate/2bhk.png'),
  ('3 BHK Flat — Resale Listing', '३ बीएचके फ्लॅट — रीसेल', 'listing', 0, '/starter-images/real-estate/3bhk.png'),
  ('Plot for Sale', 'विक्रीसाठी प्लॉट', 'listing', 0, '/starter-images/real-estate/plot.png'),
  ('Row House for Sale', 'रो हाऊस विक्रीसाठी', 'listing', 0, '/starter-images/real-estate/row-house.png'),
  ('Shop/Commercial Space', 'दुकान/व्यावसायिक जागा', 'listing', 0, '/starter-images/real-estate/shop-space.png'),
  ('Flat on Rent', 'भाड्याने फ्लॅट', 'listing', 0, '/starter-images/real-estate/rent-flat.png'),
  ('Office Space on Rent', 'भाड्याने ऑफिस जागा', 'listing', 0, '/starter-images/real-estate/office-rent.png'),
  ('Agricultural Land for Sale', 'विक्रीसाठी शेत जमीन', 'listing', 0, '/starter-images/real-estate/farmland.png'),
  ('Property Registration Assistance', 'प्रॉपर्टी नोंदणी सहाय्य', 'service', 2000, '/starter-images/real-estate/registration.png'),
  ('Home Loan Assistance', 'गृहकर्ज सहाय्य', 'service', 1500, '/starter-images/real-estate/loan-assist.png'),
  ('Property Valuation Service', 'प्रॉपर्टी मूल्यांकन सेवा', 'service', 1000, '/starter-images/real-estate/valuation.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'real-estate';
