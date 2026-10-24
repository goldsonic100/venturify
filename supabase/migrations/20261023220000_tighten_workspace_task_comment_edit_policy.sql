-- Keep task-comment edits limited to their author while the collaboration is accepted.
drop policy if exists "Authors can edit their own task comments" on public.workspace_task_comments;

create policy "Authors can edit their own task comments"
on public.workspace_task_comments
for update
to authenticated
using (
  author_id = (select auth.uid())
  and exists (
    select 1
    from public.collaboration_workspaces w
    join public.collaboration_requests cr on cr.id = w.collaboration_request_id
    join public.workspace_tasks t on t.id = workspace_task_comments.task_id
      and t.workspace_id = w.id
    where w.id = workspace_task_comments.workspace_id
      and cr.status = 'accepted'
      and ((select auth.uid()) = cr.requester_id or (select auth.uid()) = cr.recipient_id)
  )
)
with check (
  author_id = (select auth.uid())
  and exists (
    select 1
    from public.collaboration_workspaces w
    join public.collaboration_requests cr on cr.id = w.collaboration_request_id
    join public.workspace_tasks t on t.id = workspace_task_comments.task_id
      and t.workspace_id = w.id
    where w.id = workspace_task_comments.workspace_id
      and cr.status = 'accepted'
      and ((select auth.uid()) = cr.requester_id or (select auth.uid()) = cr.recipient_id)
  )
);