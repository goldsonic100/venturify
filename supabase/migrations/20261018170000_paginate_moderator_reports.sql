-- Paged moderator report queue. The existing RPC remains available for older clients.
create or replace function public.moderator_list_reports_page(
  p_status text default 'pending',
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  reporter_id uuid,
  reported_user_id uuid,
  post_id uuid,
  comment_id uuid,
  reason text,
  details text,
  status text,
  created_at timestamptz,
  moderator_notes text,
  reviewed_at timestamptz,
  reviewed_by uuid
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if (select auth.uid()) is null or not exists (
    select 1 from private.moderators m where m.user_id = (select auth.uid())
  ) then
    raise exception 'Moderator access required' using errcode = '42501';
  end if;

  if p_status is not null and p_status not in ('pending', 'reviewing', 'resolved', 'dismissed') then
    raise exception 'Invalid report status' using errcode = '22023';
  end if;

  return query
    select r.id, r.reporter_id, r.reported_user_id, r.post_id, r.comment_id,
           r.reason, r.details, r.status, r.created_at, r.moderator_notes,
           r.reviewed_at, r.reviewed_by
    from public.content_reports r
    where p_status is null or r.status = p_status
    order by r.created_at asc, r.id asc
    limit greatest(1, least(coalesce(p_limit, 50), 51))
    offset greatest(0, least(coalesce(p_offset, 0), 1000000));
end;
$function$;

revoke all on function public.moderator_list_reports_page(text, integer, integer) from public, anon;
grant execute on function public.moderator_list_reports_page(text, integer, integer) to authenticated;

comment on function public.moderator_list_reports_page(text, integer, integer) is
  'Returns one page of reports only to allowlisted moderators; use a one-row lookahead to detect more pages.';
