-- Keep task-comment identity and timestamps server-controlled.
CREATE OR REPLACE FUNCTION public.set_workspace_task_comment_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
BEGIN
  NEW.updated_at := pg_catalog.now();
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.set_workspace_task_comment_updated_at() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS workspace_task_comment_set_updated_at ON public.workspace_task_comments;
CREATE TRIGGER workspace_task_comment_set_updated_at
BEFORE UPDATE ON public.workspace_task_comments
FOR EACH ROW
EXECUTE FUNCTION public.set_workspace_task_comment_updated_at();

REVOKE UPDATE ON TABLE public.workspace_task_comments FROM anon, authenticated;
GRANT UPDATE (content) ON TABLE public.workspace_task_comments TO authenticated;
