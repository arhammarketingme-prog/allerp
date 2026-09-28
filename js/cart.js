// ==========================================
// ALL ERP — SAFE & STABLE BRIDGE ENGINE
// ==========================================

let cart = JSON.parse(localStorage.getItem('all_erp_cart')) || [];

document.addEventListener("DOMContentLoaded", function() {
  updateCartUI();
});

// 1. जुने ॲड टू कार्ट फंक्शन (एरर येऊ नये म्हणून ग्लोबल केलेले)
window.addToCart = function(productId, productName, productPrice, merchantBusinessId) {
  var name = productName || 'उत्पादनाचे नाव';
  var price = productPrice || 40;
  var activeBizId = merchantBusinessId || 'b9ea82ab-e398-4ee7-a2c0-8e4052c9188a';
  
  var existing = cart.find(function(item) { return item.id === productId || item.name === name; });
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
  
  localStorage.setItem('all_erp_cart', JSON.stringify(cart));
  updateCartUI();
  alert('✅ "' + name + '" यशस्वीरीत्या कार्टमध्ये समाविष्ट केले गेले!');
};

// 2. बॅज अपडेट करणे
function updateCartUI() {
  var totalQty = cart.reduce(function(sum, item) { return sum + item.qty; }, 0);
  var badges = document.querySelectorAll('#bar-cart-count, .cart-count-badge');
  badges.forEach(function(b) {
    b.textContent = totalQty;
  });
}

// 3. थेट 'Buy Now' किंवा 'Add to Cart' वरून थेट Weavo पोर्टल उघडणारे फंक्शन
window.buyProductDirectly = function(productName, productPrice, merchantUsername) {
  var name = productName || 'उत्पादन';
  var price = productPrice || 40;
  var storeSlug = merchantUsername || (typeof lockedStoreUsername !== 'undefined' && lockedStoreUsername ? lockedStoreUsername : 'abhinaygandhi5151');
  
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

  var orderMessage = '📦 **AllERP थेट ऑनलाईन ऑर्डर**\n\n' +
                     '🛒 **उत्पादन:** ' + name + '\n' +
                     '💰 **किंमत:** ₹' + price + '\n' +
                     '👤 **ग्राहक:** ' + customerName + '\n' +
                     '📱 **मोबाईल:** ' + customerPhone + '\n' +
                     '📍 **पत्ता:** ' + customerAddress;

  var customerEmail = localStorage.getItem('global_unified_email') || '';

  var weavoUrl = 'https://arhammarketingme-prog.github.io/weavo/?store=' + storeSlug + 
                 '&prefill_msg=' + encodeURIComponent(orderMessage) + 
                 (customerEmail ? ('&customer_email=' + encodeURIComponent(customerEmail)) : '');

  window.open(weavoUrl, '_blank');
};
