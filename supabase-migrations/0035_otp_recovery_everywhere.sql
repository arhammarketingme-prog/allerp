-- ============================================================================
-- 0035_otp_recovery_everywhere.sql
-- ----------------------------------------------------------------------------
-- इंटरनेट स्लो/बंद झाल्याने किंवा इतर कुठल्याही अडचणीमुळे कुठलाही OTP
-- रिकामा/अडकलेला राहिला, तर प्रत्येक ठिकाणी "पुन्हा तयार करा" चा पर्याय
-- असावा. आधीच जोडलेलं:
--   ✅ रिटर्न-शॉप OTP (डिलिव्हरी बॉय → दुकानदार) — regenerate_return_shop_otp (0034)
-- आता जोडतोय:
--   🆕 पिकअप OTP (दुकानदार → डिलिव्हरी बॉय)
--   🆕 रिटर्न पिन (ग्राहक → डिलिव्हरी बॉय)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. दुकानदारासाठी: पिकअप OTP रिकामा असेल किंवा बदलायचा असेल तर पुन्हा तयार करा
-- ---------------------------------------------------------------------------
create or replace function public.regenerate_pickup_otp(p_order_id uuid)
returns text
language plpgsql
security definer
as $$
declare
  v_order public.orders;
  v_is_owner boolean;
  v_new_otp text;
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

  if v_order.delivery_boy_id is null then
    raise exception 'आधी डिलिव्हरी बॉय असाइन करा';
  end if;

  if v_order.status not in ('pending', 'accepted', 'packed') then
    raise exception 'ही ऑर्डर आधीच रवाना झालेली आहे — नवीन OTP ची गरज नाही';
  end if;

  v_new_otp := lpad(floor(random() * 900000 + 100000)::text, 6, '0');
  update public.orders set pickup_otp = v_new_otp where id = p_order_id;
  return v_new_otp;
end;
$$;

grant execute on function public.regenerate_pickup_otp(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. ग्राहकासाठी: रिटर्न पिन रिकामा असेल तर पुन्हा तयार करा
-- ---------------------------------------------------------------------------
create or replace function public.regenerate_return_pin(p_order_id uuid)
returns text
language plpgsql
security definer
as $$
declare
  v_order public.orders;
  v_new_pin text;
begin
  select * into v_order from public.orders where id = p_order_id;
  if v_order is null then
    raise exception 'ऑर्डर सापडली नाही';
  end if;

  if v_order.customer_user_id is distinct from auth.uid() then
    raise exception 'ही तुमची ऑर्डर नाही';
  end if;

  if v_order.return_status is distinct from 'approved' then
    raise exception 'फक्त मंजूर झालेल्या रिटर्न/रिप्लेस विनंतीसाठीच हे शक्य आहे';
  end if;

  if v_order.return_pickup_status = 'picked_up' then
    raise exception 'वस्तू आधीच घेतली गेली आहे — नवीन पिन ची गरज नाही';
  end if;

  v_new_pin := lpad(floor(random() * 900000 + 100000)::text, 6, '0');
  update public.orders set return_pin = v_new_pin where id = p_order_id;
  return v_new_pin;
end;
$$;

grant execute on function public.regenerate_return_pin(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. जुन्या अडकलेल्या ऑर्डर्स आत्ताच दुरुस्त करा (backfill, आधीच्या
--    मायग्रेशन्सप्रमाणे) — जेणेकरून आत्ताच सगळं मोकळं होईल
-- ---------------------------------------------------------------------------
update public.orders
   set pickup_otp = lpad(floor(random() * 900000 + 100000)::text, 6, '0')
 where delivery_boy_id is not null
   and pickup_otp is null
   and status in ('pending', 'accepted', 'packed');

update public.orders
   set return_pin = lpad(floor(random() * 900000 + 100000)::text, 6, '0')
 where return_status = 'approved'
   and return_pickup_status is distinct from 'picked_up'
   and return_pin is null;
