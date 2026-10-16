alter table public.notifications
  add column if not exists task_id uuid references public.workspace_tasks(id) on delete cascade,
  add column if not exists deadline_date date;

alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check
  check (type = any (array[
    'follow','like','comment','message','mention',
    'collaboration_request','collaboration_accepted','collaboration_declined',
    'workspace_created','workspace_updated','task_assigned','task_updated',
    'project_message','task_due_soon','task_overdue'
  ]));

create unique index if not exists notifications_deadline_once_per_task_date_idx
  on public.notifications (recipient_id, task_id, type, deadline_date)
  where task_id is not null and type in ('task_due_soon','task_overdue');

create or replace function public.sync_workspace_deadline_notifications(p_workspace_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_inserted integer := 0;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1
    from public.collaboration_workspaces w
    join public.collaboration_requests cr on cr.id = w.collaboration_request_id
    where w.id = p_workspace_id
      and cr.status = 'accepted'
      and v_user_id in (cr.requester_id, cr.recipient_id)
  ) then
    raise exception 'Workspace access denied';
  end if;

  delete from public.notifications n
  using public.workspace_tasks t
  where n.task_id = t.id
    and t.workspace_id = p_workspace_id
    and n.recipient_id = v_user_id
    and n.type in ('task_due_soon','task_overdue')
    and (t.due_date is null or n.deadline_date is distinct from t.due_date);

  insert into public.notifications
    (recipient_id, actor_id, type, workspace_id, collaboration_request_id, task_id, deadline_date)
  select
    v_user_id,
    null,
    case when t.due_date < current_date then 'task_overdue' else 'task_due_soon' end,
    w.id,
    w.collaboration_request_id,
    t.id,
    t.due_date
  from public.workspace_tasks t
  join public.collaboration_workspaces w on w.id = t.workspace_id
  where t.workspace_id = p_workspace_id
    and t.status <> 'done'
    and t.due_date is not null
    and t.due_date <= current_date + 3
  on conflict (recipient_id, task_id, type, deadline_date)
    where task_id is not null and type in ('task_due_soon','task_overdue')
    do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

revoke all on function public.sync_workspace_deadline_notifications(uuid) from public;
revoke all on function public.sync_workspace_deadline_notifications(uuid) from anon;
grant execute on function public.sync_workspace_deadline_notifications(uuid) to authenticated;
