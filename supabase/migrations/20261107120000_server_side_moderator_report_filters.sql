-- Server-side report age filtering and ordering for the moderator queue.
-- Keep the original three-argument RPC unchanged for existing callers.

create or replace function public.moderator_list_reports_filtered_page(
  p_status text default 'pending',
  p_age_filter text default 'all',
  p_sort text default 'oldest',
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
    select 1
    from private.moderators m
    where m.user_id = (select auth.uid())
  ) then
    raise exception 'Moderator access required' using errcode = '42501';
  end if;

  if p_status is not null
     and p_status not in ('pending', 'reviewing', 'resolved', 'dismissed') then
    raise exception 'Invalid report status' using errcode = '22023';
  end if;

  if p_age_filter is null or p_age_filter not in ('all', 'over24', 'over7') then
    raise exception 'Invalid report age filter' using errcode = '22023';
  end if;

  if p_sort is null or p_sort not in ('oldest', 'newest', 'priority') then
    raise exception 'Invalid report sort order' using errcode = '22023';
  end if;

  return query
    select r.id, r.reporter_id, r.reported_user_id, r.post_id, r.comment_id,
           r.reason, r.details, r.status, r.created_at, r.moderator_notes,
           r.reviewed_at, r.reviewed_by
    from public.content_reports r
    where (p_status is null or r.status = p_status)
      and (
        p_age_filter = 'all'
        or (
          r.status = 'pending'
          and (
            (p_age_filter = 'over24' and r.created_at <= now() - interval '24 hours')
            or (p_age_filter = 'over7' and r.created_at <= now() - interval '7 days')
          )
        )
      )
    order by
      case when p_sort = 'priority' then
        case
          when r.status = 'pending' and r.created_at <= now() - interval '7 days' then 0
          when r.status = 'pending' and r.created_at <= now() - interval '24 hours' then 1
          when r.status = 'pending' then 2
          else 3
        end
      end asc,
      case when p_sort = 'newest' then r.created_at end desc,
      case when p_sort <> 'newest' then r.created_at end asc,
      r.id asc
    limit greatest(1, least(coalesce(p_limit, 50), 51))
    offset greatest(0, least(coalesce(p_offset, 0), 1000000));
end;
$function$;

revoke execute on function public.moderator_list_reports_filtered_page(text, text, text, integer, integer)
  from public, anon;
grant execute on function public.moderator_list_reports_filtered_page(text, text, text, integer, integer)
  to authenticated;
