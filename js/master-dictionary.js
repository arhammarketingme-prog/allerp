/**
 * AllERP - Master Product Dictionary & Smart Auto-Mapper
 * अस्सल ओरिजिनल पॅकेजिंग इमेजेस आणि ऑटो-मॅपर इंजिन
 */

window.MASTER_CATALOG_DICTIONARY = [
    // --- Instant Food / Noodles (मॅगी व इतर) ---
    {
        keywords: ['maggi', 'maggie', 'nestle maggi', 'मॅगी', '2-minute noodles', 'maggi noodles'],
        category: 'Instant Food',
        name: 'Nestle Maggi 2-Minute Noodles',
        unit: 'Packet',
        defaultPrice: 14,
        defaultMrp: 14,
        // अस्सल नेस्ले मॅगीचे ओरिजिनल पॅकेजिंग चित्र
        imageUrl: 'https://images.openfoodfacts.org/images/products/890/105/885/2399/front_en.15.400.jpg'
    },
    {
        keywords: ['yippee', 'sunfeast yippee', 'यिप्पी'],
        category: 'Instant Food',
        name: 'Sunfeast YiPPee! Classic Masala Noodles',
        unit: 'Packet',
        defaultPrice: 14,
        defaultMrp: 15,
        imageUrl: 'https://images.openfoodfacts.org/images/products/8901725181222/front_en.3.400.jpg'
    },

    // --- Biscuits & Snacks ---
    {
        keywords: ['parle-g', 'parle g', 'parleg', 'पारले जी'],
        category: 'Biscuits',
        name: 'Parle-G Gold Glucose Biscuits',
        unit: 'Packet',
        defaultPrice: 10,
        defaultMrp: 10,
        imageUrl: 'https://images.openfoodfacts.org/images/products/8901719101038/front_en.4.400.jpg'
    },
    {
        keywords: ['good day', 'britannia good day', 'गुड डे'],
        category: 'Biscuits',
        name: 'Britannia Good Day Butter Cookies',
        unit: 'Packet',
        defaultPrice: 20,
        defaultMrp: 20,
        imageUrl: 'https://images.openfoodfacts.org/images/products/8901063012640/front_en.8.400.jpg'
    },

    // --- Dairy & Butter ---
    {
        keywords: ['amul butter', 'butter', 'अमुल बटर', 'बटर'],
        category: 'Dairy',
        name: 'Amul Pasteurised Butter 100g',
        unit: 'Pack',
        defaultPrice: 56,
        defaultMrp: 58,
        imageUrl: 'https://images.openfoodfacts.org/images/products/8901262010054/front_en.10.400.jpg'
    },

    // --- Tea & Beverages ---
    {
        keywords: ['red label', 'brooke bond red label', 'रेड लेबल'],
        category: 'Tea & Coffee',
        name: 'Brooke Bond Red Label Tea',
        unit: 'Pack',
        defaultPrice: 130,
        defaultMrp: 140,
        imageUrl: 'https://images.openfoodfacts.org/images/products/8901030383457/front_en.14.400.jpg'
    },
    {
        keywords: ['wagh bakri', 'वाघ बकरी'],
        category: 'Tea & Coffee',
        name: 'Wagh Bakri Premium Leaf Tea',
        unit: 'Pack',
        defaultPrice: 140,
        defaultMrp: 150,
        imageUrl: 'https://images.openfoodfacts.org/images/products/8901784000045/front_en.6.400.jpg'
    },

    // --- Soaps & Personal Care ---
    {
        keywords: ['dettol soap', 'dettol', 'डेटॉल'],
        category: 'Personal Care',
        name: 'Dettol Original Bathing Soap',
        unit: 'Piece',
        defaultPrice: 38,
        defaultMrp: 40,
        imageUrl: 'https://images.openfoodfacts.org/images/products/8901396328209/front_en.4.400.jpg'
    },
    {
        keywords: ['lifebuoy', 'लाइफबॉय'],
        category: 'Personal Care',
        name: 'Lifebuoy Total Germ Protection Soap',
        unit: 'Piece',
        defaultPrice: 34,
        defaultMrp: 36,
        imageUrl: 'https://images.openfoodfacts.org/images/products/8901030678843/front_en.3.400.jpg'
    },
    {
        keywords: ['colgate', 'colgate paste', 'कोलगेट'],
        category: 'Oral Care',
        name: 'Colgate Strong Teeth Toothpaste',
        unit: 'Piece',
        defaultPrice: 60,
        defaultMrp: 65,
        imageUrl: 'https://images.openfoodfacts.org/images/products/8901314010520/front_en.8.400.jpg'
    },

    // --- Grocery Staples ---
    {
        keywords: ['sugar', 'साखर'],
        category: 'Staples',
        name: 'Madhur Pure & Hygienic Sugar',
        unit: 'Kg',
        defaultPrice: 44,
        defaultMrp: 48,
        imageUrl: 'https://images.openfoodfacts.org/images/products/8906014410014/front_en.4.400.jpg'
    },
    {
        keywords: ['tata salt', 'salt', 'मीठ'],
        category: 'Staples',
        name: 'Tata Salt Vacuum Evaporated Iodised Salt',
        unit: 'Kg',
        defaultPrice: 26,
        defaultMrp: 28,
        imageUrl: 'https://images.openfoodfacts.org/images/products/8901030012586/front_en.6.400.jpg'
    }
];

/**
 * डिक्शनरी मॅचर फंक्शन (पॉपअपमध्ये फोटो दाखवण्यासाठी)
 */
window.findProductInDictionary = function(query) {
    if (!query || query.trim().length === 0) return null;
    const clean = query.trim().toLowerCase();

    for (const item of window.MASTER_CATALOG_DICTIONARY) {
        for (const kw of item.keywords) {
            if (clean.includes(kw.toLowerCase()) || kw.toLowerCase().includes(clean)) {
                return item;
            }
        }
    }
    return null;
};

/**
 * डायनॅमिक लाइव्ह API फेचर (जर डिक्शनरीमध्ये नाव नसेल तर थेट भारतीय डेटाबेस शोधण्यासाठी)
 */
window.fetchLiveProductImage = async function(query) {
    try {
        const cleanQuery = encodeURIComponent(query.trim());
        const res = await fetch(`https://in.openfoodfacts.org/cgi/search.pl?search_terms=${cleanQuery}&search_simple=1&action=process&json=1&page_size=1`);
        const data = await res.json();
        if (data.products && data.products.length > 0) {
            const p = data.products[0];
            return p.image_front_url || p.image_url || null;
        }
    } catch (e) {
        console.warn("Live fetch error:", e);
    }
    return null;
};
