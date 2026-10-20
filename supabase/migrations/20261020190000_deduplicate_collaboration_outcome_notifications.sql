-- The existing private.notify_collaboration_request_activity trigger already creates
-- accepted/declined notifications. This trigger only creates the workspace.
CREATE OR REPLACE FUNCTION public.handle_collaboration_request_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  workspace_uuid uuid;
BEGIN
  IF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    INSERT INTO public.collaboration_workspaces (collaboration_request_id, created_by, title, goal)
    VALUES (NEW.id, NEW.recipient_id, 'Collaboration project', '')
    ON CONFLICT (collaboration_request_id) DO NOTHING;

    SELECT w.id INTO workspace_uuid
    FROM public.collaboration_workspaces AS w
    WHERE w.collaboration_request_id = NEW.id;

    IF workspace_uuid IS NOT NULL THEN
      INSERT INTO public.notifications (recipient_id, actor_id, type, collaboration_request_id, workspace_id)
      VALUES (NEW.requester_id, NEW.recipient_id, 'workspace_created', NEW.id, workspace_uuid);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_collaboration_request_status_change() FROM PUBLIC, anon, authenticated;
