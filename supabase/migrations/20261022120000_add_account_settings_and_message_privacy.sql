-- Account privacy and preferences for Venturify.
-- Existing users retain the current public-by-default experience.
create table if not exists public.account_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  public_profile boolean not null default true,
  public_dms boolean not null default true,
  allow_collaboration_requests boolean not null default true,
  show_in_discover boolean not null default true,
  enable_story_posts boolean not null default true,
  enable_polls boolean not null default true,
  enable_opportunities boolean not null default true,
  notify_messages boolean not null default true,
  notify_reactions boolean not null default true,
  notify_group_mentions boolean not null default true,
  appearance text not null default 'system' check (appearance in ('system','light','dark')),
  updated_at timestamptz not null default now()
);

alter table public.account_settings enable row level security;
drop policy if exists "Users can read their own account settings" on public.account_settings;
drop policy if exists "Users can create their own account settings" on public.account_settings;
drop policy if exists "Users can update their own account settings" on public.account_settings;
create policy "Users can read their own account settings" on public.account_settings
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Users can create their own account settings" on public.account_settings
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Users can update their own account settings" on public.account_settings
  for update to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create or replace function private.is_profile_public(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select s.public_profile from public.account_settings s where s.user_id = target_user_id),
    true
  );
$$;

create or replace function public.get_discoverable_founder_ids()
returns table(founder_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
  from public.profiles p
  where ((select auth.uid()) is null or p.id <> (select auth.uid()))
    and coalesce((select s.public_profile from public.account_settings s where s.user_id = p.id), true)
    and coalesce((select s.show_in_discover from public.account_settings s where s.user_id = p.id), true)
    and ((select auth.uid()) is null or not exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = (select auth.uid()) and b.blocked_id = p.id)
         or (b.blocked_id = (select auth.uid()) and b.blocker_id = p.id)
    ));
$$;

create or replace function public.get_messageable_founder_ids()
returns table(founder_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
  from public.profiles p
  where p.id <> (select auth.uid())
    and (
      coalesce((select s.public_dms from public.account_settings s where s.user_id = p.id), true)
      or exists (
        select 1 from public.follows f
        where f.follower_id = (select auth.uid()) and f.following_id = p.id
      )
      or exists (
        select 1
        from public.conversation_members mine
        join public.conversation_members theirs
          on theirs.conversation_id = mine.conversation_id
        join public.conversations c on c.id = mine.conversation_id
        where mine.user_id = (select auth.uid())
          and theirs.user_id = p.id
          and c.is_group = false
      )
    )
    and not exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = (select auth.uid()) and b.blocked_id = p.id)
         or (b.blocked_id = (select auth.uid()) and b.blocker_id = p.id)
    );
$$;

revoke all on function public.get_discoverable_founder_ids() from public;
grant execute on function public.get_discoverable_founder_ids() to anon, authenticated;
revoke all on function public.get_messageable_founder_ids() from public;
grant execute on function public.get_messageable_founder_ids() to authenticated;
revoke all on function private.is_profile_public(uuid) from public;
grant execute on function private.is_profile_public(uuid) to anon, authenticated;

-- A private account remains visible to its owner and people they follow;
-- public accounts retain the existing anonymous-browsing behavior.
drop policy if exists "Profiles are publicly readable" on public.profiles;
create policy "Profiles are visible by account privacy" on public.profiles
  for select to anon, authenticated
  using (
    private.is_profile_public(id)
    or id = (select auth.uid())
    or exists (
      select 1 from public.follows f
      where f.follower_id = (select auth.uid()) and f.following_id = profiles.id
    )
  );

drop policy if exists "Posts are publicly readable" on public.posts;
create policy "Posts respect account privacy" on public.posts
  for select to anon, authenticated
  using (
    private.is_profile_public(user_id)
    or user_id = (select auth.uid())
    or exists (
      select 1 from public.follows f
      where f.follower_id = (select auth.uid()) and f.following_id = posts.user_id
    )
  );

-- Rebuild the existing RPC without changing its return type or direct-chat reuse.
-- A closed-DM account can still be contacted by someone it follows, and existing
-- direct conversations remain usable; public-DM opt-in permits new conversations.
create or replace function public.get_or_create_direct_conversation(target_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  current_user_id uuid := auth.uid();
  conversation_id uuid;
begin
  if current_user_id is null then
    raise exception 'You must be signed in to start a conversation.';
  end if;
  if target_user_id is null or target_user_id = current_user_id then
    raise exception 'Choose another founder to message.';
  end if;
  if not exists (select 1 from public.profiles p where p.id = target_user_id) then
    raise exception 'That founder profile could not be found.';
  end if;
  if exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = current_user_id and b.blocked_id = target_user_id)
       or (b.blocked_id = current_user_id and b.blocker_id = target_user_id)
  ) then
    raise exception 'Messaging is unavailable because one of these accounts has blocked the other.'
      using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      least(current_user_id::text, target_user_id::text) || ':' ||
      greatest(current_user_id::text, target_user_id::text), 0
    )
  );

  select c.id into conversation_id
  from public.conversations c
  join public.conversation_members mine
    on mine.conversation_id = c.id and mine.user_id = current_user_id
  join public.conversation_members theirs
    on theirs.conversation_id = c.id and theirs.user_id = target_user_id
  where c.is_group = false
    and (select count(*) from public.conversation_members cm where cm.conversation_id = c.id) = 2
  order by c.created_at asc
  limit 1;

  if conversation_id is null then
    if not coalesce(
      (select s.public_dms from public.account_settings s where s.user_id = target_user_id),
      true
    ) and not exists (
      select 1 from public.follows f
      where f.follower_id = current_user_id and f.following_id = target_user_id
    ) then
      raise exception 'This founder only accepts messages from people they follow. Follow them first to request a conversation.'
        using errcode = '42501';
    end if;

    insert into public.conversations default values returning id into conversation_id;
    insert into public.conversation_members (conversation_id, user_id)
      values (conversation_id, current_user_id), (conversation_id, target_user_id);
  end if;
  return conversation_id;
end;
$function$;

revoke all on function public.get_or_create_direct_conversation(uuid) from public;
grant execute on function public.get_or_create_direct_conversation(uuid) to authenticated;
