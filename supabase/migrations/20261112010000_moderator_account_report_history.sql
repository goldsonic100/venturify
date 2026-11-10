-- Moderator-only report activity timeline for account investigations.
-- Returns report metadata for reports filed by or against one account.
-- Never exposes reporter contact details, private messages, or auth records.

create index if not exists content_reports_reporter_created_idx
  on public.content_reports (reporter_id, created_at desc);
create index if not exists content_reports_reported_user_created_idx
  on public.content_reports (reported_user_id, created_at desc);

create or replace function public.moderator_get_account_report_history(
  p_target_user_id uuid
)
returns table (
  report_id uuid,
  account_role text,
  reason text,
  details text,
  status text,
  created_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid,
  reported_user_id uuid,
  post_id uuid,
  comment_id uuid
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if (select auth.uid()) is null or not exists (
    select 1 from private.moderators m
    where m.user_id = (select auth.uid())
  ) then
    raise exception 'Moderator access required' using errcode = '42501';
  end if;

  if p_target_user_id is null then
    raise exception 'Target account is required' using errcode = '22023';
  end if;

  return query
    select
      r.id,
      case
        when r.reporter_id = p_target_user_id and r.reported_user_id = p_target_user_id
          then 'reporter_and_target'
        when r.reporter_id = p_target_user_id then 'reporter'
        else 'reported_account'
      end,
      r.reason,
      coalesce(r.details, ''),
      r.status,
      r.created_at,
      r.reviewed_at,
      r.reviewed_by,
      r.reported_user_id,
      r.post_id,
      r.comment_id
    from public.content_reports r
    where r.reporter_id = p_target_user_id
       or r.reported_user_id = p_target_user_id
    order by r.created_at desc, r.id desc
    limit 100;
end;
$function$;

revoke all on function public.moderator_get_account_report_history(uuid)
  from public, anon;
grant execute on function public.moderator_get_account_report_history(uuid)
  to authenticated;

comment on function public.moderator_get_account_report_history(uuid) is
  'Returns the latest 100 reports filed by or against one account to allowlisted moderators only; excludes private messages and auth data.';
