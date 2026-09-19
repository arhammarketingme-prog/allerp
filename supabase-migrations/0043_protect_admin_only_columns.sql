-- ============================================================================
-- 0043: Admin-only कॉलम्सचं खरं संरक्षण (column-level, RLS row-level असल्याने
-- पुरेसं नव्हतं)
--
-- सापडलेला गंभीर प्रश्न: खालच्या तिन्ही टेबल्सवर सामान्य युजरला (owner/member)
-- पूर्ण रो UPDATE करण्याची परवानगी होती (RLS row-level आहे, column-level नाही),
-- म्हणजे admin-only असायला हवेत असे कॉलम्स युजर स्वतःच बदलू शकत होता:
--   • businesses.is_verified / is_active   — दुकानदार स्वतःला "Verified" करू शकत होता
--   • advertisers.is_verified              — जाहिरातदार स्वतःला verified करू शकत होता
--   • campaigns.payment_status             — ⚠️ सर्वात गंभीर: जाहिरातदार पैसे न
--     भरताच स्वतःची जाहिरात 'verified' करून मोफत live करू शकत होता
--     (revenue bypass)
--
-- फिक्स: BEFORE UPDATE trigger — admin नसेल तर हे संरक्षित कॉलम्स शांतपणे
-- जुन्याच मूल्यावर परत नेतो (बाकी कॉलम्सचं legitimate update अडत नाही —
-- फक्त हे संरक्षित कॉलम्स बदलू देत नाही).
-- ============================================================================

create or replace function public.protect_business_admin_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    NEW.is_verified := OLD.is_verified;
    NEW.is_active := OLD.is_active;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_protect_business_admin_fields on public.businesses;
create trigger trg_protect_business_admin_fields
  before update on public.businesses
  for each row execute function public.protect_business_admin_fields();

create or replace function public.protect_advertiser_admin_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    NEW.is_verified := OLD.is_verified;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_protect_advertiser_admin_fields on public.advertisers;
create trigger trg_protect_advertiser_admin_fields
  before update on public.advertisers
  for each row execute function public.protect_advertiser_admin_fields();

create or replace function public.protect_campaign_payment_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    NEW.payment_status := OLD.payment_status;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_protect_campaign_payment_status on public.campaigns;
create trigger trg_protect_campaign_payment_status
  before update on public.campaigns
  for each row execute function public.protect_campaign_payment_status();

-- ============================================================================
-- टीप: admin.html चे Approve/Verify/Un-verify बटणं is_admin() असलेल्या
-- सत्रातूनच चालतात, त्यामुळे यांच्यावर काहीही परिणाम होणार नाही — फक्त
-- सामान्य (non-admin) युजरचे प्रयत्न आता निष्प्रभ होतील.
-- ============================================================================
