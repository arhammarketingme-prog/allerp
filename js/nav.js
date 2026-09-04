// Unified Navigation Bar Component with Vibrant Distinct Colors & Rich UI
async function renderNav() {
  const nav = document.getElementById('app-nav');
  if (!nav) return;

  let user = null;
  let isAdmin = false;
  let isDeliveryBoy = false;
  let pendingDeliveryCount = 0;
  let unreadNotifCount = 0;

  try {
    const { data } = await sb.auth.getUser();
    user = data?.user;
    if (user) {
      const { data: profile } = await sb.from('users').select('is_admin').eq('id', user.id).maybeSingle();
      if (profile) {
        isAdmin = profile.is_admin;
      }
      const { data: dbRow } = await sb.from('delivery_boys').select('id').eq('user_id', user.id).maybeSingle();
      isDeliveryBoy = !!dbRow;
      if (isDeliveryBoy) {
        const { count: newOrderCount } = await sb.from('orders').select('id', { count: 'exact', head: true })
          .eq('delivery_boy_id', dbRow.id)
          .is('delivery_accepted_at', null)
          .not('status', 'in', '("delivered","rejected")');
        const { count: pickupCount } = await sb.from('orders').select('id', { count: 'exact', head: true })
          .eq('return_delivery_boy_id', dbRow.id)
          .eq('return_pickup_status', 'assigned');
        pendingDeliveryCount = (newOrderCount || 0) + (pickupCount || 0);
      }
      const { count: notifCount } = await sb.from('notifications').select('id', { count: 'exact', head: true })
        .eq('user_id', user.id).eq('is_read', false);
      unreadNotifCount = notifCount || 0;
    }
  } catch (e) {
    console.debug('Auth note:', e);
  }

  let cartCount = 0;
  try {
    const cart = JSON.parse(localStorage.getItem('cart')) || [];
    cartCount = cart.reduce((sum, item) => sum + (item.quantity || 1), 0);
  } catch (e) {
    cartCount = 0;
  }

  const currentLang = localStorage.getItem('allerp_lang') || 'mr';

  nav.style.cssText = "width: 100%; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; padding: 12px 20px; background: #0f172a; border-bottom: 2px solid rgba(255,255,255,0.15); box-shadow: 0 4px 15px rgba(0,0,0,0.2);";

  nav.innerHTML = `
    <!-- डावी बाजू: ब्रँड नाव -->
    <div class="brand-group" style="display:flex; align-items:center; gap:10px;">
      <a href="index.html" class="brand" style="font-size: 22px; font-weight: 900; color: #38bdf8; text-decoration: none; letter-spacing: 0.5px;">🚀 ALL ERP</a>
      <span class="brand-tagline" style="color: #94a3b8; font-size: 13px; font-weight: 600; border-left: 2px solid #334155; padding-left: 10px;">Smart Marketplace</span>
    </div>

    <!-- उजवी बाजू: सर्व बटनांचे स्वतंत्र आणि आकर्षक रंग -->
    <div class="nav-links" style="display:flex; align-items:center; gap:8px; flex-wrap:wrap;">
      <a href="index.html" style="color: #ffffff; background: #334155; font-weight: 700; text-decoration: none; font-size: 13px; padding: 6px 12px; border-radius: 6px;">🏠 Home</a>
      
      <a href="advertiser.html" style="color: #1e1b4b; background: #facc15; font-weight: 800; text-decoration: none; font-size: 13px; padding: 6px 12px; border-radius: 6px; box-shadow: 0 2px 5px rgba(250,204,21,0.3);">📢 Advertise</a>
      
      <a href="b2b-collective.html" style="color: #ffffff; background: #7c3aed; font-weight: 700; text-decoration: none; font-size: 13px; padding: 6px 12px; border-radius: 6px;">🤝 B2B</a>
      
      <a href="app-store.html" style="color: #ffffff; background: #0284c7; font-weight: 700; text-decoration: none; font-size: 13px; padding: 6px 12px; border-radius: 6px;">📱 Apps</a>
      
      <a href="customer-passbook.html" style="color: #ffffff; background: #db2777; font-weight: 700; text-decoration: none; font-size: 13px; padding: 6px 12px; border-radius: 6px;">📒 Khata</a>
      
      <a href="orders.html" style="color: #ffffff; background: #475569; font-weight: 700; text-decoration: none; font-size: 13px; padding: 6px 12px; border-radius: 6px;">📦 Orders</a>
      
      <!-- 🛒 कार्ट बझ -->
      <a href="cart.html" style="color: #fff; text-decoration: none; font-size: 13px; font-weight: 700; display: flex; align-items: center; gap: 6px; background: #ea580c; padding: 6px 12px; border-radius: 6px;">
        🛒 कार्ट 
        <span style="background: #ffffff; color: #ea580c; border-radius: 50%; width: 20px; height: 20px; display: inline-flex; align-items: center; justify-content: center; font-size: 11px; font-weight: 900;">${cartCount}</span>
      </a>
      
      <!-- भाषा बदलणारा पर्याय -->
      <select id="global-lang-switcher" onchange="if(window.ALL_ERP && ALL_ERP.setLanguage) ALL_ERP.setLanguage(this.value)" style="padding:5px 10px; font-size:12px; border-radius:6px; background:#1e293b; color:#fff; border: 1px solid #475569; margin-bottom:0; width:auto; cursor:pointer; font-weight:600;">
        <option value="mr" ${currentLang === 'mr' ? 'selected' : ''}>मराठी</option>
        <option value="en" ${currentLang === 'en' ? 'selected' : ''}>English</option>
        <option value="hi" ${currentLang === 'hi' ? 'selected' : ''}>हिन्दी</option>
      </select>

      <!-- ⚙️ ॲडमिन पोर्टल -->
      ${isAdmin ? `<a href="admin.html" style="background: #dc2626; color: #ffffff; padding: 6px 12px; border-radius: 6px; font-weight: 700; text-decoration: none; font-size: 13px;">⚙️ Admin</a>` : ''}

      <!-- 🛵 डिलिव्हरी बॉय पोर्टल (फक्त ज्यांचं खातं delivery_boys शी जोडलेलं आहे त्यांनाच दिसतं) -->
      ${isDeliveryBoy ? `<a href="delivery-boy.html" style="background: #16a34a; color: #ffffff; padding: 6px 12px; border-radius: 6px; font-weight: 700; text-decoration: none; font-size: 13px; display:flex; align-items:center; gap:6px;">🛵 माझ्या डिलिव्हरी${pendingDeliveryCount > 0 ? `<span style="background:#dc2626; color:#fff; border-radius:50%; width:20px; height:20px; display:inline-flex; align-items:center; justify-content:center; font-size:11px; font-weight:900;">${pendingDeliveryCount}</span>` : ''}</a>` : ''}
      
      <!-- युजर प्रोफाईल / लॉगइन / लॉगआउट -->
      ${user 
        ? `<div style="position:relative;">
             <button onclick="toggleNotifDropdown()" style="background:#1e293b; border:1px solid #475569; color:#fff; padding:6px 10px; border-radius:6px; font-size:14px; cursor:pointer; position:relative;">
               🔔${unreadNotifCount > 0 ? `<span style="position:absolute; top:-4px; right:-4px; background:#dc2626; color:#fff; border-radius:50%; width:16px; height:16px; font-size:10px; display:flex; align-items:center; justify-content:center; font-weight:900;">${unreadNotifCount > 9 ? '9+' : unreadNotifCount}</span>` : ''}
             </button>
             <div id="notif-dropdown" style="display:none; position:absolute; right:0; top:38px; width:300px; max-height:360px; overflow-y:auto; background:#fff; border-radius:8px; box-shadow:0 8px 24px rgba(0,0,0,0.2); z-index:200;">
               <div style="padding:10px; border-bottom:1px solid #e2e8f0; display:flex; justify-content:space-between; align-items:center;">
                 <strong style="color:#0f172a; font-size:13px;">सूचना</strong>
                 <a href="#" onclick="markAllNotifsRead(); return false;" style="font-size:11.5px; color:#2563eb; text-decoration:none;">सर्व वाचलं म्हणून चिन्हांकित करा</a>
               </div>
               <div id="notif-list" style="padding:8px;"><p class="muted" style="font-size:12.5px; padding:8px;">लोड होत आहे...</p></div>
             </div>
           </div>
           <a href="b2b-wholesale.html" style="background: #7c3aed; color: #fff; padding: 6px 12px; border-radius: 6px; font-size: 13px; font-weight: 700; text-decoration: none;">🏭 Wholesale</a>
           <a href="dashboard.html" style="background: #0284c7; color: #fff; padding: 6px 12px; border-radius: 6px; font-size: 13px; font-weight: 700; text-decoration: none;">📊 My ERP</a>
           <a href="#" onclick="sb.auth.signOut().then(() => location.reload()); return false;" style="background: #1e293b; border: 1px solid #64748b; color: #ffffff; padding: 6px 10px; border-radius: 6px; font-size: 13px; font-weight: 700; text-decoration: none;">🚪 Logout</a>`
        : `<a href="login.html" style="background: #2563eb; color: #fff; padding: 6px 14px; border-radius: 6px; font-size: 13px; font-weight: 700; text-decoration: none;">🔑 Login</a>`}
    </div>
  `;

  if (!document.getElementById('global-full-marquee-strip')) {
    const stripContainer = document.createElement('div');
    stripContainer.id = 'global-full-marquee-strip';
    stripContainer.style.cssText = "width: 100vw; position: relative; left: 50%; right: 50%; margin-left: -50vw; margin-right: -50vw; background: linear-gradient(90deg, #1e3a8a, #3b82f6); border-bottom: 2px solid rgba(255,255,255,0.15); padding: 9px 20px; margin-top: 0; margin-bottom: 18px; box-shadow: 0 3px 8px rgba(0,0,0,0.15); z-index: 99; display: flex; align-items: center; justify-content: center;";
    
    stripContainer.innerHTML = `
      <div style="max-width: 1250px; width: 100%; display: flex; align-items: center; gap: 14px; flex-wrap: wrap;">
        <span style="background: #facc15; color: #1e1b4b; font-size: 12px; font-weight: 900; padding: 4px 10px; border-radius: 6px; text-transform: uppercase; white-space: nowrap;">⚡ स्पेशल ऑफर</span>
        
        <div style="flex: 1; min-width: 280px; overflow: hidden;">
          <marquee behavior="scroll" direction="left" scrollamount="4" style="color: #ffffff; font-size: 14px; font-weight: 700;">
            📢 <span style="color: #facc15;">स्थानिक व्यापाराला बनवा सुपरफास्ट!</span> आपल्या दुकानाची जाहिरात थेट ग्राहकांच्या मोबाईलवर दाखवा — फक्त <span style="color: #facc15;">₹९९ पासून सुरू (1,000 Views)</span>! 👉 थेट संपर्क व जाहिरात देण्यासाठी WhatsApp करा: <a href="https://wa.me/919130977993?text=मला%20माझ्या%20दुकानाची%20जाहिरात%20करायची%20आहे." target="_blank" style="color: #4ade80; text-decoration: underline; font-weight: 800;">+91 91309 77993</a> 🚀
          </marquee>
        </div>

        <a href="https://wa.me/919130977993?text=मला%20माझ्या%20दुकानाची%20जाहिरात%20करायची%20आहे." 
           target="_blank" 
           style="background: #10b981; color: #ffffff; padding: 5px 14px; border-radius: 6px; font-weight: 800; font-size: 13px; text-decoration: none; white-space: nowrap; box-shadow: 0 2px 5px rgba(16,185,129,0.3); display: inline-flex; align-items: center; gap: 6px;">
          <span>💬</span> जाहिरात द्या
        </a>
      </div>
    `;
    nav.parentNode.insertBefore(stripContainer, nav.nextSibling);
  }
}

document.addEventListener("DOMContentLoaded", () => {
  renderNav();
});

// 🔔 Notifications dropdown
function escapeHtmlNav(str) {
  if (!str) return '';
  return String(str).replace(/[&<>"']/g, m => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
}

function timeAgoNav(dateStr) {
  const diffMs = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diffMs / 60000);
  if (mins < 1) return 'आत्ताच';
  if (mins < 60) return `${mins} मिनिटांपूर्वी`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs} तासांपूर्वी`;
  return `${Math.floor(hrs / 24)} दिवसांपूर्वी`;
}

async function toggleNotifDropdown() {
  const dd = document.getElementById('notif-dropdown');
  if (!dd) return;
  const isOpening = dd.style.display === 'none';
  dd.style.display = isOpening ? 'block' : 'none';
  if (!isOpening) return;

  const listEl = document.getElementById('notif-list');
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return;

  const { data, error } = await sb.from('notifications')
    .select('id, type, title, body, is_read, created_at')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(20);

  if (error) { listEl.innerHTML = `<p style="color:red; font-size:12px;">त्रुटी: ${error.message}</p>`; return; }
  if (!data || data.length === 0) { listEl.innerHTML = '<p class="muted" style="font-size:12.5px; padding:8px;">अजून कुठलीही सूचना नाही.</p>'; return; }

  listEl.innerHTML = data.map(n => `
    <div style="padding:8px; border-bottom:1px solid #f1f5f9; ${n.is_read ? 'opacity:0.6;' : 'background:#eff6ff;'}">
      <div style="font-size:12.5px; font-weight:700; color:#0f172a;">${escapeHtmlNav(n.title)}</div>
      ${n.body ? `<div style="font-size:11.5px; color:#475569; margin-top:2px;">${escapeHtmlNav(n.body)}</div>` : ''}
      <div style="font-size:10.5px; color:#94a3b8; margin-top:3px;">${timeAgoNav(n.created_at)}</div>
    </div>
  `).join('');
}

async function markAllNotifsRead() {
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return;
  await sb.from('notifications').update({ is_read: true }).eq('user_id', user.id).eq('is_read', false);
  await renderNav(); // बॅज संख्या ताजी करण्यासाठी संपूर्ण नेव्ह परत रेंडर करणे
  await toggleNotifDropdown(); // नवीन रेंडर झालेली dropdown परत उघडून यादी दाखवणे
}

document.addEventListener('click', (e) => {
  const dd = document.getElementById('notif-dropdown');
  if (!dd || dd.style.display === 'none') return;
  if (!e.target.closest('#notif-dropdown') && !e.target.closest('button[onclick="toggleNotifDropdown()"]')) {
    dd.style.display = 'none';
  }
});

// 📱 PWA: Service Worker रजिस्टर करणे (आधी फाईल होती, पण कधीच रजिस्टर होत नव्हती)
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('service-worker.js').catch(err => {
      console.debug('Service worker registration failed:', err);
    });
  });
}
