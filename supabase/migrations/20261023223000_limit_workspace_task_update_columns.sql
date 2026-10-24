-- Collaborators may edit task details, but cannot reassign identity or ownership.
revoke update on table public.workspace_tasks from authenticated;
grant update (title, details, status, assigned_to, due_date, milestone_id, priority, labels)
on table public.workspace_tasks to authenticated;