# Advertising "Full Mechanism": Location Targeting + Real Sponsored Products

## 1. Supabase वर migration चालव
`0048_location_targeting_sponsored_products.sql`

## 2. GitHub वर replace कर
- `advertiser.html`, `index.html`, `js/nav.js`, `js/ads.js`

## बोनस बग फिक्स
`advertiser.html` मध्ये जाहिरातीचा प्रकार "ऑडिओ" किंवा "पोस्टर" निवडला की
insert **चुपचाप fail** व्हायचा (DB मध्ये हे प्रकार मान्यच नव्हते). आता
दुरुस्त — दोन्ही प्रकार व्यवस्थित सेव्ह होतील.

## १. Location Targeting — आता खरं काम करतं
- Advertiser जाहिरात बनवताना आता "🎯 कुठल्या शहरात दिसावी?" फील्ड भरू
  शकतो (रिकामं ठेवलं तर सर्वत्र दिसेल)
- ग्राहकाला नेव्हबारमध्ये नवीन "📍 शहर" इनपुट दिसेल — तिथे शहर टाकलं की
  फक्त त्या शहरासाठी targeted केलेल्या (किंवा सर्वत्र दाखवायच्या) जाहिराती
  दिसतील

## २. खरं "Sponsored Products" (Amazon/Flipkart सारखं) — नवीन बनवलं
- Advertiser आता "🛒 Sponsored Product" हा नवीन प्रकार निवडून **स्वतःच्या
  दुकानातलं** उत्पादन थेट sponsor करू शकतो — वेगळी फाईल अपलोड करायची
  गरज नाही
- ग्राहकाच्या search/marketplace ग्रिडमध्ये (`index.html`) दर ४ प्रॉडक्ट्सनंतर
  येणाऱ्या "जाहिरात" जागी आता खरं sponsored प्रॉडक्ट (फोटो, नाव, किंमत,
  दुकान — बाकी प्रॉडक्ट्ससारखंच पण "📢 SPONSORED" लेबलसह) दिसेल —
  sponsored प्रॉडक्ट उपलब्ध नसेल तरच आधीसारखी generic बॅनर जाहिरात
  दिसेल
- हे सुद्धा Location Targeting आणि बजेट/frequency-cap नियम पाळतं

## Admin मध्ये काही बदलायची गरज नाही
हे दोन्ही फीचर्स advertiser.html आणि customer-facing पानांवरच काम करतात.
