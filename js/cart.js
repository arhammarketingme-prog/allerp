// ==========================================
// ALL ERP — FINAL SYNCHRONIZED CART ENGINE
// ==========================================

// सर्व possible स्टोरेज की मधून युनिफाइड डेटा लोड करणे
let cart = JSON.parse(localStorage.getItem('all_erp_cart')) || JSON.parse(localStorage.getItem('cart')) || [];

document.addEventListener("DOMContentLoaded", function() {
  updateCartUI();
});

// दोन्ही स्टोरेज की मध्ये डेटा एकाच वेळी सिंक आणि सेव्ह करणे
function syncAndSaveCart() {
  localStorage.setItem('all_erp_cart', JSON.stringify(cart));
  localStorage.setItem('cart', JSON.stringify(cart));
}

// 1. कार्टमध्ये उत्पादन ॲड करणे
window.addToCart = function(productId, productName, productPrice, merchantBusinessId) {
  // लेटेस्ट डेटा रीफ्रेश करणे
  cart = JSON.parse(localStorage.getItem('all_erp_cart')) || JSON.parse(localStorage.getItem('cart')) || [];

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
  
  syncAndSaveCart();
  updateCartUI();
  alert('✅ "' + name + '" यशस्वीरीत्या कार्टमध्ये समाविष्ट केले गेले!');
};

// 2. दोन्हीकडील बॅज आणि काऊंट अचूक अपडेट करणे (एकसारखा नंबर दिसण्यासाठी)
function updateCartUI() {
  cart = JSON.parse(localStorage.getItem('all_erp_cart')) || JSON.parse(localStorage.getItem('cart')) || [];
  
  var totalQty = cart.reduce(function(sum, item) { return sum + (item.qty || 1); }, 0);
  
  // सर्वा All ERP आणि डॅशबोर्डवरील बॅजचे नंबर एकाच वेळी अपडेट करणे
  var badges = document.querySelectorAll('#bar-cart-count, .cart-count-badge, [id*="cart-count"]');
  badges.forEach(function(b) {
    b.textContent = totalQty;
  });
}
// 3. कार्ट बटण किंवा मोडलमधील 'खरेदी सुरू करा' किंवा चेकआउट इव्हेंट वीव्हो ब्रिजला जोडणे
document.addEventListener("DOMContentLoaded", function() {
  var checkoutBtns = document.querySelectorAll('.checkout-btn, .cart-checkout-btn, [onclick*="checkout"], [href*="checkout"]');
  checkoutBtns.forEach(function(btn) {
    btn.addEventListener('click', function(e) {
      e.preventDefault();
      
      var storeSlug = (typeof lockedStoreUsername !== 'undefined' && lockedStoreUsername) ? lockedStoreUsername : 'abhinaygandhi5151';
      var customerEmail = localStorage.getItem('global_unified_email') || '';
      
      // थेट Weavo पोर्टल उघडून सर्व कार्टमधील आयटम पास करणे
      var weavoUrl = 'https://arhammarketingme-prog.github.io/weavo/?store=' + storeSlug + 
                     (customerEmail ? ('&customer_email=' + encodeURIComponent(customerEmail)) : '');
                     
      window.open(weavoUrl, '_blank');
    });
  });
});
