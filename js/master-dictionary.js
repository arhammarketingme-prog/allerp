/**
 * AllERP Universal Multi-Category Catalog & Fuzzy Search Engine
 * Amazon / Blinkit Level Universal Matcher (Zero Copyright Issue)
 */

// १. युनिव्हर्सल डायनॅमिक व्हेक्टर जनरेटर (कधीही न तुटणारे व्हिज्युअल्स)
const ALLERP_VECTOR_KIT = {
  mobile: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 80 120'><rect width='80' height='120' rx='10' fill='%230f172a' stroke='%23059669' stroke-width='2'/><rect x='6' y='10' width='68' height='100' rx='4' fill='%231e293b'/><circle cx='40' cy='60' r='14' fill='%23059669'/><text x='40' y='64' font-family='Arial Black' font-size='8' fill='%23ffffff' text-anchor='middle'>5G</text><text x='40' y='95' font-family='Arial' font-size='6.5' font-weight='bold' fill='%234ade80' text-anchor='middle'>SMARTPHONE</text></svg>",
  tv: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 120 100'><rect width='120' height='75' rx='6' fill='%230f172a' stroke='%2338bdf8' stroke-width='2'/><rect x='6' y='6' width='108' height='63' rx='2' fill='%231e293b'/><text x='60' y='42' font-family='Arial Black' font-size='12' fill='%2338bdf8' text-anchor='middle'>SMART TV</text><polygon points='50,75 70,75 65,90 55,90' fill='%2364748b'/><rect x='40' y='90' width='40' height='4' rx='2' fill='%23334155'/></svg>",
  watch: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 120'><rect width='100' height='120' rx='8' fill='%230f172a'/><rect x='34' y='6' width='32' height='108' rx='4' fill='%23334155'/><rect x='22' y='28' width='56' height='64' rx='12' fill='%230284c7' stroke='%2338bdf8' stroke-width='2'/><circle cx='50' cy='60' r='18' fill='%230b192c'/><text x='50' y='58' font-family='Arial Black' font-size='9' fill='%2338bdf8' text-anchor='middle'>10:24</text><text x='50' y='68' font-family='Arial' font-size='5.5' font-weight='bold' fill='%234ade80' text-anchor='middle'>SMART</text></svg>",
  oil: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 120'><rect width='100' height='120' rx='8' fill='%23ffffff' stroke='%23f59e0b' stroke-width='3'/><rect x='6' y='6' width='88' height='108' rx='6' fill='%23fffbeb'/><circle cx='50' cy='45' r='24' fill='%23fef08a' stroke='%23eab308' stroke-width='2'/><circle cx='50' cy='45' r='12' fill='%2378350f'/><text x='50' y='82' font-family='Arial Black' font-size='10' font-weight='900' fill='%23b45309' text-anchor='middle'>EDIBLE OIL</text><text x='50' y='96' font-family='Arial' font-size='7.5' font-weight='bold' fill='%2315803d' text-anchor='middle'>खाद्यतेल 1L</text></svg>",
  salt: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 120'><rect width='100' height='120' rx='6' fill='%23ffffff' stroke='%23cbd5e1' stroke-width='2'/><path d='M0 0 L100 0 L100 38 L0 38 Z' fill='%230f4c81'/><text x='50' y='24' font-family='Arial Black' font-size='13' fill='%23ffffff' text-anchor='middle'>TATA</text><text x='50' y='34' font-family='Arial' font-size='7' fill='%2393c5fd' text-anchor='middle'>SALT</text><path d='M0 38 L100 38 L100 44 L0 44 Z' fill='%23ea580c'/><circle cx='50' cy='68' r='18' fill='%23f0fdf4' stroke='%230f4c81'/><text x='50' y='72' font-family='Arial Black' font-size='11' fill='%230f4c81' text-anchor='middle'>SALT</text><text x='50' y='96' font-family='Arial' font-size='7.5' font-weight='bold' fill='%23c2410c' text-anchor='middle'>देश का नमक</text></svg>",
  clothing: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' rx='8' fill='%23f8fafc' stroke='%23cbd5e1'/><path d='M30 20 L42 28 L58 28 L70 20 L85 35 L75 45 L70 40 L70 85 L30 85 L30 40 L25 45 L15 35 Z' fill='%230284c7'/><text x='50' y='62' font-family='Arial' font-size='8' font-weight='bold' fill='%23ffffff' text-anchor='middle'>GARMENTS</text></svg>",
  soap: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' rx='10' fill='%23fce7f3' stroke='%23f43f5e' stroke-width='2'/><circle cx='50' cy='46' r='26' fill='%23ffffff'/><text x='50' y='52' font-family='Arial Black' font-size='13' font-weight='900' fill='%23e11d48' text-anchor='middle'>SOAP</text><text x='50' y='76' font-family='Arial' font-size='8' font-weight='bold' fill='%23be185d' text-anchor='middle'>BEAUTY CARE</text></svg>",
  staples: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 120'><rect width='100' height='120' rx='8' fill='%23fef3c7' stroke='%23d97706' stroke-width='2'/><text x='50' y='55' font-family='Arial Black' font-size='11' fill='%2392400e' text-anchor='middle'>GRAINS</text><text x='50' y='72' font-family='Arial' font-size='8' font-weight='bold' fill='%23b45309' text-anchor='middle'>अन्नधान्य</text></svg>",
  dairy: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' rx='8' fill='%23eff6ff' stroke='%233b82f6' stroke-width='2'/><text x='50' y='50' font-family='Arial Black' font-size='12' fill='%231d4ed8' text-anchor='middle'>DAIRY</text><text x='50' y='68' font-family='Arial' font-size='8' font-weight='bold' fill='%232563eb' text-anchor='middle'>दूध व दुग्धजन्य</text></svg>",
  stationery: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' rx='8' fill='%23f1f5f9' stroke='%2364748b' stroke-width='2'/><text x='50' y='50' font-family='Arial Black' font-size='11' fill='%23334155' text-anchor='middle'>STATIONERY</text><text x='50' y='68' font-family='Arial' font-size='8' font-weight='bold' fill='%23475569' text-anchor='middle'>पुस्तके व वह्या</text></svg>",
  hardware: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' rx='8' fill='%23fff7ed' stroke='%23ea580c' stroke-width='2'/><text x='50' y='50' font-family='Arial Black' font-size='11' fill='%23c2410c' text-anchor='middle'>HARDWARE</text><text x='50' y='68' font-family='Arial' font-size='8' font-weight='bold' fill='%23ea580c' text-anchor='middle'>हार्डवेअर व टूल्स</text></svg>"
};

// २. Amazon/Blinkit लेव्हल टोकनाइज्ड मास्टर मॅपर
function resolveUniversalProduct(rawInput) {
  if (!rawInput || rawInput.trim().length === 0) return null;
  
  const raw = rawInput.trim();
  const clean = raw.toLowerCase().replace(/[-_.]/g, ' ');
  const tokens = clean.split(/\s+/).filter(t => t.length > 0);

  let category = 'Universal Product';
  let unit = 'pcs';
  let suggestedPrice = '';
  let img = null;
  let dynamicSuggestions = [];

  // अ. खाद्यतेल व तूप
  if (tokens.some(t => ['oil', 'ghee', 'sunflower', 'gemini', 'fortune', 'dhara', 'saffola', 'soyabean', 'mustard', 'शेंगदाणा', 'तेल', 'तूप'].includes(t))) {
    category = 'खाद्यतेल व तूप (Edible Oil & Ghee)';
    unit = 'ltr';
    suggestedPrice = '135';
    img = ALLERP_VECTOR_KIT.oil;

    dynamicSuggestions.push({ name: `${raw} 1 Litre Pouch`, cat: category, unit: 'ltr', price: 135, img: img });
    dynamicSuggestions.push({ name: `${raw} 5 Litre Jar`, cat: category, unit: 'ltr', price: 680, img: img });
    dynamicSuggestions.push({ name: `${raw} 15kg / 15L Tin`, cat: category, unit: 'ltr', price: 2150, img: img });
  }
  // ब. स्मार्टफोन व मोबाईल
  else if (tokens.some(t => ['oppo', 'vivo', 'realme', 'samsung', 'iphone', 'redmi', 'oneplus', 'xiaomi', 'phone', 'mobil', 'mobille', 'मोबाईल'].includes(t))) {
    category = 'इलेक्ट्रॉनिक्स (Smartphones)';
    unit = 'pcs';
    suggestedPrice = '14999';
    img = ALLERP_VECTOR_KIT.mobile;

    let bName = 'Smartphone';
    if (clean.includes('oppo')) bName = 'Oppo';
    else if (clean.includes('vivo')) bName = 'Vivo';
    else if (clean.includes('samsung')) bName = 'Samsung';
    else if (clean.includes('realme')) bName = 'Realme';

    dynamicSuggestions.push({ name: `${bName} A78 5G (8GB/128GB)`, cat: category, unit: 'pcs', price: 17499, img: img });
    dynamicSuggestions.push({ name: `${bName} Reno 11 Pro 5G`, cat: category, unit: 'pcs', price: 37999, img: img });
    dynamicSuggestions.push({ name: `${bName} A18 (4GB/64GB)`, cat: category, unit: 'pcs', price: 9999, img: img });
    dynamicSuggestions.push({ name: `${bName} 5G Smartphone Standard`, cat: category, unit: 'pcs', price: 13999, img: img });
  }
  // क. टीव्ही व मॉनिटर्स
  else if (tokens.some(t => ['tv', 'television', 'led', 'oled', 'screen', 'monitor'].includes(t))) {
    category = 'इलेक्ट्रॉनिक्स (Smart TV)';
    unit = 'pcs';
    suggestedPrice = '24990';
    img = ALLERP_VECTOR_KIT.tv;

    dynamicSuggestions.push({ name: `${raw} 43 Inch 4K Ultra HD Smart TV`, cat: category, unit: 'pcs', price: 26990, img: img });
    dynamicSuggestions.push({ name: `${raw} 32 Inch HD Ready Smart LED`, cat: category, unit: 'pcs', price: 13990, img: img });
  }
  // ड. स्मार्ट वॉच व घड्याळ
  else if (tokens.some(t => ['watch', 'smartwatch', 'band', 'घड्याळ'].includes(t))) {
    category = 'इलेक्ट्रॉनिक्स (Wearables)';
    unit = 'pcs';
    suggestedPrice = '1499';
    img = ALLERP_VECTOR_KIT.watch;

    dynamicSuggestions.push({ name: `${raw} Bluetooth Calling Smartwatch`, cat: category, unit: 'pcs', price: 1999, img: img });
    dynamicSuggestions.push({ name: `${raw} Fitness Band Health Tracker`, cat: category, unit: 'pcs', price: 1299, img: img });
  }
  // इ. कपडे व गारमेंट्स
  else if (tokens.some(t => ['shirt', 'pant', 'saree', 'jeans', 'tshirt', 'dress', 'cloth', 'कपडे'].includes(t))) {
    category = 'कपडे व फॅशन (Garments)';
    unit = 'pcs';
    suggestedPrice = '699';
    img = ALLERP_VECTOR_KIT.clothing;

    dynamicSuggestions.push({ name: `${raw} Men's Cotton Formal Wear`, cat: category, unit: 'pcs', price: 799, img: img });
    dynamicSuggestions.push({ name: `${raw} Slim Fit Premium`, cat: category, unit: 'pcs', price: 999, img: img });
  }
  // फ. अन्नधान्य, साखर, मीठ, डाळी
  else if (tokens.some(t => ['salt', 'solt', 'namak', 'sugar', 'rice', 'wheat', 'atta', 'dal', 'मीठ', 'साखर', 'तांदूळ', 'गहू', 'डाळ'].includes(t))) {
    category = 'अन्नधान्य व किराणा (Staples)';
    unit = 'kg';
    suggestedPrice = clean.includes('salt') ? '28' : '45';
    img = clean.includes('salt') ? ALLERP_VECTOR_KIT.salt : ALLERP_VECTOR_KIT.staples;

    dynamicSuggestions.push({ name: `${raw} 1kg Fresh Pack`, cat: category, unit: 'kg', price: suggestedPrice, img: img });
    dynamicSuggestions.push({ name: `${raw} 5kg Premium Pack`, cat: category, unit: 'kg', price: (Number(suggestedPrice)*5), img: img });
    dynamicSuggestions.push({ name: `${raw} 25kg/30kg बोरी (Bag)`, cat: category, unit: 'bag', price: (Number(suggestedPrice)*25), img: img });
  }
  // ग. साबण व वैयक्तिक स्वच्छता
  else if (tokens.some(t => ['soap', 'lux', 'dettol', 'lifebuoy', 'godrej', 'cinthol', 'साबण'].includes(t))) {
    category = 'वैयक्तिक स्वच्छता (Personal Soap)';
    unit = 'packet';
    suggestedPrice = '40';
    img = ALLERP_VECTOR_KIT.soap;

    dynamicSuggestions.push({ name: `${raw} Single Bar`, cat: category, unit: 'pcs', price: 38, img: img });
    dynamicSuggestions.push({ name: `${raw} Multipack (Pack of 4)`, cat: category, unit: 'packet', price: 135, img: img });
  }
  // ह. स्टेशनरी
  else if (tokens.some(t => ['book', 'notebook', 'pen', 'pencil', 'classmate', 'वही', 'पेन'].includes(t))) {
    category = 'स्टेशनरी व शैक्षणिक (Stationery)';
    unit = 'pcs';
    suggestedPrice = '40';
    img = ALLERP_VECTOR_KIT.stationery;

    dynamicSuggestions.push({ name: `${raw} Single Unit`, cat: category, unit: 'pcs', price: 40, img: img });
    dynamicSuggestions.push({ name: `${raw} Bundle (Pack of 6)`, cat: category, unit: 'packet', price: 220, img: img });
  }
  // य. हार्डवेअर व बांधकाम
  else if (tokens.some(t => ['cement', 'pipe', 'paint', 'wire', 'सिमेंट', 'रंग'].includes(t))) {
    category = 'हार्डवेअर व बांधकाम (Hardware)';
    unit = clean.includes('cement') ? 'bag' : 'pcs';
    suggestedPrice = clean.includes('cement') ? '380' : '150';
    img = ALLERP_VECTOR_KIT.hardware;

    dynamicSuggestions.push({ name: `${raw} Standard Pack`, cat: category, unit: unit, price: suggestedPrice, img: img });
  }
  // र. जगातील इतर कोणत्याही ब्रँडसाठी डायनॅमिक
  else {
    category = 'Universal Retail';
    unit = 'pcs';
    img = `data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' rx='8' fill='%231D4E89'/><text x='50' y='55' font-family='Arial,sans-serif' font-size='9' font-weight='bold' fill='%23ffffff' text-anchor='middle'>${encodeURIComponent(raw.substring(0, 14).toUpperCase())}</text></svg>`;
    dynamicSuggestions.push({ name: `${raw} Standard Pack`, cat: category, unit: unit, price: '', img: img });
  }

  return { rawName: raw, category, unit, price: suggestedPrice, img, suggestions: dynamicSuggestions };
}
