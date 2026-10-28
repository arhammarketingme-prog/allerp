-- ============================================================================
-- 0047: Group Buying Pool — कोणता दुकानदार/होलसेलर तो पूल प्रत्यक्ष भरणार
-- (fulfill करणार) हे नोंदवण्यासाठी, आणि admin ला पूर्ण सहभागी यादी
-- (नाव+फोन+प्रमाण) बघता यावी यासाठी दुरुस्ती.
-- ============================================================================

alter table public.group_buying_pools
  add column if not exists assigned_business_id uuid references public.businesses(id);

-- सार्वजनिक व्ह्यूमध्ये आता कोणता दुकानदार पूल भरतोय तेही दिसेल
create or replace view public.group_buying_pools_public as
select p.id, p.item_name, p.unit_label, p.factory_price, p.retail_price,
       p.target_quantity, p.city, p.status, p.closes_at, p.created_at,
       p.assigned_business_id, b.name as assigned_business_name,
       coalesce(sum(c.quantity), 0) as committed_quantity
from public.group_buying_pools p
left join public.group_buying_commitments c on c.pool_id = p.id
left join public.businesses b on b.id = p.assigned_business_id
group by p.id, b.name;

grant select on public.group_buying_pools_public to authenticated, anon;
