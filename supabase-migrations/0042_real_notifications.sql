-- ============================================================================
-- 0042: खरे Notifications — आधी `notifications` टेबल आणि RLS बांधलेले होते,
-- पण त्यात कधीच काही insert होत नव्हतं (ज्या दोन जुन्या functions मध्ये असा
-- कोड होता, ते place_order()/update_order_status() 0037 मध्ये dead-code
-- म्हणून आधीच काढून टाकले होते) — आणि frontend कुठेच notifications वाचत
-- नव्हता. आता तिन्ही खऱ्या इव्हेंट्सवर सूचना तयार होतील.
-- ============================================================================

-- 1) नवीन ऑर्डर आल्यावर दुकानदाराला सूचना — place_direct_order() मध्येच जोडतो
--    (बाकी सगळा लॉजिक जसाच्या तसा — फक्त शेवटी notification insert नवीन)
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
  v_owner_id uuid;
begin
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'कार्ट रिकामी आहे';
  end if;

  v_delivery_pin := lpad(floor(random() * 900000 + 100000)::text, 6, '0');

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

  -- 🔔 नवीन: दुकानदाराला नवीन ऑर्डरची सूचना
  select owner_id into v_owner_id from public.businesses where id = p_business_id;
  if v_owner_id is not null then
    insert into public.notifications (user_id, business_id, type, title, body, data)
    values (
      v_owner_id, p_business_id, 'new_order',
      '🛒 नवीन ऑर्डर आली!',
      p_customer_name || ' कडून ₹' || v_total || ' ची ऑर्डर',
      jsonb_build_object('order_id', v_order_id)
    );
  end if;

  return jsonb_build_object('id', v_order_id, 'delivery_pin', v_delivery_pin);
end;
$$;

grant execute on function public.place_direct_order(
  uuid, text, text, text, text, text, jsonb, text, text
) to authenticated, anon;

-- 2) स्टॉक किमान मर्यादेखाली गेल्यावर दुकानदाराला सूचना (फक्त थ्रेशोल्ड
--    ओलांडतानाच — प्रत्येक स्टॉक-अपडेटला स्पॅम होणार नाही)
create or replace function public.notify_low_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
begin
  if NEW.stock < NEW.min_stock and (OLD.stock is null or OLD.stock >= OLD.min_stock) then
    select owner_id into v_owner_id from public.businesses where id = NEW.business_id;
    if v_owner_id is not null then
      insert into public.notifications (user_id, business_id, type, title, body, data)
      values (
        v_owner_id, NEW.business_id, 'low_stock',
        '⚠️ स्टॉक कमी झाला: ' || NEW.name,
        'सध्याचा स्टॉक ' || NEW.stock || ' ' || NEW.unit || ' (किमान मर्यादा: ' || NEW.min_stock || ')',
        jsonb_build_object('product_id', NEW.id)
      );
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_notify_low_stock on public.business_products;
create trigger trg_notify_low_stock
  after update of stock on public.business_products
  for each row execute function public.notify_low_stock();

-- 3) ऑर्डरची स्थिती बदलली की ग्राहकाला सूचना (कुठल्याही पानावरून status
--    अपडेट झाला तरी हा trigger पकडतो — एकाच जागी लॉजिक, सगळीकडे लागू)
create or replace function public.notify_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if NEW.status is distinct from OLD.status and NEW.customer_user_id is not null then
    insert into public.notifications (user_id, business_id, type, title, body, data)
    values (
      NEW.customer_user_id, NEW.business_id, 'order_status',
      '📦 तुझ्या ऑर्डरची स्थिती बदलली',
      'ऑर्डर आता "' || NEW.status || '" स्थितीत आहे',
      jsonb_build_object('order_id', NEW.id, 'status', NEW.status)
    );
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_notify_order_status on public.orders;
create trigger trg_notify_order_status
  after update of status on public.orders
  for each row execute function public.notify_order_status_change();
