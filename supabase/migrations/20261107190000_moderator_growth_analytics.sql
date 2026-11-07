-- Aggregate founder, community, collaboration, and engagement trends for moderators only.
-- This function returns aggregate counts and daily buckets; no identifiers or content.
create or replace function public.moderator_growth_analytics(p_days integer default 30)
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
    'verified_profiles_current',(select count(*) from public.profiles p where p.email_verified is true),
    'new_accounts',(select count(*) from public.profiles p where p.created_at >= v_start::timestamptz),
    'new_accounts_currently_verified',(select count(*) from public.profiles p where p.created_at >= v_start::timestamptz and p.email_verified is true),
    'communities_current',(select count(*) from public.communities),
    'communities_created',(select count(*) from public.communities c where c.created_at >= v_start::timestamptz),
    'community_joins',(select count(*) from public.community_members cm where cm.created_at >= v_start::timestamptz),
    'collaboration_requests_created',(select count(*) from public.collaboration_requests cr where cr.created_at >= v_start::timestamptz),
    'collaboration_accepted_current',(select count(*) from public.collaboration_requests cr where cr.status='accepted'),
    'collaboration_declined_current',(select count(*) from public.collaboration_requests cr where cr.status='declined'),
    'posts_created',(select count(*) from public.posts p where p.created_at >= v_start::timestamptz),
    'comments_created',(select count(*) from public.comments c where c.created_at >= v_start::timestamptz),
    'likes_created',(select count(*) from public.likes l where l.created_at >= v_start::timestamptz),
    'follows_created',(select count(*) from public.follows f where f.created_at >= v_start::timestamptz)
  ) into v_summary;

  with days as (
    select generate_series(v_start,current_date,interval '1 day')::date as day
  ),
  accounts as (
    select created_at::date as day,count(*) as total from public.profiles
    where created_at >= v_start::timestamptz and created_at < (current_date+1)::timestamptz group by created_at::date
  ),
  communities as (
    select created_at::date as day,count(*) as total from public.communities
    where created_at >= v_start::timestamptz and created_at < (current_date+1)::timestamptz group by created_at::date
  ),
  joins as (
    select created_at::date as day,count(*) as total from public.community_members
    where created_at >= v_start::timestamptz and created_at < (current_date+1)::timestamptz group by created_at::date
  ),
  collaborations as (
    select created_at::date as day,count(*) as total from public.collaboration_requests
    where created_at >= v_start::timestamptz and created_at < (current_date+1)::timestamptz group by created_at::date
  ),
  posts as (
    select created_at::date as day,count(*) as total from public.posts
    where created_at >= v_start::timestamptz and created_at < (current_date+1)::timestamptz group by created_at::date
  ),
  comments as (
    select created_at::date as day,count(*) as total from public.comments
    where created_at >= v_start::timestamptz and created_at < (current_date+1)::timestamptz group by created_at::date
  ),
  likes as (
    select created_at::date as day,count(*) as total from public.likes
    where created_at >= v_start::timestamptz and created_at < (current_date+1)::timestamptz group by created_at::date
  ),
  follows as (
    select created_at::date as day,count(*) as total from public.follows
    where created_at >= v_start::timestamptz and created_at < (current_date+1)::timestamptz group by created_at::date
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'day',d.day,
    'accounts_created',coalesce(a.total,0),
    'communities_created',coalesce(c.total,0),
    'community_joins',coalesce(j.total,0),
    'collaboration_requests',coalesce(cr.total,0),
    'posts_created',coalesce(p.total,0),
    'comments_created',coalesce(co.total,0),
    'likes_created',coalesce(l.total,0),
    'follows_created',coalesce(f.total,0)
  ) order by d.day),'[]'::jsonb)
  into v_daily
  from days d
  left join accounts a on a.day=d.day
  left join communities c on c.day=d.day
  left join joins j on j.day=d.day
  left join collaborations cr on cr.day=d.day
  left join posts p on p.day=d.day
  left join comments co on co.day=d.day
  left join likes l on l.day=d.day
  left join follows f on f.day=d.day;

  return jsonb_build_object('days',v_days,'summary',v_summary,'daily',v_daily,'generated_at',now());
end;
$function$;

revoke execute on function public.moderator_growth_analytics(integer) from public,anon;
grant execute on function public.moderator_growth_analytics(integer) to authenticated;
