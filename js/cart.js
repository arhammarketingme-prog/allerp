// ==========================================
// ALL ERP — CART & ORDER MANAGEMENT ENGINE
// ==========================================

let cart = [];

// कार्टमध्ये प्रॉडक्ट जोडणे (सुधारित व सुरक्षित कोड)
function addToCart(productId, productName, productPrice, merchantBusinessId) {
  var activeBizId = merchantBusinessId || (typeof currentBusinessId !== 'undefined' ? currentBusinessId : 'b9ea82ab-e398-4ee7-a2c0-8e4052c9188a');
  
  var existing = cart.find(function(item) { return item.id === productId; });
  if (existing) {
    existing.qty++;
  } else {
    cart.push({
      id: productId,
      name: productName,
      price: productPrice,
      qty: 1,
      business_id: activeBizId
    });
  }
  updateCartUI();
  alert('✅ "' + productName + '" कार्टमध्ये यशस्वीरीत्या जोडले गेले!');
}

// कार्ट UI अपडेट करणे
function updateCartUI() {
  var totalQty = cart.reduce(function(sum, item) { return sum + item.qty; }, 0);
  var badge = document.getElementById('bar-cart-count');
  if (badge) badge.textContent = totalQty;
}
