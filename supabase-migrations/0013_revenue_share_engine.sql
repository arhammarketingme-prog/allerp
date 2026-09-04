-- ============================================================================
-- 0013: Revenue Share Engine — calculation logic.
--
-- Important design note (matches the platform's core rule that it never
-- holds funds): this does NOT collect or move any money. It computes, for a
-- given period, what each campaign's PRORATED declared budget would be
-- worth, applies the admin-configured share_percent, and records the result
-- as a 'pending' revenue_shares row — a report for manual reconciliation
-- outside the platform, exactly like payments_metadata is for orders.
-- ============================================================================

alter table public.revenue_shares add column if not exists campaign_id uuid references public.campaigns(id);
alter table public.revenue_shares add column if not exists note text;

-- prevent duplicate rows if the same period is calculated twice
create unique index if not exists revenue_shares_unique_period
  on public.revenue_shares (campaign_id, rule_id, period_start, period_end)
  where campaign_id is not null;

-- ----------------------------------------------------------------------------
-- calculate_revenue_shares: admin-only. For every campaign active during the
-- given period, prorates its declared budget by the overlapping days, applies
-- the active 'platform_default' rule, and records a pending share row.
-- ----------------------------------------------------------------------------
create or replace function public.calculate_revenue_shares(
  p_period_start date,
  p_period_end date
)
returns integer
language plpgsql
security definer
as $$
declare
  v_rule public.revenue_share_rules;
  v_campaign record;
  v_overlap_days numeric;
  v_total_days numeric;
  v_gross numeric;
  v_share numeric;
  v_count integer := 0;
begin
  if not public.is_admin() then
    raise exception 'Admin only';
  end if;

  select * into v_rule from public.revenue_share_rules
    where applies_to = 'platform_default' and is_active
    order by created_at desc limit 1;

  if v_rule is null then
    raise exception 'No active platform_default revenue share rule configured. Set one first.';
  end if;

  for v_campaign in
    select c.id, c.name, c.budget, c.start_date, c.end_date
    from public.campaigns c
    where c.status in ('active', 'completed', 'paused')
      and c.budget is not null and c.budget > 0
      and c.start_date is not null and c.end_date is not null
      and c.start_date <= p_period_end
      and c.end_date >= p_period_start
  loop
    v_overlap_days := (least(v_campaign.end_date, p_period_end) - greatest(v_campaign.start_date, p_period_start)) + 1;
    v_total_days := (v_campaign.end_date - v_campaign.start_date) + 1;

    if v_total_days <= 0 or v_overlap_days <= 0 then
      continue;
    end if;

    v_gross := round(v_campaign.budget * (v_overlap_days / v_total_days), 2);
    v_share := round(v_gross * (v_rule.share_percent / 100), 2);

    insert into public.revenue_shares (campaign_id, rule_id, gross_amount, share_amount, period_start, period_end, status, note)
    values (v_campaign.id, v_rule.id, v_gross, v_share, p_period_start, p_period_end, 'pending',
      'Auto-calculated: ' || v_overlap_days || '/' || v_total_days || ' days of campaign "' || v_campaign.name || '" in period')
    on conflict (campaign_id, rule_id, period_start, period_end) do update
      set gross_amount = excluded.gross_amount, share_amount = excluded.share_amount, note = excluded.note;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

grant execute on function public.calculate_revenue_shares(date, date) to authenticated;
