alter table public.workspace_tasks
  add column if not exists due_date date;

create index if not exists workspace_tasks_workspace_due_date_idx
  on public.workspace_tasks (workspace_id, due_date)
  where due_date is not null;
