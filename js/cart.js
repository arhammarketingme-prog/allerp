// ==========================================
// ALL ERP — SPLIT ORDER & SECURE CART ENGINE (js/cart.js)
// ==========================================

// कार्टमधील सर्व आयटम्स मिळवणे
function getCart() {
  try {
    const cartData = localStorage.getItem('marketplace_cart') || localStorage.getItem('cart');
    return cartData ? JSON.parse(cartData) : [];
  } catch (e) {
    console.error('Error reading cart from localStorage:', e);
    return [];
  }
}

// कार्ट सेव्ह करणे आणि सर्व पेजेसवर नेव्हिगेशन बारचा काऊंट तात्काळ अपडेट करणे
function saveCart(cart) {
  try {
    const cartString = JSON.stringify(cart);
    localStorage.setItem('cart', cartString);
    localStorage.setItem('marketplace_cart', cartString);
    
    if (typeof renderNav === 'function') {
      renderNav();
    }
  } catch (e) {
    console.error('Error saving cart to localStorage:', e);
  }
}

// नवीन प्रॉडक्ट कार्टमध्ये ॲड करणे
function addToCart(product) {
  let cart = getCart();
  
  const existingIndex = cart.findIndex(
    item => String(item.business_product_id) === String(product.business_product_id) && String(item.business_id) === String(product.business_id)
  );

  const addQty = Number(product.quantity) || 1;

  if (existingIndex > -1) {
    cart[existingIndex].quantity = (Number(cart[existingIndex].quantity) || 1) + addQty;
  } else {
    cart.push({
      business_product_id: product.business_product_id,
      name: product.name,
      business_id: product.business_id,
      business_name: product.business_name,
      price: Number(product.price) || 0,
      quantity: addQty,
      merchant_handle: product.merchant_handle || product.owner_username || '',
      merchant_email: product.merchant_email || product.owner_email || ''
    });
  }

  saveCart(cart);
  alert('✅ "' + (product.name || 'प्रॉडक्ट') + '" यशस्वीरीत्या कार्टमध्ये समाविष्ट केले गेले!');
}

function getCartCount() {
  const cart = getCart();
  return cart.reduce((sum, item) => sum + (Number(item.quantity) || 1), 0);
}

// 🛡️ चेकआउट उघडण्यापूर्वी कडक लॉगिन तपासणी (Login Enforcement Check)
async function enforceLoginBeforeCheckout(grandTotal, openModalCallback) {
  try {
    const { data: { user } } = await sb.auth.getUser();
    
    if (!user) {
      alert('⚠️ सुरक्षा नियम: ऑर्डर करण्यासाठी आणि खरेदी पूर्ण करण्यासाठी ऑल ईआरपीवर लॉगिन करणे बंधनकारक आहे!');
      window.location.href = 'login.html';
      return;
    }

    if (typeof openModalCallback === 'function') {
      openModalCallback(grandTotal);
    }
  } catch (err) {
    console.error('Login enforcement error:', err);
    window.location.href = 'login.html';
  }
}

// 🌟 मल्टि-वेंडर स्प्लिट ऑर्डर लॉजिकसह सुरक्षित इन-ॲप ऑर्डर सबमिट करण्याची पद्धत
async function submitSecurePlatformOrder(orderDetails) {
  try {
    const cart = getCart();
    if (!cart || cart.length === 0) {
      alert('तुमची कार्ट रिकामी आहे!');
      return false;
    }

    const { data: { user } } = await sb.auth.getUser();
    if (!user) {
      alert('⚠️ कृपया ऑर्डर करण्यासाठी आधी लॉगिन करा!');
      window.location.href = 'login.html';
      return false;
    }

    // १. कार्टमधील प्रॉडक्ट्सना संबंधित दुकानदारांनुसार (Business ID नुसार) स्वयंचलितपणे स्वतंत्र ग्रुप्समध्ये स्प्लिट करणे
    let merchantGroups = {};
    cart.forEach(item => {
      let bId = item.business_id;
      if (!bId) return;
      if (!merchantGroups[bId]) {
        merchantGroups[bId] = {
          business_id: bId,
          items: []
        };
      }
      merchantGroups[bId].items.push(item);
    });

    let groupKeys = Object.keys(merchantGroups);
    if (groupKeys.length === 0) {
      alert('त्रुटी: कार्टमधील प्रॉडक्ट्सशी कोणतेही वैध दुकान जोडलेले नाही.');
      return false;
    }

    // २. प्रत्येक दुकानदारासाठी स्वतंत्र ऑर्डर तयार करून Supabase मध्ये सेव्ह करणे व त्यांच्या अचूक चॅ트에 पाठवणे
    for (let bId of groupKeys) {
      let group = merchantGroups[bId];
      let itemsSummary = group.items.map(i => `${i.name} (×${i.quantity})`).join(', ');
      let totalAmount = group.items.reduce((sum, i) => sum + (Number(i.price) * Number(i.quantity)), 0);

      // प्रत्येक दुकानाची खरी माहिती थेट businesses टेबलमधून फेच करणे
      let { data: bizData } = await sb.from('businesses')
        .select('id, owner_id, owner_username, owner_email, name, slug')
        .eq('id', bId)
        .maybeSingle();

      let targetMerchantUserId = bizData ? bizData.owner_id : null;
      let targetHandle = bizData ? (bizData.owner_username || bizData.slug) : 'store';
      let targetEmail = bizData ? bizData.owner_email : '';

      const orderPayload = {
        business_id: bId,
        customer_name: orderDetails.customerName || 'Verified Buyer',
        customer_phone: orderDetails.customerPhone || 'Masked-Secure-ID',
        delivery_address: orderDetails.deliveryAddress || 'Local Platform Delivery Hub',
        items_summary: itemsSummary,
        total_amount: totalAmount,
        payment_method: orderDetails.paymentMethod || 'COD',
        status: 'pending',
        customer_user_id: user.id
      };

      // ऑल ईआरपीच्या orders टेबलमध्ये स्वतंत्र ऑर्डर इन्सर्ट करणे
      const { error: orderErr } = await sb.from('orders').insert([orderPayload]);
      if (orderErr) {
        console.error('Order insert error for business ' + bId, orderErr.message);
        continue;
      }

      // ३. योग्य दुकानदाराच्या युजर प्रोफाईलशी अचूक मॅच करून वीव्हो चॅट कनव्हर्सेशन तयार करणे
      if (targetMerchantUserId || targetEmail || targetHandle) {
        try {
          if (!targetMerchantUserId && targetEmail) {
            let { data: prof } = await sb.from('profiles').select('id').eq('email', targetEmail).maybeSingle();
            if (prof) targetMerchantUserId = prof.id;
          }
          if (!targetMerchantUserId && targetHandle) {
            let { data: prof } = await sb.from('profiles').select('id').ilike('username', targetHandle).maybeSingle();
            if (prof) targetMerchantUserId = prof.id;
          }

          if (targetMerchantUserId) {
            let targetConvId = null;
            let { data: myConvs } = await sb.from('conversation_members').select('conversation_id').eq('user_id', user.id);
            let myIds = (myConvs || []).map(r => r.conversation_id);

            if (myIds.length) {
              let { data: theirConvs } = await sb.from('conversation_members').select('conversation_id').eq('user_id', targetMerchantUserId).in('conversation_id', myIds);
              if (theirConvs && theirConvs.length) targetConvId = theirConvs[0].conversation_id;
            }

            if (!targetConvId) {
              let { data: newConv } = await sb.from('conversations').insert({ type: 'direct', created_by: user.id }).select().single();
              if (newConv) {
                targetConvId = newConv.id;
                await sb.from('conversation_members').insert([
                  { conversation_id: targetConvId, user_id: user.id },
                  { conversation_id: targetConvId, user_id: targetMerchantUserId }
                ]);
              }
            }

            if (targetConvId) {
              let shopNameTitle = bizData ? bizData.name : 'Store';
              let orderMsgText = `📦 नवीन ऑनलाईन ऑर्डर (दुकान: ${shopNameTitle}):\n👤 ग्राहक: ${orderPayload.customer_name}\n📱 मोबाईल: ${orderPayload.customer_phone}\n🏠 पत्ता: ${orderPayload.delivery_address}\n🛒 तपशील: ${itemsSummary}\n💰 एकूण: ₹${totalAmount}`;
              await sb.from('messages').insert({
                conversation_id: targetConvId,
                sender_id: user.id,
                content: orderMsgText
              });
            }
          }
        } catch (bridgeErr) {
          console.error('Weavo split sync note:', bridgeErr);
        }
      }
    }

    localStorage.removeItem('cart');
    localStorage.removeItem('marketplace_cart');
    saveCart([]);

    alert('✅ सर्व दुकानांच्या ऑर्डर्स यशस्वीरीत्या स्प्लिट होऊन संबंधित दुकानदारांपर्यंत पोहोचल्या आहेत!');
    window.location.href = 'index.html';
    return true;

  } catch (err) {
    console.error('Secure order error:', err);
    alert('त्रुटी: ' + err.message);
    return false;
  }
}
