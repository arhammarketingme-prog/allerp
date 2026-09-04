// ALL ERP — Unified Business Operating System Engine
// Supports 10 Indian Languages, Smart Profiles, Multi-Company, Global Search, and Demo Mode

const ALL_ERP = {
  currentLanguage: localStorage.getItem('allerp_lang') || 'mr', // default to Marathi / English
  currentBusinessId: null,
  currentBusinessType: 'grocery',
  isDemoMode: false,

  // 1. SMART BUSINESS MODULE PROFILE MATRIX
  PROFILES: {
    'grocery': {
      name: 'Grocery / Kirana',
      modules: ['dashboard', 'pos', 'inventory', 'sales', 'purchase', 'accounting', 'customers', 'suppliers', 'ai_assistant', 'reports', 'settings']
    },
    'contractor': {
      name: 'Contractor & Construction',
      modules: ['dashboard', 'contractor', 'projects', 'tasks', 'purchase', 'accounting', 'employees', 'documents', 'customers', 'suppliers', 'reports', 'settings']
    },
    'manufacturing': {
      name: 'Manufacturing & Industry',
      modules: ['dashboard', 'manufacturing', 'inventory', 'purchase', 'sales', 'accounting', 'employees', 'quality', 'reports', 'settings']
    },
    'bakery': {
      name: 'Bakery & Food Processing',
      modules: ['dashboard', 'manufacturing', 'pos', 'inventory', 'sales', 'purchase', 'accounting', 'reports', 'settings']
    },
    'restaurant': {
      name: 'Restaurant & Cafe',
      modules: ['dashboard', 'pos', 'inventory', 'purchase', 'accounting', 'employees', 'reports', 'settings']
    },
    'services': {
      name: 'Services & Consultancy',
      modules: ['dashboard', 'crm', 'services', 'appointments', 'sales', 'accounting', 'documents', 'reports', 'settings']
    },
    'healthcare': {
      name: 'Medical & Clinic',
      modules: ['dashboard', 'inventory', 'pos', 'appointments', 'sales', 'purchase', 'accounting', 'reports', 'settings']
    },
    'retail': {
      name: 'Retail & Electronics',
      modules: ['dashboard', 'pos', 'inventory', 'sales', 'purchase', 'ecommerce', 'accounting', 'reports', 'settings']
    },
    'default': {
      name: 'Standard Business',
      modules: ['dashboard', 'crm', 'sales', 'purchase', 'inventory', 'accounting', 'hr', 'projects', 'pos', 'ecommerce', 'services', 'documents', 'reports', 'ai_assistant', 'settings']
    }
  },

  // 2. MULTI-LANGUAGE TRANSLATIONS (English, Marathi, Hindi)
  TRANSLATIONS: {
    en: {
      appName: "ALL ERP",
      tagline: "One Login → One Business → All Business Operations",
      dashboard: "Dashboard",
      crm: "CRM & Leads",
      sales: "Sales & Invoices",
      purchase: "Purchases",
      inventory: "Inventory & Stock",
      accounting: "Finance & Accounting",
      hr: "HR & Payroll",
      projects: "Projects & Tasks",
      contractor: "Contractor ERP",
      manufacturing: "Manufacturing & BOM",
      pos: "Quick POS",
      ecommerce: "eCommerce Store",
      services: "Services & Helpdesk",
      appointments: "Appointments",
      documents: "Document Vault",
      reports: "Reports Center",
      ai_assistant: "AI Business Assistant",
      settings: "Settings",
      today_sales: "Today's Sales",
      today_purchase: "Today's Purchases",
      gross_profit: "Gross Profit",
      receivables: "Receivables (येणे)",
      payables: "Payables (देणे)",
      stock_value: "Total Stock Value",
      low_stock_items: "Low Stock Items",
      pending_orders: "Pending Orders",
      create_invoice: "+ New Invoice",
      create_lead: "+ New Lead",
      create_expense: "+ Add Expense",
      create_product: "+ Add Product",
      search_placeholder: "Global Search (Invoices, Customers, Products, Projects...)",
      demo_badge: "DEMO DATA ACTIVE",
      export_csv: "Export CSV",
      print_pdf: "Print Invoice",
      whatsapp_share: "Share on WhatsApp"
    },
    mr: {
      appName: "ALL ERP",
      tagline: "एक लॉगिन → एक व्यवसाय → सर्व व्यवसाय ऑपरेशन्स",
      dashboard: "मुख्य डॅशबोर्ड",
      crm: "ग्राहक संपर्क व लीड्स (CRM)",
      sales: "विक्री व जीएसटी बिलिंग",
      purchase: "खरेदी व पुरवठादार",
      inventory: "इन्व्हेंटरी व स्टॉक",
      accounting: "हिशोब व जमा-खर्च",
      hr: "कर्मचारी व पगार (HR)",
      projects: "प्रकल्प व कामांची यादी",
      contractor: "कंत्राटदार ईआरपी (Site ERP)",
      manufacturing: "उत्पादन व रेसिपी (BOM)",
      pos: "काउंटर पीओएस (Quick POS)",
      ecommerce: "ऑनलाइन दुकान (Store)",
      services: "सेवा व तक्रार निवारण",
      appointments: "अपॉइंटमेंट्स व बुकिंग",
      documents: "कागदपत्रे (Documents)",
      reports: "अहवाल केंद्र (Reports)",
      ai_assistant: "एआय बिझनेस असिस्टंट",
      settings: "सेटिंग्ज व भाषा",
      today_sales: "आजची एकूण विक्री",
      today_purchase: "आजची एकूण खरेदी",
      gross_profit: "अंदाजे निव्वळ नफा",
      receivables: "बाजार येणे (Receivables)",
      payables: "देणी रक्कम (Payables)",
      stock_value: "एकूण मालाचे मूल्य",
      low_stock_items: "कमी स्टॉक असलेले माल",
      pending_orders: "प्रलंबित ऑर्डर्स",
      create_invoice: "+ नवीन जीएसटी बिल",
      create_lead: "+ नवीन ग्राहक लीड",
      create_expense: "+ नवीन खर्च जोडा",
      create_product: "+ नवीन उत्पादन जोडा",
      search_placeholder: "सर्व शोधा (बिल, ग्राहक, माल, साईट, प्रोजेक्ट...)",
      demo_badge: "डेमो डेटा सुरू आहे",
      export_csv: "एक्सेल/CSV डाउनलोड",
      print_pdf: "बिल प्रिंट करा",
      whatsapp_share: "व्हॉट्सॲपवर पाठवा"
    },
    hi: {
      appName: "ALL ERP",
      tagline: "एक लॉगिन → एक व्यापार → सभी बिजनेस ऑपरेशन्स",
      dashboard: "डैशबोर्ड",
      crm: "लीड्स और ग्राहक (CRM)",
      sales: "बिक्री और इनवॉइस",
      purchase: "खरीद प्रबंधन",
      inventory: "स्टॉक और इन्वेंटरी",
      accounting: "लेखा और खर्च",
      hr: "कर्मचारी और वेतन (HR)",
      projects: "प्रोजेक्ट और कार्य",
      contractor: "ठेकेदार ईआरपी",
      manufacturing: "उत्पादन और बीओएम",
      pos: "त्वरित पीओएस (POS)",
      ecommerce: "ऑनलाइन स्टोर",
      services: "सेवा और हेल्पडेस्क",
      appointments: "अपॉइंटमेंट्स",
      documents: "दस्तावेज़ तिजोरी",
      reports: "रिपोर्ट्स केंद्र",
      ai_assistant: "एआई बिजनेस सहायक",
      settings: "सेटिंग्स",
      today_sales: "आज की बिक्री",
      today_purchase: "आज की खरीद",
      gross_profit: "सकल लाभ",
      receivables: "उधारी वसूली (Receivables)",
      payables: "देनदारी (Payables)",
      stock_value: "कुल स्टॉक मूल्य",
      low_stock_items: "कम स्टॉक सामग्री",
      pending_orders: "लंबित ऑर्डर",
      create_invoice: "+ नया बिल बनाएं",
      create_lead: "+ नई लीड",
      create_expense: "+ खर्च दर्ज करें",
      create_product: "+ उत्पाद जोड़ें",
      search_placeholder: "यूनिवर्सल सर्च (बिल, ग्राहक, उत्पाद, प्रोजेक्ट...)",
      demo_badge: "डेमो डेटा सक्रिय",
      export_csv: "CSV डाउनलोड",
      print_pdf: "बिल प्रिंट करें",
      whatsapp_share: "व्हाट्सएप पर भेजें"
    }
  },

  // 3. INDIAN CURRENCY & NUMBER FORMATTER (₹ Lakhs & Crores)
  formatINR: function(num) {
    const val = Number(num) || 0;
    return '₹' + val.toLocaleString('en-IN', { maximumFractionDigits: 2 });
  },

  t: function(key) {
    const lang = this.currentLanguage;
    return (this.TRANSLATIONS[lang] && this.TRANSLATIONS[lang][key]) || this.TRANSLATIONS['en'][key] || key;
  },

  setLanguage: function(lang) {
    this.currentLanguage = lang;
    localStorage.setItem('allerp_lang', lang);
    location.reload();
  },

  // 4. REALISTIC DEMO DATASET (Ensures ZERO Empty or Broken Screens)
  DEMO_DATA: {
    businessName: "ALL Demo Enterprise",
    businessType: "contractor", // rich multi-module preview
    stats: {
      todaySales: 48500,
      todayPurchases: 18200,
      grossProfit: 30300,
      receivables: 245000,
      payables: 89000,
      stockValue: 642000,
      lowStockCount: 3,
      pendingOrdersCount: 4
    },
    invoices: [
      { id: 'INV-2026-001', customer: 'M/s Patil Constructions', amount: 84500, paid: 50000, status: 'partially_paid', date: '2026-08-20' },
      { id: 'INV-2026-002', customer: 'Aditya Infotech Pune', amount: 32000, paid: 32000, status: 'paid', date: '2026-08-21' },
      { id: 'INV-2026-003', customer: 'Suresh Kirana & General', amount: 15400, paid: 0, status: 'unpaid', date: '2026-08-22' }
    ],
    crmLeads: [
      { name: 'Rameshwar Pawar', company: 'Pawar Enterprises', phone: '9822012345', stage: 'proposal', value: 150000 },
      { name: 'Snehal Deshmukh', company: 'Green Agro Logistics', phone: '9422567890', stage: 'negotiation', value: 320000 },
      { name: 'Kiran Jadhav', company: 'Shivaji Chowk Project', phone: '9158011223', stage: 'new', value: 85000 }
    ],
    projects: [
      { name: 'Commercial Complex Phase 1 - Satara', client: 'T.A. Pawar Group', budget: 1850000, actual: 920000, billed: 1200000, status: 'in_progress' },
      { name: 'Warehouse Construction - Koregaon', client: 'Kisan Agro Seed Corp', budget: 750000, actual: 340000, billed: 450000, status: 'in_progress' }
    ],
    employees: [
      { name: 'Aniket Shinde', designation: 'Site Supervisor', phone: '9822334455', salary: 35000, status: 'present' },
      { name: 'Pooja Kulkarni', designation: 'Accountant', phone: '9766112233', salary: 28000, status: 'present' },
      { name: 'Santosh Kamble', designation: 'Machine Operator', phone: '9921445566', salary: 22000, status: 'present' }
    ],
    expenses: [
      { category: 'Transport', title: 'Cement & Sand Delivery Logistics', amount: 4500, mode: 'UPI', date: '2026-08-22' },
      { category: 'Electricity', title: 'Site Office Power Bill', amount: 3200, mode: 'Bank Transfer', date: '2026-08-21' },
      { category: 'Maintenance', title: 'Excavator & JCB Servicing', amount: 8500, mode: 'Cash', date: '2026-08-20' }
    ]
  }
};

window.ALL_ERP = ALL_ERP;
