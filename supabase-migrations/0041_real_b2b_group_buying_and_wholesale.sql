-- ============================================================================
-- 0041: दोन वेगळ्या, खऱ्या (fake-data नसलेल्या) B2B फीचर्सची पायाभरणी
--
-- अ) Community Group Buying — ग्राहकांसाठी. आधीचं b2b-collective.html पान
--    पूर्णपणे hardcoded/fake होतं (कुठलाही DB कॉल नव्हता). आता खरे pools,
--    खरी commitments.
-- ब) Wholesaler ↔ Retailer B2B — व्यवसायांमधलं वेगळं, bulk price + PO सिस्टीम
--    (स्पेक section 19).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- अ) Community Group Buying
-- ---------------------------------------------------------------------------
create table public.group_buying_pools (
  id uuid primary key default gen_random_uuid(),
  item_name text not null,
  unit_label text not null,              -- उदा. 'kg', 'बॅग', 'डबे'
  factory_price numeric(12,2) not null,
  retail_price numeric(12,2),
  target_quantity numeric(12,2) not null,
  city text,
  status text not null default 'active' check (status in ('active','completed','cancelled')),
  closes_at date,
  created_at timestamptz not null default now()
);

create table public.group_buying_commitments (
  id uuid primary key default gen_random_uuid(),
  pool_id uuid not null references public.group_buying_pools(id) on delete cascade,
  customer_user_id uuid not null references public.users(id) on delete cascade,
  quantity numeric(12,2) not null check (quantity > 0),
  phone text,
  created_at timestamptz not null default now(),
  unique (pool_id, customer_user_id)
);

alter table public.group_buying_pools enable row level security;
alter table public.group_buying_commitments enable row level security;

create policy group_buying_pools_read on public.group_buying_pools for select using (true);
create policy group_buying_pools_admin_write on public.group_buying_pools for all using (public.is_admin()) with check (public.is_admin());

create policy group_buying_commitments_own_read on public.group_buying_commitments
  for select using (customer_user_id = auth.uid() or public.is_admin());

-- सार्वजनिक pools यादी + एकत्रित मागणी (individual commitments उघड न करता)
create or replace view public.group_buying_pools_public as
select p.id, p.item_name, p.unit_label, p.factory_price, p.retail_price,
       p.target_quantity, p.city, p.status, p.closes_at, p.created_at,
       coalesce(sum(c.quantity), 0) as committed_quantity
from public.group_buying_pools p
left join public.group_buying_commitments c on c.pool_id = p.id
group by p.id;

grant select on public.group_buying_pools_public to authenticated, anon;

-- ग्राहकाची मागणी नोंदवणे (already असेल तर अपडेट होईल — दोनदा नोंद होणार नाही)
create or replace function public.commit_to_pool(p_pool_id uuid, p_quantity numeric, p_phone text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'कृपया योग्य प्रमाण टाका';
  end if;

  if not exists (select 1 from public.group_buying_pools where id = p_pool_id and status = 'active') then
    raise exception 'हा पूल आता सक्रिय नाही';
  end if;

  insert into public.group_buying_commitments (pool_id, customer_user_id, quantity, phone)
  values (p_pool_id, auth.uid(), p_quantity, p_phone)
  on conflict (pool_id, customer_user_id)
  do update set quantity = excluded.quantity, phone = excluded.phone, created_at = now();
end;
$$;

grant execute on function public.commit_to_pool(uuid, numeric, text) to authenticated;

-- ---------------------------------------------------------------------------
-- ब) Wholesaler ↔ Retailer B2B
-- ---------------------------------------------------------------------------
alter table public.businesses add column if not exists is_wholesaler boolean not null default false;

alter table public.business_products add column if not exists wholesale_price numeric(12,2);
alter table public.business_products add column if not exists min_order_qty numeric(12,2);

create table public.b2b_orders (
  id uuid primary key default gen_random_uuid(),
  wholesaler_business_id uuid not null references public.businesses(id),
  buyer_business_id uuid not null references public.businesses(id),
  items_summary jsonb not null,
  total_amount numeric(12,2) not null,
  status text not null default 'placed'
    check (status in ('placed','accepted','rejected','processing','ready','shipped','delivered','cancelled')),
  payment_method text,
  created_at timestamptz not null default now()
);

alter table public.b2b_orders enable row level security;

create policy b2b_orders_wholesaler_access on public.b2b_orders for select using (
  exists (select 1 from public.businesses b where b.id = wholesaler_business_id and b.owner_id = auth.uid())
  or public.is_admin()
);
create policy b2b_orders_buyer_access on public.b2b_orders for select using (
  exists (select 1 from public.businesses b where b.id = buyer_business_id and b.owner_id = auth.uid())
  or public.is_admin()
);
create policy b2b_orders_wholesaler_update on public.b2b_orders for update using (
  exists (select 1 from public.businesses b where b.id = wholesaler_business_id and b.owner_id = auth.uid())
  or public.is_admin()
);

-- सुरक्षित B2B ऑर्डर — किंमत/MOQ/स्टॉक सर्व्हरवरच तपासतं आणि रो-लॉक करतं
-- (place_direct_order प्रमाणेच सुरक्षा पॅटर्न)
create or replace function public.place_b2b_order(
  p_wholesaler_business_id uuid,
  p_buyer_business_id uuid,
  p_items jsonb   -- [{ "business_product_id": "...", "quantity": 10 }, ...]
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item jsonb;
  v_product record;
  v_total numeric(12,2) := 0;
  v_items_summary jsonb := '[]'::jsonb;
  v_order_id uuid;
  v_buyer_owner uuid;
  v_qty numeric;
begin
  select owner_id into v_buyer_owner from public.businesses where id = p_buyer_business_id;
  if v_buyer_owner is null or v_buyer_owner <> auth.uid() then
    raise exception 'अनधिकृत: ही खरेदी तुझ्या व्यवसायाकडून नोंदवली जात नाहीये';
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_qty := (v_item->>'quantity')::numeric;

    select * into v_product from public.business_products
      where id = (v_item->>'business_product_id')::uuid
        and business_id = p_wholesaler_business_id
        and is_active = true
      for update;

    if not found then
      raise exception 'उत्पादन सापडलं नाही किंवा या होलसेलरचं नाही';
    end if;

    if v_product.wholesale_price is null then
      raise exception '"%" साठी होलसेल भाव अजून सेट केलेला नाही', v_product.name;
    end if;

    if v_qty < coalesce(v_product.min_order_qty, 0) then
      raise exception '"%" साठी किमान ऑर्डर प्रमाण % आहे', v_product.name, v_product.min_order_qty;
    end if;

    if v_product.stock < v_qty then
      raise exception '"%" साठी पुरेसा स्टॉक नाही', v_product.name;
    end if;

    update public.business_products set stock = stock - v_qty where id = v_product.id;

    v_total := v_total + (v_product.wholesale_price * v_qty);
    v_items_summary := v_items_summary || jsonb_build_object(
      'name', v_product.name, 'quantity', v_qty,
      'unit_price', v_product.wholesale_price, 'unit', v_product.unit
    );
  end loop;

  insert into public.b2b_orders (wholesaler_business_id, buyer_business_id, items_summary, total_amount)
  values (p_wholesaler_business_id, p_buyer_business_id, v_items_summary, v_total)
  returning id into v_order_id;

  return v_order_id;
end;
$$;

grant execute on function public.place_b2b_order(uuid, uuid, jsonb) to authenticated;
