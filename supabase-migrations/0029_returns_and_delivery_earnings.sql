-- ============================================================================
-- 0029_returns_and_delivery_earnings.sql
-- ----------------------------------------------------------------------------
-- भाग अ: ऑर्डर रिटर्न/रिप्लेस मेकॅनिझम
-- भाग ब: डिलिव्हरी बॉय कमिशन/पेआउट ट्रॅकिंग
-- भाग क: नवीन असाइनमेंटसाठी "न वाचलेली" गणती (नोटिफिकेशन बॅजसाठी)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- भाग अ: RETURN / REPLACE
-- ---------------------------------------------------------------------------

alter table public.orders
  add column if not exists delivered_at timestamptz,
  add column if not exists return_status text,              -- null | requested | approved | rejected | completed
  add column if not exists return_type text,                 -- return | replace
  add column if not exists return_reason text,
  add column if not exists return_requested_at timestamptz,
  add column if not exists return_resolved_at timestamptz,
  add column if not exists return_shop_note text;

comment on column public.orders.return_status is 'null=रिटर्न मागितलेली नाही, requested=ग्राहकाने मागितली, approved=दुकानदाराने मंजूर केली, rejected=नाकारली, completed=प्रक्रिया पूर्ण';
comment on column public.orders.return_type is 'return (पैसे परत) किंवा replace (नवीन वस्तू बदलून)';

-- जुन्या delivered ऑर्डर्ससाठी delivered_at अंदाजे भरून घ्या (return-window गणतीसाठी उपयोगी)
-- (orders टेबलवर updated_at कॉलम नाही, म्हणून created_at आधारे अंदाजे भरतो)
update public.orders set delivered_at = created_at
  where status = 'delivered' and delivered_at is null and created_at is not null;

-- 1. ग्राहकासाठी RPC: delivered ऑर्डरवर return/replace मागणी नोंदवा
--    (7 दिवसांच्या आत, आणि आधीच मागणी केलेली नसेल तरच)
create or replace function public.request_order_return(
  p_order_id uuid,
  p_type text,          -- 'return' किंवa 'replace'
  p_reason text
)
returns void
language plpgsql
security definer
as $$
declare
  v_order public.orders;
begin
  select * into v_order from public.orders where id = p_order_id;

  if v_order is null then
    raise exception 'ऑर्डर सापडली नाही';
  end if;

  if v_order.customer_user_id is distinct from auth.uid() then
    raise exception 'ही तुमची ऑर्डर नाही';
  end if;

  if v_order.status is distinct from 'delivered' then
    raise exception 'फक्त डिलिव्हर झालेल्या ऑर्डरसाठीच रिटर्न/रिप्लेस मागता येईल';
  end if;

  if v_order.return_status is not null then
    raise exception 'या ऑर्डरसाठी आधीच रिटर्न/रिप्लेस मागणी नोंदवलेली आहे';
  end if;

  if v_order.delivered_at is not null and v_order.delivered_at < (now() - interval '7 days') then
    raise exception 'डिलिव्हरीनंतर 7 दिवसांच्या आतच रिटर्न/रिप्लेस मागता येईल';
  end if;

  if p_type not in ('return', 'replace') then
    raise exception 'अवैध प्रकार';
  end if;

  update public.orders
     set return_status = 'requested',
         return_type = p_type,
         return_reason = p_reason,
         return_requested_at = now()
   where id = p_order_id;
end;
$$;

grant execute on function public.request_order_return(uuid, text, text) to authenticated;

-- 2. दुकानदारासाठी RPC: return/replace मागणी मंजूर/नाकारा
create or replace function public.resolve_order_return(
  p_order_id uuid,
  p_approve boolean,
  p_shop_note text default null
)
returns void
language plpgsql
security definer
as $$
declare
  v_order public.orders;
  v_is_owner boolean;
begin
  select * into v_order from public.orders where id = p_order_id;
  if v_order is null then
    raise exception 'ऑर्डर सापडली नाही';
  end if;

  select exists(
    select 1 from public.businesses b
    where b.id = v_order.business_id and b.owner_id = auth.uid()
  ) into v_is_owner;

  if not v_is_owner then
    raise exception 'फक्त संबंधित दुकानदारच ही कारवाई करू शकतो';
  end if;

  if v_order.return_status is distinct from 'requested' then
    raise exception 'सध्या कुठलीही प्रलंबित रिटर्न/रिप्लेस मागणी नाही';
  end if;

  update public.orders
     set return_status = case when p_approve then 'approved' else 'rejected' end,
         return_shop_note = p_shop_note,
         return_resolved_at = now()
   where id = p_order_id;
end;
$$;

grant execute on function public.resolve_order_return(uuid, boolean, text) to authenticated;

-- ---------------------------------------------------------------------------
-- भाग ब: डिलिव्हरी बॉय कमिशन / पेआउट
-- ---------------------------------------------------------------------------

alter table public.orders
  add column if not exists delivery_fee numeric default 0;

comment on column public.orders.delivery_fee is 'या ऑर्डरसाठी डिलिव्हरी बॉयला मिळणारं कमिशन/मानधन (₹)';

alter table public.delivery_boys
  add column if not exists default_delivery_fee numeric default 0,
  add column if not exists payout_notes text;

comment on column public.delivery_boys.default_delivery_fee is 'या डिलिव्हरी बॉयसाठी प्रत्येक डिलिव्हरीचं डिफॉल्ट कमिशन (₹) — दुकानदार ऑर्डरनुसार बदलू शकतो';

-- ---------------------------------------------------------------------------
-- भाग क: नोटिफिकेशन बॅजसाठी - काही अतिरिक्त बदल गरजेचा नाही, existing
-- delivery_accepted_at is null असलेल्या rows मोजूनच बॅज दाखवता येईल (क्लायंट क्वेरी)
-- ---------------------------------------------------------------------------
