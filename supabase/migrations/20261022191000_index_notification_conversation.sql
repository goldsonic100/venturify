-- Support the conversation foreign key and lookups by conversation.
create index if not exists notifications_conversation_id_idx
  on public.notifications (conversation_id)
  where conversation_id is not null;
