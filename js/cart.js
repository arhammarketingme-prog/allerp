// ==========================================
// ALL ERP — CART & ORDER MANAGEMENT ENGINE
// ==========================================

let cart = [];

// कार्टमध्ये प्रॉडक्ट जोडणे (नाव undefined येण्याची समस्या दूर करणारा सुरक्षित कोड)
function addToCart(productId, productName, productPrice, merchantBusinessId) {
  var cleanName = productName || 'उत्पादनाचे नाव';
  var cleanPrice = productPrice || 0;
  var activeBizId = merchantBusinessId || (typeof currentBusinessId !== 'undefined' ? currentBusinessId : 'b9ea82ab-e398-4ee7-a2c0-8e4052c9188a');
  
  var existing = cart.find(function(item) { return item.id === productId; });
  if (existing) {
    existing.qty++;
  } else {
    cart.push({
      id: productId,
      name: cleanName,
      price: cleanPrice,
      qty: 1,
      business_id: activeBizId
    });
  }
  updateCartUI();
  alert('✅ "' + cleanName + '" कार्टमध्ये यशस्वीरीत्या जोडले गेले!');
}

// कार्ट UI अपडेट करणे
function updateCartUI() {
  var totalQty = cart.reduce(function(sum, item) { return sum + item.qty; }, 0);
  var badge = document.getElementById('bar-cart-count');
  if (badge) badge.textContent = totalQty;
}
