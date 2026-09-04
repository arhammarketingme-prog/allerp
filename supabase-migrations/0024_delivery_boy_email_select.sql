-- ============================================================================
-- 0024_delivery_boy_email_select.sql
-- अ‍ॅडमिन पॅनलमध्ये डिलिव्हरी बॉय जोडताना "ईमेल टाईप करा" ऐवजी नोंदणीकृत पण
-- अजून कुठल्याही डिलिव्हरी बॉयशी न जोडलेल्या खात्यांमधून ड्रॉपडाऊनने निवडता यावं.
-- ============================================================================

create or replace function public.admin_list_linkable_accounts()
returns table (
  user_id uuid,
  full_name text,
  phone text,
  email text
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_is_admin boolean;
begin
  select u.is_admin into v_is_admin from public.users u where u.id = auth.uid();
  if not coalesce(v_is_admin, false) then
    raise exception 'फक्त अ‍ॅडमिनसाठीच ही सुविधा उपलब्ध आहे';
  end if;

  return query
  select
    au.id as user_id,
    pu.full_name,
    pu.phone,
    au.email::text as email
  from auth.users au
  left join public.users pu on pu.id = au.id
  where au.email is not null
    and not exists (
      select 1 from public.delivery_boys db where db.user_id = au.id
    )
  order by au.created_at desc
  limit 300;
end;
$$;

comment on function public.admin_list_linkable_accounts() is 'Admin-only: सर्व नोंदणीकृत पण अजून कुठल्याही डिलिव्हरी बॉयशी न जोडलेल्या खात्यांची यादी (ईमेल select dropdown साठी)';

grant execute on function public.admin_list_linkable_accounts() to authenticated;
