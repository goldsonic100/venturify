-- Make workspace task deletion match the existing UI and keep blocks enforced server-side.
CREATE POLICY "Workspace collaborators can delete tasks"
ON public.workspace_tasks
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.collaboration_workspaces w
    JOIN public.collaboration_requests r ON r.id = w.collaboration_request_id
    WHERE w.id = workspace_tasks.workspace_id
      AND r.status = 'accepted'
      AND auth.uid() IN (r.requester_id, r.recipient_id)
  )
);

CREATE OR REPLACE FUNCTION private.guard_collaboration_request_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.user_blocks b
    WHERE (b.blocker_id = NEW.requester_id AND b.blocked_id = NEW.recipient_id)
       OR (b.blocker_id = NEW.recipient_id AND b.blocked_id = NEW.requester_id)
  ) THEN
    RAISE EXCEPTION 'Collaboration requests are unavailable between these accounts'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.guard_collaboration_request_insert() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS guard_collaboration_request_insert ON public.collaboration_requests;
CREATE TRIGGER guard_collaboration_request_insert
BEFORE INSERT ON public.collaboration_requests
FOR EACH ROW
EXECUTE FUNCTION private.guard_collaboration_request_insert();
