-- ============================================================================
-- 0022_place_direct_order.sql
-- ----------------------------------------------------------------------------
-- नोंद: हे मायग्रेशन तुमच्या *लाईव्ह* production स्कीमाशी जुळवून लिहिलेलं आहे
-- (information_schema.columns मधून मिळालेल्या खऱ्या orders कॉलम्सवर आधारित),
-- 0001_core_schema.sql मधल्या order_groups/order_items मॉडेलशी नाही — कारण
-- तुमचं प्रत्यक्ष अॅप त्या मॉडेलऐवजी सपाट (flat) orders टेबल वापरतं
-- (business_id थेट orders वर, एक ऑर्डर = एक दुकान).
--
-- हे फंक्शन client कडून येणारी किंमत कधीच स्वीकारत नाही — business_products
-- मधून selling_price स्वतः वाचतं, स्टॉक लॉक करून (for update) तपासतं व कमी
-- करतं, आणि total_amount सर्व्हरवरच मोजतं.
-- ============================================================================

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

  -- आधी रिकामी ऑर्डर तयार करा (id मिळवण्यासाठी); किंमत/summary खाली अपडेट होईल
  insert into public.orders (
    business_id, customer_user_id, customer_name, customer_phone,
    delivery_address, pincode, payment_method, fulfillment_mode,
    status, delivery_pin
  ) values (
    p_business_id, auth.uid(), p_customer_name, p_customer_phone,
    p_delivery_address, p_pincode, p_payment_method,
    coalesce(p_fulfillment_mode, 'self_delivery'),
    'Pending', v_delivery_pin
  )
  returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    -- 🔒 for update: दोन ग्राहक एकाच वेळी शेवटचा स्टॉक ऑर्डर करू शकणार नाहीत
    select * into v_product from public.business_products
      where id = (v_item->>'business_product_id')::uuid
      for update;

    if v_product is null then
      raise exception 'प्रॉडक्ट सापडलं नाही: %', v_item->>'business_product_id';
    end if;

    -- सुरक्षा तपासणी: कार्टमधलं प्रत्येक प्रॉडक्ट त्याच घोषित दुकानाचं असावं
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

comment on function public.place_direct_order is
  'सुरक्षित चेकआउट: किंमत/स्टॉक क्लायंटवर कधीच ट्रस्ट करत नाही. जुना थेट orders insert किंवा order_groups-आधारित place_order() नाही. {id, delivery_pin} असलेला jsonb परत देतं.';
