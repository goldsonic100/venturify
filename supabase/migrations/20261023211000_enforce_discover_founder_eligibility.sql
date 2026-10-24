-- Enforce the established-founder eligibility rule in the discovery RPC itself.
-- The client-side filter remains a presentation layer, not the security boundary.
create or replace function public.get_discoverable_founder_ids()
returns table(founder_id uuid)
language sql stable security definer set search_path = ''
as $$
  with eligible_profiles as (
    select p.id,
      (greatest(0, floor(extract(epoch from (now() - p.created_at)) / 86400))::numeric
       + (select count(*) from public.follows f where f.following_id = p.id) * 2
       + (select count(*) from public.posts po where po.user_id = p.id) * 3
       + (select count(*) from public.comments co where co.user_id = p.id)
       + (select count(*) from public.community_members cm where cm.user_id = p.id) * 3
       + least(20, round((
           (case when nullif(btrim(coalesce(p.bio, '')), '') is not null then 1 else 0 end)
         + (case when nullif(btrim(coalesce(p.headline, '')), '') is not null then 1 else 0 end)
         + (case when nullif(btrim(coalesce(p.company, '')), '') is not null then 1 else 0 end)
         + (case when nullif(btrim(coalesce(p.location, '')), '') is not null then 1 else 0 end)
         + (case when nullif(btrim(coalesce(p.skills, '')), '') is not null then 1 else 0 end)
         + (case when nullif(btrim(coalesce(p.interests, '')), '') is not null then 1 else 0 end)
         + (case when nullif(btrim(coalesce(p.looking_for, '')), '') is not null then 1 else 0 end)
         + (case when nullif(btrim(coalesce(p.avatar_url, '')), '') is not null then 1 else 0 end)
         + (case when nullif(btrim(coalesce(p.website_url, '')), '') is not null then 1 else 0 end)
         + (case when nullif(btrim(coalesce(p.linkedin_url, '')), '') is not null then 1 else 0 end)
       )::numeric / 9 * 20))
      ) as reputation_points
    from public.profiles p
    join auth.users au on au.id = p.id
    where au.email_confirmed_at is not null
      and ((select auth.uid()) is null or p.id <> (select auth.uid()))
      and coalesce((select s.public_profile from public.account_settings s where s.user_id = p.id), true)
      and coalesce((select s.show_in_discover from public.account_settings s where s.user_id = p.id), true)
      and exists (select 1 from public.community_members cm where cm.user_id = p.id)
      and ((select auth.uid()) is null or not exists (
        select 1 from public.user_blocks b
        where (b.blocker_id = (select auth.uid()) and b.blocked_id = p.id)
           or (b.blocked_id = (select auth.uid()) and b.blocker_id = p.id)
      ))
  )
  select ep.id from eligible_profiles ep
  where least(100, 1 + floor(sqrt(ep.reputation_points / 5))) >= 5;
$$;

revoke all on function public.get_discoverable_founder_ids() from public, anon;
grant execute on function public.get_discoverable_founder_ids() to authenticated;
