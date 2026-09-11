-- ============================================================================
-- 0032_fix_return_pickup_status.sql
-- ----------------------------------------------------------------------------
-- मूळ बग सापडला: तुमची ऑर्डर 0030 मायग्रेशन लागण्याआधीच "approved" झालेली
-- होती — त्यामुळे तिला return_pickup_status ('assigned') किंवा return_pin
-- कधीच मिळाला नाही. नंतर तुम्ही दुकानदाराच्या dashboard वरून डिलिव्हरी बॉय
-- असाइन केला, पण assign_return_delivery_boy() फंक्शन फक्त
-- return_delivery_boy_id सेट करत होतं — return_pickup_status ला हातच लावत
-- नव्हतं. त्यामुळे delivery boy च्या पोर्टलवरची क्वेरी
-- (return_pickup_status = 'assigned') कधीच जुळली नाही.
-- ============================================================================

-- 1. फंक्शन दुरुस्त करा — यापुढे असाइन करताना pickup_status व (गरज असल्यास)
--    return_pin आपोआप योग्य होतील
create or replace function public.assign_return_delivery_boy(
  p_order_id uuid,
  p_delivery_boy_id uuid
)
returns void
language plpgsql
security definer
as $$
declare
  v_is_owner boolean;
  v_order public.orders;
begin
  select o.* into v_order from public.orders o
    join public.businesses b on b.id = o.business_id
   where o.id = p_order_id and b.owner_id = auth.uid();

  if v_order is null then
    raise exception 'फक्त संबंधित दुकानदारच ही कारवाई करू शकतो, किंवा ऑर्डर सापडली नाही';
  end if;

  update public.orders
     set return_delivery_boy_id = p_delivery_boy_id,
         -- आधीच picked_up/completed नसेल तरच पुन्हा 'assigned' करा
         return_pickup_status = case
           when return_pickup_status in ('picked_up') then return_pickup_status
           else 'assigned'
         end,
         -- जुन्या (0030 आधीच्या) ऑर्डर्सना पिन नसेल तर आत्ता तयार करा
         return_pin = coalesce(return_pin, lpad(floor(random() * 900000 + 100000)::text, 6, '0'))
   where id = p_order_id;
end;
$$;

grant execute on function public.assign_return_delivery_boy(uuid, uuid) to authenticated;

-- 2. सध्या "अडकलेल्या" जुन्या ऑर्डर्स दुरुस्त करा — ज्यांना delivery boy
--    असाइन आहे पण pickup_status/pin अजून रिकामे आहेत
update public.orders
   set return_pickup_status = 'assigned',
       return_pin = coalesce(return_pin, lpad(floor(random() * 900000 + 100000)::text, 6, '0'))
 where return_status = 'approved'
   and return_delivery_boy_id is not null
   and return_pickup_status is null;
