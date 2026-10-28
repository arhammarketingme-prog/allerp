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
      quantity: addQty
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
    // Supabase द्वारे युजर सेशन पक्के तपासणे
    const { data: { user } } = await sb.auth.getUser();
    
    if (!user) {
      alert('⚠️ सुरक्षा नियम: ऑर्डर करण्यासाठी आणि खरेदी पूर्ण करण्यासाठी ऑल ईआरपीवर लॉगिन करणे बंधनकारक आहे!');
      window.location.href = 'login.html';
      return;
    }

    // लॉगिन असेल तरच पुढील चेकआउट मॉडेल उघडणे
    if (typeof openModalCallback === 'function') {
      openModalCallback(grandTotal);
    }
  } catch (err) {
    console.error('Login enforcement error:', err);
    window.location.href = 'login.html';
  }
}

// 🛡️ सुरक्षित इन-ॲप ऑर्डर सबमिट करण्याची पद्धत
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

    localStorage.removeItem('cart');
    localStorage.removeItem('marketplace_cart');
    saveCart([]);

    alert('✅ ऑर्डर सुरक्षितपणे नोंदवली गेली आहे! दुकानदाराने ती स्वीकारताच तुम्हाला सिस्टीममध्ये अपडेट मिळेल.');
    window.location.href = 'index.html';
    return true;

  } catch (err) {
    console.error('Secure order error:', err);
    alert('त्रुटी: ' + err.message);
    return false;
  }
}
