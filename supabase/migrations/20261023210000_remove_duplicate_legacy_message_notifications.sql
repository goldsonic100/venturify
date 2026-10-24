-- Remove the legacy message notification trigger. The newer conversation-aware
-- trigger stores conversation_id and checks blocks; keeping both created duplicate
-- notifications for every message.
drop trigger if exists venturify_notify_message on public.messages;
