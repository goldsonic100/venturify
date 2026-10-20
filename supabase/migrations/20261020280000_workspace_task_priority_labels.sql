alter table public.workspace_tasks
  add column if not exists priority text not null default 'medium',
  add column if not exists labels text not null default '';

alter table public.workspace_tasks
  drop constraint if exists workspace_tasks_priority_check;
alter table public.workspace_tasks
  add constraint workspace_tasks_priority_check
  check (priority in ('low','medium','high','urgent'));

create index if not exists workspace_tasks_workspace_priority_idx
  on public.workspace_tasks (workspace_id, priority);

comment on column public.workspace_tasks.priority is 'Collaboration task priority: low, medium, high, urgent.';
comment on column public.workspace_tasks.labels is 'Comma-separated collaboration task labels, maximum 160 characters.';