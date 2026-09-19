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
