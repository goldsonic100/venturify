-- Keep direct-message metadata and creation behind the same block boundary as message content.
-- This migration does not alter existing messages or remove conversation history.

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
    raise exception 'You must be signed in to start a conversation.';
  end if;

  if target_user_id is null or target_user_id = current_user_id then
    raise exception 'Choose another founder to message.';
  end if;

  if not exists (select 1 from public.profiles p where p.id = target_user_id) then
    raise exception 'That founder profile could not be found.';
  end if;

  if exists (
    select 1
    from public.user_blocks b
    where (b.blocker_id = current_user_id and b.blocked_id = target_user_id)
       or (b.blocked_id = current_user_id and b.blocker_id = target_user_id)
  ) then
    raise exception 'Messaging is unavailable because one of these accounts has blocked the other.'
      using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      least(current_user_id::text, target_user_id::text) || ':' ||
      greatest(current_user_id::text, target_user_id::text),
      0
    )
  );

  select c.id
    into conversation_id
  from public.conversations c
  join public.conversation_members mine
    on mine.conversation_id = c.id and mine.user_id = current_user_id
  join public.conversation_members theirs
    on theirs.conversation_id = c.id and theirs.user_id = target_user_id
  where (select count(*) from public.conversation_members cm where cm.conversation_id = c.id) = 2
  order by c.created_at asc
  limit 1;

  if conversation_id is null then
    insert into public.conversations default values
      returning id into conversation_id;
    insert into public.conversation_members (conversation_id, user_id)
      values (conversation_id, current_user_id), (conversation_id, target_user_id);
  end if;

  return conversation_id;
end;
$function$;

revoke all on function public.get_or_create_direct_conversation(uuid) from public, anon;
grant execute on function public.get_or_create_direct_conversation(uuid) to authenticated;

-- Restrictive policies combine with the existing membership policies using AND.
drop policy if exists "Blocked accounts cannot view conversation metadata" on public.conversations;
create policy "Blocked accounts cannot view conversation metadata"
on public.conversations as restrictive for select to authenticated
using (not private.is_conversation_blocked(id));

drop policy if exists "Blocked accounts cannot view conversation membership metadata" on public.conversation_members;
create policy "Blocked accounts cannot view conversation membership metadata"
on public.conversation_members as restrictive for select to authenticated
using (not private.is_conversation_blocked(conversation_id));

drop policy if exists "Blocked accounts cannot view message read receipts" on public.message_reads;
create policy "Blocked accounts cannot view message read receipts"
on public.message_reads as restrictive for select to authenticated
using (
  not private.is_conversation_blocked((
    select m.conversation_id from public.messages m where m.id = message_reads.message_id
  ))
);

drop policy if exists "Blocked accounts cannot create message read receipts" on public.message_reads;
create policy "Blocked accounts cannot create message read receipts"
on public.message_reads as restrictive for insert to authenticated
with check (
  not private.is_conversation_blocked((
    select m.conversation_id from public.messages m where m.id = message_reads.message_id
  ))
);

drop policy if exists "Blocked accounts cannot view conversation typing metadata" on public.conversation_typing;
create policy "Blocked accounts cannot view conversation typing metadata"
on public.conversation_typing as restrictive for select to authenticated
using (not private.is_conversation_blocked(conversation_id));

drop policy if exists "Blocked accounts cannot publish conversation typing metadata" on public.conversation_typing;
create policy "Blocked accounts cannot publish conversation typing metadata"
on public.conversation_typing as restrictive for insert to authenticated
with check (not private.is_conversation_blocked(conversation_id));

drop policy if exists "Blocked accounts cannot update conversation typing metadata" on public.conversation_typing;
create policy "Blocked accounts cannot update conversation typing metadata"
on public.conversation_typing as restrictive for update to authenticated
using (not private.is_conversation_blocked(conversation_id))
with check (not private.is_conversation_blocked(conversation_id));

drop policy if exists "Blocked accounts cannot delete conversation typing metadata" on public.conversation_typing;
create policy "Blocked accounts cannot delete conversation typing metadata"
on public.conversation_typing as restrictive for delete to authenticated
using (not private.is_conversation_blocked(conversation_id));
