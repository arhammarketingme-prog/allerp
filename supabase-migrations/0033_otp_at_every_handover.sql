-- ============================================================================
-- 0033_otp_at_every_handover.sql
-- ----------------------------------------------------------------------------
-- आत्तापर्यंत फक्त ग्राहकाला मिळणाऱ्या डिलिव्हरीसाठी PIN होता. इतर तीन
-- ठिकाणी कुठलीही पडताळणी नव्हती — "मला मिळालंच नाही" असा वाद होऊ शकत होता:
--   1) 🏪→🛵 दुकानदाराने डिलिव्हरी बॉयला पार्सल दिलं (पिकअप) — आता OTP
--   2) 🛵→🏪 डिलिव्हरी बॉयने ग्राहकाकडून घेतलेला रिटर्न/रिप्लेस माल
--      दुकानदाराला परत केला — आता OTP
--   3) 🛵→🏪 डिलिव्हरी बॉयने जमा केलेली रोख दुकानदाराला दिली — आता OTP
-- ============================================================================

-- ---------------------------------------------------------------------------
-- भाग 1: दुकानदार → डिलिव्हरी बॉय (पिकअप OTP)
-- ---------------------------------------------------------------------------

alter table public.orders
  add column if not exists pickup_otp text;

comment on column public.orders.pickup_otp is 'दुकानदाराने डिलिव्हरी बॉयला प्रत्यक्ष पार्सल दिल्याची खात्री करण्यासाठीचा OTP — डिलिव्हरी बॉय दुकानदाराकडून तोंडी विचारून टाकतो';

-- डिलिव्हरी बॉय असाइन होताच आपोआप OTP तयार होईल
create or replace function public.generate_pickup_otp_trigger()
returns trigger
language plpgsql
as $$
begin
  if new.delivery_boy_id is not null and (old.delivery_boy_id is distinct from new.delivery_boy_id) then
    new.pickup_otp := lpad(floor(random() * 900000 + 100000)::text, 6, '0');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_generate_pickup_otp on public.orders;
create trigger trg_generate_pickup_otp
  before update on public.orders
  for each row
  execute function public.generate_pickup_otp_trigger();

-- जुन्या, आधीच असाइन झालेल्या पण अजून dispatched न झालेल्या ऑर्डर्ससाठी OTP भरून घ्या
update public.orders
   set pickup_otp = lpad(floor(random() * 900000 + 100000)::text, 6, '0')
 where delivery_boy_id is not null
   and pickup_otp is null
   and status in ('pending', 'accepted', 'packed');

-- डिलिव्हरी बॉयसाठी RPC: OTP पडताळून dispatch करा
create or replace function public.confirm_pickup_from_shop(
  p_order_id uuid,
  p_otp text
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
    where db.id = v_order.delivery_boy_id and db.user_id = auth.uid()
  ) into v_is_assigned;

  if not v_is_assigned then
    raise exception 'ही ऑर्डर तुम्हाला असाइन झालेली नाही';
  end if;

  if v_order.pickup_otp is null or v_order.pickup_otp is distinct from p_otp then
    raise exception 'चुकीचा OTP — दुकानदाराकडून पुन्हा विचारा';
  end if;

  update public.orders set status = 'dispatched' where id = p_order_id;
end;
$$;

grant execute on function public.confirm_pickup_from_shop(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- भाग 2: डिलिव्हरी बॉय → दुकानदार (रिटर्न केलेला माल परत केल्याचा OTP)
-- ---------------------------------------------------------------------------

alter table public.orders
  add column if not exists return_shop_otp text,
  add column if not exists return_received_by_shop_at timestamptz;

comment on column public.orders.return_shop_otp is 'डिलिव्हरी बॉयने ग्राहकाकडून घेतलेली रिटर्न/रिप्लेस वस्तू दुकानदाराला दिल्याची खात्री करण्यासाठीचा OTP';

-- confirm_return_pickup() दुरुस्त करा: ग्राहकाकडून घेताना, दुकानदारासाठीचा
-- वेगळा OTP आपोआप तयार करा
-- (जुन्या फंक्शनचा return type 'void' होता, नवीन 'jsonb' आहे — त्यामुळे
--  आधी जुनं ड्रॉप करणं गरजेचं आहे, नाहीतर Postgres तक्रार करतो)
drop function if exists public.confirm_return_pickup(uuid, text);

create or replace function public.confirm_return_pickup(
  p_order_id uuid,
  p_pin text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_order public.orders;
  v_is_assigned boolean;
  v_shop_otp text;
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

  v_shop_otp := lpad(floor(random() * 900000 + 100000)::text, 6, '0');

  update public.orders
     set return_pickup_status = 'picked_up',
         return_shop_otp = v_shop_otp
   where id = p_order_id;

  return jsonb_build_object('return_shop_otp', v_shop_otp);
end;
$$;

grant execute on function public.confirm_return_pickup(uuid, text) to authenticated;

-- दुकानदारासाठी RPC: डिलिव्हरी बॉयने सांगितलेला OTP टाकून "माल मिळाला" कन्फर्म करा
create or replace function public.confirm_return_received_by_shop(
  p_order_id uuid,
  p_otp text
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

  if v_order.return_shop_otp is null or v_order.return_shop_otp is distinct from p_otp then
    raise exception 'चुकीचा OTP — डिलिव्हरी बॉयकडून पुन्हा विचारा';
  end if;

  update public.orders
     set return_pickup_status = 'received_by_shop',
         return_received_by_shop_at = now(),
         -- replace प्रकारासाठी इथेच प्रक्रिया पूर्ण होते; return साठी अजून रिफंड नोंदवायचा बाकी आहे
         return_status = case when v_order.return_type = 'replace' then 'completed' else return_status end
   where id = p_order_id;
end;
$$;

grant execute on function public.confirm_return_received_by_shop(uuid, text) to authenticated;

-- mark_refund_done(): आता "received_by_shop" झाल्याशिवाय रिफंड मार्क करता येणार नाही
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

  if v_order.return_pickup_status is distinct from 'received_by_shop' then
    raise exception 'आधी OTP टाकून "माल मिळाला" कन्फर्म करणं आवश्यक आहे';
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
-- भाग 3: डिलिव्हरी बॉय → दुकानदार (रोख हस्तांतरणाचा OTP) — नवीन स्वतंत्र टेबल
-- ---------------------------------------------------------------------------

create table if not exists public.cash_handovers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  delivery_boy_id uuid not null references public.delivery_boys(id) on delete cascade,
  order_ids uuid[] not null,
  amount numeric not null,
  otp text not null,
  status text not null default 'pending_confirmation',   -- pending_confirmation | confirmed
  created_at timestamptz default now(),
  confirmed_at timestamptz
);

comment on table public.cash_handovers is 'डिलिव्हरी बॉय ते दुकानदार रोख हस्तांतरणाची OTP-पडताळित नोंद — फक्त हिशोब, पैसे प्लॅटफॉर्मवरून जात नाहीत';

alter table public.cash_handovers enable row level security;

drop policy if exists cash_handover_boy_select on public.cash_handovers;
create policy cash_handover_boy_select on public.cash_handovers
  for select
  using (
    delivery_boy_id in (select id from public.delivery_boys where user_id = auth.uid())
  );

drop policy if exists cash_handover_shop_select on public.cash_handovers;
create policy cash_handover_shop_select on public.cash_handovers
  for select
  using (
    exists (select 1 from public.businesses b where b.id = cash_handovers.business_id and b.owner_id = auth.uid())
  );

-- डिलिव्हरी बॉयसाठी RPC: एका दुकानाची सर्व प्रलंबित रोख OTP सह "दिली" म्हणून सुरू करा
create or replace function public.initiate_cash_handover(p_business_id uuid)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_my_delivery_boy_id uuid;
  v_order_ids uuid[];
  v_total numeric;
  v_otp text;
  v_handover_id uuid;
begin
  select id into v_my_delivery_boy_id from public.delivery_boys where user_id = auth.uid();
  if v_my_delivery_boy_id is null then
    raise exception 'तुम्ही डिलिव्हरी बॉय म्हणून नोंदणीकृत नाही';
  end if;

  select array_agg(id), coalesce(sum(cash_collected_amount), 0)
    into v_order_ids, v_total
  from public.orders
  where business_id = p_business_id
    and delivery_boy_id = v_my_delivery_boy_id
    and cash_handover_status = 'pending_handover';

  if v_order_ids is null or array_length(v_order_ids, 1) is null then
    raise exception 'सध्या या दुकानासाठी प्रलंबित रोख नाही';
  end if;

  v_otp := lpad(floor(random() * 900000 + 100000)::text, 6, '0');

  insert into public.cash_handovers (business_id, delivery_boy_id, order_ids, amount, otp)
  values (p_business_id, v_my_delivery_boy_id, v_order_ids, v_total, v_otp)
  returning id into v_handover_id;

  update public.orders
     set cash_handover_status = 'handed_over',
         cash_handed_over_at = now()
   where id = any(v_order_ids);

  return jsonb_build_object('handover_id', v_handover_id, 'otp', v_otp, 'amount', v_total);
end;
$$;

grant execute on function public.initiate_cash_handover(uuid) to authenticated;

-- दुकानदारासाठी RPC: OTP टाकून रोख हस्तांतरण कन्फर्म करा
create or replace function public.confirm_cash_handover(
  p_handover_id uuid,
  p_otp text
)
returns void
language plpgsql
security definer
as $$
declare
  v_handover public.cash_handovers;
  v_is_owner boolean;
begin
  select * into v_handover from public.cash_handovers where id = p_handover_id;
  if v_handover is null then
    raise exception 'हस्तांतरण सापडलं नाही';
  end if;

  select exists(
    select 1 from public.businesses b
    where b.id = v_handover.business_id and b.owner_id = auth.uid()
  ) into v_is_owner;

  if not v_is_owner then
    raise exception 'फक्त संबंधित दुकानदारच ही कारवाई करू शकतो';
  end if;

  if v_handover.status = 'confirmed' then
    raise exception 'हे हस्तांतरण आधीच कन्फर्म झालेलं आहे';
  end if;

  if v_handover.otp is distinct from p_otp then
    raise exception 'चुकीचा OTP — डिलिव्हरी बॉयकडून पुन्हा विचारा';
  end if;

  update public.cash_handovers
     set status = 'confirmed', confirmed_at = now()
   where id = p_handover_id;

  update public.orders
     set cash_handover_status = 'confirmed'
   where id = any(v_handover.order_ids);
end;
$$;

grant execute on function public.confirm_cash_handover(uuid, text) to authenticated;

-- जुनी mark_cash_handed_over / confirm_cash_received फंक्शन्स आता वापरात नाहीत — काढून टाकतो
drop function if exists public.mark_cash_handed_over(uuid);
drop function if exists public.confirm_cash_received(uuid);
