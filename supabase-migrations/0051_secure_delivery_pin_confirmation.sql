-- ============================================================================
-- 0051: डिलिव्हरी-वेळचा PIN आता खरंच सर्व्हरवर तपासला जाईल.
--
-- सापडलेला गंभीर प्रश्न: पिकअप-वेळचा OTP (`confirm_pickup_from_shop`)
-- बरोबर, सुरक्षित RPC वापरत होता — पण ग्राहकाला डिलिव्हरी करतानाचा PIN
-- मात्र फक्त client-side (ब्राउझर JS) मध्ये तपासला जात होता. डिलिव्हरी
-- बॉयच्या ब्राउझरला आधीच खरा PIN पाठवला जायचा, आणि जुळतो का हे browser
-- मध्येच तपासलं जायचं — म्हणजे delivery boy devtools/network मधून खरा
-- PIN बघू शकत होता, ग्राहकाला विचारायची गरजच नव्हती.
-- ============================================================================

create or replace function public.confirm_delivery(p_order_id uuid, p_pin text)
returns void
language plpgsql
security definer
set search_path = public
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

  if v_order.delivery_pin is null or v_order.delivery_pin is distinct from p_pin then
    raise exception 'चुकीचा पिन! कृपया ग्राहकाकडून पुन्हा विचारा.';
  end if;

  update public.orders set status = 'delivered', delivered_at = now() where id = p_order_id;
end;
$$;

grant execute on function public.confirm_delivery(uuid, text) to authenticated;
