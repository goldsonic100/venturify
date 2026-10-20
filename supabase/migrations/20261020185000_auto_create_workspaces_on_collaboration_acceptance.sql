-- Turn accepted collaboration requests into private workspaces and emit outcome notifications server-side.
-- SECURITY DEFINER is limited to this trigger path; clients cannot forge workspace notifications.
CREATE OR REPLACE FUNCTION public.handle_collaboration_request_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  workspace_uuid uuid;
BEGIN
  IF OLD.status = 'pending' AND NEW.status IN ('accepted', 'declined') THEN
    INSERT INTO public.notifications (recipient_id, actor_id, type, collaboration_request_id)
    VALUES (NEW.requester_id, NEW.recipient_id, CASE WHEN NEW.status = 'accepted' THEN 'collaboration_accepted' ELSE 'collaboration_declined' END, NEW.id);

    IF NEW.status = 'accepted' THEN
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
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_collaboration_request_status_change() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS collaboration_request_status_change ON public.collaboration_requests;
CREATE TRIGGER collaboration_request_status_change
AFTER UPDATE OF status ON public.collaboration_requests
FOR EACH ROW
EXECUTE FUNCTION public.handle_collaboration_request_status_change();
