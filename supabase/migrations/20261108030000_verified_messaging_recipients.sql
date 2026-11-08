-- Apply the same email-verification eligibility rule to messaging recipients
-- that the founder discovery directory already enforces.
create or replace function public.get_messageable_founder_ids()
returns table(founder_id uuid)
language sql
stable
security definer
set search_path = ''
as $function$
  select p.id
  from public.profiles p
  join auth.users au on au.id = p.id
  where p.id <> (select auth.uid())
    and au.email_confirmed_at is not null
    and (
      coalesce((select s.public_dms from public.account_settings s where s.user_id = p.id), true)
      or exists (
        select 1
        from public.follows f
        where f.follower_id = p.id
          and f.following_id = (select auth.uid())
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
      select 1
      from public.user_blocks b
      where (b.blocker_id = (select auth.uid()) and b.blocked_id = p.id)
         or (b.blocked_id = (select auth.uid()) and b.blocker_id = p.id)
    );
$function$;

create or replace function public.get_or_create_direct_conversation(target_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  current_user_id uuid := auth.uid();
  conversation_id uuid;
begin
  if current_user_id is null then
    raise exception 'You must be signed in to start a conversation.' using errcode = '42501';
  end if;
  if target_user_id is null or target_user_id = current_user_id then
    raise exception 'Choose another founder to message.' using errcode = '22023';
  end if;
  if not exists (select 1 from public.profiles p where p.id = target_user_id) then
    raise exception 'That founder profile could not be found.' using errcode = '22023';
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
    if not exists (
      select 1 from auth.users au
      where au.id = target_user_id and au.email_confirmed_at is not null
    ) then
      raise exception 'This founder must verify their account before receiving new conversations.'
        using errcode = '42501';
    end if;

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

revoke all on function public.get_messageable_founder_ids() from public;
revoke all on function public.get_messageable_founder_ids() from anon;
grant execute on function public.get_messageable_founder_ids() to authenticated;
revoke all on function public.get_or_create_direct_conversation(uuid) from public;
revoke all on function public.get_or_create_direct_conversation(uuid) from anon;
grant execute on function public.get_or_create_direct_conversation(uuid) to authenticated;
