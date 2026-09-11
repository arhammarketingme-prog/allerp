-- ============================================================================
-- 0030_return_pickup_and_refund_tracking.sql
-- ----------------------------------------------------------------------------
-- सुधारणा:
--   1) ग्राहकाचा ईमेल आयडी ऑर्डरवर साठवला जाईल — दुकानदार व डिलिव्हरी बॉयला दिसेल
--   2) Replace/Return मंजूर झाल्यावर प्रत्यक्ष "पिकअप" कोणी करायचं, ते डिलिव्हरी
--      बॉयच्या पोर्टलवर वेगळ्या टास्क म्हणून दिसेल (पिन-पडताळणीसह)
--   3) Return (पैसे परत) साठी दुकानदाराला "पैसे परत केले" असं नोंदवण्याचा मेकॅनिझम
--      (लक्षात ठेवा: प्लॅटफॉर्म स्वतः पैसे हाताळत नाही — फक्त स्थिती नोंदवते)
-- ============================================================================

alter table public.orders
  add column if not exists customer_email text,
  add column if not exists return_delivery_boy_id uuid references public.delivery_boys(id) on delete set null,
  add column if not exists return_pickup_status text,     -- null | assigned | picked_up
  add column if not exists return_pin text,
  add column if not exists refund_status text,             -- null | pending | done
  add column if not exists refund_marked_at timestamptz;

comment on column public.orders.customer_email is 'ऑर्डर देतानाच्या login सत्रातून घेतलेला ग्राहकाचा ईमेल — संपर्कासाठी दुकानदार/डिलिव्हरी बॉयला दिसतो';
comment on column public.orders.return_pickup_status is 'रिटर्न/रिप्लेस मंजूर झाल्यावरची फेरी: assigned=डिलिव्हरी बॉय ठरला, picked_up=वस्तू परत घेतली';
comment on column public.orders.refund_status is 'फक्त return प्रकारासाठी: pending=अजून पैसे द्यायचे आहेत, done=दुकानदाराने पैसे परत केले (platform च्या बाहेर, फक्त नोंद)';

-- ---------------------------------------------------------------------------
-- 1. place_direct_order() मध्ये customer_email पॅरामीटर जोडा
-- ---------------------------------------------------------------------------
create or replace function public.place_direct_order(
  p_business_id uuid,
  p_customer_name text,
  p_customer_phone text,
  p_delivery_address text,
  p_pincode text,
  p_payment_method text,
  p_items jsonb,
  p_fulfillment_mode text default 'self_delivery',
  p_customer_email text default null
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
  v_email text;
begin
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'कार्ट रिकामी आहे';
  end if;

  v_delivery_pin := lpad(floor(random() * 900000 + 100000)::text, 6, '0');

  -- ईमेल स्पष्टपणे दिला नसेल तर लॉगिन सत्रावरून घ्या
  v_email := coalesce(p_customer_email, (select email from auth.users where id = auth.uid()));

  insert into public.orders (
    business_id, customer_user_id, customer_name, customer_phone, customer_email,
    delivery_address, pincode, payment_method, fulfillment_mode,
    status, delivery_pin
  ) values (
    p_business_id, auth.uid(), p_customer_name, p_customer_phone, v_email,
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
  uuid, text, text, text, text, text, jsonb, text, text
) to authenticated, anon;

-- जुन्या ऑर्डर्ससाठी शक्य असल्यास ईमेल आत्ता भरून घ्या (customer_user_id आहे त्यांच्यासाठी)
update public.orders o
   set customer_email = au.email
  from auth.users au
 where o.customer_user_id = au.id
   and o.customer_email is null;

-- ---------------------------------------------------------------------------
-- 2. resolve_order_return(): मंजूर केल्यावर आपोआप पिकअप टास्क तयार करा
-- ---------------------------------------------------------------------------
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
  v_return_pin text;
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

  if p_approve then
    v_return_pin := lpad(floor(random() * 900000 + 100000)::text, 6, '0');
    update public.orders
       set return_status = 'approved',
           return_shop_note = p_shop_note,
           return_resolved_at = now(),
           return_pin = v_return_pin,
           return_pickup_status = 'assigned',
           -- डिफॉल्ट: ज्याने आधी डिलिव्हर केलं तोच पिकअपला जाईल (दुकानदार नंतर बदलू शकतो)
           return_delivery_boy_id = v_order.delivery_boy_id,
           refund_status = case when v_order.return_type = 'return' then 'pending' else null end
     where id = p_order_id;
  else
    update public.orders
       set return_status = 'rejected',
           return_shop_note = p_shop_note,
           return_resolved_at = now()
     where id = p_order_id;
  end if;
end;
$$;

grant execute on function public.resolve_order_return(uuid, boolean, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. दुकानदारासाठी: पिकअप डिलिव्हरी बॉय (re)असाइन करणं
-- ---------------------------------------------------------------------------
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
begin
  select exists(
    select 1 from public.orders o
    join public.businesses b on b.id = o.business_id
    where o.id = p_order_id and b.owner_id = auth.uid()
  ) into v_is_owner;

  if not v_is_owner then
    raise exception 'फक्त संबंधित दुकानदारच ही कारवाई करू शकतो';
  end if;

  update public.orders
     set return_delivery_boy_id = p_delivery_boy_id
   where id = p_order_id;
end;
$$;

grant execute on function public.assign_return_delivery_boy(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. डिलिव्हरी बॉयसाठी: पिकअप पूर्ण झाल्याची नोंद (पिन पडताळणीसह)
-- ---------------------------------------------------------------------------
create or replace function public.confirm_return_pickup(
  p_order_id uuid,
  p_pin text
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
    where db.id = v_order.return_delivery_boy_id and db.user_id = auth.uid()
  ) into v_is_assigned;

  if not v_is_assigned then
    raise exception 'ही पिकअप ऑर्डर तुम्हाला असाइन झालेली नाही';
  end if;

  if v_order.return_pin is distinct from p_pin then
    raise exception 'चुकीचा पिन';
  end if;

  update public.orders
     set return_pickup_status = 'picked_up',
         -- replace असेल तर वस्तू परत घेणं + नवीन देणं इथेच पूर्ण होतं
         return_status = case when v_order.return_type = 'replace' then 'completed' else return_status end
   where id = p_order_id;
end;
$$;

grant execute on function public.confirm_return_pickup(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. दुकानदारासाठी: (फक्त return प्रकारासाठी) पैसे परत केल्याची नोंद
-- ---------------------------------------------------------------------------
create or replace function public.mark_refund_done(p_order_id uuid)
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

  if v_order.return_type is distinct from 'return' then
    raise exception 'हे फक्त return (पैसे परत) प्रकारासाठी आहे';
  end if;

  if v_order.return_pickup_status is distinct from 'picked_up' then
    raise exception 'आधी वस्तू परत घेतल्याची नोंद (पिकअप) पूर्ण होणं आवश्यक आहे';
  end if;

  update public.orders
     set refund_status = 'done',
         refund_marked_at = now(),
         return_status = 'completed'
   where id = p_order_id;
end;
$$;

grant execute on function public.mark_refund_done(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. RLS: डिलिव्हरी बॉयला return_delivery_boy_id असलेल्या ऑर्डर्स दिसाव्यात
-- ---------------------------------------------------------------------------
drop policy if exists delivery_boy_return_orders_select on public.orders;
create policy delivery_boy_return_orders_select on public.orders
  for select
  using (
    return_delivery_boy_id in (
      select id from public.delivery_boys where user_id = auth.uid()
    )
  );
