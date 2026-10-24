-- Workspace participants may edit project details, but must not be able to
-- rewrite ownership or reassign a workspace to another collaboration request.
revoke update on table public.collaboration_workspaces from authenticated;
grant update (title, goal) on table public.collaboration_workspaces to authenticated;
