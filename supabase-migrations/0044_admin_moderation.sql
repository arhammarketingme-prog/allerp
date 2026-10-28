-- ============================================================================
-- 0044: Admin Moderation — जाहिरात थांबवणे + प्रॉडक्ट (नियम-भंग करणारा)
-- थांबवणे. आधी हे कुठेही शक्य नव्हतं — payment verify करता येत होतं, पण एकदा
-- जाहिरात live झाल्यावर ती थांबवायला कुठलंही बटणच नव्हतं.
-- ============================================================================

alter table public.campaigns add column if not exists moderation_note text;
alter table public.campaigns add column if not exists moderated_by uuid references public.users(id);
alter table public.campaigns add column if not exists moderated_at timestamptz;

alter table public.business_products add column if not exists moderation_note text;
alter table public.business_products add column if not exists moderated_by uuid references public.users(id);
alter table public.business_products add column if not exists moderated_at timestamptz;

-- जाहिरात थांबवणे/परत सुरू करणे — फक्त admin (audit_logs मध्ये नोंद होते)
create or replace function public.admin_moderate_campaign(
  p_campaign_id uuid, p_new_status text, p_reason text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'फक्त admin ला ही कृती करता येते';
  end if;

  if p_new_status not in ('active', 'paused', 'rejected') then
    raise exception 'अवैध स्थिती: %', p_new_status;
  end if;

  update public.campaigns
     set status = p_new_status,
         moderation_note = p_reason,
         moderated_by = auth.uid(),
         moderated_at = now()
   where id = p_campaign_id;

  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, after_data)
  values (auth.uid(), 'campaign_' || p_new_status, 'campaigns', p_campaign_id, jsonb_build_object('reason', p_reason));
end;
$$;

grant execute on function public.admin_moderate_campaign(uuid, text, text) to authenticated;

-- प्रॉडक्ट लिस्टिंग थांबवणे/परत सुरू करणे (उदा. कायद्याचं उल्लंघन करणारा माल)
-- — फक्त admin (business_products RLS मध्ये आधीच admin ला access आहे,
-- ही RPC फक्त accountability/audit trail साठी)
create or replace function public.admin_moderate_product(
  p_product_id uuid, p_is_active boolean, p_reason text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action text;
begin
  if not public.is_admin() then
    raise exception 'फक्त admin ला ही कृती करता येते';
  end if;

  update public.business_products
     set is_active = p_is_active,
         moderation_note = p_reason,
         moderated_by = auth.uid(),
         moderated_at = now()
   where id = p_product_id;

  v_action := case when p_is_active then 'product_reactivated' else 'product_deactivated' end;

  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, after_data)
  values (auth.uid(), v_action, 'business_products', p_product_id, jsonb_build_object('reason', p_reason));
end;
$$;

grant execute on function public.admin_moderate_product(uuid, boolean, text) to authenticated;
