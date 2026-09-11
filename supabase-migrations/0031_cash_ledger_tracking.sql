-- ============================================================================
-- 0031_cash_ledger_tracking.sql
-- ----------------------------------------------------------------------------
-- 🚨 महत्त्वाचं: प्लॅटफॉर्म कधीच पैसे स्वतःकडे घेत नाही, होल्ड करत नाही, किंवा
-- ट्रान्सफर करत नाही. रोख व्यवहार पूर्णपणे ग्राहक ↔ डिलिव्हरी बॉय ↔ दुकानदार
-- यांच्यामध्ये person-to-person होतो. हे मायग्रेशन फक्त त्या व्यवहाराचा
-- "हिशोब" (ledger) ठेवतं — जेणेकरून "कोणाकडे किती रोख प्रलंबित आहे" हे
-- सर्वांना दिसेल आणि वाद होणार नाहीत. यामुळे Payment Aggregator/PPI
-- परवान्याची गरज लागत नाही (RBI PA/PPI नियम फक्त प्लॅटफॉर्म स्वतः पैसे
-- "handle" करत असेल तरच लागू होतात).
-- ============================================================================

alter table public.orders
  add column if not exists cash_collected boolean default false,
  add column if not exists cash_collected_amount numeric,
  add column if not exists cash_collected_at timestamptz,
  add column if not exists cash_handover_status text,       -- null | pending_handover | handed_over | confirmed
  add column if not exists cash_handed_over_at timestamptz,
  add column if not exists cash_confirmed_at timestamptz;

comment on column public.orders.cash_handover_status is 'फक्त accounting/ledger साठी — प्लॅटफॉर्म पैसे हाताळत नाही. pending_handover=डिलिव्हरी बॉयकडे रोख आहे, handed_over=दुकानदाराला दिली (बॉयने नोंदवलं), confirmed=दुकानदाराने मिळाल्याचं मान्य केलं';

-- ---------------------------------------------------------------------------
-- 1. डिलिव्हरी बॉयसाठी: डिलिव्हरीच्या वेळी रोख घेतल्याची नोंद
-- ---------------------------------------------------------------------------
create or replace function public.record_cash_collected(
  p_order_id uuid,
  p_amount numeric
)
returns void
language plpgsql
security definer
as $$
declare
  v_order public.orders;
  v_is_assigned boolean;
begin
  select * into v_order from public.orders where id = p_order_id;
  if v_order is null then
    raise exception 'ऑर्डर सापडली नाही';
  end if;

  select exists(
    select 1 from public.delivery_boys db
    where db.id = v_order.delivery_boy_id and db.user_id = auth.uid()
  ) into v_is_assigned;

  if not v_is_assigned then
    raise exception 'ही ऑर्डर तुम्हाला असाइन झालेली नाही';
  end if;

  update public.orders
     set cash_collected = true,
         cash_collected_amount = p_amount,
         cash_collected_at = now(),
         cash_handover_status = 'pending_handover'
   where id = p_order_id;
end;
$$;

grant execute on function public.record_cash_collected(uuid, numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. डिलिव्हरी बॉयसाठी: एका दुकानाची सर्व प्रलंबित रोख "दिली" म्हणून नोंदवा
-- ---------------------------------------------------------------------------
create or replace function public.mark_cash_handed_over(
  p_business_id uuid
)
returns integer
language plpgsql
security definer
as $$
declare
  v_my_delivery_boy_id uuid;
  v_count integer;
begin
  select id into v_my_delivery_boy_id from public.delivery_boys where user_id = auth.uid();
  if v_my_delivery_boy_id is null then
    raise exception 'तुम्ही डिलिव्हरी बॉय म्हणून नोंदणीकृत नाही';
  end if;

  update public.orders
     set cash_handover_status = 'handed_over',
         cash_handed_over_at = now()
   where business_id = p_business_id
     and delivery_boy_id = v_my_delivery_boy_id
     and cash_handover_status = 'pending_handover';

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.mark_cash_handed_over(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. दुकानदारासाठी: एका डिलिव्हरी बॉयकडून मिळालेली रोख कन्फर्म करणं
-- ---------------------------------------------------------------------------
create or replace function public.confirm_cash_received(
  p_delivery_boy_id uuid
)
returns integer
language plpgsql
security definer
as $$
declare
  v_count integer;
begin
  update public.orders o
     set cash_handover_status = 'confirmed',
         cash_confirmed_at = now()
   where o.delivery_boy_id = p_delivery_boy_id
     and o.cash_handover_status = 'handed_over'
     and exists (
       select 1 from public.businesses b
       where b.id = o.business_id and b.owner_id = auth.uid()
     );

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.confirm_cash_received(uuid) to authenticated;
