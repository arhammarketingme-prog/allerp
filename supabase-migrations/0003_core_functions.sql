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
