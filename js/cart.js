// ==========================================
// ALL ERP — ORIGINAL BASELINE CART ENGINE
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
// 3. नेव्हबारमधील कार्ट बटनावर क्लिक केल्यावर कार्ट मोडल उघडणे आणि वस्तू दाखवणे
document.addEventListener("DOMContentLoaded", function() {
  // नेव्हबारमधील कार्ट बटण किंवा आयकॉन शोधणे
  var cartNavBtn = document.querySelector('.cart-nav-btn, [data-target="customer-cart-modal"], #nav-cart-btn, .fa-shopping-cart');
  
  if (cartNavBtn) {
    cartNavBtn.addEventListener('click', function(e) {
      e.preventDefault();
      openCartModal();
    });
  }
});

// कार्ट मोडल उघडून त्यात वस्तूंची यादी दाखवणारे फंक्शन
function openCartModal() {
  var modal = document.getElementById('customer-cart-modal');
  if (modal) {
    modal.style.display = 'block';
  } else {
    // जर मोडल नसेल तर अलर्ट किंवा सिम्पल लिस्ट दाखवणे
    if (cart.length === 0) {
      alert('🛒 तुमची कार्ट रिकामी आहे!');
      return;
    }
    var summary = cart.map(function(i) { return i.name + ' (x' + i.qty + ') - ₹' + (i.price * i.qty); }).join('\n');
    alert('🛒 **तुमची कार्ट:**\n\n' + summary);
  }
  
  // जर मोडलमधील लिस्ट अपडेट करायची असेल
  renderCartModalItems();
}

// मोडलमध्ये कार्टमधील आयटम रेंडर करणे
function renderCartModalItems() {
  var container = document.getElementById('cart-items-container');
  if (!container) return;

  if (cart.length === 0) {
    container.innerHTML = '<p>कार्ट रिकामी आहे.</p>';
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
