-- Paged public-post review queue. The original RPC remains for compatibility.
create or replace function public.moderator_list_recent_posts_page(
  p_query text default '',
  p_limit integer default 50,
  p_offset integer default 0
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
    order by po.created_at desc, po.id desc
    limit greatest(1, least(coalesce(p_limit, 50), 51))
    offset greatest(0, least(coalesce(p_offset, 0), 1000000));
end;
$function$;

revoke all on function public.moderator_list_recent_posts_page(text, integer, integer) from public, anon;
grant execute on function public.moderator_list_recent_posts_page(text, integer, integer) to authenticated;

comment on function public.moderator_list_recent_posts_page(text, integer, integer) is
  'Returns one page of public posts only to allowlisted moderators; use a one-row lookahead to detect more pages.';
