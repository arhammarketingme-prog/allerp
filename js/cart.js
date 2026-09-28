/**
 * Cart Management & Weavo Portal Integration
 * 'Buy Now' action mechanism
 */

document.addEventListener('DOMContentLoaded', () => {
    const buyNowBtn = document.querySelector('#buy-now-btn, .buy-now-btn, [data-action="buy-now"]');
    
    if (buyNowBtn) {
        buyNowBtn.addEventListener('click', handleBuyNow);
    }
});

function getCartData() {
    // तुमच्या मूळ कार्ट स्ट्रक्चरनुसार डेटा गोळा करणे
    try {
        const cartItems = JSON.parse(localStorage.getItem('cart')) || [];
        const cartTotal = localStorage.getItem('cartTotal') || 0;
        
        return {
            items: cartItems,
            total: cartTotal,
            timestamp: new Date().toISOString()
        };
    } catch (error) {
        console.error('Cart data read error:', error);
        return { items: [], total: 0 };
    }
}

function handleBuyNow(event) {
    if (event) event.preventDefault();

    const cartData = getCartData();
    
    if (!cartData.items || cartData.items.length === 0) {
        alert('तुमची कार्ट खाली आहे! कृपया आधी उत्पादने जोडा.');
        return;
    }

    // वेव्हो पोर्टलचा बेस URL (आवश्यकतेनुसार बदलू शकता)
    const weavoPortalUrl = 'https://weavo.portal/checkout'; 

    // डेटा एनकोड करून युआरएल पॅरामीटर किंवा सेशन स्टोरेजद्वारे पाठवणे
    const encodedData = encodeURIComponent(JSON.stringify(cartData));
    
    // वैकल्पिक: सुरक्षित ट्रान्सफरसाठी sessionStorage वापरणे
    sessionStorage.setItem('weavo_checkout_payload', JSON.stringify(cartData));

    // वेव्हो पोर्टलवर रीडायरेक्ट करणे
    window.location.href = `${weavoPortalUrl}?data=${encodedData}`;
}
