-- Checklist metadata is immutable; collaborators can only edit item text or completion.
REVOKE UPDATE ON TABLE public.workspace_task_checklist_items FROM anon, authenticated;
GRANT UPDATE (title, is_complete) ON TABLE public.workspace_task_checklist_items TO authenticated;
