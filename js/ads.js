// ==========================================
// ALL ERP - Advanced Multi-Format Ad & Story Engine
// ==========================================

const DEFAULT_LOCAL_PROMO_ADS = [
  {
    id: 'promo-top',
    is_house_ad: true,
    ad_type: 'banner',
    placement: 'top',
    media_url: 'https://placehold.co/1200x120/2874f0/FFFFFF?text=%F0%9F%9A%80+%E0%A4%86%E0%A4%AA%E0%A4%B2%E0%A5%8D%E0%A4%AF%E0%A4%BE+%E0%A4%B8%E0%A5%8D%E0%A4%A5%E0%A4%BE%E0%A4%A8%E0%A4%BF%E0%A4%95+%E0%A4%B5%E0%A5%8D%E0%A4%AF%E0%A4%B5%E0%A4%B8%E0%A4%BE%E0%A4%AF%E0%A4%BE%E0%A4%9A%E0%A5%80+%E0%A4%9C%E0%A4%BE%E0%A4%B9%E0%A4%BF%E0%A4%B0%E0%A4%BE%E0%A4%A4+%E0%A4%A6%E0%A5%8D%E0%A4%AF%E0%A4%BE+-+%E0%A4%AB%E0%A4%95%E0%A5%8D%E0%A4%A4+%E2%82%B9%E0%A5%AF%E0%A5%AF+%E0%A4%AA%E0%A4%BE%E0%A4%B8%E0%A5%82%E0%A4%A8',
    target_url: 'advertiser.html'
  },
  {
    id: 'promo-left',
    is_house_ad: true,
    ad_type: 'image',
    placement: 'left',
    media_url: 'https://placehold.co/300x500/ff6b35/FFFFFF?text=%F0%9F%93%A2+%E0%A4%B8%E0%A5%8D%E0%A4%AA%E0%A4%B9%E0%A5%80%E0%A4%A8+%E0%A4%9C%E0%A4%BE%E0%A4%B9%E0%A4%BF%E0%A4%B0%E0%A4%BE%E0%A4%A4',
    target_url: 'advertiser.html'
  },
  {
    id: 'promo-right',
    is_house_ad: true,
    ad_type: 'image',
    placement: 'right',
    media_url: 'https://placehold.co/300x500/16a34a/FFFFFF?text=%E2%AD%90+%E0%A4%AB%E0%A4%BF%E0%A4%9A%E0%A4%B0%E0%A5%8D%E0%A4%A1+%E0%A4%AC%E0%A5%8D%E0%A4%B0%E0%A5%85%E0%A4%82%E0%A4%A1%E0%A4%BF%E0%A4%82%E0%A4%97',
    target_url: 'advertiser.html'
  },
  {
    id: 'promo-bottom',
    is_house_ad: true,
    ad_type: 'banner',
    placement: 'bottom',
    media_url: 'https://placehold.co/1200x120/4f46e5/FFFFFF?text=%F0%9F%8F%AA+%E0%A4%A6%E0%A5%81%E0%A4%95%E0%A4%BE%E0%A4%A8%E0%A4%A6%E0%A4%BE%E0%A4%B0%E0%A4%82%E0%A4%B8%E0%A4%BE%E0%A4%A0%E0%A5%80+%E0%A5%A6%25+%E0%A4%95%E0%A4%AE%E0%A4%BF%E0%A4%B6%E0%A4%A8',
    target_url: 'advertiser.html'
  }
];

let activeAdsList = [];
let activeSlotsConfig = [];
let adRotationInterval = null;
let currentRotationStep = 0;

// Auto-cleanup expired ads — आता एका विश्वासार्ह server-side RPC मार्फत
// (आधीचा थेट-टेबल-कोड अनोळखी ग्राहकांसाठी RLS मुळे कधीच चालत नव्हता)
async function autoCleanupExpiredAds() {
  try {
    const { data: cleaned } = await sb.rpc('cleanup_expired_ads');
    if (cleaned && cleaned.length > 0) {
      for (const item of cleaned) {
        if (item.media_url && item.media_url.includes('ads-media')) {
          try {
            const urlParts = item.media_url.split('/ads-media/');
            if (urlParts.length > 1) {
              const storagePath = decodeURIComponent(urlParts[1].split('?')[0]);
              await sb.storage.from('ads-media').remove([storagePath]);
            }
          } catch (e) {}
        }
      }
    }
  } catch (err) {}
}

// 🔑 प्रत्येक ब्राउझर सेशनसाठी एक ओळख — click-fraud dedup आणि frequency
// cap साठी (हे tamper-proof नाही, पण सामान्य वापरात परिणामकारक आहे)
function getAdSessionKey() {
  let key = localStorage.getItem('allerp_ad_session');
  if (!key) {
    key = 'sess_' + Math.random().toString(36).slice(2) + Date.now();
    localStorage.setItem('allerp_ad_session', key);
  }
  return key;
}

// 📊 आजच्या दिवशी या जाहिरातीला किती वेळा दाखवलं (frequency cap साठी)
function getTodayImpressionCount(adId) {
  const key = `allerp_ad_freq_${adId}_${new Date().toISOString().slice(0, 10)}`;
  return Number(localStorage.getItem(key) || 0);
}
function bumpTodayImpressionCount(adId) {
  const key = `allerp_ad_freq_${adId}_${new Date().toISOString().slice(0, 10)}`;
  localStorage.setItem(key, String(getTodayImpressionCount(adId) + 1));
}

// Fetch active ads (आता eligible_advertisements व्ह्यू वापरतो — यात
// impressions_served < impressions_budget हा चेक आधीच असतो, त्यामुळे
// बजेट संपलेली जाहिरात कधीच परत मिळणार नाही)
async function fetchEligibleAds() {
  await autoCleanupExpiredAds();

  try {
    const { data: ads, error } = await sb
      .from('eligible_advertisements')
      .select('*');

    if (!error && ads && ads.length > 0) {
      // 🎯 Location targeting: ज्या जाहिरातींना target_location सेट आहे,
      // त्या फक्त ग्राहकाने निवडलेल्या शहराशी जुळल्या तरच दाखवायच्या.
      // target_location रिकामं/null असेल तर ती सर्वत्र दाखवली जाते.
      const customerCity = (typeof getCustomerCity === 'function' ? getCustomerCity() : '').toLowerCase().trim();
      const locationFiltered = ads.filter(a =>
        !a.target_location || !customerCity || a.target_location.toLowerCase().includes(customerCity)
      );
      const adsToUse = locationFiltered.length > 0 ? locationFiltered : ads;

      // frequency cap: आजच्या मर्यादेपेक्षा जास्त वेळा दाखवलेल्या जाहिराती वगळणे
      const withinCap = adsToUse.filter(a =>
        getTodayImpressionCount(a.id) < (a.frequency_cap_per_user_per_day || 5)
      );
      const pool = withinCap.length > 0 ? withinCap : adsToUse;

      for (let i = pool.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [pool[i], pool[j]] = [pool[j], pool[i]];
      }
      activeAdsList = pool;
      return activeAdsList;
    }
  } catch (e) {}

  activeAdsList = [...DEFAULT_LOCAL_PROMO_ADS];
  return activeAdsList;
}

// Select ad for slot
function selectAdForSlot(ads, placement, usedAdIds, stepOffset) {
  if (!ads || ads.length === 0) return null;
  const rotatedAds = ads.slice(stepOffset % ads.length).concat(ads.slice(0, stepOffset % ads.length));

  let candidate = rotatedAds.find(a => !usedAdIds.has(a.id) && (a.placement === placement));
  if (candidate) return candidate;

  candidate = rotatedAds.find(a => !usedAdIds.has(a.id));
  return candidate || rotatedAds[0];
}

// Render Ad Slots with Rotation
function updateAdSlotsVisual(step = 0) {
  if (!activeAdsList || activeAdsList.length === 0) return;
  const today = new Date().toISOString().slice(0, 10);
  const usedAdIds = new Set();

  activeSlotsConfig.forEach((slot, idx) => {
    const container = document.getElementById(slot.id);
    if (!container) return;

    const ad = selectAdForSlot(activeAdsList, slot.placement, usedAdIds, step + idx);
    if (!ad) {
      container.style.display = 'none';
      return;
    }

    usedAdIds.add(ad.id);
    container.style.display = 'block';
    container.style.transition = 'opacity 0.4s ease-in-out';
    container.style.opacity = '0.7';

    // 🎯 fallback क्रम: स्थानिक/पेड जाहिरात असेल तर तीच नेहमी प्राधान्याने
    // दिसते. ती नसेल (house/self-promo ad निवडला गेला असेल) आणि Google
    // AdSense configure केलेलं असेल, तरच त्या जागी Google ची जाहिरात
    // दाखवतो — नसेल configure तर आधीसारखी self-promo जाहिरात दिसत राहते.
    const useAdSense = ad.is_house_ad && isAdSenseConfigured();
    const adSenseHtml = useAdSense ? renderAdSenseSlot(slot.placement) : null;

    setTimeout(() => {
      if (adSenseHtml) {
        container.innerHTML = `<div class="ad-slot-inner">${adSenseHtml}</div>`;
        container.style.opacity = '1';
        triggerAdSenseLoad();
        return; // Google जाहिरातीचे impression/click Google स्वतः मोजतो — आपल्या RPC ची गरज नाही
      }

      container.innerHTML = `
        <div class="ad-slot-inner">
          <a href="${ad.target_url || '#'}" target="_blank" rel="noopener" id="ad-link-${ad.id}-${slot.id}" style="display:block; text-decoration:none">
            ${renderAdMedia(ad, slot.placement)}
          </a>
          <div style="font-size:10px; color:var(--muted); margin-top:2px; text-align:center; font-weight:700;">✨ Sponsored Local Ad</div>
        </div>
      `;
      container.style.opacity = '1';

      sb.rpc('record_ad_impression', { p_advertisement_id: ad.id, p_placement: slot.placement || 'unknown' });
      bumpTodayImpressionCount(ad.id);

      const linkEl = document.getElementById(`ad-link-${ad.id}-${slot.id}`);
      if (linkEl) {
        linkEl.addEventListener('click', async () => {
          await sb.rpc('record_ad_click', { p_advertisement_id: ad.id, p_session_key: getAdSessionKey() });
        });
      }
    }, 150);
  });
}

// ==========================================
// Google AdSense — Fallback जाहिराती (स्थानिक जाहिरात उपलब्ध नसेल तेव्हाच)
// ==========================================
// ⚠️ हे फक्त "provision" आहे — आत्ता खरी Google जाहिरात दिसणार नाही, कारण
// domain अजून .com/.in नाही आणि AdSense अकाउंट अजून approve झालेलं नाही.
// approve झाल्यावर खालच्या दोन गोष्टी भराव्या लागतील (बाकी सगळं आपोआप काम
// करेल — कोड बदलावा लागणार नाही):
//   1. GOOGLE_ADSENSE_CLIENT_ID — "ca-pub-XXXXXXXXXXXXXXXX" (AdSense कडून मिळेल)
//   2. GOOGLE_ADSENSE_SLOT_IDS — प्रत्येक जागेसाठी Ad Unit ID (AdSense मध्ये
//      "Ad units" बनवून मिळेल)
const GOOGLE_ADSENSE_CLIENT_ID = 'ca-pub-0000000000000000'; // placeholder
const GOOGLE_ADSENSE_SLOT_IDS = {
  top: '0000000000',
  left: '0000000000',
  right: '0000000000',
  bottom: '0000000000'
};

function isAdSenseConfigured() {
  return GOOGLE_ADSENSE_CLIENT_ID && !GOOGLE_ADSENSE_CLIENT_ID.includes('0000000000000000');
}

// AdSense चा स्क्रिप्ट फक्त खरी Client ID सेट झाल्यावरच लोड होतो — नाहीतर
// placeholder ID मुळे उगाच ब्राउझर कन्सोलमध्ये त्रुटी येत राहतील
if (isAdSenseConfigured() && !document.querySelector('script[src*="adsbygoogle.js"]')) {
  const s = document.createElement('script');
  s.async = true;
  s.src = `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${GOOGLE_ADSENSE_CLIENT_ID}`;
  s.crossOrigin = 'anonymous';
  document.head.appendChild(s);
}

function renderAdSenseSlot(placement) {
  const slotId = GOOGLE_ADSENSE_SLOT_IDS[placement];
  if (!slotId || slotId.includes('0000000000')) return null; // हा placement अजून configure झालेला नाही
  return `
    <ins class="adsbygoogle" style="display:block" data-ad-client="${GOOGLE_ADSENSE_CLIENT_ID}" data-ad-slot="${slotId}" data-ad-format="auto" data-full-width-responsive="true"></ins>
    <div style="font-size:9.5px; color:var(--muted); margin-top:2px; text-align:center;">Advertisement</div>
  `;
}

function triggerAdSenseLoad() {
  try { (window.adsbygoogle = window.adsbygoogle || []).push({}); } catch (e) {}
}

// 🛒 Sponsored Products — search/product-grid मध्ये थेट मिसळण्यासाठी
// (Amazon/Flipkart च्या "Sponsored" टाइल्ससारखं)
async function fetchSponsoredProducts(limit = 2) {
  try {
    const { data, error } = await sb.from('eligible_sponsored_products').select('*');
    if (error || !data || data.length === 0) return [];

    const customerCity = (typeof getCustomerCity === 'function' ? getCustomerCity() : '').toLowerCase().trim();
    const locationFiltered = data.filter(p =>
      !p.target_location || !customerCity || p.target_location.toLowerCase().includes(customerCity)
    );
    const pool = locationFiltered.length > 0 ? locationFiltered : data;

    for (let i = pool.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [pool[i], pool[j]] = [pool[j], pool[i]];
    }

    const picked = pool.slice(0, limit);
    picked.forEach(p => {
      sb.rpc('record_ad_impression', { p_advertisement_id: p.advertisement_id, p_placement: 'search_results' });
    });
    return picked;
  } catch (e) {
    return [];
  }
}

async function recordSponsoredProductClick(advertisementId) {
  await sb.rpc('record_ad_click', { p_advertisement_id: advertisementId, p_session_key: getAdSessionKey() });
}

async function renderMultiAdSlots(slots, rotationIntervalSeconds = 10) {
  activeSlotsConfig = slots;
  await fetchEligibleAds();

  if (!activeAdsList || activeAdsList.length === 0) {
    slots.forEach(s => {
      const el = document.getElementById(s.id);
      if (el) el.style.display = 'none';
    });
    return;
  }

  updateAdSlotsVisual(0);

  if (adRotationInterval) clearInterval(adRotationInterval);
  if (activeAdsList.length > 1) {
    adRotationInterval = setInterval(() => {
      currentRotationStep++;
      updateAdSlotsVisual(currentRotationStep);
    }, rotationIntervalSeconds * 1000);
  }
}

function renderAdMedia(ad, placement) {
  if (!ad.media_url) return `<div class="card" style="text-align:center; color:var(--muted); padding:16px">Sponsored Ad</div>`;
  const isSidebar = placement === 'left' || placement === 'right' || placement === 'sidebar';
  const customClass = isSidebar ? 'ad-media ad-media-side' : 'ad-media';

  switch (ad.ad_type) {
    case 'video':
      return `<video src="${ad.media_url}" autoplay muted loop playsinline controls class="${customClass}" style="display:block; width:100%; height:auto; border-radius:8px;"></video>`;
    case 'audio':
      return `<div style="text-align:center; padding:10px; background:#f0f5ff; border-radius:8px;"><audio src="${ad.media_url}" controls style="width:100%"></audio></div>`;
    default:
      return `<img src="${ad.media_url}" alt="Advertisement" class="${customClass}" style="width:100%; height:100%; object-fit:contain; border-radius:8px;">`;
  }
}
