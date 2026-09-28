// ==========================================
// ALL ERP — UNIFIED SYNCED CART ENGINE
// ==========================================

// युनिव्हर्सल कार्ट लोड करणे (दोन्ही स्टोरेज की मधून डेटा तपासणे)
let cart = JSON.parse(localStorage.getItem('cart')) || JSON.parse(localStorage.getItem('all_erp_cart')) || [];

document.addEventListener("DOMContentLoaded", function() {
  updateCartUI();
  
  // नेव्हबारमधील कार्ट बटनावर क्लिक केल्यावर मोडल उघडून आयटम लोड करणे
  var cartTriggers = document.querySelectorAll('.cart-nav-btn, [data-target="customer-cart-modal"], #nav-cart-btn, .fa-shopping-cart, [onclick*="cart"]');
  cartTriggers.forEach(function(btn) {
    btn.addEventListener('click', function() {
      renderCartModalItems();
    });
  });
});

// दोन्ही स्टोरेज की मध्ये डेटा एकाच वेळी सेव्ह करणारी फंक्शन
function saveCartState() {
  localStorage.setItem('cart', JSON.stringify(cart));
  localStorage.setItem('all_erp_cart', JSON.stringify(cart));
}

// 1. कार्टमध्ये प्रॉडक्ट अचूक ॲड करणे
window.addToCart = function(productId, productName, productPrice, merchantBusinessId) {
  // सतत लेटेस्ट डेटा सिंक करणे
  cart = JSON.parse(localStorage.getItem('cart')) || JSON.parse(localStorage.getItem('all_erp_cart')) || [];

  var name = productName || 'उत्पादनाचे नाव';
  var price = productPrice || 40;
  var activeBizId = merchantBusinessId || (typeof currentBusinessId !== 'undefined' ? currentBusinessId : 'b9ea82ab-e398-4ee7-a2c0-8e4052c9188a');
  
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
  
  saveCartState();
  updateCartUI();
  alert('✅ "' + name + '" यशस्वीरीत्या कार्टमध्ये समाविष्ट केले गेले!');
};

// 2. कार्ट बझर (Badge) अपडेट करणे
function updateCartUI() {
  cart = JSON.parse(localStorage.getItem('cart')) || JSON.parse(localStorage.getItem('all_erp_cart')) || [];
  
  var totalQty = cart.reduce(function(sum, item) { return sum + item.qty; }, 0);
  var badges = document.querySelectorAll('#bar-cart-count, .cart-count-badge');
  badges.forEach(function(b) {
    b.textContent = totalQty;
  });
}

// 3. कार्ट मोडल किंवा पेजमध्ये वस्तू आणि एकूण रक्कम दाखवणे
function renderCartModalItems() {
  cart = JSON.parse(localStorage.getItem('cart')) || JSON.parse(localStorage.getItem('all_erp_cart')) || [];
  
  var container = document.getElementById('cart-items-container');
  if (!container) return;

  if (cart.length === 0) {
    container.innerHTML = '<p>तुमचे कार्ड सध्या रिकामी आहे.</p>';
    return;
  }

  var html = '<ul style="list-style: none; padding: 0;">';
  var total = 0;
  
  cart.forEach(function(item, index) {
    var subtotal = item.price * item.qty;
    total += subtotal;
    html += '<li style="margin-bottom: 10px; border-bottom: 1px solid #ddd; padding-bottom: 5px;">' +
            '<b>' + item.name + '</b><br>' +
            'किंमत: ₹' + item.price + ' x ' + item.qty + ' = <b>₹' + subtotal + '</b>' +
            '</li>';
  });
  
  html += '</ul>';
  html += '<h4>एकूण रक्कम: ₹' + total + '</h4>';
  container.innerHTML = html;
}
