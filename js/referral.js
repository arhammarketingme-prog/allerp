// ==========================================
// ALL ERP - Clean & Direct Referral Engine
// ==========================================

// URL मधून ?ref= कोड शोधून localStorage मध्ये सेव्ह करणे
function captureReferral() {
  const params = new URLSearchParams(window.location.search);
  const ref = params.get('ref');
  if (ref) {
    localStorage.setItem('bsp_referral_code', ref);
  }
}

// सेव्ह असलेला रेफरल कोड मिळवणे
function getStoredReferralCode() {
  return localStorage.getItem('bsp_referral_code') || null;
}

// नवीन व्यवसाय/जाहिरातदार/ग्राहक रजिस्टर झाल्यावर रेफरल कोड जोडणे.
// table: 'businesses' | 'advertisers' | इ., recordId: त्या रेकॉर्डचा id,
// idColumn: recordId कुठल्या कॉलमशी जुळवायचा ('id' डिफॉल्ट, गरज पडल्यास 'user_id').
// टीप: हे फक्त attribution (कोण कोणामुळे आला) साठी आहे — कुठलाही पैसा/कमिशन इथे हलत नाही.
async function attachReferralCode(table, recordId, idColumn = 'id') {
  const refCode = getStoredReferralCode();
  if (!refCode) return;

  try {
    await sb.from(table)
      .update({ referred_by_code: refCode })
      .eq(idColumn, recordId);

    // वापर झाल्यानंतर localStorage साफ करणे
    localStorage.removeItem('bsp_referral_code');
  } catch (err) {
    console.error('Referral attach error:', err);
  }
}

// जुन्या नावाशी सुसंगतता (backward compatibility)
async function attachReferralToNewBusiness(businessId) {
  return attachReferralCode('businesses', businessId, 'id');
}

// युजरसाठी स्वतःची WhatsApp शेअरिंग लिंक तयार करणे
function shareOnWhatsApp(userCode, platformName = 'ALL ERP Platform') {
  const baseUrl = window.location.origin + window.location.pathname.replace(/\/[^\/]*$/, '/login.html');
  const refLink = `${baseUrl}?ref=${userCode}`;
  const message = `🚀 ${platformName} वर तुमचं स्वतःचं डिजिटल दुकान किंवा ERP फ्री मध्ये सुरू करा!\n\nखालील लिंकवर क्लिक करून आजच जॉइन करा:\n${refLink}`;
  const whatsappUrl = `https://wa.me/?text=${encodeURIComponent(message)}`;
  window.open(whatsappUrl, '_blank');
}

// पेज लोड झाल्यावर ऑटोमॅटिक रन होणे
captureReferral();
