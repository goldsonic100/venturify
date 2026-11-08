-- Ensure the SECURITY DEFINER poll-results RPC enforces the same post visibility
-- and block boundaries as direct reads of posts, polls, and poll options.
create or replace function public.get_poll_results(requested_poll_ids uuid[])
returns table(poll_id uuid, option_id uuid, vote_count bigint, is_my_vote boolean)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if coalesce(pg_catalog.cardinality(requested_poll_ids), 0) > 100 then
    raise exception 'Request no more than 100 polls at a time' using errcode = '22023';
  end if;

  return query
    select
      o.poll_id,
      o.id as option_id,
      count(v.id) as vote_count,
      coalesce(bool_or(v.user_id = (select auth.uid())), false) as is_my_vote
    from public.post_poll_options o
    join public.post_polls pp on pp.id = o.poll_id
    join public.posts p on p.id = pp.post_id
    left join public.post_poll_votes v
      on v.option_id = o.id and v.poll_id = o.poll_id
    where o.poll_id = any(requested_poll_ids)
      and (
        private.is_profile_public(p.user_id)
        or p.user_id = (select auth.uid())
        or exists (
          select 1 from public.follows f
          where f.follower_id = (select auth.uid())
            and f.following_id = p.user_id
        )
      )
      and not exists (
        select 1 from public.user_blocks b
        where (b.blocker_id = (select auth.uid()) and b.blocked_id = p.user_id)
           or (b.blocked_id = (select auth.uid()) and b.blocker_id = p.user_id)
      )
    group by o.poll_id, o.id;
end;
$function$;

revoke all on function public.get_poll_results(uuid[]) from public;
revoke all on function public.get_poll_results(uuid[]) from anon;
grant execute on function public.get_poll_results(uuid[]) to authenticated;
