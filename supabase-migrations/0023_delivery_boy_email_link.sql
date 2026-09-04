-- ============================================================================
-- 0023_delivery_boy_email_link.sql
-- अ‍ॅडमिनला डिलिव्हरी बॉय जोडताना ईमेल आयडी साठवता यावा, आणि तो ईमेल वापरून
-- आधीच साईनअप केलेल्या login खात्याशी थेट जोडता यावा (फोन/manual शोधण्याऐवजी).
-- ============================================================================

-- 1. delivery_boys मध्ये email कॉलम (नसेल तर) जोडा
alter table public.delivery_boys
  add column if not exists email text;

comment on column public.delivery_boys.email is 'अ‍ॅडमिनने नोंदवलेला डिलिव्हरी बॉयचा ईमेल आयडी — login खात्याशी जोडण्यासाठी वापरला जातो';

-- 2. Admin-only SECURITY DEFINER RPC: दिलेल्या ईमेलचं auth खातं शोधून द्या
--    (क्लायंटला auth.users थेट वाचता येत नाही, म्हणून हे फंक्शन गरजेचं आहे)
create or replace function public.admin_find_account_by_email(p_email text)
returns table (
  user_id uuid,
  full_name text,
  phone text,
  email text,
  already_linked_to text
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
    au.email::text as email,
    db.name as already_linked_to
  from auth.users au
  left join public.users pu on pu.id = au.id
  left join public.delivery_boys db on db.user_id = au.id
  where lower(au.email) = lower(trim(p_email))
  limit 1;
end;
$$;

comment on function public.admin_find_account_by_email(text) is 'Admin-only: दिलेल्या ईमेलने साईनअप केलेलं खातं शोधतं (delivery boy login जोडण्यासाठी वापरलं जातं)';

grant execute on function public.admin_find_account_by_email(text) to authenticated;
