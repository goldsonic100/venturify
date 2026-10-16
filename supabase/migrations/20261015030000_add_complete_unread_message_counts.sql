-- Return complete unread-message totals for the signed-in user's conversations.
-- SECURITY INVOKER preserves existing table RLS.
create or replace function public.get_my_unread_message_counts()
returns table (conversation_id uuid, unread_count bigint)
language sql
stable
set search_path = ''
as $function$
  select m.conversation_id, count(*)::bigint as unread_count
  from public.messages m
  where m.sender_id <> (select auth.uid())
    and private.is_conversation_member(m.conversation_id)
    and not exists (
      select 1
      from public.message_reads mr
      where mr.message_id = m.id
        and mr.user_id = (select auth.uid())
    )
  group by m.conversation_id;
$function$;

revoke all on function public.get_my_unread_message_counts() from public, anon;
grant execute on function public.get_my_unread_message_counts() to authenticated;
