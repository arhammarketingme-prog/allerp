/**
 * AllERP - Universal Global Auto-Mapper (Zero UI Impact)
 * ही स्क्रिप्ट कोणत्याही मूळ HTML/CSS डिझाइनला हात लावत नाही.
 */

(function () {
  let debounceTimer = null;

  // १. भारतातील आणि ग्लोबल टॉप ब्रँड्सचा थेट अचूक डेटाबेस (नाव तेच, फोटो तोच)
  const DIRECT_CATALOG = {
    "tata salt": {
      name: "Tata Salt Vacuum Evaporated 1kg",
      cat: "Staples (मीठ)",
      unit: "Kg",
      price: 28,
      mrp: 28,
      img: "https://images.openfoodfacts.org/images/products/8901030012586/front_en.6.400.jpg"
    },
    "tata solt": {
      name: "Tata Salt Vacuum Evaporated 1kg",
      cat: "Staples (मीठ)",
      unit: "Kg",
      price: 28,
      mrp: 28,
      img: "https://images.openfoodfacts.org/images/products/8901030012586/front_en.6.400.jpg"
    },
    "parle g": {
      name: "Parle-G Gold Glucose Biscuits",
      cat: "Biscuits",
      unit: "Packet",
      price: 10,
      mrp: 10,
      img: "https://images.openfoodfacts.org/images/products/8901719101038/front_en.4.400.jpg"
    },
    "bisleri": {
      name: "Bisleri Mineral Water 1L",
      cat: "Beverages / Water",
      unit: "Bottle",
      price: 20,
      mrp: 20,
      img: "https://images.openfoodfacts.org/images/products/8906007280235/front_en.13.400.jpg"
    },
    "gemini": {
      name: "Gemini Pure Sunflower Oil 1L",
      cat: "Cooking Oil",
      unit: "Liter",
      price: 135,
      mrp: 145,
      img: "https://images.openfoodfacts.org/images/products/8906007280235/front_en.13.400.jpg"
    },
    "maggi": {
      name: "Nestle Maggi 2-Minute Masala Noodles 70g",
      cat: "Instant Food",
      unit: "Packet",
      price: 14,
      mrp: 14,
      img: "https://images.openfoodfacts.org/images/products/890/105/890/1559/front_en.3.400.jpg"
    },
    "lux": {
      name: "Lux Rose Beauty Soap",
      cat: "Personal Care",
      unit: "Piece",
      price: 35,
      mrp: 38,
      img: "https://images.openfoodfacts.org/images/products/8901030383846/front_en.4.400.jpg"
    }
  };

  // २. ग्लोबल ओपन वेब सर्च (कपडे, स्टेशनरी, इतर कशासाठीही)
  async function searchGlobalWeb(query) {
    const clean = query.trim().toLowerCase();

    // आधी डायरेक्ट कॅटलॉग तपासणे (१ सेकंदाच्या आत अचूक रिझल्ट)
    for (const key in DIRECT_CATALOG) {
      if (clean.includes(key)) {
        return DIRECT_CATALOG[key];
      }
    }

    // जर कॅटलॉगमध्ये नसेल (उदा. Navneet, Raymond, Colgate) तर ओपन फूड/प्रॉडक्ट फॅक्ट्स सर्च
    try {
      const res = await fetch(`https://in.openfoodfacts.org/cgi/search.pl?search_terms=${encodeURIComponent(query)}&search_simple=1&action=process&json=1&page_size=1`);
      const data = await res.json();
      if (data.products && data.products.length > 0) {
        const p = data.products[0];
        const img = p.image_front_url || p.image_url;
        if (img) {
          return {
            name: p.product_name || query,
            cat: p.categories ? p.categories.split(',')[0] : "General",
            unit: "Piece",
            price: 50,
            mrp: 50,
            img: img
          };
        }
      }
    } catch (e) {}

    // जर काहीच सापडले नाही, तर त्या प्रॉडक्टच्या नावाचेच स्वच्छ व्यावसायिक कार्ड
    const initialText = encodeURIComponent(query.substring(0, 14).toUpperCase());
    return {
      name: query,
      cat: "Universal Product",
      unit: "Piece",
      price: null,
      mrp: null,
      img: `data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' rx='8' fill='%23b45309'/><text x='50' y='55' font-family='Arial,sans-serif' font-size='10' font-weight='bold' fill='%23ffffff' text-anchor='middle'>${initialText}</text></svg>`
    };
  }

  // ३. तुमच्या मूळ डॅशबोर्डच्या इनपुटला हुक करणे
  function bindToExistingModal() {
    const inputField = document.querySelector('input[placeholder*="Turmeric Powder"], input[name="product_name"], #product_name, #product_name_input');
    if (!inputField || inputField.dataset.smartBound) return;

    inputField.dataset.smartBound = "true";

    inputField.addEventListener('input', function (e) {
      const val = e.target.value.trim();
      clearTimeout(debounceTimer);

      if (val.length < 2) return;

      debounceTimer = setTimeout(async () => {
        const result = await searchGlobalWeb(val);

        // मूळ ऑटो-मॅप इमेज टॅग शोधून त्यात अचूक फोटो भरणे
        const modal = inputField.closest('form') || document.body;
        const imgTags = modal.querySelectorAll('img');
        
        for (const img of imgTags) {
          // जो इमेज टॅग प्रीव्ह्यूसाठी वापरला आहे त्यालाच टार्गेट करणे
          if (img.id.includes('preview') || img.id.includes('Auto') || img.src.includes('svg') || img.closest('#autoMapSection') || img.closest('.auto-map')) {
            img.src = result.img;
            img.style.objectFit = 'contain';
            break;
          }
        }

        // युनिट, दर आणि एमआरपी मूळ इनपुट्समध्ये सेट करणे
        const unitDropdown = modal.querySelector('select');
        const priceInput = modal.querySelector('input[type="number"][placeholder*="विक्री"], input[name="price"], #price');
        const mrpInput = modal.querySelector('input[type="number"][placeholder*="एमआरपी"], input[placeholder*="MRP"], input[name="mrp"], #mrp');

        if (unitDropdown && result.unit) unitDropdown.value = result.unit;
        if (priceInput && result.price && !priceInput.value) priceInput.value = result.price;
        if (mrpInput && result.mrp && !mrpInput.value) mrpInput.value = result.mrp;
      }, 300);
    });
  }

  // पेज लोड झाल्यावर आणि मोडल उघडल्यावर आपोआप जोडणे
  document.addEventListener('DOMContentLoaded', bindToExistingModal);
  document.addEventListener('click', () => setTimeout(bindToExistingModal, 300));
})();
