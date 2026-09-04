-- 0018_auto_cleanup_expired_ads.sql
-- Automatic cleanup of expired advertisements and their media files from storage

-- 1. Helper function to delete expired ads and return file paths for storage cleanup
create or replace function public.cleanup_expired_ads()
returns table (
  deleted_ad_id uuid,
  deleted_media_url text,
  campaign_name text
)
language plpgsql
security definer
as $$
declare
  r record;
begin
  -- Find all ads belonging to campaigns where end_date has passed (end_date < CURRENT_DATE)
  for r in
    select a.id as ad_id, a.media_url, c.name as camp_name, a.campaign_id
    from public.advertisements a
    join public.campaigns c on c.id = a.campaign_id
    where (c.end_date is not null and c.end_date < current_date)
       or c.status = 'completed'
  loop
    deleted_ad_id := r.ad_id;
    deleted_media_url := r.media_url;
    campaign_name := r.camp_name;

    -- Delete tracking records first
    delete from public.ad_clicks where advertisement_id = r.ad_id;
    delete from public.ad_impressions where advertisement_id = r.ad_id;
    
    -- Delete the advertisement record
    delete from public.advertisements where id = r.ad_id;

    -- Mark campaign as completed
    update public.campaigns set status = 'completed' where id = r.campaign_id and status != 'completed';

    return next;
  end loop;
end;
$$;

grant execute on function public.cleanup_expired_ads() to authenticated, anon;
