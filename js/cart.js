// ==========================================
// ALL ERP — MASTER CART & CHECKOUT ENGINE
// ==========================================

// ग्लोबल कार्ट यादी (जी संपूर्ण डॅशबोर्डवर दिसेल)
let cart = JSON.parse(localStorage.getItem('all_erp_cart')) || [];

// पेज लोड झाल्यावर कार्ट युजर्ससाठी अपडेट करणे
document.addEventListener("DOMContentLoaded", function() {
  updateCartUI();
});

// 1. कार्टमध्ये प्रॉडक्ट प्रत्यक्ष साठवणारा आणि बॅज अपडेट करणारा अचूक कोड
function addToCart(productId, productName, productPrice, merchantBusinessId) {
  var name = productName;
  var price = productPrice;

  // जर प्रॉडक्टचे नाव किंवा किंमत बटणावरून आली नसेल, तर पेजवरून अचूक शोधणे
  if (!name || name === 'उत्पादनाचे नाव' || name === 'undefined') {
    var titleEl = document.querySelector('h1, h2, .product-title, strong');
    if (titleEl) name = titleEl.textContent.trim();
    else name = "Lux Soap";
  }

  if (!price || isNaN(price)) {
    var priceEl = document.querySelector('.price, span[style*="14px"], div[style*="14px"]');
    if (priceEl) {
      var priceText = priceEl.textContent.replace(/[^\d.]/g, '');
      price = parseFloat(priceText) || 40;
    } else {
      price = 40;
    }
  }

  var activeBizId = merchantBusinessId || (typeof currentBusinessId !== 'undefined' ? currentBusinessId : 'b9ea82ab-e398-4ee7-a2c0-8e4052c9188a');
  
  // कार्टमध्ये आधीच ती वस्तू आहे का तपणे
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
  
  // लोकलस्टोरेजमध्ये सेव्ह करणे जेणेकरून रिफ्रेश झाल्यावरही डेटा उडणार नाही
  localStorage.setItem('all_erp_cart', JSON.stringify(cart));
  
  updateCartUI();
  alert('✅ "' + name + '" यशस्वीरीत्या कार्टमध्ये समाविष्ट केले गेले!');
}

// 2. नेव्हबारमधील कार्ट बझर (Badge Counter) अपडेट करणारे फंक्शन
function updateCartUI() {
  var totalQty = cart.reduce(function(sum, item) { return sum + item.qty; }, 0);
  
  // सर्व पानांवर जिथे कार्टची संख्या दाखवली जाते तिथे ती अपडेट करणे
  var badges = document.querySelectorAll('#bar-cart-count, .cart-count-badge');
  badges.forEach(function(b) {
    b.textContent = totalQty;
  });
}

// 3. मर्चंट वाईज स्प्लिटिंग, OTP आणि Weavo ऑटोमॅटिक चॅट ब्रिजिंगसह ऑर्डर सबमिट करणे
async function submitCustomerOrderWithOTPAndWeavo() {
  var nameField = document.getElementById('cust-order-name');
  var phoneField = document.getElementById('cust-order-phone');
  var addressField = document.getElementById('cust-order-address');

  var name = nameField ? nameField.value.trim() : '';
  var phone = phoneField ? phoneField.value.trim() : '';
  var address = addressField ? addressField.value.trim() : '';
  
  if (!name || phone.length < 10 || !address) { 
    alert('कृपया पूर्ण नाव, १० अंकी मोबाईल नंबर आणि डिलिव्हरी पत्ता अचूक भरा!'); 
    return; 
  }
  
  if (typeof loggedInCustomer === 'undefined' || !loggedInCustomer) { 
    if (typeof loginCustomerWithGoogle === 'function') {
      loginCustomerWithGoogle(); 
    } else {
      alert('कृपया पहिले लॉगिन करा!');
    }
    return; 
  }

  if (!cart || cart.length === 0) {
    alert('तुमची कार्ट रिकामी आहे!');
    return;
  }

  try {
    var merchantGroups = {};
    cart.forEach(function(item) {
      var mId = item.business_id || (typeof currentBusinessId !== 'undefined' ? currentBusinessId : 'b9ea82ab-e398-4ee7-a2c0-8e4052c9188a');
      if (!merchantGroups[mId]) merchantGroups[mId] = [];
      merchantGroups[mId].push(item);
    });

    var customerUserId = loggedInCustomer.id;
    var storeSlug = (typeof lockedStoreUsername !== 'undefined' && lockedStoreUsername) ? lockedStoreUsername : ((typeof currentMerchantUsername !== 'undefined' && currentMerchantUsername) ? currentMerchantUsername : 'abhinaygandhi5151');

    for (var mId in merchantGroups) {
      var items = merchantGroups[mId];
      var totalAmt = items.reduce(function(sum, i) { return sum + (i.price * i.qty); }, 0);
      var itemsSummaryText = items.map(function(i) { return i.name + ' (' + i.qty + ' नग)'; }).join(', ');
      
      var orderOtp = Math.floor(1000 + Math.random() * 9000).toString();

      var orderRes = await sb.from('orders').insert({
        business_id: mId,
        customer_name: name,
        customer_phone: phone,
        customer_address: address,
        items_summary: itemsSummaryText,
        total_amount: totalAmt,
        otp_code: orderOtp,
        status: 'pending'
      }).select().single();

      if (orderRes.error) {
        console.error("Order insert error:", orderRes.error.message);
        continue;
      }

      var targetMerchantId = (typeof currentMerchantUserId !== 'undefined') ? currentMerchantUserId : null;
      var bizRes = await sb.from('businesses').select('owner_id').eq('id', mId).maybeSingle();
      if (bizRes.data && bizRes.data.owner_id) {
        targetMerchantId = bizRes.data.owner_id;
      } else {
        var profRes = await sb.from('profiles').select('id').ilike('username', storeSlug).maybeSingle();
        if (profRes.data) targetMerchantId = profRes.data.id;
      }

      if (targetMerchantId && targetMerchantId !== customerUserId) {
        var targetConvId = null;
        var myConvsRes = await sb.from('conversation_members').select('conversation_id').eq('user_id', customerUserId);
        var myIds = (myConvsRes.data || []).map(function(r) { return r.conversation_id; });

        if (myIds.length) {
          var theirConvsRes = await sb.from('conversation_members').select('conversation_id').eq('user_id', targetMerchantId).in('conversation_id', myIds);
          if (theirConvsRes.data && theirConvsRes.data.length) {
            targetConvId = theirConvsRes.data[0].conversation_id;
          }
        }

        if (!targetConvId) {
          var newConvRes = await sb.from('conversations').insert({ type: 'direct', created_by: customerUserId }).select().single();
          if (newConvRes.data) {
            targetConvId = newConvRes.data.id;
            await sb.from('conversation_members').insert([
              { conversation_id: targetConvId, user_id: customerUserId },
              { conversation_id: targetConvId, user_id: targetMerchantId }
            ]);
          }
        }

        if (targetConvId) {
          var weavoMsg = '📦 **AllERP नवीन ऑनलाईन ऑर्डर**\n\n' +
                         '🛒 **तपशील:** ' + itemsSummaryText + '\n' +
                         '💰 **एकूण रक्कम:** ₹' + totalAmt.toFixed(2) + '\n' +
                         '🔐 **सुरक्षा OTP:** ' + orderOtp + '\n' +
                         '📍 **पत्ता:** ' + address + '\n' +
                         '📱 **मोबाईल:** ' + phone + '\n\n' +
                         'ही ऑर्डर यशस्वीरीत्या नोंदवली गेली आहे.';

          await sb.from('messages').insert({
            conversation_id: targetConvId,
            sender_id: customerUserId,
            content: weavoMsg
          });
        }
      }
    }

    alert('🎉 ऑर्डर यशस्वीरीत्या नोंदवली गेली, सुरक्षित OTP जनरेट झाला आणि Weavo चॅटमध्ये पाठवला गेला!');
    cart = [];
    localStorage.removeItem('all_erp_cart');
    updateCartUI();
    if (typeof closeModal === 'function') closeModal('customer-cart-modal');
    if (typeof openWeavoChat === 'function') openWeavoChat();
  } catch (err) {
    console.error('Order process error:', err);
    alert('ऑर्डर प्रक्रिया करताना त्रुटी आली. कृपया पुन्हा प्रयत्न करा.');
  }
}
