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
    localStorage.setItem('marketplace_cart', cartString); // दोन्ही की सेफ ठेवल्या आहेत
    
    // नेव्हिगेशन बारमधील काऊंट जागेवरच अपडेट करणे
    if (typeof renderNav === 'function') {
      renderNav();
    }
  } catch (e) {
    console.error('Error saving cart to localStorage:', e);
  }
}

// नवीन प्रॉडक्ट कार्टमध्ये ॲड करणे (किंवा आधीच असल्यास क्वांटिटी वाढवणे)
function addToCart(product) {
  let cart = getCart();
  
  // शोधणे की हेच प्रॉडक्ट त्याच दुकानदाराकडून आधीच कार्टमध्ये आहे का
  const existingIndex = cart.findIndex(
    item => String(item.business_product_id) === String(product.business_product_id) && String(item.business_id) === String(product.business_id)
  );

  const addQty = Number(product.quantity) || 1;

  if (existingIndex > -1) {
    // असल्यास क्वांटिटी वाढवणे
    cart[existingIndex].quantity = (Number(cart[existingIndex].quantity) || 1) + addQty;
  } else {
    // नसल्यास नवीन आयटम जोडणे
    cart.push({
      business_product_id: product.business_product_id,
      name: product.name,
      business_id: product.business_id,
      business_name: product.business_name,
      price: Number(product.price) || 0,
      quantity: addQty
    });
  }

  // सेव्ह केल्यावर आपोआप नेव्हिगेशन बार अपडेट होईल
  saveCart(cart);
}

// कार्टमधील एकूण आयटमची संख्या मिळवणे
function getCartCount() {
  const cart = getCart();
  return cart.reduce((sum, item) => sum + (Number(item.quantity) || 1), 0);
}

// 🛡️ सुरक्षित इन-ॲप ऑर्डर सबमिट करण्याची पद्धत (WhatsApp नंबर एक्सचेंज पूर्णपणे बंद)
async function submitSecurePlatformOrder(orderDetails) {
  try {
    const cart = getCart();
    if (!cart || cart.length === 0) {
      alert('तुमची कार्ट रिकामी आहे!');
      return false;
    }

    // एका ऑर्डरजवळ सर्व प्रॉडक्ट्सचा समरी मजकूर तयार करणे
    let itemsSummary = cart.map(i => `${i.name} (×${i.quantity})`).join(', ');
    let totalAmount = cart.reduce((sum, i) => sum + (Number(i.price) * Number(i.quantity)), 0);
    let businessId = cart[0].business_id; // संबंधित दुकानदाराचा ID

    // Supabase मधील orders टेबलमध्ये डेटा इन्सर्ट करणे (नंबर मास्किंग आणि प्रायव्हसीसह)
    const { data: { user } } = await sb.auth.getUser();
    
    const orderPayload = {
      business_id: businessId,
      customer_name: orderDetails.customerName || 'Verified Buyer',
      customer_phone: orderDetails.customerPhone || 'Masked-Secure-ID',
      delivery_address: orderDetails.deliveryAddress || 'Local Platform Delivery Hub',
      items_summary: itemsSummary,
      total_amount: totalAmount,
      payment_method: orderDetails.paymentMethod || 'COD',
      status: 'pending',
      customer_user_id: user ? user.id : null
    };

    const { error } = await sb.from('orders').insert([orderPayload]);

    if (error) {
      alert('ऑर्डर सेव्ह करताना अडचण आली: ' + error.message);
      return false;
    }

    // यशस्वीरित्या ऑर्डर नोंदवल्यावर कार्ट रिकामी करणे
    localStorage.removeItem('cart');
    localStorage.removeItem('marketplace_cart');
    saveCart([]);

    alert('✅ ऑर्डर सुरक्षितपणे नोंदवली गेली आहे! दुकानदाराने ती स्वीकारताच तुम्हाला सिस्टीममध्ये अपडेट मिळेल.');
    window.location.href = 'index.html'; // होमपेजवर री-डाइरेक्ट करणे
    return true;

  } catch (err) {
    console.error('Secure order error:', err);
    alert('त्रुटी: ' + err.message);
    return false;
  }
}
