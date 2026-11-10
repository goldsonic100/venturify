-- Server-side account directory filters and sorting for authorized moderators.
-- Returns profile-level information plus moderation state only; never auth or message data.

create or replace function public.moderator_search_accounts(
  p_query text default '',
  p_status text default 'all',
  p_sort text default 'newest',
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  username text,
  display_name text,
  bio text,
  created_at timestamptz,
  headline text,
  company text,
  location text,
  post_count bigint,
  follower_count bigint,
  following_count bigint,
  moderation_status text,
  moderation_expires_at timestamptz,
  moderation_reason text
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_query text := left(trim(coalesce(p_query, '')), 120);
  v_status text := coalesce(p_status, 'all');
  v_sort text := coalesce(p_sort, 'newest');
begin
  if (select auth.uid()) is null or not exists (
    select 1 from private.moderators m where m.user_id = (select auth.uid())
  ) then
    raise exception 'Moderator access required' using errcode = '42501';
  end if;

  if v_status not in ('all', 'needs_attention', 'posting_restricted', 'warning', 'clear') then
    raise exception 'Invalid account status filter' using errcode = '22023';
  end if;
  if v_sort not in ('newest', 'oldest', 'most_posts', 'most_followers') then
    raise exception 'Invalid account sort order' using errcode = '22023';
  end if;

  return query
    with account_rows as (
      select
        p.id, p.username, coalesce(p.display_name, '') as display_name,
        coalesce(p.bio, '') as bio, p.created_at,
        coalesce(p.headline, '') as headline, coalesce(p.company, '') as company,
        coalesce(p.location, '') as location,
        (select count(*) from public.posts po where po.user_id = p.id) as post_count,
        (select count(*) from public.follows f where f.following_id = p.id) as follower_count,
        (select count(*) from public.follows f where f.follower_id = p.id) as following_count,
        case
          when s.status = 'posting_restricted'
            and s.expires_at is not null and s.expires_at <= now()
          then 'clear'
          else coalesce(s.status, 'clear')
        end as moderation_status,
        s.expires_at as moderation_expires_at,
        coalesce(s.reason, '') as moderation_reason
      from public.profiles p
      left join private.account_moderation_state s on s.user_id = p.id
      where v_query = ''
         or p.username ilike '%' || v_query || '%'
         or coalesce(p.display_name, '') ilike '%' || v_query || '%'
         or p.id::text = v_query
    )
    select a.id, a.username, a.display_name, a.bio, a.created_at,
           a.headline, a.company, a.location, a.post_count,
           a.follower_count, a.following_count, a.moderation_status,
           a.moderation_expires_at, a.moderation_reason
    from account_rows a
    where v_status = 'all'
       or (v_status = 'needs_attention' and a.moderation_status in ('warning', 'posting_restricted'))
       or (v_status = 'posting_restricted' and a.moderation_status = 'posting_restricted')
       or (v_status = 'warning' and a.moderation_status = 'warning')
       or (v_status = 'clear' and a.moderation_status = 'clear')
    order by
      case when v_sort = 'newest' then a.created_at end desc nulls last,
      case when v_sort = 'oldest' then a.created_at end asc nulls last,
      case when v_sort = 'most_posts' then a.post_count end desc nulls last,
      case when v_sort = 'most_followers' then a.follower_count end desc nulls last,
      a.created_at desc, a.id
    limit greatest(1, least(coalesce(p_limit, 50), 100))
    offset greatest(0, least(coalesce(p_offset, 0), 100000));
end;
$function$;

revoke all on function public.moderator_search_accounts(text, text, text, integer, integer) from public, anon;
grant execute on function public.moderator_search_accounts(text, text, text, integer, integer) to authenticated;

comment on function public.moderator_search_accounts(text, text, text, integer, integer) is
  'Server-side filtered and sorted moderator account directory; profile-level data and moderation status only, protected by the private moderator allowlist.';
