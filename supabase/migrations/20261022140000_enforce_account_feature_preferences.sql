-- Enforce account feature and notification preferences in the database.
-- Existing accounts without settings rows keep the current enabled defaults.

create or replace function private.can_receive_collaboration_requests(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select s.allow_collaboration_requests
     from public.account_settings s
     where s.user_id = target_user_id),
    true
  );
$$;
revoke all on function private.can_receive_collaboration_requests(uuid) from public;
grant execute on function private.can_receive_collaboration_requests(uuid) to authenticated;

-- Feature preferences are restrictive guards: existing ownership and
-- membership policies remain in force and these checks add another condition.
drop policy if exists "Account preference guard: story publishing" on public.stories;
create policy "Account preference guard: story publishing"
  on public.stories as restrictive for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and coalesce(
      (select s.enable_story_posts from public.account_settings s where s.user_id = (select auth.uid())),
      true
    )
  );

drop policy if exists "Account preference guard: poll publishing" on public.posts;
create policy "Account preference guard: poll publishing"
  on public.posts as restrictive for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and (
      coalesce(post_type, 'standard') <> 'poll'
      or coalesce(
        (select s.enable_polls from public.account_settings s where s.user_id = (select auth.uid())),
        true
      )
    )
    and (
      coalesce(post_type, 'standard') not in ('idea', 'resource', 'lesson')
      or coalesce(
        (select s.enable_opportunities from public.account_settings s where s.user_id = (select auth.uid())),
        true
      )
    )
  );

drop policy if exists "Account preference guard: poll records" on public.post_polls;
create policy "Account preference guard: poll records"
  on public.post_polls as restrictive for insert to authenticated
  with check (
    exists (
      select 1 from public.posts p
      where p.id = post_polls.post_id
        and p.user_id = (select auth.uid())
        and coalesce(
          (select s.enable_polls from public.account_settings s where s.user_id = (select auth.uid())),
          true
        )
    )
  );

drop policy if exists "Account preference guard: collaboration requests" on public.collaboration_requests;
create policy "Account preference guard: collaboration requests"
  on public.collaboration_requests as restrictive for insert to authenticated
  with check (
    requester_id = (select auth.uid())
    and private.can_receive_collaboration_requests(recipient_id)
  );

-- Private accounts must not leak story or poll content through related tables.
drop policy if exists "Active stories are publicly readable" on public.stories;
create policy "Active stories respect account privacy"
  on public.stories for select to anon, authenticated
  using (
    expires_at > now()
    and (
      private.is_profile_public(user_id)
      or user_id = (select auth.uid())
      or exists (
        select 1 from public.follows f
        where f.follower_id = (select auth.uid()) and f.following_id = stories.user_id
      )
    )
  );

drop policy if exists "Polls are publicly readable" on public.post_polls;
create policy "Polls respect account privacy"
  on public.post_polls for select to anon, authenticated
  using (
    exists (
      select 1 from public.posts p
      where p.id = post_polls.post_id
        and (
          private.is_profile_public(p.user_id)
          or p.user_id = (select auth.uid())
          or exists (
            select 1 from public.follows f
            where f.follower_id = (select auth.uid()) and f.following_id = p.user_id
          )
        )
    )
  );

drop policy if exists "Poll options are publicly readable" on public.post_poll_options;
create policy "Poll options respect account privacy"
  on public.post_poll_options for select to anon, authenticated
  using (
    exists (
      select 1
      from public.post_polls pp
      join public.posts p on p.id = pp.post_id
      where pp.id = post_poll_options.poll_id
        and (
          private.is_profile_public(p.user_id)
          or p.user_id = (select auth.uid())
          or exists (
            select 1 from public.follows f
            where f.follower_id = (select auth.uid()) and f.following_id = p.user_id
          )
        )
    )
  );

-- Respect the recipient's message-notification preference.
create or replace function public.venturify_notify_message()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if auth.uid() is null or auth.uid() is distinct from new.sender_id then
    return new;
  end if;

  insert into public.notifications (recipient_id, actor_id, type)
  select cm.user_id, new.sender_id, 'message'
  from public.conversation_members cm
  left join public.account_settings s on s.user_id = cm.user_id
  where cm.conversation_id = new.conversation_id
    and cm.user_id <> new.sender_id
    and coalesce(s.notify_messages, true);
  return new;
end;
$function$;

create or replace function private.notify_message_reaction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  recipient uuid;
begin
  if auth.uid() is null or auth.uid() is distinct from new.user_id then
    return new;
  end if;

  select m.sender_id into recipient
  from public.messages m
  where m.id = new.message_id;

  if recipient is not null
     and recipient <> new.user_id
     and coalesce(
       (select s.notify_reactions from public.account_settings s where s.user_id = recipient),
       true
     ) then
    insert into public.notifications (recipient_id, actor_id, type)
    values (recipient, new.user_id, 'message_reaction');
  end if;
  return new;
end;
$function$;
revoke all on function private.notify_message_reaction() from public;

drop trigger if exists notify_message_reaction on public.message_reactions;
create trigger notify_message_reaction
  after insert on public.message_reactions
  for each row execute function private.notify_message_reaction();

create or replace function private.notify_group_chat_mentions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  mention_match text[];
  mentioned_username text;
  recipient uuid;
  seen_usernames text[] := array[]::text[];
begin
  if auth.uid() is null or auth.uid() is distinct from new.sender_id then
    return new;
  end if;

  if not exists (
    select 1 from public.conversations c
    where c.id = new.conversation_id and c.is_group = true
  ) then
    return new;
  end if;

  for mention_match in
    select regexp_matches(coalesce(new.content, ''), '@([A-Za-z0-9_]{1,30})', 'g')
  loop
    mentioned_username := lower(mention_match[1]);
    if mentioned_username = any(seen_usernames) then
      continue;
    end if;
    seen_usernames := array_append(seen_usernames, mentioned_username);

    select p.id into recipient
    from public.profiles p
    join public.conversation_members cm
      on cm.user_id = p.id and cm.conversation_id = new.conversation_id
    left join public.account_settings s on s.user_id = p.id
    where lower(p.username) = mentioned_username
      and p.id <> new.sender_id
      and coalesce(s.notify_group_mentions, true)
    limit 1;

    if recipient is not null then
      insert into public.notifications (recipient_id, actor_id, type)
      values (recipient, new.sender_id, 'group_mention');
    end if;
    recipient := null;
  end loop;
  return new;
end;
$function$;
revoke all on function private.notify_group_chat_mentions() from public;

drop trigger if exists notify_group_chat_mentions on public.messages;
create trigger notify_group_chat_mentions
  after insert on public.messages
  for each row execute function private.notify_group_chat_mentions();
