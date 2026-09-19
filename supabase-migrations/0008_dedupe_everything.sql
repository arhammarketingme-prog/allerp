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
