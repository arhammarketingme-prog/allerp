// ALL ERP PWA — install as a real app (Android/Chrome/Edge supported where available)
(function () {
  'use strict';
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('./service-worker.js', { scope: './' }).catch(function (err) {
        console.warn('ALL ERP service worker registration failed:', err);
      });
    });
  }

  let deferredPrompt = null;
  const installKey = 'allerp-install-dismissed';

  function makeInstallUI() {
    if (document.getElementById('allerp-install-banner')) return;
    const banner = document.createElement('div');
    banner.id = 'allerp-install-banner';
    banner.innerHTML = `
      <div class="allerp-install-card" role="dialog" aria-label="Install ALL ERP app">
        <div class="allerp-install-icon">A</div>
        <div class="allerp-install-copy">
          <strong>Install ALL ERP</strong>
          <span>Use ALL ERP like a real app — faster access from your home screen.</span>
        </div>
        <button type="button" id="allerp-install-btn">Install</button>
        <button type="button" id="allerp-install-close" aria-label="Close">×</button>
      </div>`;
    document.body.appendChild(banner);
    banner.querySelector('#allerp-install-btn').addEventListener('click', async function () {
      if (!deferredPrompt) return;
      deferredPrompt.prompt();
      try { await deferredPrompt.userChoice; } catch (_) {}
      deferredPrompt = null;
      banner.remove();
    });
    banner.querySelector('#allerp-install-close').addEventListener('click', function () {
      banner.remove();
      try { localStorage.setItem(installKey, '1'); } catch (_) {}
    });
  }

  window.addEventListener('beforeinstallprompt', function (event) {
    event.preventDefault();
    deferredPrompt = event;
    let dismissed = false;
    try { dismissed = localStorage.getItem(installKey) === '1'; } catch (_) {}
    if (!dismissed && !window.matchMedia('(display-mode: standalone)').matches) {
      makeInstallUI();
    }
  });

  window.addEventListener('appinstalled', function () {
    deferredPrompt = null;
    const banner = document.getElementById('allerp-install-banner');
    if (banner) banner.remove();
  });
})();
