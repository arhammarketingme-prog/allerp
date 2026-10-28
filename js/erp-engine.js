/**
 * AllERP - Core ERP & Visual Auto-Mapper Engine
 * मूळ डॅशबोर्ड डिझाइनला धक्का न लावता फक्त इमेज व माहिती अचूक मॅप करणारी फाईल
 */

(function () {
  // १. अस्सल अधिकृत व्हेक्टर पॅकेट्स (कधीही न तुटणारे)
  const MASTER_PACKS = {
    bisleri: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 90 120'><rect width='90' height='120' rx='8' fill='%23ffffff' stroke='%23059669' stroke-width='2'/><path d='M35 15 L55 15 L55 25 L65 35 L65 105 L25 105 L25 35 L35 25 Z' fill='%23e0f2fe' stroke='%230284c7' stroke-width='1.5'/><rect x='38' y='8' width='14' height='8' rx='2' fill='%23059669'/><rect x='25' y='52' width='40' height='28' fill='%23059669'/><text x='45' y='68' font-family='Arial Black,sans-serif' font-size='8' font-weight='900' fill='%23ffffff' text-anchor='middle'>Bisleri</text><text x='45' y='76' font-family='Arial,sans-serif' font-size='5' fill='%23ecfdf5' text-anchor='middle'>with minerals</text><text x='45' y='114' font-family='Arial,sans-serif' font-size='7' font-weight='bold' fill='%23065f46' text-anchor='middle'>1 LITRE</text></svg>",
    salt: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 120'><rect width='100' height='120' rx='8' fill='%23ffffff' stroke='%230284c7' stroke-width='3'/><rect x='6' y='6' width='88' height='40' rx='4' fill='%230284c7'/><text x='50' y='32' font-family='Arial Black,sans-serif' font-size='14' font-weight='900' fill='%23ffffff' text-anchor='middle'>TATA</text><circle cx='50' cy='65' r='18' fill='%23e0f2fe'/><text x='50' y='70' font-family='Arial Black,sans-serif' font-size='13' font-weight='900' fill='%230369a1' text-anchor='middle'>SALT</text><text x='50' y='92' font-family='Arial,sans-serif' font-size='8' font-weight='bold' fill='%23b91c1c' text-anchor='middle'>DESH KA NAMAK</text><text x='50' y='106' font-family='Arial,sans-serif' font-size='7' fill='%23334155' text-anchor='middle'>Vacuum Evaporated 1kg</text></svg>",
    gemini: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 120'><rect width='100' height='120' rx='8' fill='%23ffffff' stroke='%23f59e0b' stroke-width='3'/><rect x='6' y='6' width='88' height='108' rx='6' fill='%23fffbeb'/><circle cx='50' cy='45' r='24' fill='%23fef08a' stroke='%23eab308' stroke-width='2'/><path d='M50 25 C45 35 55 35 50 25 Z' fill='%23f59e0b'/><path d='M50 65 C45 55 55 55 50 65 Z' fill='%23f59e0b'/><path d='M30 45 C40 40 40 50 30 45 Z' fill='%23f59e0b'/><path d='M70 45 C60 40 60 50 70 45 Z' fill='%23f59e0b'/><circle cx='50' cy='45' r='12' fill='%2378350f'/><text x='50' y='82' font-family='Arial,sans-serif' font-size='11' font-weight='900' fill='%23b45309' text-anchor='middle'>GEMINI</text><text x='50' y='94' font-family='Arial,sans-serif' font-size='8' font-weight='bold' fill='%2315803d' text-anchor='middle'>SUNFLOWER OIL</text><text x='50' y='105' font-family='Arial,sans-serif' font-size='7' fill='%23334155' text-anchor='middle'>1 Ltr Pouch</text></svg>",
    parle: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 120 90'><rect width='120' height='90' rx='6' fill='%23fef08a' stroke='%23ca8a04' stroke-width='2'/><rect x='5' y='5' width='110' height='80' rx='4' fill='%23fef9c3'/><rect x='10' y='22' width='100' height='28' rx='4' fill='%23dc2626'/><text x='60' y='42' font-family='Arial Black,sans-serif' font-size='18' font-weight='900' fill='%23ffffff' text-anchor='middle'>Parle-G</text><text x='60' y='64' font-family='Arial,sans-serif' font-size='9' font-weight='bold' fill='%23854d0e' text-anchor='middle'>GLUCOSE BISCUITS</text><text x='60' y='76' font-family='Arial,sans-serif' font-size='8' font-weight='bold' fill='%2315803d' text-anchor='middle'>ORIGINAL TASTE</text></svg>",
    maggi: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' rx='10' fill='%23facc15'/><rect x='6' y='6' width='88' height='88' rx='6' fill='%23eab308'/><circle cx='50' cy='48' r='30' fill='%23dc2626'/><text x='50' y='54' font-family='Arial Black,sans-serif' font-size='16' font-weight='900' fill='%23fef08a' text-anchor='middle'>Maggi</text><text x='50' y='76' font-family='Arial,sans-serif' font-size='8' font-weight='bold' fill='%2378350f' text-anchor='middle'>2-MINUTE NOODLES</text></svg>",
    classmate: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' rx='10' fill='%230284c7'/><rect x='45' y='15' width='10' height='60' rx='3' fill='%23ffffff'/><polygon points='45,75 55,75 50,88' fill='%2394a3b8'/><text x='50' y='52' font-family='Arial,sans-serif' font-size='6' font-weight='bold' fill='%230284c7' text-anchor='middle' transform='rotate(90 50 52)'>classmate</text></svg>"
  };

  // २. स्मार्ट मॅचिंग फंक्शन
  function getAutoMapData(query) {
    const clean = query.toLowerCase().replace(/[-_.]/g, ' ');

    if (clean.includes('bisleri') || clean.includes('water') || clean.includes('बिसलेरी')) {
      return { img: MASTER_PACKS.bisleri, cat: 'Beverages / Water', unit: 'Bottle', price: 20, mrp: 20 };
    }
    if (clean.includes('salt') || clean.includes('solt') || clean.includes('namak') || (clean.includes('tata') && (clean.includes('sa') || clean.includes('so')))) {
      return { img: MASTER_PACKS.salt, cat: 'Staples (मीठ)', unit: 'Kg', price: 28, mrp: 28 };
    }
    if (clean.includes('parle')) {
      return { img: MASTER_PACKS.parle, cat: 'Biscuits', unit: 'Packet', price: 10, mrp: 10 };
    }
    if (clean.includes('gemini') || (clean.includes('sunflower') && clean.includes('oil'))) {
      return { img: MASTER_PACKS.gemini, cat: 'Cooking Oil', unit: 'Liter', price: 135, mrp: 145 };
    }
    if (clean.includes('maggi') || clean.includes('maggie')) {
      return { img: MASTER_PACKS.maggi, cat: 'Instant Food', unit: 'Packet', price: 14, mrp: 14 };
    }
    if (clean.includes('classmate') || clean.includes('pen')) {
      return { img: MASTER_PACKS.classmate, cat: 'Stationery', unit: 'Piece', price: 10, mrp: 10 };
    }

    const text = encodeURIComponent(query.substring(0, 14).toUpperCase());
    return {
      img: `data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' rx='10' fill='%230284c7'/><text x='50' y='55' font-family='Arial,sans-serif' font-size='10' font-weight='bold' fill='%23ffffff' text-anchor='middle'>${text}</text></svg>`,
      cat: 'Universal Product',
      unit: 'Piece',
      price: null,
      mrp: null
    };
  }

  // ३. मूळ डॅशबोर्डच्या इनपुटला हुक करणे
  function attachAutoMapper() {
    const inputEl = document.querySelector('input[placeholder*="Turmeric Powder"], input[name="product_name"], #product_name');
    if (!inputEl || inputEl.dataset.mapperAttached) return;

    inputEl.dataset.mapperAttached = "true";

    inputEl.addEventListener('input', function (e) {
      const q = e.target.value.trim();
      if (q.length < 2) return;

      const data = getAutoMapData(q);

      // मूळ ऑटो-मॅप कंटेनर शोधणे
      const allDivs = document.querySelectorAll('div');
      for (const div of allDivs) {
        if (div.textContent && div.textContent.includes('Auto-Mapped') && div.querySelector('img')) {
          const imgTag = div.querySelector('img');
          imgTag.src = data.img;
          imgTag.style.width = '65px';
          imgTag.style.height = '65px';
          imgTag.style.objectFit = 'contain';

          // कॅटेगरी टेक्स्ट बदलणे
          const textNodes = div.querySelectorAll('span, div');
          textNodes.forEach(t => {
            if (t.innerText && t.innerText.includes('Auto-Mapped')) {
              t.innerText = `✨ Auto-Mapped (${data.cat})`;
            }
          });
          break;
        }
      }

      // युनिट, दर आणि एमआरपी ऑटो-फिल
      const unitEl = document.querySelector('select[name="unit"], #unit');
      const priceEl = document.querySelector('input[placeholder*="विक्री दर"], input[name="price"], #price');
      const mrpEl = document.querySelector('input[placeholder*="MRP"], input[name="mrp"], #mrp');

      if (unitEl && data.unit) unitEl.value = data.unit;
      if (priceEl && data.price && !priceEl.value) priceEl.value = data.price;
      if (mrpEl && data.mrp && !mrpEl.value) mrpEl.value = data.mrp;
    });
  }

  document.addEventListener('DOMContentLoaded', attachAutoMapper);
  document.addEventListener('click', function () {
    setTimeout(attachAutoMapper, 400);
  });
})();
