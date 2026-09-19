# ALL ERP — Business Operating System

> **«One Login → One Business → One ERP → All Business Operations»**

ALL ERP is a comprehensive, modular, AI-first Business Operating System designed for Indian small & medium businesses, retail shops, contractors, manufacturers, distributors, bakeries, service providers, and multi-branch companies.

---

## 🚀 Key Modules & Capabilities

1. **Dashboard & KPIs:** Today's Sales, Purchases, Gross Profit, Receivables, Payables, Stock Value, Live alerts.
2. **Smart Business Profile Engine:** Automatic configuration of modules based on business type (Kirana, Contractor, Bakery, Manufacturing, Restaurant, Services, Healthcare, Retail).
3. **Sales & GST Invoicing:** Quotations, Orders, Tax Invoices (CGST+SGST+IGST), PDF Print, WhatsApp sharing, Payment status.
4. **Inventory & Warehouse:** Real-time stock movements, low stock alerts, image upload, direct marketplace live sync.
5. **Purchases & Suppliers:** Purchase Orders (PO), vendor bills, procurement tracking.
6. **CRM & Lead Pipeline:** Pipeline stages (New → Contacted → Qualified → Proposal → Negotiation → Won), customer directory.
7. **Finance & Accounting:** Category-wise expense tracking (Transport, Electricity, Rent, Salary), ledger entries.
8. **HR & Payroll:** Employee management, attendance, salary structures, payroll records.
9. **Projects & Contractor ERP:** Construction sites, BOQ items, budget tracking, actual costs, running bills.
10. **Manufacturing & Recipes:** Bill of Materials (BOM), production orders, raw material costing.
11. **Quick POS Counter:** Fast product search, barcode-ready, cart calculation, cash/UPI receipt generation.
12. **eCommerce & Marketplace:** Integrated consumer storefront, multi-vendor cart, order split, real-time status.
13. **AI Business Assistant:** In-app business intelligence for sales summary, low stock queries, profit analysis, and WhatsApp offer generator.
14. **Document Vault & Reports Center:** Universal CSV exports, tax summaries, secure document attachments.

---

## 📦 Database & Migrations Setup (Supabase)

Run the SQL files in `supabase-migrations/` in sequential order:

- `0001_core_schema.sql` to `0016_ad_types_audio_poster.sql` — Core platform tables & RLS
- `0017_setup_storage_buckets.sql` — Ads & Product Media storage buckets
- `0018_auto_cleanup_expired_ads.sql` — Automatic expired ads cleanup
- `0019_public_ads_rls.sql` — Anonymous marketplace ads visibility
- `0020_all_erp_comprehensive_schema.sql` — Complete modular ERP tables (CRM, Invoices, PO, Expenses, HR, Projects, BOM, POS, Documents)

---

## 🌐 Zero-Build Static Deployment (GitHub Pages)

- **Tech Stack:** Vanilla HTML5, CSS3, ES6+ JavaScript, Supabase CDN.
- **Zero Build Step:** Works directly on GitHub Pages by serving the repository root.
- **Multi-Language:** English, Marathi (मराठी), and Hindi (हिन्दी).
