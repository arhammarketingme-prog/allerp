// 3. कार्ट मोडल उघडणे आणि आयटम दाखवणे (सुरक्षित जोडणी)
document.addEventListener("DOMContentLoaded", function() {
  // नेव्हबारमधील कार्ट बटण किंवा आयकॉन शोधून क्लिक इव्हेंट जोडणे
  var cartTriggers = document.querySelectorAll('.cart-nav-btn, [data-target="customer-cart-modal"], #nav-cart-btn, .fa-shopping-cart, [onclick*="cart"]');
  cartTriggers.forEach(function(btn) {
    btn.addEventListener('click', function(e) {
      renderCartModalItems();
    });
  });
});

function renderCartModalItems() {
  // मूळ कार्ट डेटा लोकल स्टोरेजमधून घेणे
  var currentCart = JSON.parse(localStorage.getItem('cart')) || [];
  var container = document.getElementById('cart-items-container');
  if (!container) return;

  if (currentCart.length === 0) {
    container.innerHTML = '<p>तुमचे कार्ड सध्या रिकामी आहे.</p>';
    return;
  }

  var html = '<ul style="list-style: none; padding: 0;">';
  var total = 0;
  
  currentCart.forEach(function(item) {
    var subtotal = (item.price || 0) * (item.qty || 1);
    total += subtotal;
    html += '<li style="margin-bottom: 10px; border-bottom: 1px solid #ddd; padding-bottom: 5px;">' +
            '<b>' + (item.name || 'उत्पादन') + '</b><br>' +
            'किंमत: ₹' + (item.price || 0) + ' x ' + (item.qty || 1) + ' = <b>₹' + subtotal + '</b>' +
            '</li>';
  });
  
  html += '</ul>';
  html += '<h4>एकूण रक्कम: ₹' + total + '</h4>';
  container.innerHTML = html;
}
