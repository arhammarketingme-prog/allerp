-- ============================================================================
-- 0037: Remove dead order_groups/order_items model.
--
-- Confirmed via full-repo grep: the frontend does NOT use order_groups,
-- order_items, place_order(), lookup_orders_by_phone(), or
-- update_order_status() anywhere. The live app uses the flat `orders` table
-- + place_direct_order() (see migration 0022's own comment, which already
-- documents this divergence). This migration removes the superseded model.
--
-- ⚠️ BEFORE RUNNING ON PRODUCTION:
--   Check these are empty (or contain no data you need) first:
--     select count(*) from public.order_groups;
--     select count(*) from public.order_items;
--     select count(*) from public.payments_metadata;
--   If any has real rows, export them (Table Editor → Export CSV) before
--   proceeding — this migration is irreversible once applied.
-- ============================================================================

-- 0) Drop payments_metadata first — also confirmed dead (unused in
--    frontend; orders.payment_method/payment_status already cover this on
--    the flat model). Its FK to order_groups blocks step 3 below otherwise.
drop policy if exists payments_metadata_seller_only on public.payments_metadata;
drop table if exists public.payments_metadata;

-- 1) Drop RLS policies on the tables being removed
drop policy if exists order_groups_seller_read     on public.order_groups;
drop policy if exists order_groups_customer_read    on public.order_groups;
drop policy if exists order_groups_customer_insert  on public.order_groups;
drop policy if exists order_groups_seller_update    on public.order_groups;
drop policy if exists order_items_seller_read       on public.order_items;
drop policy if exists order_items_customer_read     on public.order_items;
drop policy if exists order_items_insert            on public.order_items;

-- 2) Drop the dead RPCs that only this old model supported
drop function if exists public.place_order(text, text, jsonb);
drop function if exists public.lookup_orders_by_phone(text);
drop function if exists public.update_order_status(uuid, text);

-- 3) Drop the tables (order_items first — it references order_groups)
drop table if exists public.order_items;
drop table if exists public.order_groups;

-- ============================================================================
-- Result: only the flat `orders` table + place_direct_order() remain as the
-- single, live order model. No dead schema left to confuse future audits.
-- ============================================================================
