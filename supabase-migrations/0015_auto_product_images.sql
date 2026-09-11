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
