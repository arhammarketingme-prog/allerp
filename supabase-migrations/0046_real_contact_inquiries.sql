-- ============================================================================
-- 0046: Contact Us फॉर्म खरा बनवणे — आधी "Send Inquiry" बटण फक्त alert()
-- दाखवायचं, संदेश कुठेच सेव्ह व्हायचा नाही (कायमचा हरवायचा).
-- ============================================================================

create table public.contact_inquiries (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact_info text not null,
  message text not null,
  status text not null default 'new' check (status in ('new', 'read', 'resolved')),
  created_at timestamptz not null default now()
);

alter table public.contact_inquiries enable row level security;

-- कोणीही (लॉगिन नसतानाही) संदेश पाठवू शकतो
create policy contact_inquiries_insert_any on public.contact_inquiries for insert with check (true);

-- फक्त admin वाचू/स्थिती बदलू शकतो
create policy contact_inquiries_admin_read on public.contact_inquiries for select using (public.is_admin());
create policy contact_inquiries_admin_update on public.contact_inquiries for update using (public.is_admin());
