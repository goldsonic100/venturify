-- Venturify messaging: durable read receipts and typing status.
-- Applied to Supabase project edyssdvytwdvpqkmalow.

create table if not exists public.message_reads (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create index if not exists message_reads_user_read_at_idx
  on public.message_reads (user_id, read_at desc);

alter table public.message_reads enable row level security;

drop policy if exists "Conversation members can view message read receipts" on public.message_reads;
create policy "Conversation members can view message read receipts"
  on public.message_reads for select to authenticated
  using (
    exists (
      select 1 from public.messages m
      where m.id = message_reads.message_id
        and private.is_conversation_member(m.conversation_id)
    )
  );

drop policy if exists "Recipients can mark messages as read" on public.message_reads;
create policy "Recipients can mark messages as read"
  on public.message_reads for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.messages m
      where m.id = message_reads.message_id
        and m.sender_id <> (select auth.uid())
        and private.is_conversation_member(m.conversation_id)
    )
  );

create table if not exists public.conversation_typing (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  updated_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create index if not exists conversation_typing_updated_at_idx
  on public.conversation_typing (updated_at desc);

alter table public.conversation_typing enable row level security;

drop policy if exists "Conversation members can view typing status" on public.conversation_typing;
create policy "Conversation members can view typing status"
  on public.conversation_typing for select to authenticated
  using (private.is_conversation_member(conversation_id));

drop policy if exists "Members can publish their own typing status" on public.conversation_typing;
create policy "Members can publish their own typing status"
  on public.conversation_typing for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and private.is_conversation_member(conversation_id)
  );

drop policy if exists "Members can update their own typing status" on public.conversation_typing;
create policy "Members can update their own typing status"
  on public.conversation_typing for update to authenticated
  using (user_id = (select auth.uid()) and private.is_conversation_member(conversation_id))
  with check (user_id = (select auth.uid()) and private.is_conversation_member(conversation_id));

drop policy if exists "Members can delete their own typing status" on public.conversation_typing;
create policy "Members can delete their own typing status"
  on public.conversation_typing for delete to authenticated
  using (user_id = (select auth.uid()) and private.is_conversation_member(conversation_id));

grant select, insert on public.message_reads to authenticated;
grant select, insert, update, delete on public.conversation_typing to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'message_reads'
  ) then
    alter publication supabase_realtime add table public.message_reads;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'conversation_typing'
  ) then
    alter publication supabase_realtime add table public.conversation_typing;
  end if;
end $$;
