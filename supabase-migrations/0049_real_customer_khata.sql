-- ============================================================================
-- 0049: खरं Customer Khata (उधारी वही) — आधी हे फीचर अस्तित्वातच नव्हतं.
--
-- सापडलेला गंभीर प्रश्न: customer-passbook.html हे प्रत्यक्षात ग्राहकाच्या
-- सगळ्या ऑर्डर्सची किंमत बेरीज करून "एकूण उधारी" म्हणून दाखवत होतं —
-- ऑर्डर आधीच रोख/UPI ने पूर्ण झाली असली तरीही ती रक्कम उधारी म्हणून
-- मोजली जायची. ही दिशाभूल करणारी, चुकीची माहिती होती. आणि दुकानदाराला
-- (retailer) कुठल्याही ग्राहकाची उधारी manually नोंदवायला जागाच नव्हती
-- (उदा. दुकानात येऊन उधार घेतलेला माल — जो app मधून order केलेलाच नाही).
--
-- आता: वेगळा, खरा khata_entries टेबल — दुकानदार debit (उधार दिली) आणि
-- credit (पैसे परत मिळाले) नोंदी टाकू शकतो, ग्राहकाला खरी शिल्लक दिसते.
-- ============================================================================

create table public.khata_entries (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_phone text not null,
  customer_name text not null,
  customer_user_id uuid references public.users(id), -- ग्राहकाचंही अकाउंट असेल तरच लिंक होतं (ऐच्छिक)
  entry_type text not null check (entry_type in ('debit', 'credit')), -- debit = उधार दिली (वाढते), credit = पैसे मिळाले (कमी होते)
  amount numeric(12,2) not null check (amount > 0),
  note text,
  due_date date,
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now()
);

create index idx_khata_business_customer on public.khata_entries(business_id, customer_phone);
create index idx_khata_customer_user on public.khata_entries(customer_user_id);

alter table public.khata_entries enable row level security;

-- दुकानदार (व्यवसायाचा मालक/सदस्य) — फक्त स्वतःच्या दुकानाच्या नोंदी बघू/जोडू शकतो
create policy khata_business_owner_access on public.khata_entries
  for all using (public.is_business_member(business_id))
  with check (public.is_business_member(business_id));

-- ग्राहक — फक्त स्वतःच्या नोंदी वाचू शकतो (edit करू शकत नाही — फक्त दुकानदारच नोंदवतो, खऱ्या Khata सारखं)
create policy khata_customer_read_own on public.khata_entries
  for select using (customer_user_id = auth.uid());

-- 📊 प्रत्येक ग्राहकाची सध्याची शिल्लक (debit - credit) एका दृष्टीक्षेपात
-- ⚠️ security_invoker=true अनिवार्य — नाहीतर हा view underlying RLS
-- बायपास करून सगळ्या दुकानांची सगळ्या ग्राहकांची शिल्लक+फोन नंबर
-- कोणालाही दाखवेल (गंभीर privacy leak).
create or replace view public.khata_customer_balances
with (security_invoker = true) as
select business_id, customer_phone, customer_name,
       max(customer_user_id) as customer_user_id,
       coalesce(sum(case when entry_type = 'debit' then amount else 0 end), 0)
         - coalesce(sum(case when entry_type = 'credit' then amount else 0 end), 0) as balance,
       max(created_at) as last_entry_at
from public.khata_entries
group by business_id, customer_phone, customer_name;

grant select on public.khata_customer_balances to authenticated;

-- 🔍 फोन नंबरवरून युजर आयडी शोधण्यासाठी सुरक्षित RPC — दुकानदाराला दुसऱ्या
-- युजरची कुठलीही खाजगी माहिती (नाव, इतर तपशील) दिसू नये म्हणून फक्त id
-- परत देतो, आणि तेही फक्त Khata entry ला त्या account शी लिंक करण्यासाठी.
create or replace function public.find_user_id_by_phone(p_phone text)
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select id from public.users where phone = p_phone limit 1;
$$;

grant execute on function public.find_user_id_by_phone(text) to authenticated;
