-- Prevent clients from changing milestone ownership, workspace association, or identity.
revoke update on table public.workspace_milestones from authenticated;
grant update (title, description, target_date)
on table public.workspace_milestones to authenticated;