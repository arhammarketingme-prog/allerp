// ==========================================
// BUSINESS SUPER PLATFORM - CART ENGINE (js/cart.js)
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

// 🌟 नवीन प्रॉडक्ट कार्टमध्ये ॲड करताना दुकानदाराचा युजरनेम व ईमेल सोबत साठवणे
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
      // 🌟 मर्चंटची अचूक माहिती कार्टमध्ये कॅरी करणे
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

// 🛡️ सुरक्षित इन-ॲप ऑर्डर सबमिट करण्याची पद्धत व वीव्हो चॅट सिंक
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

    let itemsSummary = cart.map(i => `${i.name} (×${i.quantity})`).join(', ');
    let totalAmount = cart.reduce((sum, i) => sum + (Number(i.price) * Number(i.quantity)), 0);
    let businessId = cart[0].business_id;
    
    // 🌟 कार्टमधील पहिल्या प्रॉडक्टवरून संबंधित दुकानदाराचा युजरनेम व ईमेल मिळवणे
    let targetHandle = cart[0].merchant_handle;
    let targetEmail = cart[0].merchant_email;

    // जर कार्टमध्ये थेट नसेल, तर businesses टेबलवरून फेच करणे
    if ((!targetHandle || !targetEmail) && businessId) {
      const { data: bizData } = await sb.from('businesses')
        .select('owner_username, owner_email')
        .eq('id', businessId)
        .maybeSingle();
      
      if (bizData) {
        targetHandle = targetHandle || bizData.owner_username;
        targetEmail = targetEmail || bizData.owner_email;
      }
    }

    const orderPayload = {
      business_id: businessId,
      customer_name: orderDetails.customerName || 'Verified Buyer',
      customer_phone: orderDetails.customerPhone || 'Masked-Secure-ID',
      delivery_address: orderDetails.deliveryAddress || 'Local Platform Delivery Hub',
      items_summary: itemsSummary,
      total_amount: totalAmount,
      payment_method: orderDetails.paymentMethod || 'COD',
      status: 'pending',
      customer_user_id: user.id
    };

    const { error } = await sb.from('orders').insert([orderPayload]);

    if (error) {
      alert('ऑर्डर सेव्ह करताना अडचण आली: ' + error.message);
      return false;
    }

    // 🌟 वीव्हो चॅटमध्ये अचूक मर्चंटच्या कनव्हर्सेशनमध्ये ऑर्डर मेसेज पाठवणे
    if (targetEmail || targetHandle) {
      try {
        let targetMerchantId = null;
        const { data: prof } = await sb.from('profiles')
          .select('id')
          .or(`email.ilike.${targetEmail},username.ilike.${targetHandle}`)
          .maybeSingle();
        
        if (prof) targetMerchantId = prof.id;

        if (targetMerchantId) {
          let targetConvId = null;
          const { data: myConvs } = await sb.from('conversation_members').select('conversation_id').eq('user_id', user.id);
          const myIds = (myConvs || []).map(r => r.conversation_id);
          
          if (myIds.length) {
            const { data: theirConvs } = await sb.from('conversation_members').select('conversation_id').eq('user_id', targetMerchantId).in('conversation_id', myIds);
            if (theirConvs && theirConvs.length) targetConvId = theirConvs[0].conversation_id;
          }

          if (!targetConvId) {
            const { data: newConv } = await sb.from('conversations').insert({ type: 'direct', created_by: user.id }).select().single();
            if (newConv) {
              targetConvId = newConv.id;
              await sb.from('conversation_members').insert([
                { conversation_id: targetConvId, user_id: user.id },
                { conversation_id: targetConvId, user_id: targetMerchantId }
              ]);
            }
          }

          if (targetConvId) {
            const orderMsgText = `📦 नवीन ऑनलाईन ऑर्डर:\n👤 ग्राहक: ${orderPayload.customer_name}\n📱 मोबाईल: ${orderPayload.customer_phone}\n🏠 पत्ता: ${orderPayload.delivery_address}\n🛒 तपशील: ${itemsSummary}\n💰 एकूण: ₹${totalAmount}`;
            await sb.from('messages').insert({
              conversation_id: targetConvId,
              sender_id: user.id,
              content: orderMsgText
            });
          }
        }
      } catch (bridgeErr) {
        console.error('Weavo bridge sync note:', bridgeErr);
      }
    }

    localStorage.removeItem('cart');
    localStorage.removeItem('marketplace_cart');
    saveCart([]);

    alert('✅ ऑर्डर सुरक्षितपणे नोंदवली गेली आहे आणि दुकानदाराच्या वीव्हो चॅटवर पाठवली गेली आहे!');
    
    // योग्य मर्चंटच्या युजरनेमसह वीव्हो चॅट उघडणे
    if (targetHandle) {
      window.open(`https://arhammarketingme-prog.github.io/weavo/?store=${encodeURIComponent(targetHandle)}${targetEmail ? '&merchant_email=' + encodeURIComponent(targetEmail) : ''}`, '_blank');
    } else {
      window.location.href = 'index.html';
    }
    
    return true;

  } catch (err) {
    console.error('Secure order error:', err);
    alert('त्रुटी: ' + err.message);
    return false;
  }
}
