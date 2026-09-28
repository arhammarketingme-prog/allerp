// ==========================================
// ALL ERP — FORCE GOOGLE LOGIN & CART CHECKOUT ENGINE
// ==========================================

// 1. युनिव्हर्सल कार्ट लोड करणे
let cart = JSON.parse(localStorage.getItem('all_erp_cart')) || JSON.parse(localStorage.getItem('cart')) || [];

document.addEventListener("DOMContentLoaded", function() {
  updateCartUI();
  
  // नेव्हबारमधील कार्ट बटनावर क्लिक केल्यावर आधी लॉगिन तपासणे
  var cartTriggers = document.querySelectorAll('.cart-nav-btn, [data-target="customer-cart-modal"], #nav-cart-btn, .fa-shopping-cart, [onclick*="cart"]');
  cartTriggers.forEach(function(btn) {
    btn.addEventListener('click', function(e) {
      e.preventDefault();
      checkLoginAndOpenCart();
    });
  });
});

// दोन्ही स्टोरेज की मध्ये डेटा एकाच वेळी सेव्ह करणारी फंक्शन
function saveCartState() {
  localStorage.setItem('all_erp_cart', JSON.stringify(cart));
  localStorage.setItem('cart', JSON.stringify(cart));
}

// 2. कार्टमध्ये उत्पादन ॲड करणे (कोणत्याही रहदारीशिवाय विनासायास ॲड होईल)
window.addToCart = function(productId, productName, productPrice, merchantBusinessId) {
  cart = JSON.parse(localStorage.getItem('all_erp_cart')) || JSON.parse(localStorage.getItem('cart')) || [];

  var name = productName || 'उत्पादनाचे नाव';
  var price = productPrice || 40;
  var activeBizId = merchantBusinessId || (typeof currentBusinessId !== 'undefined' ? currentBusinessId : 'b9ea82ab-e398-4ee7-a2c0-8e4052c9188a');
  
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

// 3. नेव्हबार बझर (Badge) अपडेट करणे
function updateCartUI() {
  cart = JSON.parse(localStorage.getItem('all_erp_cart')) || JSON.parse(localStorage.getItem('cart')) || [];
  var totalQty = cart.reduce(function(sum, item) { return sum + (item.qty || 1); }, 0);
  
  var badges = document.querySelectorAll('#bar-cart-count, .cart-count-badge, [id*="cart-count"]');
  badges.forEach(function(b) {
    b.textContent = totalQty;
  });
}

// 4. कार्ट क्लिक केल्यावर लॉगिन बंधनकारक करणे (Force Google Login)
function checkLoginAndOpenCart() {
  // युजर लॉगिन आहे किंवा नाही हे तपासणे (उदा. localStorage किंवा Supabase सेशन)
  var isLogged = localStorage.getItem('global_unified_email') || localStorage.getItem('supabase_user') || (typeof loggedInCustomer !== 'undefined' && loggedInCustomer);
  
  if (!isLogged) {
    alert('⚠️ कृपया कार्ट पाहण्यासाठी आणि ऑर्डर करण्यासाठी आधी गुगल (Google) द्वारे लॉगिन करा!');
    
    // गुगल लॉगिन पेज किंवा मोडलवर रीडायरेक्ट करणे
    window.location.href = 'login.html'; // किंवा तुमच्या लॉगिन पेजची योग्य लिंक
    return;
  }
  
  // युजर लॉगिन असेल तरच कार्ट मोडल उघडणे
  var modal = document.getElementById('customer-cart-modal');
  if (modal) {
    modal.style.display = 'block';
  }
  renderCartModalItems();
}

// 5. मोडलमध्ये सर्व वस्तू रेंडर करणे
function renderCartModalItems() {
  cart = JSON.parse(localStorage.getItem('all_erp_cart')) || JSON.parse(localStorage.getItem('cart')) || [];
  var container = document.getElementById('cart-items-container');
  if (!container) return;

  if (cart.length === 0) {
    container.innerHTML = '<p style="text-align: center; padding: 20px;">🛒 तुमचे कार्ट सध्या रिकामी आहे.</p>';
    return;
  }

  var html = '<ul style="list-style: none; padding: 0; margin: 0;">';
  var total = 0;
  
  cart.forEach(function(item) {
    var subtotal = (item.price || 0) * (item.qty || 1);
    total += subtotal;
    html += '<li style="margin-bottom: 12px; border-bottom: 1px solid #eee; padding-bottom: 8px; display: flex; justify-content: space-between; align-items: center;">' +
            '<div><b>' + (item.name || 'उत्पादन') + '</b><br>' +
            '<small style="color: #666;">किंमत: ₹' + (item.price || 0) + ' x ' + (item.qty || 1) + '</small></div>' +
            '<div style="font-weight: bold; color: #333;">₹' + subtotal + '</div>' +
            '</li>';
  });
  
  html += '</ul>';
  html += '<div style="margin-top: 15px; border-top: 2px solid #ddd; padding-top: 10px; display: flex; justify-content: space-between;">' +
          '<h3>एकूण रक्कम:</h3><h3>₹' + total + '</h3>' +
          '</div>';
          
  html += '<button onclick="processCartCheckout()" style="width: 100%; background: #28a745; color: white; border: none; padding: 12px; font-size: 16px; font-weight: bold; border-radius: 5px; margin-top: 15px; cursor: pointer;">⚡ खरेदी पूर्ण करा (Buy Now)</button>';

  container.innerHTML = html;
}

// 6. फायनल चेकआउट आणि वीव्हो ब्रिज
window.processCartCheckout = async function() {
  cart = JSON.parse(localStorage.getItem('all_erp_cart')) || JSON.parse(localStorage.getItem('cart')) || [];
  
  if (!cart || cart.length === 0) {
    alert('🛒 तुमची कार्ट रिकामी आहे!');
    return;
  }

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
        customer_name: customerName,
        customer_phone: customerPhone,
        customer_address: customerAddress,
        items_summary: itemsSummaryText,
        total_amount: totalAmt,
        otp_code: orderOtp,
        status: 'pending'
      });
    }
  } catch (err) {
    console.error('Supabase order insert error:', err);
  }

  var orderMessage = '📦 **AllERP युनिफाइड ऑर्डर**\n\n' +
                     '🛒 **उत्पादने:**\n' + itemsSummaryText + '\n\n' +
                     '💰 **एकूण रक्कम:** ₹' + totalAmt + '\n' +
                     '🔐 **डिलिव्हरी पिन (OTP):** ' + orderOtp + '\n\n' +
                     '👤 **ग्राहक:** ' + customerName + '\n' +
                     '📱 **मोबाईल:** ' + customerPhone + '\n' +
                     '📍 **पत्ता:** ' + customerAddress;

  var storeSlug = (typeof lockedStoreUsername !== 'undefined' && lockedStoreUsername) ? lockedStoreUsername : 'abhinaygandhi5151';
  var customerEmail = localStorage.getItem('global_unified_email') || '';

  cart = [];
  saveCartState();
  updateCartUI();
  
  var modal = document.getElementById('customer-cart-modal');
  if (modal) modal.style.display = 'none';

  alert('🎉 ऑर्डर यशस्वीरीत्या नोंदवली गेली!\n🔐 तुमचा ओटीपी (OTP): ' + orderOtp);

  var weavoUrl = 'https://arhammarketingme-prog.github.io/weavo/?store=' + storeSlug + 
                 '&prefill_msg=' + encodeURIComponent(orderMessage) + 
                 (customerEmail ? ('&customer_email=' + encodeURIComponent(customerEmail)) : '');

  window.open(weavoUrl, '_blank');
};
