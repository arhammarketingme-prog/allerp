-- ============================================================================
-- 0025_fix_order_status_casing.sql
-- ----------------------------------------------------------------------------
-- बग फिक्स: place_direct_order() ऑर्डर status = 'Pending' (कॅपिटल P) सेट
-- करत होतं, पण dashboard.html व delivery-boy.html सगळीकडे lowercase
-- 'pending'/'accepted'/'packed'/'dispatched'/'delivered' वापरतात.
-- यामुळे नवीन ऑर्डर दुकानदार/डिलिव्हरी बॉयच्या स्क्रीनवर योग्य स्थितीत
-- (Accept/Pack/Dispatch बटणांसकट) दिसत नव्हत्या.
-- ============================================================================

-- 1. आधीच चुकीच्या केसमध्ये साठवलेल्या जुन्या ऑर्डर्स दुरुस्त करा
update public.orders set status = 'pending' where status = 'Pending';

-- 2. फंक्शन दुरुस्त करा जेणेकरून पुढच्या सर्व ऑर्डर्स योग्य (lowercase) status ने तयार होतील
create or replace function public.place_direct_order(
  p_business_id uuid,
  p_customer_name text,
  p_customer_phone text,
  p_delivery_address text,
  p_pincode text,
  p_payment_method text,
  p_items jsonb,              -- [{"business_product_id": "...", "quantity": 2}, ...]
  p_fulfillment_mode text default 'self_delivery'
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_order_id uuid;
  v_item jsonb;
  v_product public.business_products;
  v_qty numeric;
  v_total numeric := 0;
  v_summary text := '';
  v_delivery_pin text;
begin
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'कार्ट रिकामी आहे';
  end if;

  v_delivery_pin := lpad(floor(random() * 900000 + 100000)::text, 6, '0');

  insert into public.orders (
    business_id, customer_user_id, customer_name, customer_phone,
    delivery_address, pincode, payment_method, fulfillment_mode,
    status, delivery_pin
  ) values (
    p_business_id, auth.uid(), p_customer_name, p_customer_phone,
    p_delivery_address, p_pincode, p_payment_method,
    coalesce(p_fulfillment_mode, 'self_delivery'),
    'pending', v_delivery_pin
  )
  returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select * into v_product from public.business_products
      where id = (v_item->>'business_product_id')::uuid
      for update;

    if v_product is null then
      raise exception 'प्रॉडक्ट सापडलं नाही: %', v_item->>'business_product_id';
    end if;

    if v_product.business_id is distinct from p_business_id then
      raise exception 'प्रॉडक्ट % वेगळ्या दुकानाचं आहे', v_product.name;
    end if;

    if not v_product.is_active then
      raise exception 'प्रॉडक्ट सध्या उपलब्ध नाही: %', v_product.name;
    end if;

    v_qty := (v_item->>'quantity')::numeric;

    if v_product.stock < v_qty then
      raise exception 'अपुरा स्टॉक: % (शिल्लक: %)', v_product.name, v_product.stock;
    end if;

    update public.business_products
       set stock = stock - v_qty
     where id = v_product.id;

    v_total := v_total + (v_product.selling_price * v_qty);
    v_summary := v_summary || v_product.name || ' (x' || v_qty || '), ';
  end loop;

  update public.orders
     set total_amount = v_total,
         items_summary = rtrim(v_summary, ', ')
   where id = v_order_id;

  return jsonb_build_object('id', v_order_id, 'delivery_pin', v_delivery_pin);
end;
$$;

grant execute on function public.place_direct_order(
  uuid, text, text, text, text, text, jsonb, text
) to authenticated, anon;
