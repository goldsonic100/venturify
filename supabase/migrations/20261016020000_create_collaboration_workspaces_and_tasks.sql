-- Shared project workspaces and task tracking for accepted collaboration requests.
create table if not exists public.collaboration_workspaces (
  id uuid primary key default gen_random_uuid(),
  collaboration_request_id uuid not null unique references public.collaboration_requests(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 120),
  goal text not null default '' check (length(goal) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.workspace_tasks (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.collaboration_workspaces(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 180),
  details text not null default '' check (length(details) <= 2000),
  status text not null default 'todo' check (status in ('todo','in_progress','done')),
  assigned_to uuid references public.profiles(id) on delete set null,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists workspace_tasks_workspace_created_idx on public.workspace_tasks(workspace_id, created_at desc);
alter table public.collaboration_workspaces enable row level security;
alter table public.workspace_tasks enable row level security;
revoke all on table public.collaboration_workspaces from anon, authenticated;
revoke all on table public.workspace_tasks from anon, authenticated;
grant select, insert, update on table public.collaboration_workspaces to authenticated;
grant select, insert, update on table public.workspace_tasks to authenticated;
create policy "Accepted collaborators can view workspaces" on public.collaboration_workspaces for select to authenticated using (exists(select 1 from public.collaboration_requests r where r.id=collaboration_request_id and r.status='accepted' and ((select auth.uid())=r.requester_id or (select auth.uid())=r.recipient_id)));
create policy "Accepted collaborators can create workspaces" on public.collaboration_workspaces for insert to authenticated with check (created_by=(select auth.uid()) and exists(select 1 from public.collaboration_requests r where r.id=collaboration_request_id and r.status='accepted' and ((select auth.uid())=r.requester_id or (select auth.uid())=r.recipient_id)));
create policy "Accepted collaborators can update workspaces" on public.collaboration_workspaces for update to authenticated using (exists(select 1 from public.collaboration_requests r where r.id=collaboration_request_id and r.status='accepted' and ((select auth.uid())=r.requester_id or (select auth.uid())=r.recipient_id))) with check (exists(select 1 from public.collaboration_requests r where r.id=collaboration_request_id and r.status='accepted' and ((select auth.uid())=r.requester_id or (select auth.uid())=r.recipient_id)));
create policy "Workspace collaborators can view tasks" on public.workspace_tasks for select to authenticated using (exists(select 1 from public.collaboration_workspaces w join public.collaboration_requests r on r.id=w.collaboration_request_id where w.id=workspace_id and r.status='accepted' and ((select auth.uid())=r.requester_id or (select auth.uid())=r.recipient_id)));
create policy "Workspace collaborators can add tasks" on public.workspace_tasks for insert to authenticated with check (created_by=(select auth.uid()) and exists(select 1 from public.collaboration_workspaces w join public.collaboration_requests r on r.id=w.collaboration_request_id where w.id=workspace_id and r.status='accepted' and ((select auth.uid())=r.requester_id or (select auth.uid())=r.recipient_id)));
create policy "Workspace collaborators can update tasks" on public.workspace_tasks for update to authenticated using (exists(select 1 from public.collaboration_workspaces w join public.collaboration_requests r on r.id=w.collaboration_request_id where w.id=workspace_id and r.status='accepted' and ((select auth.uid())=r.requester_id or (select auth.uid())=r.recipient_id))) with check (exists(select 1 from public.collaboration_workspaces w join public.collaboration_requests r on r.id=w.collaboration_request_id where w.id=workspace_id and r.status='accepted' and ((select auth.uid())=r.requester_id or (select auth.uid())=r.recipient_id)));
create or replace function private.guard_workspace_task_update() returns trigger language plpgsql security invoker set search_path='' as $function$
begin
 if new.id is distinct from old.id or new.workspace_id is distinct from old.workspace_id or new.created_by is distinct from old.created_by or new.created_at is distinct from old.created_at then raise exception 'Workspace task identity fields cannot be changed'; end if;
 new.updated_at:=now(); return new;
end;
$function$;
create trigger guard_workspace_task_update before update on public.workspace_tasks for each row execute function private.guard_workspace_task_update();
revoke all on function private.guard_workspace_task_update() from public, anon, authenticated;
