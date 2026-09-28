// ==========================================
// ALL ERP — BULLETPROOF SYNCED CART ENGINE
// ==========================================

// युनिव्हर्सल कार्ट लोड करणे
let cart = JSON.parse(localStorage.getItem('all_erp_cart')) || JSON.parse(localStorage.getItem('cart')) || [];

document.addEventListener("DOMContentLoaded", function() {
  updateCartUI();
});

// दोन्ही स्टोरेज की मध्ये डेटा एकाच वेळी सेव्ह करणारी फंक्शन
function saveCartToStorage() {
  localStorage.setItem('all_erp_cart', JSON.stringify(cart));
  localStorage.setItem('cart', JSON.stringify(cart));
}

// 1. कार्टमध्ये प्रॉडक्ट ॲड करणे (ग्लोबल फंक्शन)
window.addToCart = function(productId, productName, productPrice, merchantBusinessId) {
  // खात्रीसाठी लोकल स्टोरेज मधून लेटेस्ट डेटा घेणे
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
  
  // डेटा दोन्ही स्टोरेज की मध्ये强制 सेव्ह करणे
  saveCartToStorage();
  updateCartUI();
  
  console.log("Updated Cart Data:", cart); // कन्सोलमध्ये तपासण्यासाठी
  alert('✅ "' + name + '" यशस्वीरीत्या कार्टमध्ये समाविष्ट केले गेले!');
};

// 2. कार्ट बझर (Badge) अपडेट करणे
function updateCartUI() {
  cart = JSON.parse(localStorage.getItem('all_erp_cart')) || JSON.parse(localStorage.getItem('cart')) || [];
  
  var totalQty = cart.reduce(function(sum, item) { return sum + item.qty; }, 0);
  var badges = document.querySelectorAll('#bar-cart-count, .cart-count-badge');
  badges.forEach(function(b) {
    b.textContent = totalQty;
  });
}
