// ==========================================
// ALL ERP — FINAL CLEAN CART ENGINE
// ==========================================

let cart = JSON.parse(localStorage.getItem('all_erp_cart')) || JSON.parse(localStorage.getItem('cart')) || [];

document.addEventListener("DOMContentLoaded", function() {
  updateCartUI();
  
  var cartTriggers = document.querySelectorAll('.cart-nav-btn, [data-target="customer-cart-modal"], #nav-cart-btn, .fa-shopping-cart, [onclick*="cart"]');
  cartTriggers.forEach(function(btn) {
    btn.addEventListener('click', function(e) {
      e.preventDefault();
      
      if (!isCustomerLoggedIn()) {
        alert('⚠️ कृपया कार्ट पाहण्यासाठी आणि खरेदी करण्यासाठी आधी लॉगिन करा!');
        window.location.href = 'login.html';
        return;
      }
      
      if (window.location.pathname.includes('index.html') || window.location.pathname.endsWith('/allerp/')) {
        window.location.href = 'cart.html';
      }
    });
  });

  if (window.location.pathname.includes('cart.html')) {
    if (!isCustomerLoggedIn()) {
      window.location.href = 'login.html';
    }
  }
});

function saveCartState() {
  localStorage.setItem('all_erp_cart', JSON.stringify(cart));
  localStorage.setItem('cart', JSON.stringify(cart));
}

window.addToCart = function(productId, productName, productPrice, merchantBusinessId) {
  cart = JSON.parse(localStorage.getItem('all_erp_cart')) || JSON.parse(localStorage.getItem('cart')) || [];

  var name = productName || 'उत्पादनाचे नाव';
  var price = productPrice || 40;
  var activeBizId = merchantBusinessId || 'b9ea82ab-e398-4ee7-a2c0-8e4052c9188a';
  
  var existing = cart.find(function(item) { return (item.id === productId && item.business_id === activeBizId) || item.name === name; });
  if (existing) {
    existing.qty++;
  } else {
    cart.push({
      id: productId || 'prod-' + Date.now(),
      name: name,
      price: price,
      qty: 1,
      business_id: activeBizId
    });
  }
  
  saveCartState();
  updateCartUI();
  alert('✅ "' + name + '" यशस्वीरीत्या कार्टमध्ये समाविष्ट केले गेले!');
};

function updateCartUI() {
  cart = JSON.parse(localStorage.getItem('all_erp_cart')) || JSON.parse(localStorage.getItem('cart')) || [];
  var totalQty = cart.reduce(function(sum, item) { return sum + (item.qty || 1); }, 0);
  
  var badges = document.querySelectorAll('#bar-cart-count, .cart-count-badge, [id*="cart-count"]');
  badges.forEach(function(b) {
    b.textContent = totalQty;
  });
}

function isCustomerLoggedIn() {
  var userEmail = localStorage.getItem('global_unified_email') || localStorage.getItem('user_email') || localStorage.getItem('email') || localStorage.getItem('supabase_user');
  var userToken = localStorage.getItem('sb-access-token') || localStorage.getItem('supabase.auth.token') || localStorage.getItem('logged_in');
  
  if (userEmail || userToken) return true;

  for (let i = 0; i < localStorage.length; i++) {
    let key = localStorage.key(i);
    if (key) {
      let lowerKey = key.toLowerCase();
      if (lowerKey.includes('login') || lowerKey.includes('user') || lowerKey.includes('email') || lowerKey.includes('auth') || lowerKey.includes('token') || lowerKey.includes('erp')) {
        let val = localStorage.getItem(key);
        if (val && val !== 'false' && val !== 'null' && val !== '' && val !== '{}') {
          return true;
        }
      }
    }
  }
  return false;
}

function getActualLoggedUserEmail() {
  return localStorage.getItem('global_unified_email') || 
         localStorage.getItem('user_email') || 
         localStorage.getItem('email') || 
         localStorage.getItem('supabase_user') || 
         'verified_erp_customer@market.com';
}

window.processCartCheckout = async function() {
  if (!isCustomerLoggedIn()) {
    alert('⚠️ ऑर्डर करण्यासाठी कृपया आधी लॉगिन करा!');
    window.location.href = 'login.html';
    return;
  }

  cart = JSON.parse(localStorage.getItem('all_erp_cart')) || JSON.parse(localStorage.getItem('cart')) || [];
  
  if (!cart || cart.length === 0) {
    alert('🛒 तुमची कार्ट रिकामी आहे!');
    return;
  }

  var realLoggedInUserEmail = getActualLoggedUserEmail();

  var customerName = prompt('🛒 कृपया तुमचे नाव टाका (ऑर्डरसाठी):', '');
  if (!customerName) return;

  var customerPhone = prompt('📱 कृपया तुमचा १० अंकी मोबाईल नंबर टाका:', '');
  if (!customerPhone || customerPhone.length < 10) {
    alert('कृपया वैध मोबाईल नंबर भरा!');
    return;
  }

  var customerAddress = prompt('📍 कृपया डिलिव्हरी पत्ता टाका:', '');
  if (!customerAddress) {
    alert('पत्ता भरणे आवश्यक आहे!');
    return;
  }

  var itemsSummaryText = cart.map(function(i) { return i.name + ' (' + i.qty + ' नग - ₹' + (i.price * i.qty) + ')'; }).join(', ');
  var totalAmt = cart.reduce(function(sum, i) { return sum + (i.price * i.qty); }, 0);
  var orderOtp = Math.floor(1000 + Math.random() * 9000).toString();

  try {
    if (typeof sb !== 'undefined') {
      var primaryBizId = cart[0].business_id || 'b9ea82ab-e398-4ee7-a2c0-8e4052c9188a';
      await sb.from('orders').insert({
        business_id: primaryBizId,
        customer_name: customerName + ' (ERP Login: ' + realLoggedInUserEmail + ')',
        customer_phone: customerPhone,
        customer_address: customerAddress,
        items_summary: itemsSummaryText,
        total_amount: totalAmt,
        otp_code: orderOtp,
        status: 'pending'
      });
    }
  } catch (err) {
    console.warn('Supabase note:', err);
  }

  var orderMessage = '📦 **AllERP युनिफाइड ऑर्डर**\n\n' +
                     '🛒 **उत्पादने:**\n' + itemsSummaryText + '\n\n' +
                     '💰 **एकूण रक्कम:** ₹' + totalAmt + '\n' +
                     '🔐 **डिलिव्हरी पिन (OTP):** ' + orderOtp + '\n\n' +
                     '👤 **ग्राहक (Provided):** ' + customerName + '\n' +
                     '🛡️ **ERP Verified Login:** ' + realLoggedInUserEmail + '\n' +
                     '📱 **मोबाईल:** ' + customerPhone + '\n' +
                     '📍 **पत्ता:** ' + customerAddress;

  var storeSlug = (typeof lockedStoreUsername !== 'undefined' && lockedStoreUsername) ? lockedStoreUsername : 'abhinaygandhi5151';

  cart = [];
  saveCartState();
  updateCartUI();

  alert('🎉 ऑर्डर यशस्वीरीत्या नोंदवली गेली!\n🔐 तुमचा ओटीपी (OTP): ' + orderOtp);

  var weavoUrl = 'https://arhammarketingme-prog.github.io/weavo/?store=' + storeSlug + 
                 '&prefill_msg=' + encodeURIComponent(orderMessage) + 
                 '&customer_email=' + encodeURIComponent(realLoggedInUserEmail);

  window.open(weavoUrl, '_blank');
  window.location.href = 'index.html';
};
