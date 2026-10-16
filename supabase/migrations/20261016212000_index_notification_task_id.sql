create index if not exists notifications_task_id_idx
  on public.notifications (task_id)
  where task_id is not null;