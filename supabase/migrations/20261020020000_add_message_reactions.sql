-- Persistent per-user reactions on direct messages.
-- RLS limits reaction access to conversation members and respects user blocks.
create table if not exists public.message_reactions (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null check (reaction in ('❤️','😂','👍','😮','🎉','👀')),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, reaction)
);
create index if not exists message_reactions_message_idx on public.message_reactions (message_id, created_at asc);
alter table public.message_reactions enable row level security;

drop policy if exists "Conversation members can view message reactions" on public.message_reactions;
create policy "Conversation members can view message reactions"
on public.message_reactions for select to authenticated
using (exists (select 1 from public.messages m where m.id = message_reactions.message_id and private.is_conversation_member(m.conversation_id) and not private.is_conversation_blocked(m.conversation_id)));

drop policy if exists "Members can react as themselves" on public.message_reactions;
create policy "Members can react as themselves"
on public.message_reactions for insert to authenticated
with check (user_id = (select auth.uid()) and exists (select 1 from public.messages m where m.id = message_reactions.message_id and private.is_conversation_member(m.conversation_id) and not private.is_conversation_blocked(m.conversation_id)));

drop policy if exists "Users can remove their own message reactions" on public.message_reactions;
create policy "Users can remove their own message reactions"
on public.message_reactions for delete to authenticated
using (user_id = (select auth.uid()) and exists (select 1 from public.messages m where m.id = message_reactions.message_id and private.is_conversation_member(m.conversation_id) and not private.is_conversation_blocked(m.conversation_id)));

grant select, insert, delete on public.message_reactions to authenticated;

do $realtime$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'message_reactions'
  ) then
    alter publication supabase_realtime add table public.message_reactions;
  end if;
end $realtime$;
