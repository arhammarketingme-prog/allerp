-- ============================================================================
-- 0000_BOOTSTRAP: निरुपयोगी नाही — हे खरंच missing होतं!
--
-- सापडलेला प्रश्न: `delivery_boys` हा टेबल कुठल्याही tracked migration
-- मध्ये कधीच CREATE केला गेला नव्हता — नंतरच्या सगळ्या migrations फक्त
-- त्यावर ALTER TABLE करतात, जणू तो आधीच अस्तित्वात आहे असं गृहीत धरून.
-- तुझ्या मूळ (live) Supabase वर तो आधीपासूनच (बहुधा थेट डॅशबोर्डमधून
-- manually) बनवलेला होता, म्हणून आधीचे runs यशस्वी झाले — पण नवीन/रिकाम्या
-- प्रोजेक्टवर ही संपूर्ण फाईल चालवली तर हा टेबलच सापडणार नाही.
--
-- ही फाईल संपूर्ण codebase मधल्या वापरावरून (insert/select/update calls)
-- पुनर्रचित केलेली रचना आहे — जर live वर आधीच टेबल असेल तर काहीही बदलणार
-- नाही (IF NOT EXISTS मुळे); नसेल (नवीन प्रोजेक्ट) तरच नव्याने बनेल.
-- ============================================================================

create table if not exists public.delivery_boys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  business_id uuid references public.businesses(id) on delete set null, -- null = प्लॅटफॉर्म-शेअर्ड, भरलेला = फक्त त्या दुकानाचा स्वतःचा
  name text not null,
  phone text not null,
  email text,
  vehicle_number text,
  is_available boolean not null default true,
  default_delivery_fee numeric(10,2) default 0,
  created_at timestamptz not null default now()
);

alter table public.delivery_boys enable row level security;
