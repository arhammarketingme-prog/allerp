-- ============================================================================
-- 0028_shop_owned_delivery_boys.sql
-- ----------------------------------------------------------------------------
-- मूळ कल्पना: डिलिव्हरी दोन प्रकारे होऊ शकते —
--   1) 🏪 दुकानाचा स्वतःचा माणूस/कर्मचारी (shop-owned) — फक्त त्याच
--      दुकानाला दिसतो/असाइन करता येतो, दुकानदार स्वतः जोडतो.
--   2) 🏢 प्लॅटफॉर्मचा (आमचा) सामायिक डिलिव्हरी बॉय पूल — admin.html मधून
--      अ‍ॅडमिन जोडतो/मॅनेज करतो, सर्व दुकानांना दिसतो/असाइन करता येतो.
-- (Self delivery — दुकानदार स्वतः देतो — त्यासाठी delivery_boy_id रिकामाच
--  ठेवायचा, वेगळी नोंद लागत नाही; ते आधीपासूनच आहे.)
-- ============================================================================

-- 1. business_id जोडा: null = प्लॅटफॉर्मचा (admin-managed), भरलेला = त्या
--    दुकानाचा स्वतःचा कर्मचारी
alter table public.delivery_boys
  add column if not exists business_id uuid references public.businesses(id) on delete cascade;

comment on column public.delivery_boys.business_id is 'null = प्लॅटफॉर्मचा शेअर्ड डिलिव्हरी बॉय (अ‍ॅडमिन-व्यवस्थापित); भरलेला असेल तर तो फक्त त्या दुकानाचा स्वतःचा कर्मचारी आहे';

create index if not exists delivery_boys_business_idx on public.delivery_boys(business_id);

-- 2. RLS: दुकानदाराला स्वतःच्या दुकानाचे delivery boys पूर्णपणे मॅनेज (add/edit/delete/toggle)
--    करता यावेत
alter table public.delivery_boys enable row level security;

drop policy if exists delivery_boy_shop_owner_all on public.delivery_boys;
create policy delivery_boy_shop_owner_all on public.delivery_boys
  for all
  using (
    business_id is not null
    and exists (
      select 1 from public.businesses b
      where b.id = delivery_boys.business_id and b.owner_id = auth.uid()
    )
  )
  with check (
    business_id is not null
    and exists (
      select 1 from public.businesses b
      where b.id = delivery_boys.business_id and b.owner_id = auth.uid()
    )
  );

-- 3. आधीची "सर्व उपलब्ध डिलिव्हरी बॉय दिसू द्या" policy फक्त प्लॅटफॉर्मच्या
--    (business_id null असलेल्या) साठीच ठेवा — शेजारच्या दुकानाचा खासगी
--    कर्मचारी दुसऱ्या दुकानदाराला दिसता कामा नये
drop policy if exists delivery_boy_public_available_select on public.delivery_boys;
create policy delivery_boy_public_available_select on public.delivery_boys
  for select
  using (business_id is null and is_available = true);
