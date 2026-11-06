-- Aggregated moderator analytics; no raw messages or private account data are returned.
create or replace function public.moderator_dashboard_analytics(p_days integer default 30)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_days integer := coalesce(p_days,30);
  v_start date;
  v_summary jsonb;
  v_daily jsonb;
begin
  if (select auth.uid()) is null or not exists (
    select 1 from private.moderators m where m.user_id=(select auth.uid())
  ) then
    raise exception 'Moderator access required' using errcode='42501';
  end if;
  if v_days not in (7,30,90) then
    raise exception 'Analytics range must be 7, 30, or 90 days' using errcode='22023';
  end if;
  v_start := current_date - (v_days - 1);

  select jsonb_build_object(
    'reports_received', (select count(*) from public.content_reports r where r.created_at >= v_start::timestamptz),
    'reports_reviewed', (select count(*) from public.content_reports r where r.reviewed_at >= v_start::timestamptz),
    'avg_report_review_hours', (select round((avg(extract(epoch from (r.reviewed_at-r.created_at))/3600))::numeric,1)
      from public.content_reports r where r.reviewed_at >= v_start::timestamptz and r.reviewed_at>=r.created_at),
    'appeals_submitted', (select count(*) from private.account_moderation_appeals a where a.created_at >= v_start::timestamptz),
    'appeals_decided', (select count(*) from private.account_moderation_appeals a where a.reviewed_at >= v_start::timestamptz),
    'avg_appeal_review_hours', (select round((avg(extract(epoch from (a.reviewed_at-a.created_at))/3600))::numeric,1)
      from private.account_moderation_appeals a where a.reviewed_at >= v_start::timestamptz and a.reviewed_at>=a.created_at),
    'restrictions_issued', (select count(*) from private.account_moderation_audit a where a.created_at >= v_start::timestamptz and a.action='posting_restricted'),
    'restrictions_restored', (select count(*) from private.account_moderation_audit a where a.created_at >= v_start::timestamptz and a.action in ('restore','appeal_accepted'))
  ) into v_summary;

  select coalesce(jsonb_agg(jsonb_build_object(
    'day',d.day,
    'reports_received',coalesce(r.received,0),
    'reports_reviewed',coalesce(r.reviewed,0),
    'appeals_submitted',coalesce(a.submitted,0),
    'appeals_decided',coalesce(a.decided,0),
    'restrictions_issued',coalesce(m.issued,0),
    'restrictions_restored',coalesce(m.restored,0)
  ) order by d.day),'[]'::jsonb)
  into v_daily
  from generate_series(v_start::timestamp,current_date::timestamp,interval '1 day') as d(day)
  left join lateral (
    select count(*) filter(where created_at >= d.day and created_at < d.day+interval '1 day') as received,
           count(*) filter(where reviewed_at >= d.day and reviewed_at < d.day+interval '1 day') as reviewed
    from public.content_reports
  ) r on true
  left join lateral (
    select count(*) filter(where created_at >= d.day and created_at < d.day+interval '1 day') as submitted,
           count(*) filter(where reviewed_at >= d.day and reviewed_at < d.day+interval '1 day') as decided
    from private.account_moderation_appeals
  ) a on true
  left join lateral (
    select count(*) filter(where created_at >= d.day and created_at < d.day+interval '1 day' and action='posting_restricted') as issued,
           count(*) filter(where created_at >= d.day and created_at < d.day+interval '1 day' and action in ('restore','appeal_accepted')) as restored
    from private.account_moderation_audit
  ) m on true;

  return jsonb_build_object('days',v_days,'summary',v_summary,'daily',v_daily,'generated_at',now());
end;
$function$;

revoke execute on function public.moderator_dashboard_analytics(integer) from public,anon;
grant execute on function public.moderator_dashboard_analytics(integer) to authenticated;
