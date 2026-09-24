/**
 * AllERP - Core ERP & Smart Auto-Mapping Engine
 * बारकोड, ऑटो-कॅटलॉग मॅपिंग आणि अस्सल ब्रँडेड ओरिजिनल इमेजेस
 */

(function () {
    // अस्सल प्रॉडक्ट्सचा मास्टर डेटाबेस (ओरिजिनल हाय-क्वालिटी पॅकेजिंग इमेजेससह)
    const BUILTIN_MASTER_CATALOG = [
        {
            keywords: ['maggi', 'maggie', 'nestle maggi', 'मॅगी', 'noodles', 'मॅगी नूडल्स'],
            category: 'Instant Food',
            name: 'Nestle Maggi 2-Minute Masala Noodles 70g',
            unit: 'Packet',
            price: 14,
            mrp: 14,
            // अस्सल नेस्ले मॅगीचे ओरिजिनल पॅकेजिंग चित्र
            image: 'https://images.openfoodfacts.org/images/products/890/105/885/2399/front_en.15.400.jpg'
        },
        {
            keywords: ['yippee', 'sunfeast yippee', 'यिप्पी'],
            category: 'Instant Food',
            name: 'Sunfeast YiPPee! Classic Masala Noodles',
            unit: 'Packet',
            price: 14,
            mrp: 15,
            image: 'https://images.openfoodfacts.org/images/products/8901725181222/front_en.3.400.jpg'
        },
        {
            keywords: ['parle-g', 'parle g', 'parleg', 'पारले जी'],
            category: 'Biscuits',
            name: 'Parle-G Gold Glucose Biscuits',
            unit: 'Packet',
            price: 10,
            mrp: 10,
            image: 'https://images.openfoodfacts.org/images/products/8901719101038/front_en.4.400.jpg'
        },
        {
            keywords: ['good day', 'britannia good day', 'गुड डे'],
            category: 'Biscuits',
            name: 'Britannia Good Day Butter Cookies',
            unit: 'Packet',
            price: 20,
            mrp: 20,
            image: 'https://images.openfoodfacts.org/images/products/8901063012640/front_en.8.400.jpg'
        },
        {
            keywords: ['amul butter', 'butter', 'अमूल बटर', 'बटर'],
            category: 'Dairy',
            name: 'Amul Pasteurised Butter 100g',
            unit: 'Pack',
            price: 56,
            mrp: 58,
            image: 'https://images.openfoodfacts.org/images/products/8901262010054/front_en.10.400.jpg'
        },
        {
            keywords: ['red label', 'red label tea', 'रेड लेबल'],
            category: 'Beverages',
            name: 'Brooke Bond Red Label Tea',
            unit: 'Pack',
            price: 130,
            mrp: 140,
            image: 'https://images.openfoodfacts.org/images/products/8901030383457/front_en.14.400.jpg'
        },
        {
            keywords: ['dettol', 'dettol soap', 'डेटॉल'],
            category: 'Personal Care',
            name: 'Dettol Original Bathing Soap',
            unit: 'Piece',
            price: 38,
            mrp: 40,
            image: 'https://images.openfoodfacts.org/images/products/8901396328209/front_en.4.400.jpg'
        },
        {
            keywords: ['colgate', 'toothpaste', 'कोलगेट'],
            category: 'Oral Care',
            name: 'Colgate Strong Teeth Toothpaste',
            unit: 'Piece',
            price: 60,
            mrp: 65,
            image: 'https://images.openfoodfacts.org/images/products/8901314010520/front_en.8.400.jpg'
        },
        {
            keywords: ['tata salt', 'salt', 'टाटा मीठ', 'मीठ'],
            category: 'Staples',
            name: 'Tata Salt Vacuum Evaporated Iodised Salt 1kg',
            unit: 'Kg',
            price: 26,
            mrp: 28,
            image: 'https://images.openfoodfacts.org/images/products/8901030012586/front_en.6.400.jpg'
        },
        {
            keywords: ['sugar', 'साखर'],
            category: 'Staples',
            name: 'Madhur Pure Sugar 1kg',
            unit: 'Kg',
            price: 44,
            mrp: 48,
            image: 'https://images.openfoodfacts.org/images/products/8906014410014/front_en.4.400.jpg'
        }
    ];

    // कीवर्डवरून योग्य प्रॉडक्ट शोधणारे फंक्शन
    function matchCatalogItem(inputVal) {
        if (!inputVal || inputVal.trim().length === 0) return null;
        const q = inputVal.trim().toLowerCase();

        // १. आधी स्थानिक मास्टर डिक्शनरीमध्ये शोधणे
        for (const item of BUILTIN_MASTER_CATALOG) {
            for (const kw of item.keywords) {
                if (q.includes(kw.toLowerCase()) || kw.toLowerCase().includes(q)) {
                    return item;
                }
            }
        }

        // २. बाहेरील master-dictionary उपलब्ध असल्यास तिथे शोधणे
        if (window.MASTER_CATALOG_DICTIONARY && typeof window.findProductInDictionary === 'function') {
            const ext = window.findProductInDictionary(q);
            if (ext) {
                return {
                    name: ext.name,
                    category: ext.category,
                    unit: ext.unit,
                    price: ext.defaultPrice,
                    mrp: ext.defaultMrp,
                    image: ext.imageUrl
                };
            }
        }
        return null;
    }

    // इनपुटवर टाईप करताना ऑटो-मॅपिंग हाताळणे
    function setupProductAutoMapping() {
        // प्रॉडक्ट नावाचा इनपुट शोधणे
        const nameInput = document.querySelector('input[placeholder*="Turmeric Powder"], input[name="product_name"], #product_name, #productName');
        if (!nameInput) return;

        nameInput.addEventListener('input', async function (e) {
            const query = e.target.value.trim();
            const previewContainer = document.querySelector('[class*="preview"], [id*="preview"], [id*="auto_mapped"]') 
                || nameInput.closest('form')?.querySelector('.auto-mapped-box, div[style*="background"]');

            // मॅच शोधणे
            const match = matchCatalogItem(query);

            if (match) {
                renderAutoMappedBox(match);
            } else if (query.length > 2) {
                // जर स्थानिक सापडले नाही तर लाइव्ह API कॉल
                try {
                    const res = await fetch(`https://in.openfoodfacts.org/cgi/search.pl?search_terms=${encodeURIComponent(query)}&search_simple=1&action=process&json=1&page_size=1`);
                    const data = await res.json();
                    if (data.products && data.products.length > 0) {
                        const p = data.products[0];
                        const apiMatch = {
                            name: p.product_name || query,
                            category: p.categories ? p.categories.split(',')[0] : 'General',
                            unit: 'Packet',
                            price: 0,
                            mrp: 0,
                            image: p.image_front_url || p.image_url
                        };
                        if (apiMatch.image) {
                            renderAutoMappedBox(apiMatch);
                        }
                    }
                } catch (err) {
                    console.warn("API Auto-fetch err:", err);
                }
            }
        });
    }

    // ऑटो-मॅप बॉक्समध्ये अस्सल फोटो योग्यरीत्या रेंडर करणे
    function renderAutoMappedBox(item) {
        // पॉप-अपमधील ऑटो-मॅप्ड बॉक्स शोधणे
        const allBoxes = document.querySelectorAll('div');
        let targetBox = null;

        for (const el of allBoxes) {
            if (el.textContent && el.textContent.includes('Auto-Mapped') && el.querySelector('img, span')) {
                targetBox = el;
                break;
            }
        }

        if (!targetBox) {
            targetBox = document.querySelector('[id*="auto-map"], .auto-map-preview');
        }

        if (targetBox) {
            targetBox.style.display = 'flex';
            targetBox.style.alignItems = 'center';
            targetBox.style.gap = '15px';
            targetBox.style.padding = '12px';
            targetBox.style.background = '#f0fdf4';
            targetBox.style.border = '1px solid #bbf7d0';
            targetBox.style.borderRadius = '8px';

            targetBox.innerHTML = `
                <img src="${item.image}" alt="${item.name}" style="width: 60px; height: 60px; object-fit: contain; background: #fff; border-radius: 6px; border: 1px solid #ddd; padding: 2px;">
                <div style="text-align: left;">
                    <div style="font-weight: bold; color: #166534; font-size: 14px;">✨ Auto-Mapped (${item.category})</div>
                    <div style="font-size: 13px; color: #333; margin-top: 2px;">${item.name} चे ओरिजिनल चित्र सेट केले आहे.</div>
                    <input type="hidden" id="selected_auto_image" name="image_url" value="${item.image}">
                </div>
            `;
        }

        // युनिट, एमआरपी आणि दर असल्यास ऑटो-फिल करणे
        const unitSelect = document.querySelector('select[name="unit"], #unit, input[placeholder*="Unit"]');
        const priceInput = document.querySelector('input[name="price"], #price, input[placeholder*="विक्री दर"]');
        const mrpInput = document.querySelector('input[name="mrp"], #mrp, input[placeholder*="MRP"]');

        if (unitSelect && item.unit) unitSelect.value = item.unit;
        if (priceInput && item.price && !priceInput.value) priceInput.value = item.price;
        if (mrpInput && item.mrp && !mrpInput.value) mrpInput.value = item.mrp;
    }

    // पेज पूर्ण लोड झाल्यावर सुरू करणे
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', setupProductAutoMapping);
    } else {
        setupProductAutoMapping();
    }

    // Modal उघडल्यानंतर पुन्हा इव्हेंट जोडणे
    document.addEventListener('click', function(e) {
        if (e.target && (e.target.innerText?.includes('नवीन प्रॉडक्ट') || e.target.closest('[onclick*="Modal"], [data-target]'))) {
            setTimeout(setupProductAutoMapping, 300);
        }
    });

    window.AllErpEngine = {
        matchCatalogItem,
        renderAutoMappedBox
    };
})();
