-- Group creation accepts participant IDs directly, so enforce the same
-- email-verification eligibility used by the message recipient picker.
create or replace function public.create_group_conversation(group_title text, participant_ids uuid[])
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  current_user_id uuid := auth.uid();
  member_ids uuid[];
  new_conversation_id uuid;
  member_count integer;
begin
  if current_user_id is null then
    raise exception 'You must be signed in to create a group chat.' using errcode = '42501';
  end if;
  if group_title is null or pg_catalog.length(pg_catalog.btrim(group_title)) < 2 or pg_catalog.length(pg_catalog.btrim(group_title)) > 80 then
    raise exception 'Group name must be between 2 and 80 characters.' using errcode = '22023';
  end if;

  select pg_catalog.array_agg(x order by x) into member_ids
  from (
    select distinct unnest(coalesce(participant_ids, array[]::uuid[])) as x
    union select current_user_id
  ) ids;
  member_count := coalesce(pg_catalog.cardinality(member_ids), 0);
  if member_count < 3 or member_count > 20 then
    raise exception 'Group chats must have 3 to 20 members, including you.' using errcode = '22023';
  end if;
  if exists (
    select 1 from pg_catalog.unnest(member_ids) as candidate(user_id)
    where not exists (select 1 from public.profiles p where p.id = candidate.user_id)
  ) then
    raise exception 'One or more selected founder profiles could not be found.' using errcode = '22023';
  end if;
  if exists (
    select 1 from pg_catalog.unnest(member_ids) as candidate(user_id)
    where not exists (
      select 1 from auth.users au
      where au.id = candidate.user_id and au.email_confirmed_at is not null
    )
  ) then
    raise exception 'Every group member must verify their account before joining a group chat.' using errcode = '42501';
  end if;
  if exists (
    select 1 from public.user_blocks b
    where b.blocker_id = any(member_ids) and b.blocked_id = any(member_ids)
  ) then
    raise exception 'A group chat cannot include members who have blocked one another.' using errcode = '42501';
  end if;
  if exists (
    select 1
    from pg_catalog.unnest(member_ids) as candidate(user_id)
    where candidate.user_id <> current_user_id
      and not coalesce(
        (select s.public_dms from public.account_settings s where s.user_id = candidate.user_id),
        true
      )
      and not exists (
        select 1
        from public.follows f
        where f.follower_id = candidate.user_id
          and f.following_id = current_user_id
      )
  ) then
    raise exception 'One or more founders only accept messages from founders who follow them. They must follow you before you can add them to a group chat.' using errcode = '42501';
  end if;

  insert into public.conversations (is_group, title, created_by)
  values (true, pg_catalog.btrim(group_title), current_user_id)
  returning id into new_conversation_id;
  insert into public.conversation_members (conversation_id, user_id)
  select new_conversation_id, member_id
  from pg_catalog.unnest(member_ids) as members(member_id);
  return new_conversation_id;
end;
$function$;

revoke all on function public.create_group_conversation(text, uuid[]) from public;
revoke all on function public.create_group_conversation(text, uuid[]) from anon;
grant execute on function public.create_group_conversation(text, uuid[]) to authenticated;
