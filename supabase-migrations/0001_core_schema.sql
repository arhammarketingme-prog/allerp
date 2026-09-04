-- ============================================================================
-- BUSINESS SUPER PLATFORM — CORE SCHEMA (Migration 0001)
-- ============================================================================
-- Design principles this migration enforces:
--   1. Multi-tenant isolation: every business-owned row carries business_id
--      and is protected by Row Level Security (RLS). Frontend is NEVER trusted.
--   2. Starter catalog vs seller catalog are separate tables (industry_products
--      vs business_products) — activating a starter product COPIES it into
--      business_products, it never edits the shared template.
--   3. Marketplace visibility is a generated/derived state (stock > 0 AND
--      is_active), not a manually-set flag that can drift from reality.
--   4. No permanent media storage: image columns are external URLs + license
--      metadata only.
--   5. Platform never touches money: payments_metadata is informational only,
--      no ledger/wallet tables exist for holding funds.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. USERS  (profile row 1:1 with auth.users; auth.users itself is Supabase-managed)
-- ----------------------------------------------------------------------------
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  avatar_url text,
  -- a single person can be a shopkeeper AND an advertiser AND a developer
  is_business_owner boolean not null default false,
  is_advertiser boolean not null default false,
  is_developer boolean not null default false,
  is_partner boolean not null default false,
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.users is 'Profile data for every authenticated person. Role flags gate portal access, not separate accounts.';

-- ----------------------------------------------------------------------------
-- 2. BUSINESS TYPES  (the 100+ industry templates — admin-managed, public read)
-- ----------------------------------------------------------------------------
create table public.business_types (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,              -- 'grocery', 'medical-store', ...
  name_en text not null,
  name_mr text,
  category text,                          -- retail / food / services / real-estate ...
  icon_url text,
  default_modules jsonb not null default '["inventory","sales","purchase","customers","orders","reports"]',
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

comment on table public.business_types is 'The 100+ ERP verticals. default_modules drives which core modules a new business of this type gets enabled.';

-- ----------------------------------------------------------------------------
-- 3. ERP MODULES  (catalog of pluggable modules a template can turn on/off)
-- ----------------------------------------------------------------------------
create table public.erp_modules (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,              -- 'inventory','sales','gst_billing','table_management'...
  name text not null,
  description text,
  is_core boolean not null default false, -- core modules can't be disabled
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 4. ERP TEMPLATES  (per business_type configuration: which modules + custom fields)
-- ----------------------------------------------------------------------------
create table public.erp_templates (
  id uuid primary key default gen_random_uuid(),
  business_type_id uuid not null references public.business_types(id) on delete cascade,
  version int not null default 1,
  enabled_modules jsonb not null default '[]',   -- array of erp_modules.code
  custom_fields jsonb not null default '[]',      -- industry-specific product/order fields
  report_config jsonb not null default '[]',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (business_type_id, version)
);

-- ----------------------------------------------------------------------------
-- 5. BUSINESSES  (the tenant root — every owned table hangs off business_id)
-- ----------------------------------------------------------------------------
create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id) on delete restrict,
  business_type_id uuid not null references public.business_types(id),
  name text not null,
  slug text not null unique,               -- used in /store/:slug public URL
  logo_url text,
  about text,
  address text,
  city text,
  location_lat double precision,
  location_lng double precision,
  contact_phone text,
  contact_whatsapp text,
  working_hours jsonb,
  payment_methods jsonb not null default '[]', -- ['upi','cod','bank_transfer'] — informational only
  is_verified boolean not null default false,   -- admin approval gate
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index businesses_owner_idx on public.businesses(owner_id);
create index businesses_type_idx on public.businesses(business_type_id);

comment on table public.businesses is 'Tenant root. is_verified gates marketplace visibility; owner always has full access via RLS.';

-- ----------------------------------------------------------------------------
-- 6. BUSINESS MEMBERS  (staff access to a business, beyond just the owner)
-- ----------------------------------------------------------------------------
create table public.business_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null default 'staff' check (role in ('owner','manager','staff')),
  created_at timestamptz not null default now(),
  unique (business_id, user_id)
);

-- ----------------------------------------------------------------------------
-- 7. CATEGORIES  (shared taxonomy, admin-managed, public read)
-- ----------------------------------------------------------------------------
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.categories(id),
  name_en text not null,
  name_mr text,
  slug text not null unique,
  business_type_id uuid references public.business_types(id), -- null = cross-vertical
  sort_order int not null default 0
);

-- ----------------------------------------------------------------------------
-- 8. INDUSTRY PRODUCTS  (starter catalog — template only, NEVER a live listing)
-- ----------------------------------------------------------------------------
create table public.industry_products (
  id uuid primary key default gen_random_uuid(),
  business_type_id uuid not null references public.business_types(id) on delete cascade,
  category_id uuid references public.categories(id),
  name_en text not null,
  name_mr text,
  brand text,
  description text,
  unit text not null default 'pcs',
  suggested_price numeric(12,2),
  image_url text,
  image_source text,          -- 'public-domain' | 'ai-generated' | 'licensed' | 'seller-owned'
  image_license text,
  image_attribution text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index industry_products_type_idx on public.industry_products(business_type_id);

comment on table public.industry_products is 'Starter catalog per vertical. Copied into business_products on activation — this table is never directly customer-facing.';

-- ----------------------------------------------------------------------------
-- 9. BUSINESS PRODUCTS  (a seller''s actual product — the tenant-owned copy)
-- ----------------------------------------------------------------------------
create table public.business_products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  industry_product_id uuid references public.industry_products(id), -- null if seller-added custom product
  category_id uuid references public.categories(id),
  name text not null,
  brand text,
  description text,
  sku text,
  unit text not null default 'pcs',
  purchase_price numeric(12,2),
  selling_price numeric(12,2) not null default 0,
  tax_rate numeric(5,2) default 0,
  image_url text,
  image_source text,
  image_license text,
  stock numeric(12,2) not null default 0,
  min_stock numeric(12,2) not null default 0,
  is_active boolean not null default false,   -- seller-controlled on/off switch
  -- marketplace_visible is DERIVED, not stored — see view below. Kept here only
  -- as a cached/generated column for fast indexed marketplace queries.
  marketplace_visible boolean generated always as (is_active and stock > 0) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index business_products_business_idx on public.business_products(business_id);
create index business_products_marketplace_idx on public.business_products(marketplace_visible) where marketplace_visible = true;
create index business_products_category_idx on public.business_products(category_id);

comment on table public.business_products is 'Tenant-owned live products. marketplace_visible is generated from is_active+stock so it can never drift out of sync.';

-- ----------------------------------------------------------------------------
-- 10. INVENTORY LEDGER  (stock movement history — business_products.stock is current total)
-- ----------------------------------------------------------------------------
create table public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  business_product_id uuid not null references public.business_products(id) on delete cascade,
  change_qty numeric(12,2) not null,       -- positive = stock in, negative = stock out
  reason text not null check (reason in ('purchase','sale','adjustment','order','return')),
  reference_id uuid,                        -- e.g. order_items.id
  created_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

create index inventory_movements_business_idx on public.inventory_movements(business_id);
create index inventory_movements_product_idx on public.inventory_movements(business_product_id);

-- ----------------------------------------------------------------------------
-- 11. CUSTOMERS  (per-business customer book, distinct from platform users)
-- ----------------------------------------------------------------------------
create table public.customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid references public.users(id),  -- nullable: walk-in customers have no login
  name text,
  phone text,
  address text,
  notes text,
  created_at timestamptz not null default now()
);

create index customers_business_idx on public.customers(business_id);
create index customers_phone_idx on public.customers(phone);

-- ----------------------------------------------------------------------------
-- 12. SUPPLIERS
-- ----------------------------------------------------------------------------
create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  phone text,
  address text,
  gstin text,
  created_at timestamptz not null default now()
);

create index suppliers_business_idx on public.suppliers(business_id);

-- ----------------------------------------------------------------------------
-- 13. STORES  (public storefront config — mostly businesses table already covers
--     this; stores holds display-only extras like banners/offers/theme)
-- ----------------------------------------------------------------------------
create table public.stores (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null unique references public.businesses(id) on delete cascade,
  banner_url text,
  theme jsonb not null default '{}',
  offers jsonb not null default '[]',
  is_public boolean not null default true,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 14. ORDERS  (master order = one customer checkout, may span multiple sellers)
-- ----------------------------------------------------------------------------
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid references public.users(id),  -- nullable for phone-only lookups
  customer_phone text not null,
  customer_name text,
  created_at timestamptz not null default now()
);

create index orders_customer_phone_idx on public.orders(customer_phone);

comment on table public.orders is 'Master order shell. Real fulfillment happens per order_groups row (one per seller).';

-- ----------------------------------------------------------------------------
-- 15. ORDER GROUPS  (one per seller within a master order — this is what
--     actually appears on a business owner''s "New Order" dashboard)
-- ----------------------------------------------------------------------------
create table public.order_groups (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  business_id uuid not null references public.businesses(id) on delete restrict,
  status text not null default 'placed'
    check (status in ('placed','accepted','rejected','processing','ready','shipped','delivered','cancelled')),
  subtotal numeric(12,2) not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index order_groups_business_idx on public.order_groups(business_id);
create index order_groups_order_idx on public.order_groups(order_id);

-- ----------------------------------------------------------------------------
-- 16. ORDER ITEMS
-- ----------------------------------------------------------------------------
create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_group_id uuid not null references public.order_groups(id) on delete cascade,
  business_product_id uuid not null references public.business_products(id),
  product_name text not null,   -- snapshot at time of order
  unit_price numeric(12,2) not null,
  quantity numeric(12,2) not null,
  line_total numeric(12,2) generated always as (unit_price * quantity) stored
);

create index order_items_group_idx on public.order_items(order_group_id);

-- ----------------------------------------------------------------------------
-- 17. PAYMENTS METADATA  (informational only — platform never holds funds)
-- ----------------------------------------------------------------------------
create table public.payments_metadata (
  id uuid primary key default gen_random_uuid(),
  order_group_id uuid not null references public.order_groups(id) on delete cascade,
  method text check (method in ('upi','bank_transfer','cash','cod','other')),
  reference_note text,   -- e.g. UPI txn id typed in by seller, not verified by platform
  marked_paid_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

comment on table public.payments_metadata is 'Purely informational record of a direct seller/customer payment arrangement. Platform is never a party to the transaction.';

-- ----------------------------------------------------------------------------
-- 18. REVIEWS
-- ----------------------------------------------------------------------------
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  business_product_id uuid references public.business_products(id),
  reviewer_user_id uuid not null references public.users(id),
  rating int not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

create index reviews_business_idx on public.reviews(business_id);

-- ----------------------------------------------------------------------------
-- 19. DEVELOPERS / APPS  (Business App Store)
-- ----------------------------------------------------------------------------
create table public.developers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  company_name text,
  website text,
  is_verified boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.apps (
  id uuid primary key default gen_random_uuid(),
  developer_id uuid not null references public.developers(id) on delete cascade,
  name text not null,
  slug text not null unique,
  category text,
  description text,
  pricing_model text not null default 'free' check (pricing_model in ('free','paid','freemium','subscription')),
  price numeric(12,2),
  icon_url text,
  screenshot_urls jsonb not null default '[]',
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.app_versions (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references public.apps(id) on delete cascade,
  version text not null,
  changelog text,
  is_current boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.app_installations (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references public.apps(id) on delete cascade,
  business_id uuid not null references public.businesses(id) on delete cascade,
  is_enabled boolean not null default true,
  installed_at timestamptz not null default now(),
  unique (app_id, business_id)
);

create index app_installations_business_idx on public.app_installations(business_id);

-- ----------------------------------------------------------------------------
-- 20. ADVERTISERS / CAMPAIGNS / ADS
-- ----------------------------------------------------------------------------
create table public.advertisers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  company_name text not null,
  is_verified boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.campaigns (
  id uuid primary key default gen_random_uuid(),
  advertiser_id uuid not null references public.advertisers(id) on delete cascade,
  name text not null,
  status text not null default 'draft' check (status in ('draft','active','paused','completed','rejected')),
  budget numeric(12,2),
  start_date date,
  end_date date,
  target_location text,
  target_business_type_id uuid references public.business_types(id),
  target_audience jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table public.advertisements (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  ad_type text not null check (ad_type in ('banner','image','video','sponsored_product','sponsored_business','native')),
  media_url text,
  target_url text,
  placement text,          -- e.g. 'marketplace_home','store_page','search_results'
  frequency_cap_per_user_per_day int not null default 5,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.ad_impressions (
  id uuid primary key default gen_random_uuid(),
  advertisement_id uuid not null references public.advertisements(id) on delete cascade,
  viewer_user_id uuid references public.users(id),
  placement text,
  created_at timestamptz not null default now()
);

create index ad_impressions_ad_idx on public.ad_impressions(advertisement_id, created_at);

create table public.ad_clicks (
  id uuid primary key default gen_random_uuid(),
  advertisement_id uuid not null references public.advertisements(id) on delete cascade,
  viewer_user_id uuid references public.users(id),
  created_at timestamptz not null default now()
);

create index ad_clicks_ad_idx on public.ad_clicks(advertisement_id, created_at);

-- ----------------------------------------------------------------------------
-- 21. REVENUE SHARE ENGINE  (policy-based, not per-impression fixed payout)
-- ----------------------------------------------------------------------------
create table public.revenue_share_rules (
  id uuid primary key default gen_random_uuid(),
  applies_to text not null check (applies_to in ('developer_app_ads','partner_referral','platform_default')),
  share_percent numeric(5,2) not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.revenue_shares (
  id uuid primary key default gen_random_uuid(),
  advertisement_id uuid references public.advertisements(id),
  app_id uuid references public.apps(id),
  partner_id uuid,   -- references partners(id), added below after partners table
  rule_id uuid references public.revenue_share_rules(id),
  gross_amount numeric(12,2) not null,
  share_amount numeric(12,2) not null,
  period_start date not null,
  period_end date not null,
  status text not null default 'pending' check (status in ('pending','payable','paid')),
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 22. PARTNERS / PUBLISHERS
-- ----------------------------------------------------------------------------
create table public.partners (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  referral_code text not null unique,
  is_verified boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.revenue_shares
  add constraint revenue_shares_partner_fk foreign key (partner_id) references public.partners(id);

-- ----------------------------------------------------------------------------
-- 23. NOTIFICATIONS
-- ----------------------------------------------------------------------------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  business_id uuid references public.businesses(id) on delete cascade,
  type text not null,        -- 'new_order','low_stock','order_status', ...
  title text not null,
  body text,
  data jsonb not null default '{}',
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index notifications_user_idx on public.notifications(user_id, is_read);

-- ----------------------------------------------------------------------------
-- 24. AI USAGE  (per-business AI assistant call log, for permissions + limits)
-- ----------------------------------------------------------------------------
create table public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid references public.users(id),
  prompt text,
  response_summary text,
  tokens_used int,
  created_at timestamptz not null default now()
);

create index ai_usage_business_idx on public.ai_usage(business_id);

-- ----------------------------------------------------------------------------
-- 25. AUDIT LOGS  (append-only; no update/delete policy granted to anyone but admin)
-- ----------------------------------------------------------------------------
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.users(id),
  business_id uuid references public.businesses(id),
  action text not null,       -- 'product.create','stock.update','order.status_change', ...
  entity_type text,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

create index audit_logs_business_idx on public.audit_logs(business_id, created_at);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- keep updated_at fresh
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger businesses_set_updated_at before update on public.businesses
  for each row execute function public.set_updated_at();
create trigger business_products_set_updated_at before update on public.business_products
  for each row execute function public.set_updated_at();
create trigger order_groups_set_updated_at before update on public.order_groups
  for each row execute function public.set_updated_at();

-- keep business_products.stock in sync with inventory_movements (append-only ledger)
create or replace function public.apply_inventory_movement()
returns trigger language plpgsql as $$
begin
  update public.business_products
     set stock = stock + new.change_qty
   where id = new.business_product_id;
  return new;
end;
$$;

create trigger inventory_movements_apply after insert on public.inventory_movements
  for each row execute function public.apply_inventory_movement();

-- auto-create a public.users row when someone signs up via Supabase Auth
create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.users (id, full_name) values (new.id, new.raw_user_meta_data->>'full_name');
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_auth_user();
