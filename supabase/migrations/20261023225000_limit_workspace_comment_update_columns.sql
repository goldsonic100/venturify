-- Comment edits should change content and timestamp only, not authorship or parent linkage.
revoke update on table public.workspace_task_comments from authenticated;
grant update (content, updated_at)
on table public.workspace_task_comments to authenticated;