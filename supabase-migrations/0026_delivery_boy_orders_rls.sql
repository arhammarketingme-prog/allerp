-- ============================================================================
-- 0026_delivery_boy_orders_rls.sql
-- ----------------------------------------------------------------------------
-- मूळ समस्या: orders टेबलवर RLS चालू आहे, पण डिलिव्हरी बॉयला त्याला असाइन
-- झालेल्या ऑर्डर्स वाचायला/अपडेट करायला परवानगी देणारी कुठलीही policy
-- अस्तित्वातच नव्हती. त्यामुळे delivery-boy.html वरची क्वेरी नेहमी रिकामी
-- (empty) यायची — ना जुन्या असाइन केलेल्या ऑर्डर्स दिसायच्या, ना पिन
-- टाकण्याचा/status बदलण्याचा पर्याय दिसायचा (कारण दिसण्यासाठी डेटाच येत
-- नव्हता). हे मायग्रेशन ती परवानगी जोडतं.
-- ============================================================================

-- 1. SELECT: डिलिव्हरी बॉय फक्त स्वतःला असाइन झालेल्या ऑर्डर्स वाचू शकतो
drop policy if exists delivery_boy_orders_select on public.orders;
create policy delivery_boy_orders_select on public.orders
  for select
  using (
    delivery_boy_id in (
      select id from public.delivery_boys where user_id = auth.uid()
    )
  );

-- 2. UPDATE: डिलिव्हरी बॉय फक्त स्वतःला असाइन झालेल्या ऑर्डरचा status बदलू
--    शकतो (उदा. dispatched/delivered), किंवा स्वतःला असाइनमेंटमधून काढून
--    (नाकारून) टाकू शकतो (delivery_boy_id = null करून)
drop policy if exists delivery_boy_orders_update on public.orders;
create policy delivery_boy_orders_update on public.orders
  for update
  using (
    delivery_boy_id in (
      select id from public.delivery_boys where user_id = auth.uid()
    )
  )
  with check (
    delivery_boy_id is null
    or delivery_boy_id in (
      select id from public.delivery_boys where user_id = auth.uid()
    )
  );

-- 3. डिलिव्हरी बॉयला स्वतःचा delivery_boys रो वाचता/बदलता यावा (उपलब्धता टॉगल इ.)
--    — जर आधीच permissive असेल तर ह्या policies अतिरिक्त सुरक्षा म्हणून काम करतील
alter table public.delivery_boys enable row level security;

drop policy if exists delivery_boy_self_select on public.delivery_boys;
create policy delivery_boy_self_select on public.delivery_boys
  for select
  using (user_id = auth.uid());

drop policy if exists delivery_boy_self_update on public.delivery_boys;
create policy delivery_boy_self_update on public.delivery_boys
  for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- 4. अ‍ॅडमिनला delivery_boys चं पूर्ण व्यवस्थापन (admin.html) करता यावं
drop policy if exists delivery_boy_admin_all on public.delivery_boys;
create policy delivery_boy_admin_all on public.delivery_boys
  for all
  using (
    exists (select 1 from public.users u where u.id = auth.uid() and u.is_admin)
  )
  with check (
    exists (select 1 from public.users u where u.id = auth.uid() and u.is_admin)
  );

-- 5. दुकानदाराला (business owner) स्वतःच्या दुकानाचे delivery boy assign
--    करण्यासाठी delivery_boys यादी दिसणं गरजेचं आहे (dashboard.html dropdown) —
--    उपलब्ध (is_available) डिलिव्हरी बॉईज सर्व लॉगिन केलेल्या युजरना दिसू द्या
drop policy if exists delivery_boy_public_available_select on public.delivery_boys;
create policy delivery_boy_public_available_select on public.delivery_boys
  for select
  using (is_available = true);
