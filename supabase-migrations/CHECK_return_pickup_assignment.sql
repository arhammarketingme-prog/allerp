-- ============================================================================
-- CHECK: रिटर्न/रिप्लेस पिकअप असाइनमेंट नीट झालंय का ते तपासा
-- Supabase Dashboard → SQL Editor मध्ये रन करा
-- ============================================================================

select
  o.id                       as order_id,
  o.return_status,
  o.return_type,
  o.return_pickup_status,    -- हे 'assigned' असायलाच हवं, नाहीतर delivery boy ला दिसणारच नाही
  o.return_delivery_boy_id,  -- हे रिकामं (null) नसावं
  db.name                    as delivery_boy_name,
  db.user_id                 as delivery_boy_linked_user_id,   -- हे रिकामं असेल तर तो login शीच जोडलेला नाही!
  au.email                   as delivery_boy_login_email,
  case
    when o.return_status is null then 'ℹ️ या ऑर्डरवर कुठलीही return/replace विनंतीच नाही'
    when o.return_status = 'requested' then '⏳ अजून दुकानदाराने मंजूर/नाकारलेलं नाही'
    when o.return_delivery_boy_id is null then '❌ मंजूर झालं, पण अजून कुठलाही डिलिव्हरी बॉय असाइन केलेला नाही'
    when o.return_pickup_status is distinct from 'assigned' then '⚠️ delivery boy असाइन आहे, पण pickup_status ''assigned'' नाहीये (कदाचित आधीच picked_up/completed झालंय)'
    when db.user_id is null then '❌ हा डिलिव्हरी बॉय login खात्याशी जोडलेलाच नाही — त्यामुळे त्याला पोर्टलवर लॉगिनच करता येणार नाही'
    else '✅ सर्व व्यवस्थित आहे — delivery boy लॉगिन करून पोर्टल उघडल्यावर हे दिसायलाच हवं'
  end as diagnosis
from public.orders o
left join public.delivery_boys db on db.id = o.return_delivery_boy_id
left join auth.users au on au.id = db.user_id
where o.return_status is not null
order by o.return_requested_at desc nulls last;
