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
