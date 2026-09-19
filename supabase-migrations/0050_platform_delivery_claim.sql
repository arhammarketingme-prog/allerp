-- ============================================================================
-- 0050: Platform Delivery — खरा "उपलब्ध डिलिव्हरी स्वीकारा" mechanism
--
-- सापडलेला गंभीर गॅप: दुकानदार store-orders.html मध्ये "🟡 Platform
-- Delivery Boy" हा पर्याय निवडू शकत होता, पण त्यानंतर त्या ऑर्डरला
-- प्रत्यक्ष कुठलाही delivery boy नेमण्याची किंवा एखाद्या delivery boy ला ती
-- ऑर्डर दिसण्याची यंत्रणाच अस्तित्वात नव्हती. (टीप: store-orders.html हे
-- नंतर पूर्णपणे orphaned/dead सापडलं आणि काढून टाकलं — खरं order-management
-- dashboard.html च्या tab-orders मध्येच आहे, जे platform+shop-owned दोन्ही
-- delivery boys आधीच manually नेमू देतं. ही RPC मात्र वेगळी, पूरक सोय आहे —
-- delivery boy स्वतः "pool" मधली न-नेमलेली ऑर्डर बघून स्वतःहून स्वीकारू
-- शकतो, retailer ने आधीच specific कोणीतरी नेमलं नसेल तरीही.)
-- ============================================================================

create or replace function public.get_available_platform_deliveries()
returns table(order_id uuid, business_name text, business_city text, total_amount numeric, created_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.delivery_boys where user_id = auth.uid()) then
    raise exception 'फक्त नोंदणीकृत डिलिव्हरी बॉयच ही यादी बघू शकतात';
  end if;

  return query
  select o.id, b.name, b.city, o.total_amount, o.created_at
  from public.orders o
  join public.businesses b on b.id = o.business_id
  where o.fulfillment_mode = 'platform_delivery'
    and o.delivery_boy_id is null
    and o.status not in ('delivered', 'cancelled')
  order by o.created_at asc;
end;
$$;

grant execute on function public.get_available_platform_deliveries() to authenticated;

create or replace function public.claim_platform_delivery(p_order_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_my_delivery_boy_id uuid;
  v_rows_updated int;
begin
  select id into v_my_delivery_boy_id from public.delivery_boys where user_id = auth.uid();
  if v_my_delivery_boy_id is null then
    raise exception 'फक्त नोंदणीकृत डिलिव्हरी बॉयच ऑर्डर स्वीकारू शकतात';
  end if;

  update public.orders
     set delivery_boy_id = v_my_delivery_boy_id,
         delivery_accepted_at = now()
   where id = p_order_id
     and fulfillment_mode = 'platform_delivery'
     and delivery_boy_id is null;

  get diagnostics v_rows_updated = row_count;
  return v_rows_updated > 0;
end;
$$;

grant execute on function public.claim_platform_delivery(uuid) to authenticated;
