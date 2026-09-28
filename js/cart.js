// ==========================================
// ALL ERP — DIRECT WEAVO BUY NOW BRIDGE ENGINE
// ==========================================

document.addEventListener("DOMContentLoaded", function() {
  // नेव्हबारमधील किंवा होमपेजवरील जुने कार्ट बॅज किंवा काउंटर असल्यास ते शून्य किंवा लपवून ठेवणे
  var badge = document.getElementById('bar-cart-count');
  if (badge) badge.textContent = '0';
});

// थेट 'Buy Now' किंवा 'Order Now' दाबल्यावर चालणारे युनिव्हर्सल फंक्शन
window.buyProductDirectly = function(productName, productPrice, merchantUsername, businessId) {
  var name = productName || 'उत्पादन';
  var price = productPrice || 0;
  var storeSlug = merchantUsername || (typeof lockedStoreUsername !== 'undefined' && lockedStoreUsername ? lockedStoreUsername : 'abhinaygandhi5151');
  
  // ग्राहकाची माहिती विचारणे किंवा थेट वीव्हो चॅटमध्ये पाठवणे
  var customerName = prompt('🛒 कृपया तुमचे नाव टाका (ऑर्डरसाठी):', '');
  if (!customerName) {
    return; // नाव दिले नाही तर प्रक्रिया रद्द करणे
  }

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

  // वीव्हो पोर्टलसाठी मेसेज फॉरमॅट तयार करणे
  var orderMessage = '📦 **AllERP थेट ऑनलाईन ऑर्डर**\n\n' +
                     '🛒 **उत्पादन:** ' + name + '\n' +
                     '💰 **किंमत:** ₹' + price + '\n' +
                     '👤 **ग्राहक:** ' + customerName + '\n' +
                     '📱 **मोबाईल:** ' + customerPhone + '\n' +
                     '📍 **पत्ता:** ' + customerAddress;

  // लोकल स्टोरेज किंवा युनिव्हर्सल ईमेल मिळवणे
  var customerEmail = localStorage.getItem('global_unified_email') || '';

  // थेट वीव्हो पोर्टल उघडून दुकानदाराशी संवाद साधणे आणि मेसेज पास करणे
  var weavoUrl = 'https://arhammarketingme-prog.github.io/weavo/?store=' + storeSlug + 
                 '&prefill_msg=' + encodeURIComponent(orderMessage) + 
                 (customerEmail ? ('&customer_email=' + encodeURIComponent(customerEmail)) : '');

  window.open(weavoUrl, '_blank');
};
