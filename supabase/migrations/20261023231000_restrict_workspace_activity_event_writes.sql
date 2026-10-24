-- Workspace activity is an audit trail. Do not let browser clients forge or rewrite events.
revoke insert, update, delete on table public.workspace_activity_events from anon, authenticated;