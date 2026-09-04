
-- ========================================================
-- FILE: 0001_core_schema.sql
-- ========================================================
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


-- ========================================================
-- FILE: 0002_rls_policies.sql
-- ========================================================
-- ============================================================================
-- ROW LEVEL SECURITY — every business-owned table is locked to its tenant.
-- ============================================================================
-- Helper: is the current user a member (owner or staff) of a given business?
-- SECURITY DEFINER so it can read business_members without recursive RLS.
-- ============================================================================

create or replace function public.is_business_member(target_business_id uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.businesses b
    where b.id = target_business_id and b.owner_id = auth.uid()
    union
    select 1 from public.business_members m
    where m.business_id = target_business_id and m.user_id = auth.uid()
  );
$$;

create or replace function public.is_admin()
returns boolean language sql security definer stable as $$
  select coalesce((select is_admin from public.users where id = auth.uid()), false);
$$;

-- ----------------------------------------------------------------------------
-- users
-- ----------------------------------------------------------------------------
alter table public.users enable row level security;

create policy users_select_self on public.users
  for select using (id = auth.uid() or public.is_admin());
create policy users_update_self on public.users
  for update using (id = auth.uid());
-- public read of minimal profile info (name) is handled via a view, not raw table access

-- ----------------------------------------------------------------------------
-- business_types / erp_modules / erp_templates / categories / industry_products
-- Admin-managed reference data: public read, admin write.
-- ----------------------------------------------------------------------------
alter table public.business_types enable row level security;
alter table public.erp_modules enable row level security;
alter table public.erp_templates enable row level security;
alter table public.categories enable row level security;
alter table public.industry_products enable row level security;

create policy business_types_public_read on public.business_types for select using (true);
create policy business_types_admin_write on public.business_types for all using (public.is_admin()) with check (public.is_admin());

create policy erp_modules_public_read on public.erp_modules for select using (true);
create policy erp_modules_admin_write on public.erp_modules for all using (public.is_admin()) with check (public.is_admin());

create policy erp_templates_public_read on public.erp_templates for select using (true);
create policy erp_templates_admin_write on public.erp_templates for all using (public.is_admin()) with check (public.is_admin());

create policy categories_public_read on public.categories for select using (true);
create policy categories_admin_write on public.categories for all using (public.is_admin()) with check (public.is_admin());

create policy industry_products_public_read on public.industry_products for select using (true);
create policy industry_products_admin_write on public.industry_products for all using (public.is_admin()) with check (public.is_admin());

-- ----------------------------------------------------------------------------
-- businesses
-- Public can read verified+active businesses (for marketplace/store pages).
-- Owner/staff/admin can read+write their own regardless of verification.
-- ----------------------------------------------------------------------------
alter table public.businesses enable row level security;

create policy businesses_public_read on public.businesses
  for select using (is_verified and is_active);
create policy businesses_member_read on public.businesses
  for select using (public.is_business_member(id) or public.is_admin());
create policy businesses_owner_insert on public.businesses
  for insert with check (owner_id = auth.uid());
create policy businesses_member_write on public.businesses
  for update using (public.is_business_member(id) or public.is_admin());
create policy businesses_admin_delete on public.businesses
  for delete using (public.is_admin());

-- ----------------------------------------------------------------------------
-- business_members
-- ----------------------------------------------------------------------------
alter table public.business_members enable row level security;

create policy business_members_read on public.business_members
  for select using (public.is_business_member(business_id) or public.is_admin());
create policy business_members_owner_write on public.business_members
  for all using (
    exists (select 1 from public.businesses b where b.id = business_id and b.owner_id = auth.uid())
    or public.is_admin()
  );

-- ----------------------------------------------------------------------------
-- business_products
-- Public can read marketplace_visible products of verified businesses.
-- Tenant can read/write ALL their own products regardless of visibility.
-- ----------------------------------------------------------------------------
alter table public.business_products enable row level security;

create policy business_products_public_read on public.business_products
  for select using (
    marketplace_visible
    and exists (
      select 1 from public.businesses b
      where b.id = business_id and b.is_verified and b.is_active
    )
  );
create policy business_products_tenant_read on public.business_products
  for select using (public.is_business_member(business_id) or public.is_admin());
create policy business_products_tenant_write on public.business_products
  for all using (public.is_business_member(business_id) or public.is_admin())
  with check (public.is_business_member(business_id) or public.is_admin());

-- ----------------------------------------------------------------------------
-- inventory_movements — tenant only, append-only (no update/delete for non-admin)
-- ----------------------------------------------------------------------------
alter table public.inventory_movements enable row level security;

create policy inventory_movements_tenant_read on public.inventory_movements
  for select using (public.is_business_member(business_id) or public.is_admin());
create policy inventory_movements_tenant_insert on public.inventory_movements
  for insert with check (public.is_business_member(business_id) or public.is_admin());
create policy inventory_movements_admin_modify on public.inventory_movements
  for update using (public.is_admin());
create policy inventory_movements_admin_delete on public.inventory_movements
  for delete using (public.is_admin());

-- ----------------------------------------------------------------------------
-- customers / suppliers — strictly tenant-private, never public
-- ----------------------------------------------------------------------------
alter table public.customers enable row level security;
alter table public.suppliers enable row level security;

create policy customers_tenant_only on public.customers
  for all using (public.is_business_member(business_id) or public.is_admin())
  with check (public.is_business_member(business_id) or public.is_admin());

create policy suppliers_tenant_only on public.suppliers
  for all using (public.is_business_member(business_id) or public.is_admin())
  with check (public.is_business_member(business_id) or public.is_admin());

-- ----------------------------------------------------------------------------
-- stores — public read (storefront page), tenant write
-- ----------------------------------------------------------------------------
alter table public.stores enable row level security;

create policy stores_public_read on public.stores for select using (is_public);
create policy stores_tenant_write on public.stores
  for all using (public.is_business_member(business_id) or public.is_admin())
  with check (public.is_business_member(business_id) or public.is_admin());

-- ----------------------------------------------------------------------------
-- orders — a customer sees only their own (by user_id OR phone match handled
-- in application layer for no-login lookup, which uses a service-role RPC,
-- never direct table select for anonymous phone-only access).
-- ----------------------------------------------------------------------------
alter table public.orders enable row level security;

create policy orders_customer_read on public.orders
  for select using (customer_user_id = auth.uid() or public.is_admin());
create policy orders_customer_insert on public.orders
  for insert with check (customer_user_id = auth.uid() or customer_user_id is null);

-- ----------------------------------------------------------------------------
-- order_groups — visible to the seller business AND the buying customer
-- ----------------------------------------------------------------------------
alter table public.order_groups enable row level security;

create policy order_groups_seller_read on public.order_groups
  for select using (public.is_business_member(business_id) or public.is_admin());
create policy order_groups_customer_read on public.order_groups
  for select using (
    exists (select 1 from public.orders o where o.id = order_id and o.customer_user_id = auth.uid())
  );
create policy order_groups_customer_insert on public.order_groups
  for insert with check (
    exists (select 1 from public.orders o where o.id = order_id
            and (o.customer_user_id = auth.uid() or o.customer_user_id is null))
  );
create policy order_groups_seller_update on public.order_groups
  for update using (public.is_business_member(business_id) or public.is_admin());

-- ----------------------------------------------------------------------------
-- order_items — inherits visibility from parent order_group
-- ----------------------------------------------------------------------------
alter table public.order_items enable row level security;

create policy order_items_seller_read on public.order_items
  for select using (
    exists (
      select 1 from public.order_groups g
      where g.id = order_group_id and public.is_business_member(g.business_id)
    ) or public.is_admin()
  );
create policy order_items_customer_read on public.order_items
  for select using (
    exists (
      select 1 from public.order_groups g join public.orders o on o.id = g.order_id
      where g.id = order_group_id and o.customer_user_id = auth.uid()
    )
  );
create policy order_items_insert on public.order_items
  for insert with check (
    exists (
      select 1 from public.order_groups g join public.orders o on o.id = g.order_id
      where g.id = order_group_id and (o.customer_user_id = auth.uid() or o.customer_user_id is null)
    )
  );

-- ----------------------------------------------------------------------------
-- payments_metadata — seller only (customer doesn't need to see internal notes)
-- ----------------------------------------------------------------------------
alter table public.payments_metadata enable row level security;

create policy payments_metadata_seller_only on public.payments_metadata
  for all using (
    exists (
      select 1 from public.order_groups g
      where g.id = order_group_id and public.is_business_member(g.business_id)
    ) or public.is_admin()
  );

-- ----------------------------------------------------------------------------
-- reviews — public read, author write
-- ----------------------------------------------------------------------------
alter table public.reviews enable row level security;

create policy reviews_public_read on public.reviews for select using (true);
create policy reviews_author_write on public.reviews
  for insert with check (reviewer_user_id = auth.uid());
create policy reviews_author_update on public.reviews
  for update using (reviewer_user_id = auth.uid());
create policy reviews_author_delete on public.reviews
  for delete using (reviewer_user_id = auth.uid() or public.is_admin());

-- ----------------------------------------------------------------------------
-- developers / apps / app_versions / app_installations
-- ----------------------------------------------------------------------------
alter table public.developers enable row level security;
alter table public.apps enable row level security;
alter table public.app_versions enable row level security;
alter table public.app_installations enable row level security;

create policy developers_self on public.developers
  for all using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

create policy apps_public_read on public.apps for select using (is_published);
create policy apps_owner_read on public.apps
  for select using (
    exists (select 1 from public.developers d where d.id = developer_id and d.user_id = auth.uid())
    or public.is_admin()
  );
create policy apps_owner_write on public.apps
  for all using (
    exists (select 1 from public.developers d where d.id = developer_id and d.user_id = auth.uid())
    or public.is_admin()
  )
  with check (
    exists (select 1 from public.developers d where d.id = developer_id and d.user_id = auth.uid())
    or public.is_admin()
  );

create policy app_versions_public_read on public.app_versions
  for select using (exists (select 1 from public.apps a where a.id = app_id and a.is_published));
create policy app_versions_owner_write on public.app_versions
  for all using (
    exists (
      select 1 from public.apps a join public.developers d on d.id = a.developer_id
      where a.id = app_id and d.user_id = auth.uid()
    ) or public.is_admin()
  );

create policy app_installations_tenant_only on public.app_installations
  for all using (public.is_business_member(business_id) or public.is_admin())
  with check (public.is_business_member(business_id) or public.is_admin());

-- ----------------------------------------------------------------------------
-- advertisers / campaigns / advertisements
-- ----------------------------------------------------------------------------
alter table public.advertisers enable row level security;
alter table public.campaigns enable row level security;
alter table public.advertisements enable row level security;

create policy advertisers_self on public.advertisers
  for all using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

create policy campaigns_owner_only on public.campaigns
  for all using (
    exists (select 1 from public.advertisers a where a.id = advertiser_id and a.user_id = auth.uid())
    or public.is_admin()
  )
  with check (
    exists (select 1 from public.advertisers a where a.id = advertiser_id and a.user_id = auth.uid())
    or public.is_admin()
  );

create policy advertisements_public_read on public.advertisements
  for select using (
    is_active and exists (
      select 1 from public.campaigns c where c.id = campaign_id and c.status = 'active'
    )
  );
create policy advertisements_owner_write on public.advertisements
  for all using (
    exists (
      select 1 from public.campaigns c join public.advertisers a on a.id = c.advertiser_id
      where c.id = campaign_id and a.user_id = auth.uid()
    ) or public.is_admin()
  );

-- ----------------------------------------------------------------------------
-- ad_impressions / ad_clicks — insert by anyone (tracking pixel), read by
-- owning advertiser + admin only. Never expose raw viewer data broadly.
-- ----------------------------------------------------------------------------
alter table public.ad_impressions enable row level security;
alter table public.ad_clicks enable row level security;

create policy ad_impressions_insert_any on public.ad_impressions for insert with check (true);
create policy ad_impressions_owner_read on public.ad_impressions
  for select using (
    exists (
      select 1 from public.advertisements ad
      join public.campaigns c on c.id = ad.campaign_id
      join public.advertisers a on a.id = c.advertiser_id
      where ad.id = advertisement_id and a.user_id = auth.uid()
    ) or public.is_admin()
  );

create policy ad_clicks_insert_any on public.ad_clicks for insert with check (true);
create policy ad_clicks_owner_read on public.ad_clicks
  for select using (
    exists (
      select 1 from public.advertisements ad
      join public.campaigns c on c.id = ad.campaign_id
      join public.advertisers a on a.id = c.advertiser_id
      where ad.id = advertisement_id and a.user_id = auth.uid()
    ) or public.is_admin()
  );

-- ----------------------------------------------------------------------------
-- revenue_share_rules / revenue_shares — admin manages rules; participants
-- see only their own share rows.
-- ----------------------------------------------------------------------------
alter table public.revenue_share_rules enable row level security;
alter table public.revenue_shares enable row level security;

create policy revenue_share_rules_admin_only on public.revenue_share_rules
  for all using (public.is_admin()) with check (public.is_admin());

create policy revenue_shares_participant_read on public.revenue_shares
  for select using (
    public.is_admin()
    or exists (
      select 1 from public.apps a join public.developers d on d.id = a.developer_id
      where a.id = app_id and d.user_id = auth.uid()
    )
    or exists (select 1 from public.partners p where p.id = partner_id and p.user_id = auth.uid())
  );
create policy revenue_shares_admin_write on public.revenue_shares
  for insert with check (public.is_admin());
create policy revenue_shares_admin_update on public.revenue_shares
  for update using (public.is_admin());

-- ----------------------------------------------------------------------------
-- partners
-- ----------------------------------------------------------------------------
alter table public.partners enable row level security;

create policy partners_self on public.partners
  for all using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

-- ----------------------------------------------------------------------------
-- notifications — strictly the owning user
-- ----------------------------------------------------------------------------
alter table public.notifications enable row level security;

create policy notifications_self on public.notifications
  for select using (user_id = auth.uid() or public.is_admin());
create policy notifications_self_update on public.notifications
  for update using (user_id = auth.uid());
create policy notifications_system_insert on public.notifications
  for insert with check (true); -- inserted by triggers/server functions (security definer)

-- ----------------------------------------------------------------------------
-- ai_usage — tenant only
-- ----------------------------------------------------------------------------
alter table public.ai_usage enable row level security;

create policy ai_usage_tenant_only on public.ai_usage
  for all using (public.is_business_member(business_id) or public.is_admin())
  with check (public.is_business_member(business_id) or public.is_admin());

-- ----------------------------------------------------------------------------
-- audit_logs — write via security-definer functions only; read: owner business
-- or admin. No update/delete policy exists for anyone (append-only).
-- ----------------------------------------------------------------------------
alter table public.audit_logs enable row level security;

create policy audit_logs_business_read on public.audit_logs
  for select using (
    (business_id is not null and public.is_business_member(business_id)) or public.is_admin()
  );
create policy audit_logs_insert on public.audit_logs
  for insert with check (true);
-- deliberately: no update policy, no delete policy → immutable to all non-superuser roles


-- ========================================================
-- FILE: 0003_core_functions.sql
-- ========================================================
-- ============================================================================
-- CORE BUSINESS LOGIC — the automation the whole spec's UX depends on:
--   create_business()   → business + ERP + 100+ starter products, all atomic
--   set_product_stock() → stock change through the ledger (never direct UPDATE)
--   place_order()       → one multi-vendor cart → split into per-seller orders
--   lookup_orders_by_phone() → no-login "my orders" lookup
-- All are SECURITY DEFINER where they must cross RLS boundaries on the
-- caller's behalf, but every one re-checks auth.uid() itself — RLS bypass is
-- never a blanket bypass, it's scoped to exactly what the function checks.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- create_business: Step 3-5 of the spec's business creation flow, atomic.
-- ----------------------------------------------------------------------------
create or replace function public.create_business(
  p_name text,
  p_business_type_slug text,
  p_city text default null
)
returns public.businesses
language plpgsql
security definer
as $$
declare
  v_business_type public.business_types;
  v_business public.businesses;
  v_slug text;
  v_suffix int := 0;
begin
  if auth.uid() is null then
    raise exception 'Must be authenticated to create a business';
  end if;

  select * into v_business_type from public.business_types
    where slug = p_business_type_slug and is_active
    limit 1;

  if v_business_type is null then
    raise exception 'Unknown or inactive business_type: %', p_business_type_slug;
  end if;

  -- slugify name, dedupe with numeric suffix if taken
  v_slug := lower(regexp_replace(trim(p_name), '[^a-zA-Z0-9]+', '-', 'g'));
  while exists (select 1 from public.businesses where slug = v_slug || case when v_suffix = 0 then '' else '-' || v_suffix end) loop
    v_suffix := v_suffix + 1;
  end loop;
  if v_suffix > 0 then
    v_slug := v_slug || '-' || v_suffix;
  end if;

  insert into public.businesses (owner_id, business_type_id, name, slug, city)
  values (auth.uid(), v_business_type.id, p_name, v_slug, p_city)
  returning * into v_business;

  insert into public.business_members (business_id, user_id, role)
  values (v_business.id, auth.uid(), 'owner');

  insert into public.stores (business_id) values (v_business.id);

  update public.users set is_business_owner = true where id = auth.uid();

  -- copy the ENTIRE starter catalog for this business_type into business_products
  -- stock = 0, is_active = false → invisible on marketplace until owner stocks it
  insert into public.business_products (
    business_id, industry_product_id, category_id, name, brand, description,
    unit, selling_price, image_url, image_source, image_license, stock, is_active
  )
  select
    v_business.id, ip.id, ip.category_id, ip.name_en, ip.brand, ip.description,
    ip.unit, coalesce(ip.suggested_price, 0), ip.image_url, ip.image_source, ip.image_license,
    0, false
  from public.industry_products ip
  where ip.business_type_id = v_business_type.id;

  insert into public.audit_logs (actor_user_id, business_id, action, entity_type, entity_id, after_data)
  values (auth.uid(), v_business.id, 'business.create', 'business', v_business.id, to_jsonb(v_business));

  return v_business;
end;
$$;

grant execute on function public.create_business(text, text, text) to authenticated;

-- ----------------------------------------------------------------------------
-- set_product_stock: the ONLY sanctioned way to change stock. Writes through
-- inventory_movements (trigger applies the delta), so history is always kept
-- and marketplace_visible stays correctly derived.
-- ----------------------------------------------------------------------------
create or replace function public.set_product_stock(
  p_business_product_id uuid,
  p_new_stock numeric,
  p_activate boolean default null   -- null = leave is_active untouched
)
returns public.business_products
language plpgsql
security definer
as $$
declare
  v_product public.business_products;
  v_delta numeric;
begin
  select * into v_product from public.business_products where id = p_business_product_id;
  if v_product is null then
    raise exception 'Product not found';
  end if;
  if not public.is_business_member(v_product.business_id) then
    raise exception 'Not authorized for this business';
  end if;

  v_delta := p_new_stock - v_product.stock;

  if v_delta != 0 then
    insert into public.inventory_movements (business_id, business_product_id, change_qty, reason, created_by)
    values (v_product.business_id, p_business_product_id, v_delta, 'adjustment', auth.uid());
  end if;

  if p_activate is not null then
    update public.business_products set is_active = p_activate where id = p_business_product_id;
  end if;

  select * into v_product from public.business_products where id = p_business_product_id;

  insert into public.audit_logs (actor_user_id, business_id, action, entity_type, entity_id, after_data)
  values (auth.uid(), v_product.business_id, 'stock.update', 'business_product', v_product.id, to_jsonb(v_product));

  return v_product;
end;
$$;

grant execute on function public.set_product_stock(uuid, numeric, boolean) to authenticated;

-- ----------------------------------------------------------------------------
-- place_order: takes a flat cart (possibly multiple businesses) and splits it
-- into one order_group per seller, per spec section 8-9. Stock is decremented
-- through the ledger and re-checked at write time (no overselling on race).
-- p_items: jsonb array of {business_product_id, quantity}
-- ----------------------------------------------------------------------------
create or replace function public.place_order(
  p_customer_phone text,
  p_customer_name text,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
as $$
declare
  v_order_id uuid;
  v_item jsonb;
  v_product public.business_products;
  v_group_id uuid;
  v_group_business uuid;
  v_qty numeric;
begin
  insert into public.orders (customer_user_id, customer_phone, customer_name)
  values (auth.uid(), p_customer_phone, p_customer_name)
  returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select * into v_product from public.business_products
      where id = (v_item->>'business_product_id')::uuid
      for update; -- lock row to prevent oversell races

    if v_product is null or not v_product.marketplace_visible then
      raise exception 'Product % is not available', v_item->>'business_product_id';
    end if;

    v_qty := (v_item->>'quantity')::numeric;

    if v_product.stock < v_qty then
      raise exception 'Insufficient stock for %', v_product.name;
    end if;

    -- one order_group per seller business — create on first item from that seller
    if v_group_business is distinct from v_product.business_id then
      insert into public.order_groups (order_id, business_id)
      values (v_order_id, v_product.business_id)
      returning id into v_group_id;
      v_group_business := v_product.business_id;
    end if;

    insert into public.order_items (order_group_id, business_product_id, product_name, unit_price, quantity)
    values (v_group_id, v_product.id, v_product.name, v_product.selling_price, v_qty);

    insert into public.inventory_movements (business_id, business_product_id, change_qty, reason, reference_id, created_by)
    values (v_product.business_id, v_product.id, -v_qty, 'order', v_group_id, auth.uid());

    update public.order_groups
       set subtotal = subtotal + (v_product.selling_price * v_qty)
     where id = v_group_id;

    -- notify the seller
    insert into public.notifications (user_id, business_id, type, title, body)
    select b.owner_id, b.id, 'new_order', 'नवीन ऑर्डर आली', v_product.name || ' x ' || v_qty
    from public.businesses b where b.id = v_product.business_id;
  end loop;

  return v_order_id;
end;
$$;

grant execute on function public.place_order(text, text, jsonb) to authenticated, anon;

-- ----------------------------------------------------------------------------
-- lookup_orders_by_phone: the no-login "My Orders" flow. Deliberately narrow —
-- returns only order/status data, never other customers' info, never payment
-- details beyond method.
-- ----------------------------------------------------------------------------
create or replace function public.lookup_orders_by_phone(p_phone text)
returns table (
  order_group_id uuid,
  business_name text,
  status text,
  subtotal numeric,
  created_at timestamptz
)
language sql
security definer
stable
as $$
  select g.id, b.name, g.status, g.subtotal, g.created_at
  from public.order_groups g
  join public.orders o on o.id = g.order_id
  join public.businesses b on b.id = g.business_id
  where o.customer_phone = p_phone
  order by g.created_at desc;
$$;

grant execute on function public.lookup_orders_by_phone(text) to authenticated, anon;

-- ----------------------------------------------------------------------------
-- update_order_status: seller-only status transitions (accept/reject/ship/...)
-- ----------------------------------------------------------------------------
create or replace function public.update_order_status(
  p_order_group_id uuid,
  p_new_status text
)
returns public.order_groups
language plpgsql
security definer
as $$
declare
  v_group public.order_groups;
begin
  select * into v_group from public.order_groups where id = p_order_group_id;
  if v_group is null then
    raise exception 'Order not found';
  end if;
  if not public.is_business_member(v_group.business_id) then
    raise exception 'Not authorized for this order';
  end if;
  if p_new_status not in ('accepted','rejected','processing','ready','shipped','delivered','cancelled') then
    raise exception 'Invalid status: %', p_new_status;
  end if;

  update public.order_groups set status = p_new_status where id = p_order_group_id
    returning * into v_group;

  insert into public.notifications (user_id, business_id, type, title, body)
  select o.customer_user_id, v_group.business_id, 'order_status', 'ऑर्डर स्टेटस अपडेट', p_new_status
  from public.orders o where o.id = v_group.order_id and o.customer_user_id is not null;

  insert into public.audit_logs (actor_user_id, business_id, action, entity_type, entity_id, after_data)
  values (auth.uid(), v_group.business_id, 'order.status_change', 'order_group', v_group.id, to_jsonb(v_group));

  return v_group;
end;
$$;

grant execute on function public.update_order_status(uuid, text) to authenticated;


-- ========================================================
-- FILE: 0004_seed_starter_data.sql
-- ========================================================
-- ============================================================================
-- SEED DATA — demonstrates the pattern for all 100+ verticals.
-- This migration ships business_types for the 10 first-priority verticals
-- (spec section 39) plus a full 20-item starter catalog for Grocery and a
-- 15-item catalog for Electronics, enough to exercise every acceptance test
-- in section 43 end-to-end. Extending to 100+ products x 100+ verticals is a
-- data-entry/content task, not an architecture task — same INSERT pattern,
-- run per vertical (ideally via an admin CSV importer, see README).
--
-- Images: every image_url below is a placeholder path (/starter-images/...)
-- pointing at square-cropped, license-tagged illustrations to be generated/
-- sourced separately per rule #4 (no copyrighted marketplace images). Swap
-- these for real licensed/AI-generated asset URLs before going live.
-- ============================================================================

insert into public.business_types (slug, name_en, name_mr, category, sort_order) values
  ('grocery', 'Grocery / Kirana', 'किराणा दुकान', 'retail', 1),
  ('electronics', 'Electronics', 'इलेक्ट्रॉनिक्स', 'retail', 2),
  ('clothing', 'Clothing', 'कापड दुकान', 'retail', 3),
  ('hardware', 'Hardware', 'हार्डवेअर', 'retail', 4),
  ('restaurant', 'Restaurant', 'रेस्टॉरंट', 'food', 5),
  ('medical-store', 'Medical Store', 'मेडिकल स्टोअर', 'healthcare', 6),
  ('contractor', 'Contractor', 'कंत्राटदार', 'services', 7),
  ('furniture', 'Furniture', 'फर्निचर', 'retail', 8),
  ('mobile-shop', 'Mobile Shop', 'मोबाईल शॉप', 'retail', 9),
  ('real-estate', 'Real Estate / Property Dealer', 'रिअल इस्टेट', 'services', 10);

-- ---- Grocery starter catalog (20 of target 100+) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Rice (1kg)', 'तांदूळ (१ किलो)', 'kg', 60, '/starter-images/grocery/rice.png'),
  ('Wheat Flour (1kg)', 'गहू पीठ (१ किलो)', 'kg', 45, '/starter-images/grocery/wheat-flour.png'),
  ('Sugar (1kg)', 'साखर (१ किलो)', 'kg', 44, '/starter-images/grocery/sugar.png'),
  ('Salt (1kg)', 'मीठ (१ किलो)', 'kg', 20, '/starter-images/grocery/salt.png'),
  ('Cooking Oil (1L)', 'खाद्यतेल (१ लिटर)', 'L', 140, '/starter-images/grocery/oil.png'),
  ('Tea Powder (250g)', 'चहा पावडर (२५० ग्रॅम)', 'pack', 90, '/starter-images/grocery/tea.png'),
  ('Coffee (100g)', 'कॉफी (१०० ग्रॅम)', 'pack', 120, '/starter-images/grocery/coffee.png'),
  ('Biscuits (Pack)', 'बिस्कीट पॅक', 'pack', 25, '/starter-images/grocery/biscuits.png'),
  ('Turmeric Powder (100g)', 'हळद पावडर (१०० ग्रॅम)', 'pack', 35, '/starter-images/grocery/turmeric.png'),
  ('Red Chilli Powder (100g)', 'तिखट (१०० ग्रॅम)', 'pack', 40, '/starter-images/grocery/chilli.png'),
  ('Bathing Soap', 'अंघोळीचा साबण', 'pcs', 35, '/starter-images/grocery/soap.png'),
  ('Shampoo (200ml)', 'शॅम्पू (२०० मिली)', 'bottle', 110, '/starter-images/grocery/shampoo.png'),
  ('Toothpaste (100g)', 'टूथपेस्ट (१०० ग्रॅम)', 'tube', 55, '/starter-images/grocery/toothpaste.png'),
  ('Detergent Powder (1kg)', 'डिटर्जंट पावडर (१ किलो)', 'kg', 95, '/starter-images/grocery/detergent.png'),
  ('Milk (500ml)', 'दूध (५०० मिली)', 'packet', 28, '/starter-images/grocery/milk.png'),
  ('Curd (200g)', 'दही (२०० ग्रॅम)', 'cup', 22, '/starter-images/grocery/curd.png'),
  ('Namkeen Snacks (Pack)', 'नमकीन पॅक', 'pack', 30, '/starter-images/grocery/namkeen.png'),
  ('Toor Dal (1kg)', 'तूर डाळ (१ किलो)', 'kg', 130, '/starter-images/grocery/toor-dal.png'),
  ('Match Box', 'काडेपेटी', 'pcs', 2, '/starter-images/grocery/matchbox.png'),
  ('Agarbatti Pack', 'उदबत्ती पॅक', 'pack', 30, '/starter-images/grocery/agarbatti.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'grocery';

-- ---- Electronics starter catalog (15 of target 100+) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('LED Bulb 9W', 'एलईडी बल्ब ९W', 'pcs', 90, '/starter-images/electronics/led-bulb.png'),
  ('Extension Board (4 socket)', 'एक्सटेंशन बोर्ड', 'pcs', 350, '/starter-images/electronics/extension-board.png'),
  ('USB Cable Type-C', 'यूएसबी केबल टाइप-सी', 'pcs', 150, '/starter-images/electronics/usb-cable.png'),
  ('Mobile Charger 20W', 'मोबाईल चार्जर २०W', 'pcs', 400, '/starter-images/electronics/charger.png'),
  ('Table Fan', 'टेबल फॅन', 'pcs', 900, '/starter-images/electronics/table-fan.png'),
  ('Ceiling Fan', 'सीलिंग फॅन', 'pcs', 1500, '/starter-images/electronics/ceiling-fan.png'),
  ('Electric Iron', 'इस्त्री', 'pcs', 750, '/starter-images/electronics/iron.png'),
  ('Wired Earphones', 'इअरफोन्स', 'pcs', 250, '/starter-images/electronics/earphones.png'),
  ('Bluetooth Speaker', 'ब्लूटूथ स्पीकर', 'pcs', 1200, '/starter-images/electronics/speaker.png'),
  ('Power Bank 10000mAh', 'पॉवर बँक १०,०००mAh', 'pcs', 1100, '/starter-images/electronics/powerbank.png'),
  ('Switch Board 6A', 'स्विच बोर्ड ६A', 'pcs', 60, '/starter-images/electronics/switch-board.png'),
  ('LED Tube Light 20W', 'एलईडी ट्यूब लाईट २०W', 'pcs', 220, '/starter-images/electronics/tube-light.png'),
  ('Multimeter', 'मल्टीमीटर', 'pcs', 450, '/starter-images/electronics/multimeter.png'),
  ('Extension Wire (10m)', 'वायर (१० मीटर)', 'roll', 500, '/starter-images/electronics/wire-roll.png'),
  ('Inverter Battery', 'इन्व्हर्टर बॅटरी', 'pcs', 8500, '/starter-images/electronics/inverter-battery.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'electronics';

-- ---- Core ERP modules referenced by default_modules on business_types ----
insert into public.erp_modules (code, name, is_core) values
  ('inventory', 'Inventory', true),
  ('sales', 'Sales / POS', true),
  ('purchase', 'Purchase', true),
  ('customers', 'Customers', true),
  ('suppliers', 'Suppliers', false),
  ('orders', 'Orders', true),
  ('reports', 'Reports', true),
  ('marketplace', 'Marketplace', true),
  ('advertising', 'Advertising', false),
  ('ai_assistant', 'AI Assistant', false),
  ('gst_billing', 'GST Billing', false),
  ('table_management', 'Table Management', false)
on conflict (code) do nothing;


-- ========================================================
-- FILE: 0005_mobile_shop_and_sync.sql
-- ========================================================
-- ============================================================================
-- 0005: Mobile Shop starter catalog + retroactive sync mechanism.
-- Why "sync" is needed: create_business() copies the starter catalog that
-- exists AT THE MOMENT of creation. A business created before its vertical's
-- catalog was seeded (like the mobile-shop test business) ends up with zero
-- products. sync_starter_catalog() lets an owner pull in anything added since.
-- ============================================================================

insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Smartphone (Entry-level)', 'स्मार्टफोन (एंट्री-लेव्हल)', 'pcs', 8000, '/starter-images/mobile-shop/phone-entry.png'),
  ('Smartphone (Mid-range)', 'स्मार्टफोन (मिड-रेंज)', 'pcs', 15000, '/starter-images/mobile-shop/phone-mid.png'),
  ('Screen Guard (Tempered Glass)', 'स्क्रीन गार्ड', 'pcs', 150, '/starter-images/mobile-shop/screen-guard.png'),
  ('Mobile Back Cover', 'मोबाईल कव्हर', 'pcs', 200, '/starter-images/mobile-shop/back-cover.png'),
  ('Charger (Original)', 'चार्जर (ओरिजिनल)', 'pcs', 500, '/starter-images/mobile-shop/charger.png'),
  ('Charging Cable', 'चार्जिंग केबल', 'pcs', 150, '/starter-images/mobile-shop/cable.png'),
  ('Earphones (Wired)', 'इअरफोन्स', 'pcs', 250, '/starter-images/mobile-shop/earphones.png'),
  ('Bluetooth Earbuds', 'ब्लूटूथ इअरबड्स', 'pcs', 1500, '/starter-images/mobile-shop/earbuds.png'),
  ('Power Bank 10000mAh', 'पॉवर बँक', 'pcs', 1100, '/starter-images/mobile-shop/powerbank.png'),
  ('Memory Card 32GB', 'मेमरी कार्ड ३२GB', 'pcs', 350, '/starter-images/mobile-shop/memory-card.png'),
  ('SIM Card', 'सिम कार्ड', 'pcs', 20, '/starter-images/mobile-shop/sim.png'),
  ('Mobile Stand/Holder', 'मोबाईल स्टँड', 'pcs', 150, '/starter-images/mobile-shop/stand.png'),
  ('Bluetooth Speaker', 'ब्लूटूथ स्पीकर', 'pcs', 1200, '/starter-images/mobile-shop/speaker.png'),
  ('Screen Repair Service', 'स्क्रीन रिपेअर सर्व्हिस', 'service', 800, '/starter-images/mobile-shop/repair.png'),
  ('Battery Replacement Service', 'बॅटरी बदलणे सर्व्हिस', 'service', 600, '/starter-images/mobile-shop/battery-service.png'),
  ('Mobile Recharge/Data Pack', 'मोबाईल रिचार्ज', 'pcs', 199, '/starter-images/mobile-shop/recharge.png'),
  ('USB OTG Adapter', 'OTG अ‍ॅडॉप्टर', 'pcs', 100, '/starter-images/mobile-shop/otg.png'),
  ('Selfie Stick', 'सेल्फी स्टिक', 'pcs', 250, '/starter-images/mobile-shop/selfie-stick.png'),
  ('Car Mobile Holder', 'कार मोबाईल होल्डर', 'pcs', 300, '/starter-images/mobile-shop/car-holder.png'),
  ('Mobile Cleaning Kit', 'मोबाईल क्लीनिंग किट', 'pcs', 120, '/starter-images/mobile-shop/cleaning-kit.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'mobile-shop';

-- ----------------------------------------------------------------------------
-- sync_starter_catalog: pulls in any industry_products the caller's business
-- doesn't already have (matched via industry_product_id), stock=0, inactive —
-- exactly like the initial copy in create_business(), just re-runnable.
-- ----------------------------------------------------------------------------
create or replace function public.sync_starter_catalog(p_business_id uuid)
returns integer
language plpgsql
security definer
as $$
declare
  v_business public.businesses;
  v_added integer;
begin
  if not public.is_business_member(p_business_id) then
    raise exception 'Not authorized for this business';
  end if;

  select * into v_business from public.businesses where id = p_business_id;

  insert into public.business_products (
    business_id, industry_product_id, category_id, name, brand, description,
    unit, selling_price, image_url, image_source, image_license, stock, is_active
  )
  select
    p_business_id, ip.id, ip.category_id, ip.name_en, ip.brand, ip.description,
    ip.unit, coalesce(ip.suggested_price, 0), ip.image_url, ip.image_source, ip.image_license,
    0, false
  from public.industry_products ip
  where ip.business_type_id = v_business.business_type_id
    and ip.id not in (
      select industry_product_id from public.business_products
      where business_id = p_business_id and industry_product_id is not null
    );

  get diagnostics v_added = row_count;

  insert into public.audit_logs (actor_user_id, business_id, action, entity_type, after_data)
  values (auth.uid(), p_business_id, 'catalog.sync', 'business_products', jsonb_build_object('added', v_added));

  return v_added;
end;
$$;

grant execute on function public.sync_starter_catalog(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- add_custom_product: the "+ Add New Product" flow (spec section 6) — a
-- seller-authored product not tied to any industry_products template.
-- ----------------------------------------------------------------------------
create or replace function public.add_custom_product(
  p_business_id uuid,
  p_name text,
  p_unit text,
  p_selling_price numeric,
  p_stock numeric default 0,
  p_purchase_price numeric default null,
  p_brand text default null,
  p_description text default null,
  p_sku text default null,
  p_image_url text default null
)
returns public.business_products
language plpgsql
security definer
as $$
declare
  v_product public.business_products;
begin
  if not public.is_business_member(p_business_id) then
    raise exception 'Not authorized for this business';
  end if;

  insert into public.business_products (
    business_id, name, unit, selling_price, purchase_price, brand, description, sku, image_url,
    stock, is_active
  )
  values (
    p_business_id, p_name, p_unit, p_selling_price, p_purchase_price, p_brand, p_description, p_sku, p_image_url,
    0, p_stock > 0
  )
  returning * into v_product;

  if p_stock != 0 then
    insert into public.inventory_movements (business_id, business_product_id, change_qty, reason, created_by)
    values (p_business_id, v_product.id, p_stock, 'purchase', auth.uid());
    select * into v_product from public.business_products where id = v_product.id;
  end if;

  insert into public.audit_logs (actor_user_id, business_id, action, entity_type, entity_id, after_data)
  values (auth.uid(), p_business_id, 'product.create', 'business_product', v_product.id, to_jsonb(v_product));

  return v_product;
end;
$$;

grant execute on function public.add_custom_product(uuid, text, text, numeric, numeric, numeric, text, text, text, text) to authenticated;


-- ========================================================
-- FILE: 0006_fix_duplicate_products.sql
-- ========================================================
-- ============================================================================
-- 0006: Fix duplicate starter-catalog products + prevent it permanently.
--
-- Root cause: business_products had no constraint stopping the same
-- industry_product from being copied into the same business twice. A double
-- click on "Sync Starter Catalog" (or a slow network causing a retry) could
-- fire two inserts before either committed, so both succeeded.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1 — clean up existing duplicates.
-- Keeps the OLDEST row per (business_id, industry_product_id) and deletes the
-- rest, but first moves any stock/order history off the duplicates onto the
-- kept row so nothing is silently lost.
-- ----------------------------------------------------------------------------
do $$
declare
  r record;
  v_keep_id uuid;
  v_dupe_id uuid;
  v_dupe_stock numeric;
begin
  for r in
    select business_id, industry_product_id
    from public.business_products
    where industry_product_id is not null
    group by business_id, industry_product_id
    having count(*) > 1
  loop
    -- the row to keep: oldest one
    select id into v_keep_id
    from public.business_products
    where business_id = r.business_id and industry_product_id = r.industry_product_id
    order by created_at asc
    limit 1;

    for v_dupe_id, v_dupe_stock in
      select id, stock from public.business_products
      where business_id = r.business_id
        and industry_product_id = r.industry_product_id
        and id != v_keep_id
    loop
      -- fold any stock on the duplicate into the kept row
      if v_dupe_stock != 0 then
        insert into public.inventory_movements (business_id, business_product_id, change_qty, reason, created_by)
        values (r.business_id, v_keep_id, v_dupe_stock, 'adjustment', null);
      end if;

      -- re-point any orders/inventory history that reference the duplicate
      update public.order_items set business_product_id = v_keep_id where business_product_id = v_dupe_id;
      update public.inventory_movements set business_product_id = v_keep_id where business_product_id = v_dupe_id;
      update public.reviews set business_product_id = v_keep_id where business_product_id = v_dupe_id;

      delete from public.business_products where id = v_dupe_id;
    end loop;
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- STEP 2 — stop it from ever happening again: a hard database constraint.
-- (Custom seller-added products have industry_product_id = null and are
-- exempt — a seller can add as many custom products as they like.)
-- ----------------------------------------------------------------------------
create unique index if not exists business_products_unique_starter_item
  on public.business_products (business_id, industry_product_id)
  where industry_product_id is not null;

-- ----------------------------------------------------------------------------
-- STEP 3 — make create_business() and sync_starter_catalog() safe to
-- run/click any number of times: ON CONFLICT DO NOTHING against the new
-- constraint, so even a double-click is now a harmless no-op.
-- ----------------------------------------------------------------------------
create or replace function public.create_business(
  p_name text,
  p_business_type_slug text,
  p_city text default null
)
returns public.businesses
language plpgsql
security definer
as $$
declare
  v_business_type public.business_types;
  v_business public.businesses;
  v_slug text;
  v_suffix int := 0;
begin
  if auth.uid() is null then
    raise exception 'Must be authenticated to create a business';
  end if;

  select * into v_business_type from public.business_types
    where slug = p_business_type_slug and is_active
    limit 1;

  if v_business_type is null then
    raise exception 'Unknown or inactive business_type: %', p_business_type_slug;
  end if;

  v_slug := lower(regexp_replace(trim(p_name), '[^a-zA-Z0-9]+', '-', 'g'));
  while exists (select 1 from public.businesses where slug = v_slug || case when v_suffix = 0 then '' else '-' || v_suffix end) loop
    v_suffix := v_suffix + 1;
  end loop;
  if v_suffix > 0 then
    v_slug := v_slug || '-' || v_suffix;
  end if;

  insert into public.businesses (owner_id, business_type_id, name, slug, city)
  values (auth.uid(), v_business_type.id, p_name, v_slug, p_city)
  returning * into v_business;

  insert into public.business_members (business_id, user_id, role)
  values (v_business.id, auth.uid(), 'owner');

  insert into public.stores (business_id) values (v_business.id);

  update public.users set is_business_owner = true where id = auth.uid();

  insert into public.business_products (
    business_id, industry_product_id, category_id, name, brand, description,
    unit, selling_price, image_url, image_source, image_license, stock, is_active
  )
  select
    v_business.id, ip.id, ip.category_id, ip.name_en, ip.brand, ip.description,
    ip.unit, coalesce(ip.suggested_price, 0), ip.image_url, ip.image_source, ip.image_license,
    0, false
  from public.industry_products ip
  where ip.business_type_id = v_business_type.id
  on conflict (business_id, industry_product_id) where industry_product_id is not null do nothing;

  insert into public.audit_logs (actor_user_id, business_id, action, entity_type, entity_id, after_data)
  values (auth.uid(), v_business.id, 'business.create', 'business', v_business.id, to_jsonb(v_business));

  return v_business;
end;
$$;

create or replace function public.sync_starter_catalog(p_business_id uuid)
returns integer
language plpgsql
security definer
as $$
declare
  v_business public.businesses;
  v_added integer;
begin
  if not public.is_business_member(p_business_id) then
    raise exception 'Not authorized for this business';
  end if;

  select * into v_business from public.businesses where id = p_business_id;

  insert into public.business_products (
    business_id, industry_product_id, category_id, name, brand, description,
    unit, selling_price, image_url, image_source, image_license, stock, is_active
  )
  select
    p_business_id, ip.id, ip.category_id, ip.name_en, ip.brand, ip.description,
    ip.unit, coalesce(ip.suggested_price, 0), ip.image_url, ip.image_source, ip.image_license,
    0, false
  from public.industry_products ip
  where ip.business_type_id = v_business.business_type_id
  on conflict (business_id, industry_product_id) where industry_product_id is not null do nothing;

  get diagnostics v_added = row_count;

  insert into public.audit_logs (actor_user_id, business_id, action, entity_type, after_data)
  values (auth.uid(), p_business_id, 'catalog.sync', 'business_products', jsonb_build_object('added', v_added));

  return v_added;
end;
$$;


-- ========================================================
-- FILE: 0007_remaining_priority_catalogs.sql
-- ========================================================
-- ============================================================================
-- 0007: Starter catalogs for the remaining first-priority verticals.
-- With this, all 10 priority business_types have a real starter catalog
-- BEFORE anyone can select them — so create_business() alone is always
-- enough. The "Sync Starter Catalog" button becomes a safety net for future
-- vertical launches, never a required step for these 10.
-- ============================================================================

-- ---- Clothing (18 items) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Men''s Shirt', 'पुरुषांचा शर्ट', 'pcs', 500, '/starter-images/clothing/mens-shirt.png'),
  ('Men''s T-Shirt', 'पुरुषांचा टी-शर्ट', 'pcs', 350, '/starter-images/clothing/mens-tshirt.png'),
  ('Men''s Jeans', 'पुरुषांची जीन्स', 'pcs', 900, '/starter-images/clothing/mens-jeans.png'),
  ('Men''s Formal Trousers', 'पुरुषांची फॉर्मल पँट', 'pcs', 750, '/starter-images/clothing/mens-trousers.png'),
  ('Women''s Kurti', 'महिलांचा कुर्ती', 'pcs', 600, '/starter-images/clothing/kurti.png'),
  ('Women''s Saree', 'महिलांची साडी', 'pcs', 1500, '/starter-images/clothing/saree.png'),
  ('Women''s Leggings', 'महिलांची लेगिंग्स', 'pcs', 300, '/starter-images/clothing/leggings.png'),
  ('Women''s Salwar Suit', 'महिलांचा सलवार सूट', 'pcs', 1100, '/starter-images/clothing/salwar.png'),
  ('Kids T-Shirt', 'मुलांचा टी-शर्ट', 'pcs', 250, '/starter-images/clothing/kids-tshirt.png'),
  ('Kids Frock', 'मुलींचा फ्रॉक', 'pcs', 450, '/starter-images/clothing/frock.png'),
  ('School Uniform Set', 'शाळेचा गणवेश', 'set', 700, '/starter-images/clothing/uniform.png'),
  ('Innerwear (Pack)', 'इनरवेअर पॅक', 'pack', 300, '/starter-images/clothing/innerwear.png'),
  ('Socks (Pair)', 'मोजे जोडी', 'pair', 100, '/starter-images/clothing/socks.png'),
  ('Belt', 'बेल्ट', 'pcs', 350, '/starter-images/clothing/belt.png'),
  ('Handkerchief (Pack)', 'रुमाल पॅक', 'pack', 100, '/starter-images/clothing/handkerchief.png'),
  ('Winter Jacket', 'हिवाळी जॅकेट', 'pcs', 1400, '/starter-images/clothing/jacket.png'),
  ('Nightwear Set', 'नाईटवेअर सेट', 'set', 500, '/starter-images/clothing/nightwear.png'),
  ('Dupatta', 'दुपट्टा', 'pcs', 300, '/starter-images/clothing/dupatta.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'clothing';

-- ---- Hardware (18 items) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Cement Bag (50kg)', 'सिमेंट बॅग', 'bag', 400, '/starter-images/hardware/cement.png'),
  ('Steel Rod (per kg)', 'सळई (प्रति किलो)', 'kg', 70, '/starter-images/hardware/steel-rod.png'),
  ('Hammer', 'हातोडा', 'pcs', 250, '/starter-images/hardware/hammer.png'),
  ('Screwdriver Set', 'स्क्रूड्रायव्हर सेट', 'set', 300, '/starter-images/hardware/screwdriver.png'),
  ('Nails (1kg)', 'खिळे (१ किलो)', 'kg', 120, '/starter-images/hardware/nails.png'),
  ('Screws (Pack)', 'स्क्रू पॅक', 'pack', 80, '/starter-images/hardware/screws.png'),
  ('Paint (1L)', 'रंग (१ लिटर)', 'L', 350, '/starter-images/hardware/paint.png'),
  ('Paint Brush', 'रंगाचा ब्रश', 'pcs', 60, '/starter-images/hardware/brush.png'),
  ('PVC Pipe (per foot)', 'पीव्हीसी पाईप (प्रति फूट)', 'ft', 25, '/starter-images/hardware/pvc-pipe.png'),
  ('Tap/Faucet', 'नळ', 'pcs', 200, '/starter-images/hardware/tap.png'),
  ('Door Lock', 'दाराचं कुलूप', 'pcs', 450, '/starter-images/hardware/lock.png'),
  ('Hinges (Pair)', 'बिजागरी जोडी', 'pair', 80, '/starter-images/hardware/hinges.png'),
  ('Measuring Tape', 'मापन टेप', 'pcs', 150, '/starter-images/hardware/tape.png'),
  ('Wire Mesh (per sq ft)', 'जाळी (प्रति चौ. फूट)', 'sqft', 40, '/starter-images/hardware/wire-mesh.png'),
  ('Sandpaper', 'सँडपेपर', 'pcs', 20, '/starter-images/hardware/sandpaper.png'),
  ('Bucket (Plastic)', 'प्लास्टिक बादली', 'pcs', 150, '/starter-images/hardware/bucket.png'),
  ('Rope (per meter)', 'दोरी (प्रति मीटर)', 'm', 15, '/starter-images/hardware/rope.png'),
  ('Adhesive/Fevicol', 'फेविकॉल', 'pcs', 90, '/starter-images/hardware/adhesive.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'hardware';

-- ---- Restaurant (16 items) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Veg Thali', 'व्हेज थाळी', 'plate', 130, '/starter-images/restaurant/veg-thali.png'),
  ('Paneer Butter Masala', 'पनीर बटर मसाला', 'plate', 180, '/starter-images/restaurant/paneer-butter-masala.png'),
  ('Chicken Curry', 'चिकन करी', 'plate', 220, '/starter-images/restaurant/chicken-curry.png'),
  ('Plain Rice', 'साधा भात', 'plate', 60, '/starter-images/restaurant/rice.png'),
  ('Roti (per piece)', 'रोटी (प्रति नग)', 'pcs', 15, '/starter-images/restaurant/roti.png'),
  ('Dal Fry', 'डाळ फ्राय', 'bowl', 80, '/starter-images/restaurant/dal-fry.png'),
  ('Masala Dosa', 'मसाला डोसा', 'plate', 90, '/starter-images/restaurant/dosa.png'),
  ('Idli (Plate)', 'इडली प्लेट', 'plate', 60, '/starter-images/restaurant/idli.png'),
  ('Vada Pav', 'वडा पाव', 'pcs', 20, '/starter-images/restaurant/vada-pav.png'),
  ('Misal Pav', 'मिसळ पाव', 'plate', 70, '/starter-images/restaurant/misal.png'),
  ('Pav Bhaji', 'पाव भाजी', 'plate', 100, '/starter-images/restaurant/pav-bhaji.png'),
  ('Tea (Cup)', 'चहा', 'cup', 15, '/starter-images/restaurant/tea.png'),
  ('Coffee (Cup)', 'कॉफी', 'cup', 25, '/starter-images/restaurant/coffee.png'),
  ('Cold Drink (Bottle)', 'कोल्ड ड्रिंक', 'bottle', 40, '/starter-images/restaurant/cold-drink.png'),
  ('Gulab Jamun (Plate)', 'गुलाब जामून', 'plate', 60, '/starter-images/restaurant/gulab-jamun.png'),
  ('Papad', 'पापड', 'pcs', 15, '/starter-images/restaurant/papad.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'restaurant';

-- ---- Medical Store (18 items — generic categories only, no brand/Rx claims) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Paracetamol Tablets (Strip)', 'पॅरासिटामॉल गोळ्या', 'strip', 20, '/starter-images/medical/paracetamol.png'),
  ('Antacid Tablets (Strip)', 'अँटासिड गोळ्या', 'strip', 25, '/starter-images/medical/antacid.png'),
  ('ORS Sachet', 'ओआरएस पाकीट', 'pcs', 20, '/starter-images/medical/ors.png'),
  ('Cotton Roll', 'कापूस रोल', 'pcs', 40, '/starter-images/medical/cotton.png'),
  ('Bandage Roll', 'बँडेज रोल', 'pcs', 30, '/starter-images/medical/bandage.png'),
  ('Antiseptic Liquid (100ml)', 'अँटीसेप्टिक लिक्विड', 'bottle', 60, '/starter-images/medical/antiseptic.png'),
  ('Hand Sanitizer (100ml)', 'हँड सॅनिटायझर', 'bottle', 60, '/starter-images/medical/sanitizer.png'),
  ('Face Mask (Pack of 5)', 'मास्क पॅक', 'pack', 50, '/starter-images/medical/mask.png'),
  ('Thermometer', 'थर्मामीटर', 'pcs', 150, '/starter-images/medical/thermometer.png'),
  ('BP Monitor', 'बीपी मॉनिटर', 'pcs', 1500, '/starter-images/medical/bp-monitor.png'),
  ('Glucometer Strips', 'ग्लुकोमीटर स्ट्रिप्स', 'pack', 400, '/starter-images/medical/glucometer.png'),
  ('Multivitamin Tablets (Strip)', 'मल्टीविटॅमिन गोळ्या', 'strip', 100, '/starter-images/medical/multivitamin.png'),
  ('Cough Syrup (100ml)', 'खोकल्याचं औषध', 'bottle', 90, '/starter-images/medical/cough-syrup.png'),
  ('Pain Relief Spray', 'पेन रिलीफ स्प्रे', 'bottle', 180, '/starter-images/medical/pain-spray.png'),
  ('Baby Diapers (Pack)', 'बेबी डायपर पॅक', 'pack', 300, '/starter-images/medical/diapers.png'),
  ('Sanitary Pads (Pack)', 'सॅनिटरी पॅड्स', 'pack', 60, '/starter-images/medical/sanitary-pads.png'),
  ('Surgical Gloves (Pair)', 'सर्जिकल ग्लोव्ह्ज जोडी', 'pair', 20, '/starter-images/medical/gloves.png'),
  ('Weighing Scale', 'वजन काटा', 'pcs', 500, '/starter-images/medical/weighing-scale.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'medical-store';

-- ---- Contractor (15 items — services + materials) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Site Visit / Consultation', 'साईट व्हिजिट / सल्ला', 'visit', 500, '/starter-images/contractor/site-visit.png'),
  ('Masonry Work (per sq ft)', 'गवंडी काम (प्रति चौ. फूट)', 'sqft', 60, '/starter-images/contractor/masonry.png'),
  ('Plastering (per sq ft)', 'प्लास्टरिंग (प्रति चौ. फूट)', 'sqft', 35, '/starter-images/contractor/plastering.png'),
  ('Tile Fitting (per sq ft)', 'टाईल फिटिंग (प्रति चौ. फूट)', 'sqft', 40, '/starter-images/contractor/tiling.png'),
  ('Painting Work (per sq ft)', 'रंगकाम (प्रति चौ. फूट)', 'sqft', 18, '/starter-images/contractor/painting.png'),
  ('Electrical Wiring (per point)', 'इलेक्ट्रिकल वायरिंग (प्रति पॉइंट)', 'point', 350, '/starter-images/contractor/wiring.png'),
  ('Plumbing Work (per point)', 'प्लंबिंग काम (प्रति पॉइंट)', 'point', 400, '/starter-images/contractor/plumbing.png'),
  ('False Ceiling (per sq ft)', 'फॉल्स सीलिंग (प्रति चौ. फूट)', 'sqft', 80, '/starter-images/contractor/false-ceiling.png'),
  ('Waterproofing (per sq ft)', 'वॉटरप्रूफिंग (प्रति चौ. फूट)', 'sqft', 45, '/starter-images/contractor/waterproofing.png'),
  ('Demolition Work (per sq ft)', 'तोडफोड काम (प्रति चौ. फूट)', 'sqft', 25, '/starter-images/contractor/demolition.png'),
  ('Labour (per day)', 'मजूर (प्रति दिवस)', 'day', 600, '/starter-images/contractor/labour.png'),
  ('Sand (per brass)', 'वाळू (प्रति ब्रास)', 'brass', 3500, '/starter-images/contractor/sand.png'),
  ('Bricks (per 1000)', 'विटा (प्रति १०००)', 'unit1000', 6000, '/starter-images/contractor/bricks.png'),
  ('Scaffolding Rental (per day)', 'बांधकाम मचाण भाडे (प्रति दिवस)', 'day', 300, '/starter-images/contractor/scaffolding.png'),
  ('Site Cleaning', 'साईट साफसफाई', 'visit', 1000, '/starter-images/contractor/cleaning.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'contractor';

-- ---- Furniture (16 items) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Wooden Dining Table (4-seater)', 'लाकडी डायनिंग टेबल', 'pcs', 12000, '/starter-images/furniture/dining-table.png'),
  ('Dining Chair', 'डायनिंग चेअर', 'pcs', 2000, '/starter-images/furniture/dining-chair.png'),
  ('Sofa Set (3-seater)', 'सोफा सेट', 'set', 20000, '/starter-images/furniture/sofa.png'),
  ('Double Bed', 'डबल बेड', 'pcs', 15000, '/starter-images/furniture/bed.png'),
  ('Mattress', 'गादी', 'pcs', 6000, '/starter-images/furniture/mattress.png'),
  ('Wardrobe/Cupboard', 'कपाट', 'pcs', 18000, '/starter-images/furniture/wardrobe.png'),
  ('Study Table', 'अभ्यासाचं टेबल', 'pcs', 4500, '/starter-images/furniture/study-table.png'),
  ('Office Chair', 'ऑफिस चेअर', 'pcs', 3500, '/starter-images/furniture/office-chair.png'),
  ('Bookshelf', 'बुकशेल्फ', 'pcs', 5000, '/starter-images/furniture/bookshelf.png'),
  ('TV Unit/Stand', 'टीव्ही युनिट', 'pcs', 6000, '/starter-images/furniture/tv-unit.png'),
  ('Shoe Rack', 'शू रॅक', 'pcs', 2000, '/starter-images/furniture/shoe-rack.png'),
  ('Plastic Chair', 'प्लास्टिक खुर्ची', 'pcs', 500, '/starter-images/furniture/plastic-chair.png'),
  ('Folding Table', 'फोल्डिंग टेबल', 'pcs', 1800, '/starter-images/furniture/folding-table.png'),
  ('Kids Study Set', 'मुलांचा अभ्यास सेट', 'set', 5500, '/starter-images/furniture/kids-study.png'),
  ('Dressing Table', 'ड्रेसिंग टेबल', 'pcs', 7000, '/starter-images/furniture/dressing-table.png'),
  ('Recliner Chair', 'रिक्लायनर चेअर', 'pcs', 9000, '/starter-images/furniture/recliner.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'furniture';

-- ---- Real Estate / Property Dealer (12 service-oriented listings) ----
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('1 BHK Flat — Resale Listing', '१ बीएचके फ्लॅट — रीसेल', 'listing', 0, '/starter-images/real-estate/1bhk.png'),
  ('2 BHK Flat — Resale Listing', '२ बीएचके फ्लॅट — रीसेल', 'listing', 0, '/starter-images/real-estate/2bhk.png'),
  ('3 BHK Flat — Resale Listing', '३ बीएचके फ्लॅट — रीसेल', 'listing', 0, '/starter-images/real-estate/3bhk.png'),
  ('Plot for Sale', 'विक्रीसाठी प्लॉट', 'listing', 0, '/starter-images/real-estate/plot.png'),
  ('Row House for Sale', 'रो हाऊस विक्रीसाठी', 'listing', 0, '/starter-images/real-estate/row-house.png'),
  ('Shop/Commercial Space', 'दुकान/व्यावसायिक जागा', 'listing', 0, '/starter-images/real-estate/shop-space.png'),
  ('Flat on Rent', 'भाड्याने फ्लॅट', 'listing', 0, '/starter-images/real-estate/rent-flat.png'),
  ('Office Space on Rent', 'भाड्याने ऑफिस जागा', 'listing', 0, '/starter-images/real-estate/office-rent.png'),
  ('Agricultural Land for Sale', 'विक्रीसाठी शेत जमीन', 'listing', 0, '/starter-images/real-estate/farmland.png'),
  ('Property Registration Assistance', 'प्रॉपर्टी नोंदणी सहाय्य', 'service', 2000, '/starter-images/real-estate/registration.png'),
  ('Home Loan Assistance', 'गृहकर्ज सहाय्य', 'service', 1500, '/starter-images/real-estate/loan-assist.png'),
  ('Property Valuation Service', 'प्रॉपर्टी मूल्यांकन सेवा', 'service', 1000, '/starter-images/real-estate/valuation.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'real-estate';


-- ========================================================
-- FILE: 0008_dedupe_everything.sql
-- ========================================================
-- ============================================================================
-- 0008: Generic duplicate-product cleanup (reusable for ANY business, not
-- just mobile shop) + confirms the unique constraint from 0006 is active.
-- Safe to re-run any time — it's a no-op if there's nothing to clean.
-- ============================================================================

-- STEP 1 — dedupe, same logic as 0006, but covers everything again in case
-- new dupes were created (e.g. by a double form-submit) since then.
do $$
declare
  r record;
  v_keep_id uuid;
  v_dupe_id uuid;
  v_dupe_stock numeric;
begin
  for r in
    select business_id, industry_product_id
    from public.business_products
    where industry_product_id is not null
    group by business_id, industry_product_id
    having count(*) > 1
  loop
    select id into v_keep_id
    from public.business_products
    where business_id = r.business_id and industry_product_id = r.industry_product_id
    order by created_at asc
    limit 1;

    for v_dupe_id, v_dupe_stock in
      select id, stock from public.business_products
      where business_id = r.business_id
        and industry_product_id = r.industry_product_id
        and id != v_keep_id
    loop
      if v_dupe_stock != 0 then
        insert into public.inventory_movements (business_id, business_product_id, change_qty, reason, created_by)
        values (r.business_id, v_keep_id, v_dupe_stock, 'adjustment', null);
      end if;

      update public.order_items set business_product_id = v_keep_id where business_product_id = v_dupe_id;
      update public.inventory_movements set business_product_id = v_keep_id where business_product_id = v_dupe_id;
      update public.reviews set business_product_id = v_keep_id where business_product_id = v_dupe_id;

      delete from public.business_products where id = v_dupe_id;
    end loop;
  end loop;
end $$;

-- STEP 2 — also clean up duplicate BUSINESSES with the same owner + same name
-- (the "Nikhil Kirana" / "Nikhil Kirana-1" pattern from a double form-submit
-- on Create Business). Keeps the OLDEST, deletes newer duplicates that have
-- zero orders on them (never deletes one that already has real order history).
do $$
declare
  r record;
  v_keep_id uuid;
  v_dupe_id uuid;
begin
  for r in
    select owner_id, name
    from public.businesses
    group by owner_id, name
    having count(*) > 1
  loop
    select id into v_keep_id
    from public.businesses
    where owner_id = r.owner_id and name = r.name
    order by created_at asc
    limit 1;

    for v_dupe_id in
      select id from public.businesses
      where owner_id = r.owner_id and name = r.name and id != v_keep_id
    loop
      if not exists (select 1 from public.order_groups where business_id = v_dupe_id) then
        delete from public.audit_logs where business_id = v_dupe_id;
        delete from public.businesses where id = v_dupe_id;
      else
        raise notice 'Skipped deleting business % — it already has orders, review manually', v_dupe_id;
      end if;
    end loop;
  end loop;
end $$;

-- STEP 3 — re-confirm the unique constraint from 0006 actually exists
-- (harmless if it's already there).
create unique index if not exists business_products_unique_starter_item
  on public.business_products (business_id, industry_product_id)
  where industry_product_id is not null;


-- ========================================================
-- FILE: 0009_fix_catalog_template_duplicates.sql
-- ========================================================
-- ============================================================================
-- 0009: Fix the ACTUAL root cause — duplicate rows inside industry_products
-- itself (the master starter-catalog template), not just inside individual
-- businesses. If migration 0005 (or any seed file) ran twice, every mobile-
-- shop item ended up as two separate template rows with two different ids
-- but the same name — so every NEW business created after that copied BOTH,
-- and no per-business constraint could catch it (they're genuinely different
-- industry_product_id values).
-- ============================================================================

-- STEP 1 — clear out the entire Mobile Shop template catalog completely.
delete from public.industry_products
where business_type_id = (select id from public.business_types where slug = 'mobile-shop');

-- STEP 2 — permanently prevent this from ever happening again, for every
-- vertical, not just mobile-shop: the same product name can't be seeded
-- twice into the same business_type's template.
create unique index if not exists industry_products_unique_name_per_type
  on public.industry_products (business_type_id, name_en);

-- STEP 3 — re-insert the Mobile Shop starter catalog cleanly, once.
insert into public.industry_products (business_type_id, name_en, name_mr, unit, suggested_price, image_url, image_source, image_license)
select id, p.name_en, p.name_mr, p.unit, p.price, p.img, 'ai-generated', 'CC0-placeholder'
from public.business_types, lateral (values
  ('Smartphone (Entry-level)', 'स्मार्टफोन (एंट्री-लेव्हल)', 'pcs', 8000, '/starter-images/mobile-shop/phone-entry.png'),
  ('Smartphone (Mid-range)', 'स्मार्टफोन (मिड-रेंज)', 'pcs', 15000, '/starter-images/mobile-shop/phone-mid.png'),
  ('Screen Guard (Tempered Glass)', 'स्क्रीन गार्ड', 'pcs', 150, '/starter-images/mobile-shop/screen-guard.png'),
  ('Mobile Back Cover', 'मोबाईल कव्हर', 'pcs', 200, '/starter-images/mobile-shop/back-cover.png'),
  ('Charger (Original)', 'चार्जर (ओरिजिनल)', 'pcs', 500, '/starter-images/mobile-shop/charger.png'),
  ('Charging Cable', 'चार्जिंग केबल', 'pcs', 150, '/starter-images/mobile-shop/cable.png'),
  ('Earphones (Wired)', 'इअरफोन्स', 'pcs', 250, '/starter-images/mobile-shop/earphones.png'),
  ('Bluetooth Earbuds', 'ब्लूटूथ इअरबड्स', 'pcs', 1500, '/starter-images/mobile-shop/earbuds.png'),
  ('Power Bank 10000mAh', 'पॉवर बँक', 'pcs', 1100, '/starter-images/mobile-shop/powerbank.png'),
  ('Memory Card 32GB', 'मेमरी कार्ड ३२GB', 'pcs', 350, '/starter-images/mobile-shop/memory-card.png'),
  ('SIM Card', 'सिम कार्ड', 'pcs', 20, '/starter-images/mobile-shop/sim.png'),
  ('Mobile Stand/Holder', 'मोबाईल स्टँड', 'pcs', 150, '/starter-images/mobile-shop/stand.png'),
  ('Bluetooth Speaker', 'ब्लूटूथ स्पीकर', 'pcs', 1200, '/starter-images/mobile-shop/speaker.png'),
  ('Screen Repair Service', 'स्क्रीन रिपेअर सर्व्हिस', 'service', 800, '/starter-images/mobile-shop/repair.png'),
  ('Battery Replacement Service', 'बॅटरी बदलणे सर्व्हिस', 'service', 600, '/starter-images/mobile-shop/battery-service.png'),
  ('Mobile Recharge/Data Pack', 'मोबाईल रिचार्ज', 'pcs', 199, '/starter-images/mobile-shop/recharge.png'),
  ('USB OTG Adapter', 'OTG अ‍ॅडॉप्टर', 'pcs', 100, '/starter-images/mobile-shop/otg.png'),
  ('Selfie Stick', 'सेल्फी स्टिक', 'pcs', 250, '/starter-images/mobile-shop/selfie-stick.png'),
  ('Car Mobile Holder', 'कार मोबाईल होल्डर', 'pcs', 300, '/starter-images/mobile-shop/car-holder.png'),
  ('Mobile Cleaning Kit', 'मोबाईल क्लीनिंग किट', 'pcs', 120, '/starter-images/mobile-shop/cleaning-kit.png')
) as p(name_en, name_mr, unit, price, img)
where business_types.slug = 'mobile-shop';

-- STEP 4 — sanity check: also dedupe every OTHER vertical's template, in
-- case the same double-run affected them too. Keeps the oldest row per
-- (business_type_id, name_en), deletes newer duplicates. Any business that
-- already copied a now-deleted duplicate row keeps what it has — this only
-- cleans the template, not existing businesses (use 0008's logic for that
-- if a specific business still shows doubles).
do $$
declare
  r record;
  v_keep_id uuid;
begin
  for r in
    select business_type_id, name_en
    from public.industry_products
    group by business_type_id, name_en
    having count(*) > 1
  loop
    select id into v_keep_id
    from public.industry_products
    where business_type_id = r.business_type_id and name_en = r.name_en
    order by created_at asc
    limit 1;

    delete from public.industry_products
    where business_type_id = r.business_type_id and name_en = r.name_en and id != v_keep_id;
  end loop;
end $$;


-- ========================================================
-- FILE: 0010_wishlist.sql
-- ========================================================
-- ============================================================================
-- 0010: Wishlist table. (Reviews already existed since 0001/0002 — just
-- needed frontend UI, which comes in this same batch.)
-- ============================================================================

create table public.wishlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  business_product_id uuid not null references public.business_products(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, business_product_id)
);

create index wishlists_user_idx on public.wishlists(user_id);

alter table public.wishlists enable row level security;

create policy wishlists_self_only on public.wishlists
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant all on public.wishlists to authenticated;
grant usage on all sequences in schema public to authenticated;


-- ========================================================
-- FILE: 0011_saved_address.sql
-- ========================================================
-- ============================================================================
-- 0011: Saved delivery info on the user's own profile — so checkout can
-- pre-fill name/phone/address next time instead of retyping every order.
-- ============================================================================

alter table public.users add column if not exists default_phone text;
alter table public.users add column if not exists default_address text;


-- ========================================================
-- FILE: 0011_saved_delivery_info.sql
-- ========================================================
-- ============================================================================
-- 0011: Saved delivery info on profile — so returning customers don't have
-- to retype phone/name/address every checkout. Pure DB columns, no cost.
-- ============================================================================

alter table public.users add column if not exists saved_phone text;
alter table public.users add column if not exists saved_address text;


-- ========================================================
-- FILE: 0012_fix_product_images.sql
-- ========================================================
-- ============================================================================
-- 0012: Fix broken/missing product images.
-- Root cause: starter catalog rows were seeded with placeholder PATHS
-- (/starter-images/...) that were never backed by real uploaded files.
--
-- Fix: point every starter product at a free, copyright-safe generated
-- image via placehold.co (no signup, no cost, no copyright risk — it just
-- renders the product name as text on a colored box). This is a real,
-- always-working image URL, not a broken path. Swap these for real product
-- photos later; nothing else needs to change since it's just a URL.
-- ============================================================================

update public.industry_products ip
set image_url = 'https://placehold.co/400x400/' || colors.hex || '/FFFFFF?text=' ||
  replace(replace(ip.name_en, ' ', '+'), '&', 'and')
from (
  select bt.id as business_type_id,
    case bt.slug
      when 'grocery' then 'ff6b35'
      when 'electronics' then '2874f0'
      when 'mobile-shop' then '6c5ce7'
      when 'clothing' then 'e84393'
      when 'hardware' then '636e72'
      when 'restaurant' then 'e17055'
      when 'medical-store' then '00b894'
      when 'contractor' then 'fdcb6e'
      when 'furniture' then '8B5A2B'
      when 'real-estate' then '0984e3'
      else '95a5a6'
    end as hex
  from public.business_types bt
) colors
where ip.business_type_id = colors.business_type_id;

-- Also fix images already copied into existing businesses' live products
-- (business_products.image_url was copied at creation time, before this fix).
update public.business_products bp
set image_url = ip.image_url
from public.industry_products ip
where bp.industry_product_id = ip.id
  and (bp.image_url is null or bp.image_url like '/starter-images/%');


-- ========================================================
-- FILE: 0013_revenue_share_engine.sql
-- ========================================================
-- ============================================================================
-- 0013: Revenue Share Engine — calculation logic.
--
-- Important design note (matches the platform's core rule that it never
-- holds funds): this does NOT collect or move any money. It computes, for a
-- given period, what each campaign's PRORATED declared budget would be
-- worth, applies the admin-configured share_percent, and records the result
-- as a 'pending' revenue_shares row — a report for manual reconciliation
-- outside the platform, exactly like payments_metadata is for orders.
-- ============================================================================

alter table public.revenue_shares add column if not exists campaign_id uuid references public.campaigns(id);
alter table public.revenue_shares add column if not exists note text;

-- prevent duplicate rows if the same period is calculated twice
create unique index if not exists revenue_shares_unique_period
  on public.revenue_shares (campaign_id, rule_id, period_start, period_end)
  where campaign_id is not null;

-- ----------------------------------------------------------------------------
-- calculate_revenue_shares: admin-only. For every campaign active during the
-- given period, prorates its declared budget by the overlapping days, applies
-- the active 'platform_default' rule, and records a pending share row.
-- ----------------------------------------------------------------------------
create or replace function public.calculate_revenue_shares(
  p_period_start date,
  p_period_end date
)
returns integer
language plpgsql
security definer
as $$
declare
  v_rule public.revenue_share_rules;
  v_campaign record;
  v_overlap_days numeric;
  v_total_days numeric;
  v_gross numeric;
  v_share numeric;
  v_count integer := 0;
begin
  if not public.is_admin() then
    raise exception 'Admin only';
  end if;

  select * into v_rule from public.revenue_share_rules
    where applies_to = 'platform_default' and is_active
    order by created_at desc limit 1;

  if v_rule is null then
    raise exception 'No active platform_default revenue share rule configured. Set one first.';
  end if;

  for v_campaign in
    select c.id, c.name, c.budget, c.start_date, c.end_date
    from public.campaigns c
    where c.status in ('active', 'completed', 'paused')
      and c.budget is not null and c.budget > 0
      and c.start_date is not null and c.end_date is not null
      and c.start_date <= p_period_end
      and c.end_date >= p_period_start
  loop
    v_overlap_days := (least(v_campaign.end_date, p_period_end) - greatest(v_campaign.start_date, p_period_start)) + 1;
    v_total_days := (v_campaign.end_date - v_campaign.start_date) + 1;

    if v_total_days <= 0 or v_overlap_days <= 0 then
      continue;
    end if;

    v_gross := round(v_campaign.budget * (v_overlap_days / v_total_days), 2);
    v_share := round(v_gross * (v_rule.share_percent / 100), 2);

    insert into public.revenue_shares (campaign_id, rule_id, gross_amount, share_amount, period_start, period_end, status, note)
    values (v_campaign.id, v_rule.id, v_gross, v_share, p_period_start, p_period_end, 'pending',
      'Auto-calculated: ' || v_overlap_days || '/' || v_total_days || ' days of campaign "' || v_campaign.name || '" in period')
    on conflict (campaign_id, rule_id, period_start, period_end) do update
      set gross_amount = excluded.gross_amount, share_amount = excluded.share_amount, note = excluded.note;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

grant execute on function public.calculate_revenue_shares(date, date) to authenticated;


-- ========================================================
-- FILE: 0014_partner_referrals.sql
-- ========================================================
-- ============================================================================
-- 0014: Partner referral tracking. A partner shares a link like
-- index.html?ref=CODE — whoever signs up through it and later creates a
-- business or registers as an advertiser gets attributed to that partner.
-- ============================================================================

alter table public.businesses add column if not exists referred_by_partner_id uuid references public.partners(id);
alter table public.advertisers add column if not exists referred_by_partner_id uuid references public.advertisers(id);
-- fix: advertisers should reference partners, not itself
alter table public.advertisers drop constraint if exists advertisers_referred_by_partner_id_fkey;
alter table public.advertisers add constraint advertisers_referred_by_partner_id_fkey
  foreign key (referred_by_partner_id) references public.partners(id);

-- Let a partner see (read-only) the businesses/advertisers they referred —
-- without exposing those tenants' private data beyond name/verification.
create policy businesses_partner_read on public.businesses
  for select using (
    referred_by_partner_id in (select id from public.partners where user_id = auth.uid())
  );

create policy advertisers_partner_read on public.advertisers
  for select using (
    referred_by_partner_id in (select id from public.partners where user_id = auth.uid())
  );


-- ========================================================
-- FILE: 0015_auto_product_images.sql
-- ========================================================
-- ============================================================================
-- 0015: Automatic image_url on EVERY new product, from any insertion path —
-- CSV bulk import, "+ Add New Product", or new industry_products rows.
-- Implemented as triggers (not per-page JS) so it's guaranteed regardless of
-- which flow creates the row, now or in the future.
-- Sellers/admins can always override it afterward — nothing here locks it.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Helper: pick a brand color per business_type slug (same palette as 0012),
-- falling back to a neutral gray for anything not in the list.
-- ----------------------------------------------------------------------------
create or replace function public.business_type_color(p_slug text)
returns text
language sql
immutable
as $$
  select case p_slug
    when 'grocery' then 'ff6b35'
    when 'electronics' then '2874f0'
    when 'mobile-shop' then '6c5ce7'
    when 'clothing' then 'e84393'
    when 'hardware' then '636e72'
    when 'restaurant' then 'e17055'
    when 'medical-store' then '00b894'
    when 'contractor' then 'fdcb6e'
    when 'furniture' then '8B5A2B'
    when 'real-estate' then '0984e3'
    else '95a5a6'
  end;
$$;

-- ----------------------------------------------------------------------------
-- industry_products: auto-fill image_url on insert if left blank (covers
-- CSV bulk import via admin-catalog.html, and any future admin/API insert).
-- ----------------------------------------------------------------------------
create or replace function public.set_default_industry_product_image()
returns trigger
language plpgsql
as $$
declare
  v_slug text;
begin
  if new.image_url is null or new.image_url = '' then
    select slug into v_slug from public.business_types where id = new.business_type_id;
    new.image_url := 'https://placehold.co/400x400/' || public.business_type_color(v_slug) || '/FFFFFF?text=' ||
      replace(replace(new.name_en, ' ', '+'), '&', 'and');
    new.image_source := coalesce(new.image_source, 'auto-placeholder');
  end if;
  return new;
end;
$$;

drop trigger if exists industry_products_default_image on public.industry_products;
create trigger industry_products_default_image
  before insert on public.industry_products
  for each row execute function public.set_default_industry_product_image();

-- ----------------------------------------------------------------------------
-- business_products: auto-fill image_url on insert if still blank after the
-- copy-from-catalog step (covers "+ Add New Product" custom items, which
-- have no industry_product_id to inherit a photo from).
-- ----------------------------------------------------------------------------
create or replace function public.set_default_business_product_image()
returns trigger
language plpgsql
as $$
declare
  v_slug text;
begin
  if new.image_url is null or new.image_url = '' then
    select bt.slug into v_slug
    from public.businesses b join public.business_types bt on bt.id = b.business_type_id
    where b.id = new.business_id;

    new.image_url := 'https://placehold.co/400x400/' || public.business_type_color(v_slug) || '/FFFFFF?text=' ||
      replace(replace(new.name, ' ', '+'), '&', 'and');
    new.image_source := coalesce(new.image_source, 'auto-placeholder');
  end if;
  return new;
end;
$$;

drop trigger if exists business_products_default_image on public.business_products;
create trigger business_products_default_image
  before insert on public.business_products
  for each row execute function public.set_default_business_product_image();


-- ========================================================
-- FILE: 0016_ad_types_audio_poster.sql
-- ========================================================
-- ============================================================================
-- 0016: Expand supported ad creative types to audio and poster (banner,
-- image, video, native, sponsored_product, sponsored_business already existed).
-- ============================================================================

alter table public.advertisements drop constraint if exists advertisements_ad_type_check;
alter table public.advertisements add constraint advertisements_ad_type_check
  check (ad_type in ('banner', 'image', 'video', 'audio', 'poster', 'sponsored_product', 'sponsored_business', 'native'));


-- ========================================================
-- FILE: 0017_setup_storage_buckets.sql
-- ========================================================
-- 0017_setup_storage_buckets.sql
-- Create storage buckets for ads and products if they do not exist

insert into storage.buckets (id, name, public)
values 
  ('ads-media', 'ads-media', true),
  ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

-- Allow public read access to all uploaded media
create policy "Public Access to Ads Media"
on storage.objects for select
using ( bucket_id = 'ads-media' );

create policy "Public Access to Product Images"
on storage.objects for select
using ( bucket_id = 'product-images' );

-- Allow authenticated users to upload files
create policy "Authenticated Users Can Upload Ads Media"
on storage.objects for insert
to authenticated
with check ( bucket_id = 'ads-media' );

create policy "Authenticated Users Can Upload Product Images"
on storage.objects for insert
to authenticated
with check ( bucket_id = 'product-images' );


-- ========================================================
-- FILE: 0018_auto_cleanup_expired_ads.sql
-- ========================================================
-- 0018_auto_cleanup_expired_ads.sql
-- Automatic cleanup of expired advertisements and their media files from storage

-- 1. Helper function to delete expired ads and return file paths for storage cleanup
create or replace function public.cleanup_expired_ads()
returns table (
  deleted_ad_id uuid,
  deleted_media_url text,
  campaign_name text
)
language plpgsql
security definer
as $$
declare
  r record;
begin
  -- Find all ads belonging to campaigns where end_date has passed (end_date < CURRENT_DATE)
  for r in
    select a.id as ad_id, a.media_url, c.name as camp_name, a.campaign_id
    from public.advertisements a
    join public.campaigns c on c.id = a.campaign_id
    where (c.end_date is not null and c.end_date < current_date)
       or c.status = 'completed'
  loop
    deleted_ad_id := r.ad_id;
    deleted_media_url := r.media_url;
    campaign_name := r.camp_name;

    -- Delete tracking records first
    delete from public.ad_clicks where advertisement_id = r.ad_id;
    delete from public.ad_impressions where advertisement_id = r.ad_id;
    
    -- Delete the advertisement record
    delete from public.advertisements where id = r.ad_id;

    -- Mark campaign as completed
    update public.campaigns set status = 'completed' where id = r.campaign_id and status != 'completed';

    return next;
  end loop;
end;
$$;

grant execute on function public.cleanup_expired_ads() to authenticated, anon;


-- ========================================================
-- FILE: 0020_all_erp_comprehensive_schema.sql
-- ========================================================
-- ============================================================================
-- 0020: ALL ERP — Comprehensive Business Operating System Schema
-- Extends the Business Super Platform with complete modular ERP tables
-- ============================================================================

-- 1. COMPANIES & BRANCHES (Multi-Company & Multi-Branch Architecture)
create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  legal_name text not null,
  trade_name text,
  gstin text,
  pan text,
  state text default 'Maharashtra',
  country text default 'India',
  currency text default 'INR',
  financial_year_start date default '2026-04-01',
  logo_url text,
  is_active boolean default true,
  created_at timestamptz default now()
);

create table if not exists public.branches (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  company_id uuid references public.companies(id) on delete cascade,
  name text not null,
  code text,
  city text,
  state text default 'Maharashtra',
  address text,
  phone text,
  is_main boolean default false,
  created_at timestamptz default now()
);

-- 2. CRM (Leads, Opportunities, Pipeline)
create table if not exists public.crm_leads (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  company_name text,
  email text,
  phone text not null,
  source text default 'direct', -- website, referral, call, ads, walk-in
  stage text default 'new' check (stage in ('new', 'contacted', 'qualified', 'proposal', 'negotiation', 'won', 'lost')),
  expected_value numeric(12,2) default 0,
  assigned_to uuid references public.users(id),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. SALES & INVOICING (GST, Quotes, Orders, Invoices)
create table if not exists public.sales_quotations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  quotation_number text not null,
  customer_id uuid references public.customers(id),
  customer_name text not null,
  customer_phone text,
  quotation_date date default current_date,
  valid_until date default (current_date + interval '30 days'),
  subtotal numeric(12,2) default 0,
  tax_amount numeric(12,2) default 0,
  discount_amount numeric(12,2) default 0,
  grand_total numeric(12,2) default 0,
  status text default 'draft' check (status in ('draft', 'sent', 'accepted', 'rejected', 'converted')),
  items jsonb default '[]',
  notes text,
  created_at timestamptz default now()
);

create table if not exists public.sales_invoices (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  invoice_number text not null,
  customer_id uuid references public.customers(id),
  customer_name text not null,
  customer_phone text,
  customer_gstin text,
  invoice_date date default current_date,
  due_date date default (current_date + interval '15 days'),
  subtotal numeric(12,2) default 0,
  cgst numeric(12,2) default 0,
  sgst numeric(12,2) default 0,
  igst numeric(12,2) default 0,
  discount numeric(12,2) default 0,
  grand_total numeric(12,2) default 0,
  paid_amount numeric(12,2) default 0,
  balance_amount numeric(12,2) default 0,
  payment_status text default 'unpaid' check (payment_status in ('unpaid', 'partially_paid', 'paid', 'overdue')),
  items jsonb default '[]',
  notes text,
  created_at timestamptz default now()
);

-- 4. PURCHASE MANAGEMENT (PO, Bills)
create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  po_number text not null,
  supplier_id uuid references public.suppliers(id),
  supplier_name text not null,
  order_date date default current_date,
  expected_delivery date,
  total_amount numeric(12,2) default 0,
  paid_amount numeric(12,2) default 0,
  status text default 'draft' check (status in ('draft', 'ordered', 'received', 'billed', 'cancelled')),
  items jsonb default '[]',
  created_at timestamptz default now()
);

-- 5. ACCOUNTING & EXPENSES
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  category text not null, -- rent, electricity, salary, transport, maintenance, marketing, other
  title text not null,
  amount numeric(12,2) not null,
  payment_mode text default 'cash' check (payment_mode in ('cash', 'upi', 'bank_transfer', 'cheque', 'card')),
  expense_date date default current_date,
  vendor_name text,
  receipt_url text,
  notes text,
  created_by uuid references public.users(id),
  created_at timestamptz default now()
);

create table if not exists public.accounts_ledger (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  account_name text not null,
  account_type text not null, -- asset, liability, equity, revenue, expense
  debit numeric(12,2) default 0,
  credit numeric(12,2) default 0,
  balance numeric(12,2) default 0,
  reference_type text, -- invoice, payment, expense, po
  reference_id uuid,
  narration text,
  entry_date date default current_date,
  created_at timestamptz default now()
);

-- 6. HR & PAYROLL
create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  phone text not null,
  email text,
  department text default 'General',
  designation text default 'Staff',
  salary_amount numeric(12,2) default 0,
  salary_type text default 'monthly' check (salary_type in ('monthly', 'daily', 'hourly')),
  joining_date date default current_date,
  status text default 'active' check (status in ('active', 'on_leave', 'resigned', 'terminated')),
  created_at timestamptz default now()
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  date date default current_date,
  status text default 'present' check (status in ('present', 'absent', 'half_day', 'holiday', 'leave')),
  check_in time,
  check_out time,
  unique(employee_id, date)
);

create table if not exists public.payroll_records (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  month text not null, -- e.g. 2026-08
  basic_salary numeric(12,2) not null,
  allowances numeric(12,2) default 0,
  deductions numeric(12,2) default 0,
  net_salary numeric(12,2) not null,
  payment_status text default 'pending' check (payment_status in ('pending', 'paid')),
  paid_date date,
  created_at timestamptz default now()
);

-- 7. PROJECTS & CONTRACTOR ERP
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  client_name text,
  site_location text,
  budget numeric(12,2) default 0,
  estimated_cost numeric(12,2) default 0,
  actual_cost numeric(12,2) default 0,
  billed_amount numeric(12,2) default 0,
  received_amount numeric(12,2) default 0,
  start_date date,
  deadline date,
  status text default 'planning' check (status in ('planning', 'in_progress', 'review', 'completed', 'on_hold')),
  created_at timestamptz default now()
);

create table if not exists public.project_tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  title text not null,
  assigned_to text,
  status text default 'todo' check (status in ('todo', 'in_progress', 'review', 'done')),
  priority text default 'medium' check (priority in ('low', 'medium', 'high', 'urgent')),
  due_date date,
  created_at timestamptz default now()
);

-- 8. MANUFACTURING & RECIPES (BOM, Production)
create table if not exists public.bill_of_materials (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  finished_product_name text not null,
  output_quantity numeric(12,2) default 1,
  unit text default 'pcs',
  raw_materials jsonb not null default '[]', -- [{name, qty, unit, cost}]
  estimated_cost numeric(12,2) default 0,
  notes text,
  created_at timestamptz default now()
);

create table if not exists public.production_orders (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  bom_id uuid references public.bill_of_materials(id),
  product_name text not null,
  target_qty numeric(12,2) not null,
  produced_qty numeric(12,2) default 0,
  status text default 'planned' check (status in ('planned', 'in_production', 'completed', 'cancelled')),
  start_date date default current_date,
  end_date date,
  created_at timestamptz default now()
);

-- 9. SERVICE HELPDESK & APPOINTMENTS
create table if not exists public.service_tickets (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  ticket_number text not null,
  customer_name text not null,
  customer_phone text not null,
  service_type text not null, -- repair, amc, installation, consultation, complaint
  issue_description text,
  assigned_technician text,
  charge_amount numeric(12,2) default 0,
  status text default 'new' check (status in ('new', 'assigned', 'in_progress', 'resolved', 'closed')),
  created_at timestamptz default now()
);

create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_name text not null,
  customer_phone text not null,
  service_name text not null,
  staff_name text,
  appointment_date date not null,
  appointment_time time not null,
  status text default 'scheduled' check (status in ('scheduled', 'confirmed', 'completed', 'cancelled')),
  notes text,
  created_at timestamptz default now()
);

-- 10. DOCUMENT REPOSITORY
create table if not exists public.business_documents (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  category text not null default 'general', -- gst, license, contract, employee, tax, invoice, site
  title text not null,
  file_url text not null,
  file_type text,
  file_size text,
  tags text[],
  created_at timestamptz default now()
);

-- 11. ENABLE RLS FOR ALL NEW TABLES
alter table public.companies enable row level security;
alter table public.branches enable row level security;
alter table public.crm_leads enable row level security;
alter table public.sales_quotations enable row level security;
alter table public.sales_invoices enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.expenses enable row level security;
alter table public.accounts_ledger enable row level security;
alter table public.employees enable row level security;
alter table public.attendance enable row level security;
alter table public.payroll_records enable row level security;
alter table public.projects enable row level security;
alter table public.project_tasks enable row level security;
alter table public.bill_of_materials enable row level security;
alter table public.production_orders enable row level security;
alter table public.service_tickets enable row level security;
alter table public.appointments enable row level security;
alter table public.business_documents enable row level security;

-- Tenant Isolation RLS Policies
do $$
declare
  tbl text;
begin
  for tbl in select unnest(array[
    'companies','branches','crm_leads','sales_quotations','sales_invoices',
    'purchase_orders','expenses','accounts_ledger','employees','attendance',
    'payroll_records','projects','bill_of_materials','production_orders',
    'service_tickets','appointments','business_documents'
  ]) loop
    execute format('
      drop policy if exists %I_tenant_policy on public.%I;
      create policy %I_tenant_policy on public.%I
      for all using (public.is_business_member(business_id) or public.is_admin())
      with check (public.is_business_member(business_id) or public.is_admin());
    ', tbl, tbl, tbl, tbl);
  end loop;
end $$;

-- Tasks policy (via project_id)
drop policy if exists project_tasks_tenant_policy on public.project_tasks;
create policy project_tasks_tenant_policy on public.project_tasks
for all using (
  exists (select 1 from public.projects p where p.id = project_id and (public.is_business_member(p.business_id) or public.is_admin()))
);


-- ========================================================
-- FILE: 0021_ad_monetization_upi.sql
-- ========================================================
-- ============================================================================
-- 0021: Ad Monetization Engine via UPI & Payment Verifications
-- Adds UPI payment references, verification status, and monetization rules
-- ============================================================================

alter table public.campaigns 
  add column if not exists payment_status text default 'pending' check (payment_status in ('pending', 'paid', 'verified', 'failed')),
  add column if not exists payment_mode text default 'UPI',
  add column if not exists utr_number text,
  add column if not exists payment_screenshot_url text,
  add column if not exists impressions_budget integer default 1000,
  add column if not exists impressions_served integer default 0;

-- Allow advertisers to update their own campaign payment references
drop policy if exists campaigns_payment_update on public.campaigns;
create policy campaigns_payment_update on public.campaigns
  for update using (
    exists (
      select 1 from public.advertisers a 
      where a.id = advertiser_id and a.user_id = auth.uid()
    ) or public.is_admin()
  );

-- Admins can view and verify all campaign payments
grant select, update on public.campaigns to authenticated, anon;


-- Ensure public/anonymous can view active, verified ads on Marketplace
create policy if not exists advertisements_public_verified_read on public.advertisements
  for select using (
    is_active and exists (
      select 1 from public.campaigns c where c.id = campaign_id and c.status = 'active' and c.payment_status = 'verified'
    )
  );
