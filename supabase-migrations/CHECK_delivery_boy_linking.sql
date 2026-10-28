-- ============================================================================
-- CHECK: कुठला डिलिव्हरी बॉय कुठल्या login ईमेलला जोडलेला आहे (किंवा नाही)
-- Supabase Dashboard → SQL Editor मध्ये कॉपी-पेस्ट करून "Run" दाबा
-- ============================================================================

select
  db.id                as delivery_boy_id,
  db.name              as delivery_boy_name,
  db.phone,
  db.email             as saved_email_in_delivery_boys,   -- अ‍ॅडमिनने फॉर्ममध्ये टाकलेला ईमेल
  db.user_id           as linked_user_id,                  -- हे भरलेलं असेल तरच लिंक झालेलं आहे
  au.email             as actual_login_email,               -- त्या user_id चा खरा login ईमेल
  case
    when db.user_id is null then '❌ लिंक झालेलंच नाही — user_id रिकामा आहे'
    when au.id is null then '⚠️ user_id आहे पण तो auth.users मध्ये सापडत नाही (चुकीचा id)'
    else '✅ व्यवस्थित लिंक झालेलं आहे'
  end as status
from public.delivery_boys db
left join auth.users au on au.id = db.user_id
order by db.created_at desc;
