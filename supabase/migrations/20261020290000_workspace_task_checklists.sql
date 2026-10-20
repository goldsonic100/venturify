-- Shared task checklist items, scoped to the same workspace/task and accepted collaborators.
alter table public.workspace_tasks
  add constraint workspace_tasks_id_workspace_unique unique (id, workspace_id);

create table if not exists public.workspace_task_checklist_items (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.collaboration_workspaces(id) on delete cascade,
  task_id uuid not null,
  title text not null check (char_length(btrim(title)) between 1 and 240),
  is_complete boolean not null default false,
  position integer not null default 0 check (position >= 0),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workspace_task_checklist_task_workspace_fk
    foreign key (task_id, workspace_id)
    references public.workspace_tasks(id, workspace_id) on delete cascade
);

create index if not exists workspace_task_checklist_task_position_idx
  on public.workspace_task_checklist_items (workspace_id, task_id, position, created_at);

alter table public.workspace_task_checklist_items enable row level security;

drop policy if exists "Accepted collaborators can view task checklist items" on public.workspace_task_checklist_items;
create policy "Accepted collaborators can view task checklist items"
on public.workspace_task_checklist_items for select to authenticated
using (
  exists (
    select 1 from public.collaboration_workspaces w
    join public.collaboration_requests cr on cr.id = w.collaboration_request_id
    where w.id = workspace_task_checklist_items.workspace_id
      and cr.status = 'accepted'
      and (select auth.uid()) in (cr.requester_id, cr.recipient_id)
  )
);

drop policy if exists "Accepted collaborators can add task checklist items" on public.workspace_task_checklist_items;
create policy "Accepted collaborators can add task checklist items"
on public.workspace_task_checklist_items for insert to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1 from public.collaboration_workspaces w
    join public.collaboration_requests cr on cr.id = w.collaboration_request_id
    where w.id = workspace_task_checklist_items.workspace_id
      and cr.status = 'accepted'
      and (select auth.uid()) in (cr.requester_id, cr.recipient_id)
  )
);

drop policy if exists "Accepted collaborators can update task checklist items" on public.workspace_task_checklist_items;
create policy "Accepted collaborators can update task checklist items"
on public.workspace_task_checklist_items for update to authenticated
using (
  exists (
    select 1 from public.collaboration_workspaces w
    join public.collaboration_requests cr on cr.id = w.collaboration_request_id
    where w.id = workspace_task_checklist_items.workspace_id
      and cr.status = 'accepted'
      and (select auth.uid()) in (cr.requester_id, cr.recipient_id)
  )
)
with check (
  exists (
    select 1 from public.collaboration_workspaces w
    join public.collaboration_requests cr on cr.id = w.collaboration_request_id
    where w.id = workspace_task_checklist_items.workspace_id
      and cr.status = 'accepted'
      and (select auth.uid()) in (cr.requester_id, cr.recipient_id)
  )
);

drop policy if exists "Accepted collaborators can delete task checklist items" on public.workspace_task_checklist_items;
create policy "Accepted collaborators can delete task checklist items"
on public.workspace_task_checklist_items for delete to authenticated
using (
  exists (
    select 1 from public.collaboration_workspaces w
    join public.collaboration_requests cr on cr.id = w.collaboration_request_id
    where w.id = workspace_task_checklist_items.workspace_id
      and cr.status = 'accepted'
      and (select auth.uid()) in (cr.requester_id, cr.recipient_id)
  )
);

grant select, insert, update, delete on public.workspace_task_checklist_items to authenticated;

-- Audit checklist changes into the existing immutable workspace activity stream.
create or replace function public.log_workspace_task_checklist_activity()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  row_data public.workspace_task_checklist_items;
  task_title text;
  action_type text;
  action_summary text;
  actor uuid := auth.uid();
begin
  if TG_OP = 'DELETE' then row_data := OLD; else row_data := NEW; end if;
  select t.title into task_title
  from public.workspace_tasks t
  where t.id = row_data.task_id and t.workspace_id = row_data.workspace_id;

  if TG_OP = 'INSERT' then
    action_type := 'checklist_item_added';
    action_summary := 'Added checklist item to ' || coalesce(task_title, 'task');
  elsif TG_OP = 'DELETE' then
    action_type := 'checklist_item_deleted';
    action_summary := 'Removed checklist item from ' || coalesce(task_title, 'task');
  elsif OLD.is_complete is distinct from NEW.is_complete then
    action_type := case when NEW.is_complete then 'checklist_item_completed' else 'checklist_item_reopened' end;
    action_summary := case when NEW.is_complete then 'Completed checklist item in ' else 'Reopened checklist item in ' end || coalesce(task_title, 'task');
  elsif OLD.title is distinct from NEW.title then
    action_type := 'checklist_item_renamed';
    action_summary := 'Renamed checklist item in ' || coalesce(task_title, 'task');
  else
    return NEW;
  end if;

  insert into public.workspace_activity_events
    (workspace_id, actor_id, event_type, entity_type, entity_id, summary, details)
  values
    (row_data.workspace_id, actor, action_type, 'task', row_data.task_id,
     left(action_summary, 240),
     jsonb_build_object('task_id', row_data.task_id, 'task_title', task_title,
                        'item_title', row_data.title, 'is_complete', row_data.is_complete));
  if TG_OP = 'DELETE' then return OLD; else return NEW; end if;
end;
$$;

revoke execute on function public.log_workspace_task_checklist_activity() from public, anon, authenticated;
drop trigger if exists workspace_task_checklist_activity_log on public.workspace_task_checklist_items;
create trigger workspace_task_checklist_activity_log
after insert or update or delete on public.workspace_task_checklist_items
for each row execute function public.log_workspace_task_checklist_activity();

-- Realtime is needed for both collaborators to see checklist changes without refreshing.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'workspace_task_checklist_items'
  ) then
    alter publication supabase_realtime add table public.workspace_task_checklist_items;
  end if;
end $$;