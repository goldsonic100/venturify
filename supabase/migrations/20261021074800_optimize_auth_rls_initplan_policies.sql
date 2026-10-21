-- Evaluate auth.uid() once per statement in frequently used RLS policies.
-- Predicates and role boundaries are preserved; only the evaluation shape changes.
DROP POLICY IF EXISTS "Users can block accounts as themselves" ON public.user_blocks;
CREATE POLICY "Users can block accounts as themselves"
ON public.user_blocks AS PERMISSIVE FOR INSERT TO authenticated
WITH CHECK ((SELECT auth.uid()) = blocker_id);

DROP POLICY IF EXISTS "Users can unblock accounts as themselves" ON public.user_blocks;
CREATE POLICY "Users can unblock accounts as themselves"
ON public.user_blocks AS PERMISSIVE FOR DELETE TO authenticated
USING ((SELECT auth.uid()) = blocker_id);

DROP POLICY IF EXISTS "Users can view blocks involving them" ON public.user_blocks;
CREATE POLICY "Users can view blocks involving them"
ON public.user_blocks AS PERMISSIVE FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = blocker_id OR (SELECT auth.uid()) = blocked_id);

DROP POLICY IF EXISTS "Users can submit reports as themselves" ON public.content_reports;
CREATE POLICY "Users can submit reports as themselves"
ON public.content_reports AS PERMISSIVE FOR INSERT TO authenticated
WITH CHECK ((SELECT auth.uid()) = reporter_id);

DROP POLICY IF EXISTS "Users can view their own reports" ON public.content_reports;
CREATE POLICY "Users can view their own reports"
ON public.content_reports AS PERMISSIVE FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = reporter_id);

DROP POLICY IF EXISTS "Requesters can withdraw pending collaboration requests" ON public.collaboration_requests;
CREATE POLICY "Requesters can withdraw pending collaboration requests"
ON public.collaboration_requests AS PERMISSIVE FOR DELETE TO authenticated
USING ((SELECT auth.uid()) = requester_id AND status = 'pending');

DROP POLICY IF EXISTS "Workspace collaborators can delete tasks" ON public.workspace_tasks;
CREATE POLICY "Workspace collaborators can delete tasks"
ON public.workspace_tasks AS PERMISSIVE FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.collaboration_workspaces w
    JOIN public.collaboration_requests r ON r.id = w.collaboration_request_id
    WHERE w.id = workspace_tasks.workspace_id
      AND r.status = 'accepted'
      AND ((SELECT auth.uid()) = r.requester_id OR (SELECT auth.uid()) = r.recipient_id)
  )
);

DROP POLICY IF EXISTS "Accepted workspace collaborators can add milestones" ON public.workspace_milestones;
CREATE POLICY "Accepted workspace collaborators can add milestones"
ON public.workspace_milestones AS PERMISSIVE FOR INSERT TO authenticated
WITH CHECK (
  created_by = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.collaboration_workspaces w
    JOIN public.collaboration_requests r ON r.id = w.collaboration_request_id
    WHERE w.id = workspace_milestones.workspace_id
      AND r.status = 'accepted'
      AND ((SELECT auth.uid()) = r.requester_id OR (SELECT auth.uid()) = r.recipient_id)
  )
);

DROP POLICY IF EXISTS "Accepted workspace collaborators can delete milestones" ON public.workspace_milestones;
CREATE POLICY "Accepted workspace collaborators can delete milestones"
ON public.workspace_milestones AS PERMISSIVE FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.collaboration_workspaces w
    JOIN public.collaboration_requests r ON r.id = w.collaboration_request_id
    WHERE w.id = workspace_milestones.workspace_id
      AND r.status = 'accepted'
      AND ((SELECT auth.uid()) = r.requester_id OR (SELECT auth.uid()) = r.recipient_id)
  )
);

DROP POLICY IF EXISTS "Accepted workspace collaborators can update milestones" ON public.workspace_milestones;
CREATE POLICY "Accepted workspace collaborators can update milestones"
ON public.workspace_milestones AS PERMISSIVE FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.collaboration_workspaces w
    JOIN public.collaboration_requests r ON r.id = w.collaboration_request_id
    WHERE w.id = workspace_milestones.workspace_id
      AND r.status = 'accepted'
      AND ((SELECT auth.uid()) = r.requester_id OR (SELECT auth.uid()) = r.recipient_id)
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.collaboration_workspaces w
    JOIN public.collaboration_requests r ON r.id = w.collaboration_request_id
    WHERE w.id = workspace_milestones.workspace_id
      AND r.status = 'accepted'
      AND ((SELECT auth.uid()) = r.requester_id OR (SELECT auth.uid()) = r.recipient_id)
  )
);

DROP POLICY IF EXISTS "Accepted workspace collaborators can view milestones" ON public.workspace_milestones;
CREATE POLICY "Accepted workspace collaborators can view milestones"
ON public.workspace_milestones AS PERMISSIVE FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.collaboration_workspaces w
    JOIN public.collaboration_requests r ON r.id = w.collaboration_request_id
    WHERE w.id = workspace_milestones.workspace_id
      AND r.status = 'accepted'
      AND ((SELECT auth.uid()) = r.requester_id OR (SELECT auth.uid()) = r.recipient_id)
  )
);
