-- Keep checklist item identity, parent task, workspace, and creator immutable to clients.
revoke update on table public.workspace_task_checklist_items from authenticated;
grant update (title, is_complete, position, updated_at)
on table public.workspace_task_checklist_items to authenticated;