-- Match the statement-level auth UID evaluation used by the other workspace RLS policies.
DROP POLICY IF EXISTS "Accepted collaborators can view workspace activity" ON public.workspace_activity_events;
CREATE POLICY "Accepted collaborators can view workspace activity"
ON public.workspace_activity_events AS PERMISSIVE FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.collaboration_workspaces w
    JOIN public.collaboration_requests r ON r.id = w.collaboration_request_id
    WHERE w.id = workspace_activity_events.workspace_id
      AND r.status = 'accepted'
      AND ((SELECT auth.uid()) = r.requester_id OR (SELECT auth.uid()) = r.recipient_id)
  )
);
