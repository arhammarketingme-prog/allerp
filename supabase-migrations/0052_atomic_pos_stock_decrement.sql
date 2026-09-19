-- ============================================================================
-- 0052: POS स्टॉक अपडेट आता race-condition-सुरक्षित (atomic) आहे.
--
-- सापडलेला प्रश्न: POS checkout मध्ये स्टॉक कमी करताना client-side आकडा
-- (browser मध्ये आधीच वाचलेला item.stock मधून item.qty वजा करून) थेट
-- सर्व्हरला पाठवला जायचा. दोन वेगळ्या विक्री (वेगळे टॅब/डिव्हाइस) जवळपास
-- एकाच वेळी झाल्या, तर दोन्ही जुन्याच (stale) स्टॉक आकड्यावरून वजाबाकी
-- करायच्या — शेवटचा update जिंकायचा, आणि प्रत्यक्षात विकलेला माल स्टॉकमधून
-- कधीच कमी न झाल्यासारखा दिसायचा (स्टॉक चुकीचा, जास्त दाखवायचा).
-- ============================================================================

create or replace function public.decrement_stock_atomic(p_product_id uuid, p_qty numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current numeric;
begin
  select stock into v_current from public.business_products where id = p_product_id for update;

  if v_current is null then
    raise exception 'उत्पादन सापडलं नाही';
  end if;

  if v_current < p_qty then
    raise exception 'अपुरा स्टॉक (शिल्लक: %, हवं: %)', v_current, p_qty;
  end if;

  update public.business_products set stock = stock - p_qty where id = p_product_id;
end;
$$;

grant execute on function public.decrement_stock_atomic(uuid, numeric) to authenticated;
