-- ============================================================================
-- 0034_backfill_return_shop_otp.sql
-- ----------------------------------------------------------------------------
-- ज्या ऑर्डर्स 0033 लागण्याआधीच "picked_up" झालेल्या होत्या, त्यांना
-- return_shop_otp कधीच मिळाला नव्हता (जुनं फंक्शन तो तयार करतच नव्हतं).
-- आत्ता त्या दुरुस्त करतो, आणि भविष्यासाठी डिलिव्हरी बॉयला "OTP दिसत नसेल तर
-- पुन्हा तयार करा" असा पर्यायही देतो.
-- ============================================================================

-- 1. सध्या अडकलेल्या ऑर्डर्स दुरुस्त करा
update public.orders
   set return_shop_otp = lpad(floor(random() * 900000 + 100000)::text, 6, '0')
 where return_pickup_status = 'picked_up'
   and return_shop_otp is null;

-- 2. डिलिव्हरी बॉयसाठी RPC: OTP दिसत नसेल / हरवला असेल तर पुन्हा तयार करा
create or replace function public.regenerate_return_shop_otp(p_order_id uuid)
returns text
language plpgsql
security definer
as $$
declare
  v_order public.orders;
  v_is_assigned boolean;
  v_new_otp text;
begin
  select * into v_order from public.orders where id = p_order_id;
  if v_order is null then
    raise exception 'ऑर्डर सापडली नाही';
  end if;

  select exists(
    select 1 from public.delivery_boys db
    where db.id = v_order.return_delivery_boy_id and db.user_id = auth.uid()
  ) into v_is_assigned;

  if not v_is_assigned then
    raise exception 'ही पिकअप ऑर्डर तुम्हाला असाइन झालेली नाही';
  end if;

  if v_order.return_pickup_status is distinct from 'picked_up' then
    raise exception 'फक्त "picked_up" स्थितीतच OTP पुन्हा तयार करता येईल';
  end if;

  v_new_otp := lpad(floor(random() * 900000 + 100000)::text, 6, '0');
  update public.orders set return_shop_otp = v_new_otp where id = p_order_id;
  return v_new_otp;
end;
$$;

grant execute on function public.regenerate_return_shop_otp(uuid) to authenticated;
