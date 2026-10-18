-- Protected moderator dashboard read APIs. No client roles can bypass the allowlist.
-- Exposes profile-level moderation context only; never exposes auth emails, credentials,
-- private messages, session tokens, or the private.moderators table.

create or replace function public.moderator_dashboard_overview()
returns jsonb
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

  return jsonb_build_object(
    'accounts', (select count(*) from public.profiles),
    'posts', (select count(*) from public.posts),
    'comments', (select count(*) from public.comments),
    'communities', (select count(*) from public.communities),
    'community_memberships', (select count(*) from public.community_members),
    'pending_reports', (select count(*) from public.content_reports where status = 'pending'),
    'reviewing_reports', (select count(*) from public.content_reports where status = 'reviewing'),
    'resolved_reports', (select count(*) from public.content_reports where status = 'resolved'),
    'dismissed_reports', (select count(*) from public.content_reports where status = 'dismissed'),
    'messages', (select count(*) from public.messages),
    'generated_at', now()
  );
end;
$function$;

create or replace function public.moderator_list_users(
  p_query text default '',
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
  following_count bigint
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_query text := left(trim(coalesce(p_query, '')), 120);
begin
  if (select auth.uid()) is null or not exists (
    select 1 from private.moderators m where m.user_id = (select auth.uid())
  ) then
    raise exception 'Moderator access required' using errcode = '42501';
  end if;

  return query
    select p.id, p.username, coalesce(p.display_name, ''), coalesce(p.bio, ''),
           p.created_at, coalesce(p.headline, ''), coalesce(p.company, ''),
           coalesce(p.location, ''),
           (select count(*) from public.posts po where po.user_id = p.id),
           (select count(*) from public.follows f where f.following_id = p.id),
           (select count(*) from public.follows f where f.follower_id = p.id)
    from public.profiles p
    where v_query = ''
       or p.username ilike '%' || v_query || '%'
       or coalesce(p.display_name, '') ilike '%' || v_query || '%'
       or p.id::text = v_query
    order by p.created_at desc
    limit greatest(1, least(coalesce(p_limit, 50), 100))
    offset greatest(0, least(coalesce(p_offset, 0), 100000));
end;
$function$;

create or replace function public.moderator_list_recent_posts(
  p_query text default '',
  p_limit integer default 50
)
returns table (
  id uuid,
  user_id uuid,
  username text,
  content text,
  created_at timestamptz,
  community_id uuid
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_query text := left(trim(coalesce(p_query, '')), 120);
begin
  if (select auth.uid()) is null or not exists (
    select 1 from private.moderators m where m.user_id = (select auth.uid())
  ) then
    raise exception 'Moderator access required' using errcode = '42501';
  end if;

  return query
    select po.id, po.user_id, p.username, po.content, po.created_at, po.community_id
    from public.posts po
    left join public.profiles p on p.id = po.user_id
    where v_query = '' or po.content ilike '%' || v_query || '%'
       or coalesce(p.username, '') ilike '%' || v_query || '%'
       or po.id::text = v_query
    order by po.created_at desc
    limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$function$;

revoke all on function public.moderator_dashboard_overview() from public, anon;
revoke all on function public.moderator_list_users(text, integer, integer) from public, anon;
revoke all on function public.moderator_list_recent_posts(text, integer) from public, anon;
grant execute on function public.moderator_dashboard_overview() to authenticated;
grant execute on function public.moderator_list_users(text, integer, integer) to authenticated;
grant execute on function public.moderator_list_recent_posts(text, integer) to authenticated;

comment on function public.moderator_dashboard_overview() is
  'Aggregate system counters visible only to explicitly provisioned moderators.';
comment on function public.moderator_list_users(text, integer, integer) is
  'Searches profile-level account details only for explicitly provisioned moderators; does not return auth data.';
comment on function public.moderator_list_recent_posts(text, integer) is
  'Lists recent public posts for moderation only for explicitly provisioned moderators.';
