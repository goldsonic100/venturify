create table if not exists public.workspace_milestones (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.collaboration_workspaces(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 140),
  description text not null default '' check (char_length(description) <= 1000),
  target_date date,
  created_at timestamptz not null default now()
);

alter table public.workspace_milestones enable row level security;
grant select, insert, update, delete on public.workspace_milestones to authenticated;

create policy "Accepted workspace collaborators can view milestones"
on public.workspace_milestones for select to authenticated
using (
  exists (
    select 1 from public.collaboration_workspaces w
    join public.collaboration_requests r on r.id = w.collaboration_request_id
    where w.id = workspace_milestones.workspace_id
      and r.status = 'accepted'
      and (auth.uid() = r.requester_id or auth.uid() = r.recipient_id)
  )
);

create policy "Accepted workspace collaborators can add milestones"
on public.workspace_milestones for insert to authenticated
with check (
  created_by = auth.uid()
  and exists (
    select 1 from public.collaboration_workspaces w
    join public.collaboration_requests r on r.id = w.collaboration_request_id
    where w.id = workspace_milestones.workspace_id
      and r.status = 'accepted'
      and (auth.uid() = r.requester_id or auth.uid() = r.recipient_id)
  )
);

create policy "Accepted workspace collaborators can update milestones"
on public.workspace_milestones for update to authenticated
using (
  exists (
    select 1 from public.collaboration_workspaces w
    join public.collaboration_requests r on r.id = w.collaboration_request_id
    where w.id = workspace_milestones.workspace_id
      and r.status = 'accepted'
      and (auth.uid() = r.requester_id or auth.uid() = r.recipient_id)
  )
)
with check (
  exists (
    select 1 from public.collaboration_workspaces w
    join public.collaboration_requests r on r.id = w.collaboration_request_id
    where w.id = workspace_milestones.workspace_id
      and r.status = 'accepted'
      and (auth.uid() = r.requester_id or auth.uid() = r.recipient_id)
  )
);

create policy "Accepted workspace collaborators can delete milestones"
on public.workspace_milestones for delete to authenticated
using (
  exists (
    select 1 from public.collaboration_workspaces w
    join public.collaboration_requests r on r.id = w.collaboration_request_id
    where w.id = workspace_milestones.workspace_id
      and r.status = 'accepted'
      and (auth.uid() = r.requester_id or auth.uid() = r.recipient_id)
  )
);

alter table public.workspace_tasks
  add column if not exists milestone_id uuid
  references public.workspace_milestones(id) on delete set null;

create index if not exists workspace_milestones_workspace_date_idx
  on public.workspace_milestones(workspace_id, target_date);
create index if not exists workspace_tasks_milestone_id_idx
  on public.workspace_tasks(milestone_id);
