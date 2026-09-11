// Service Worker for ALL ERP PWA Offline Capabilities
const CACHE_NAME = 'allerp-cache-v2';
const ASSETS_TO_CACHE = [
  'index.html',
  'dashboard.html',
  'css/style.css',
  'js/supabase-client.js',
  'js/erp-engine.js',
  'js/cart.js',
  'js/nav.js',
  'js/ads.js',
  'manifest.json'
];

self.addEventListener('install', (e) => {
  // ⚠️ आधी हे install इव्हेंटमध्ये कधीच cache भरत नव्हतं — फक्त skipWaiting()
  // होतं. त्यामुळे नंतरचा fetch fallback (caches.match) कायम रिकामाच सापडायचा,
  // म्हणजे ऑफलाईन काम अजिबात होत नव्हतं. आता खरं cache भरतो.
  e.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS_TO_CACHE)).catch(() => {})
  );
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  // जुन्या कॅशची स्वच्छता
  e.waitUntil(
    caches.keys().then((names) =>
      Promise.all(names.filter((n) => n !== CACHE_NAME).map((n) => caches.delete(n)))
    )
  );
  e.waitUntil(clients.claim());
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);

  // Supabase API कॉल्स (डेटा/ऑथ) कधीच cache करू नयेत — नेहमी थेट नेटवर्कवरच
  if (url.hostname.includes('supabase.co') || e.request.method !== 'GET') {
    return; // सामान्य नेटवर्क वर्तन — service worker मध्ये हस्तक्षेप करत नाही
  }

  // बाकी (आपल्याच साईटच्या) स्टॅटिक फाईल्ससाठी: नेटवर्क आधी, अयशस्वी झालं
  // (ऑफलाईन) तरच cache मधून द्यायचं — म्हणजे नवीन बदल नेहमी आधी दिसतील,
  // आणि नेट नसतानाही किमान app-shell उघडेल.
  e.respondWith(
    fetch(e.request)
      .then((response) => {
        if (response && response.status === 200 && url.origin === self.location.origin) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(e.request, clone));
        }
        return response;
      })
      .catch(() => caches.match(e.request))
  );
});
