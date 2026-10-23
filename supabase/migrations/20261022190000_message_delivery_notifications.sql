-- Message delivery notifications and conversation-aware notification links.
-- The trigger runs only after a message row has passed the existing message RLS checks.
alter table public.notifications
  add column if not exists conversation_id uuid
  references public.conversations(id) on delete cascade;

create index if not exists notifications_recipient_conversation_created_idx
  on public.notifications (recipient_id, conversation_id, created_at desc)
  where type = 'message';

create or replace function private.notify_conversation_message()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  -- Defense in depth: only create notifications for a message sent by its authenticated sender.
  if auth.uid() is not null and auth.uid() <> new.sender_id then
    return new;
  end if;

  if private.is_conversation_blocked(new.conversation_id) then
    return new;
  end if;

  insert into public.notifications (recipient_id, actor_id, type, conversation_id, created_at)
  select cm.user_id, new.sender_id, 'message', new.conversation_id, now()
  from public.conversation_members cm
  left join public.account_settings settings on settings.user_id = cm.user_id
  where cm.conversation_id = new.conversation_id
    and cm.user_id <> new.sender_id
    and coalesce(settings.notify_messages, true)
  on conflict do nothing;

  return new;
end;
$$;

revoke all on function private.notify_conversation_message() from public, anon, authenticated;

drop trigger if exists notify_conversation_message_after_insert on public.messages;
create trigger notify_conversation_message_after_insert
after insert on public.messages
for each row execute function private.notify_conversation_message();

do $realtime$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end
$realtime$;
