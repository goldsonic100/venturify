-- Keep workspace creation in this trigger, but let private.notify_workspace_activity
-- be the sole source of workspace_created notifications. This prevents duplicates.
CREATE OR REPLACE FUNCTION public.handle_collaboration_request_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    INSERT INTO public.collaboration_workspaces (collaboration_request_id, created_by, title, goal)
    VALUES (NEW.id, NEW.recipient_id, 'Collaboration project', '')
    ON CONFLICT (collaboration_request_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_collaboration_request_status_change() FROM PUBLIC, anon, authenticated;
