-- ============================================================================
-- 0038: Barcode-based Product Master + Product Variants
--
-- Adds the missing pieces from ALL ERP V2 spec sections 11, 12, 14, 16:
--   - A real, global, cross-tenant Product Master keyed by barcode (GTIN),
--     separate from industry_products (which is just a per-business-type
--     starter catalog, not a shared barcode identity).
--   - barcode + product_master_id on business_products (Store Listing).
--   - parent_id + variant_label on business_products for product variants
--     (e.g. Coca-Cola 250ml / 500ml / 750ml as sibling rows).
-- ============================================================================

-- 1) Global Product Master
create table if not exists public.product_master (
  id uuid primary key default gen_random_uuid(),
  barcode text not null unique,
  name text not null,
  brand text,
  category text,
  unit text,
  image_url text,
  image_source text,
  approval_status text not null default 'pending'
    check (approval_status in ('pending','approved','rejected')),
  created_by_business_id uuid references public.businesses(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_product_master_barcode on public.product_master(barcode);

alter table public.product_master enable row level security;

-- कुठलाही logged-in युजर वाचू शकतो (auto-fill साठी आवश्यक)
drop policy if exists product_master_read on public.product_master;
create policy product_master_read on public.product_master
  for select using (auth.role() = 'authenticated');

-- फक्त platform admin approve/reject/edit करू शकतो
drop policy if exists product_master_admin_write on public.product_master;
create policy product_master_admin_write on public.product_master
  for update using (
    exists (select 1 from public.users u where u.id = auth.uid() and u.is_admin)
  );

-- 2) business_products (Store Listing) — barcode + master link + variants
alter table public.business_products add column if not exists barcode text;
alter table public.business_products add column if not exists product_master_id uuid
  references public.product_master(id) on delete set null;
alter table public.business_products add column if not exists parent_id uuid
  references public.business_products(id) on delete cascade;
alter table public.business_products add column if not exists variant_label text;

-- एका दुकानात एकच barcode दोनदा नको
create unique index if not exists idx_business_products_business_barcode
  on public.business_products(business_id, barcode) where barcode is not null;

-- 3) RPC: बारकोड स्कॅन केल्यावर आधी स्वतःच्या दुकानात, मग ग्लोबल मास्टरमध्ये शोध
create or replace function public.lookup_barcode(p_barcode text, p_business_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_own record;
  v_master record;
begin
  select * into v_own from public.business_products
    where business_id = p_business_id and barcode = p_barcode limit 1;
  if found then
    return jsonb_build_object('source', 'own_shop', 'product', to_jsonb(v_own));
  end if;

  select * into v_master from public.product_master
    where barcode = p_barcode limit 1;
  if found then
    return jsonb_build_object('source', 'master', 'product', to_jsonb(v_master));
  end if;

  return jsonb_build_object('source', 'not_found');
end;
$$;

grant execute on function public.lookup_barcode(text, uuid) to authenticated;

-- 4) RPC: नवीन बारकोड सेव्ह करताना ग्लोबल मास्टरमध्येही (crowd-sourced, pending
--    status) नोंद कर — आधीच असेल तर तीच id परत दे (डुप्लिकेट नको)
create or replace function public.get_or_create_product_master(
  p_barcode text, p_name text, p_unit text, p_image_url text, p_business_id uuid
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  select id into v_id from public.product_master where barcode = p_barcode;
  if v_id is not null then
    return v_id;
  end if;

  insert into public.product_master (barcode, name, unit, image_url, image_source, approval_status, created_by_business_id)
  values (p_barcode, p_name, p_unit, p_image_url, 'seller-provided', 'pending', p_business_id)
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.get_or_create_product_master(text, text, text, text, uuid) to authenticated;

-- ============================================================================
-- Result: barcode scan → lookup_barcode() checks own shop then global master.
-- Save → get_or_create_product_master() crowd-sources the master (pending,
-- admin must approve in admin.html before it's trusted platform-wide).
-- Variants → business_products.parent_id + variant_label (sibling rows).
-- ============================================================================
