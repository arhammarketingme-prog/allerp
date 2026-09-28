// ==========================================
// ALL ERP — ORIGINAL ZIP CART ENGINE
// ==========================================

let cart = JSON.parse(localStorage.getItem('cart')) || [];

document.addEventListener("DOMContentLoaded", function() {
  updateCartUI();
});

// 1. मूळ ॲड टू कार्ट फंक्शन
function addToCart(productId, productName, productPrice, merchantBusinessId) {
  var name = productName || 'उत्पादनाचे नाव';
  var price = productPrice || 0;
  
  var existing = cart.find(function(item) { return item.id === productId; });
  if (existing) {
    existing.qty++;
  } else {
    cart.push({
      id: productId || 'prod-' + Date.now(),
      name: name,
      price: price,
      qty: 1,
      business_id: merchantBusinessId || ''
    });
  }
  
  localStorage.setItem('cart', JSON.stringify(cart));
  updateCartUI();
  alert('✅ "' + name + '" कार्टमध्ये यशस्वीरीत्या जोडले गेले!');
}

// 2. कार्ट युनिट/बॅज अपडेट करणे
function updateCartUI() {
  var totalQty = cart.reduce(function(sum, item) { return sum + item.qty; }, 0);
  var badge = document.getElementById('bar-cart-count');
  if (badge) {
    badge.textContent = totalQty;
  }
}
