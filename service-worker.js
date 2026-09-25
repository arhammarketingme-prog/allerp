// Service Worker for ALL ERP PWA WebAPK
const CACHE_NAME = 'allerp-core-v3';
const ASSETS_TO_CACHE = [
  './index.html',
  './dashboard.html',
  './manifest.json',
  './css/style.css',
  './js/supabase-client.js',
  './js/erp-engine.js',
  './js/cart.js',
  './js/nav.js',
  './js/tracking.js'
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE);
    }).catch(() => {})
  );
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      );
    })
  );
  e.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);

  // Supabase API कॉल्सना कॅश करू नये
  if (url.hostname.includes('supabase.co') || e.request.method !== 'GET') {
    return;
  }

  e.respondWith(
    fetch(e.request)
      .then((res) => {
        if (res && res.status === 200 && url.origin === self.location.origin) {
          const resClone = res.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(e.request, resClone));
        }
        return res;
      })
      .catch(() => caches.match(e.request))
  );
});
