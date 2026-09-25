// Service Worker for ALL ERP PWA WebAPK (Version 4)
// बदल केल्यावर version वाढवले आहे (v4) — जुना कॅश साफ होऊन नवीन Google लॉगिन लगेच सक्रिय होईल.

const CACHE_NAME = 'allerp-core-v4';
const ASSETS_TO_CACHE = [
  './index.html',
  './dashboard.html',
  './store.html',
  './manifest.json',
  './css/style.css',
  './js/supabase-client.js',
  './js/erp-engine.js',
  './js/cart.js',
  './js/nav.js',
  './js/tracking.js',
  './icon-192.png',
  './icon-512.png'
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE);
    }).catch(() => {})
  );
  self.skipWaiting(); // नवीन service worker लगेच सक्रिय करतो
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      );
    })
  );
  e.waitUntil(self.clients.claim()); // उघडलेल्या सर्व पानांवर नवीन कोड लागू करतो
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);

  // Supabase API कॉल्स किंवा बाहेरील डेटा कॅश करू नये
  if (url.hostname.includes('supabase.co') || e.request.method !== 'GET') {
    return;
  }

  // नेटवर्क-फर्स्ट रणनीती: नेट असेल तेव्हा नेहमी ताजी फाईल आणणे
  e.respondWith(
    fetch(e.request)
      .then((res) => {
        if (res && res.status === 200 && url.origin === self.location.origin) {
          const resClone = res.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(e.request, resClone));
        }
        return res;
      })
      .catch(() => caches.match(e.request)) // नेट बंद असेल तरच कॅशमधून चालवा
  );
});
