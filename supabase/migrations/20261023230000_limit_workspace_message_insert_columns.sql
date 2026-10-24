-- Message identity and timestamps are server-managed; clients supply only message content and scope.
revoke insert on table public.workspace_messages from authenticated;
grant insert (workspace_id, sender_id, content)
on table public.workspace_messages to authenticated;