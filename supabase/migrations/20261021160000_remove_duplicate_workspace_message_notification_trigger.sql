-- A workspace message was notifying its recipient through two AFTER INSERT
-- triggers. Keep the richer private handler, which includes the collaboration
-- request ID, and remove the redundant legacy handler.
DROP TRIGGER IF EXISTS workspace_message_notifications
ON public.workspace_messages;
