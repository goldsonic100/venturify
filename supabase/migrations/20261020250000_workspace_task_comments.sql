create table if not exists public.workspace_task_comments (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.collaboration_workspaces(id) on delete cascade,
  task_id uuid not null references public.workspace_tasks(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(btrim(content)) between 1 and 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workspace_task_comments_task_workspace_check
    check (workspace_id is not null)
);

create index if not exists workspace_task_comments_workspace_task_created_idx
  on public.workspace_task_comments (workspace_id, task_id, created_at);

alter table public.workspace_task_comments enable row level security;

drop policy if exists "Workspace collaborators can read task comments" on public.workspace_task_comments;
create policy "Workspace collaborators can read task comments"
on public.workspace_task_comments for select to authenticated
using (
  exists (
    select 1
    from public.collaboration_workspaces w
    join public.collaboration_requests cr on cr.id = w.collaboration_request_id
    join public.workspace_tasks t on t.id = workspace_task_comments.task_id and t.workspace_id = w.id
    where w.id = workspace_task_comments.workspace_id
      and cr.status = 'accepted'
      and (select auth.uid()) in (cr.requester_id, cr.recipient_id)
  )
);

drop policy if exists "Workspace collaborators can add task comments" on public.workspace_task_comments;
create policy "Workspace collaborators can add task comments"
on public.workspace_task_comments for insert to authenticated
with check (
  author_id = (select auth.uid())
  and exists (
    select 1
    from public.collaboration_workspaces w
    join public.collaboration_requests cr on cr.id = w.collaboration_request_id
    join public.workspace_tasks t on t.id = workspace_task_comments.task_id and t.workspace_id = w.id
    where w.id = workspace_task_comments.workspace_id
      and cr.status = 'accepted'
      and (select auth.uid()) in (cr.requester_id, cr.recipient_id)
  )
);

drop policy if exists "Authors can edit their own task comments" on public.workspace_task_comments;
create policy "Authors can edit their own task comments"
on public.workspace_task_comments for update to authenticated
using (author_id = (select auth.uid()))
with check (
  author_id = (select auth.uid())
  and exists (
    select 1
    from public.collaboration_workspaces w
    join public.collaboration_requests cr on cr.id = w.collaboration_request_id
    join public.workspace_tasks t on t.id = workspace_task_comments.task_id and t.workspace_id = w.id
    where w.id = workspace_task_comments.workspace_id
      and cr.status = 'accepted'
      and (select auth.uid()) in (cr.requester_id, cr.recipient_id)
  )
);

drop policy if exists "Authors can delete their own task comments" on public.workspace_task_comments;
create policy "Authors can delete their own task comments"
on public.workspace_task_comments for delete to authenticated
using (
  author_id = (select auth.uid())
  and exists (
    select 1
    from public.collaboration_workspaces w
    join public.collaboration_requests cr on cr.id = w.collaboration_request_id
    join public.workspace_tasks t on t.id = workspace_task_comments.task_id and t.workspace_id = w.id
    where w.id = workspace_task_comments.workspace_id
      and cr.status = 'accepted'
      and (select auth.uid()) in (cr.requester_id, cr.recipient_id)
  )
);

grant select, insert, update, delete on public.workspace_task_comments to authenticated;