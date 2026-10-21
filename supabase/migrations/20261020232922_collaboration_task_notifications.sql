-- Collaboration task notifications: assignment, status changes, completion, and finished checklists.
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check check (type = any (array[
  'follow','like','comment','message','mention','collaboration_request','collaboration_accepted','collaboration_declined',
  'workspace_created','workspace_updated','task_assigned','task_updated','project_message','task_due_soon','task_overdue',
  'task_comment','task_completed','checklist_completed'
]::text[]));

create or replace function public.notify_workspace_task_changes()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid := auth.uid();
  v_recipient uuid;
  v_request public.collaboration_requests%rowtype;
begin
  if v_actor is null then
    return new;
  end if;

  select cr.* into v_request
  from public.collaboration_workspaces w
  join public.collaboration_requests cr on cr.id = w.collaboration_request_id
  where w.id = new.workspace_id and cr.status = 'accepted'
  limit 1;

  if not found or v_actor not in (v_request.requester_id, v_request.recipient_id) then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.assigned_to is not null
       and new.assigned_to <> v_actor
       and new.assigned_to in (v_request.requester_id, v_request.recipient_id) then
      insert into public.notifications
        (recipient_id, actor_id, type, workspace_id, collaboration_request_id, task_id)
      values
        (new.assigned_to, v_actor, 'task_assigned', new.workspace_id, v_request.id, new.id);
    end if;
    return new;
  end if;

  if new.assigned_to is distinct from old.assigned_to
     and new.assigned_to is not null
     and new.assigned_to <> v_actor
     and new.assigned_to in (v_request.requester_id, v_request.recipient_id) then
    insert into public.notifications
      (recipient_id, actor_id, type, workspace_id, collaboration_request_id, task_id)
    values
      (new.assigned_to, v_actor, 'task_assigned', new.workspace_id, v_request.id, new.id);
  end if;

  if new.status is distinct from old.status then
    if v_actor = v_request.requester_id then
      v_recipient := v_request.recipient_id;
    else
      v_recipient := v_request.requester_id;
    end if;
    if v_recipient is not null and v_recipient <> v_actor then
      insert into public.notifications
        (recipient_id, actor_id, type, workspace_id, collaboration_request_id, task_id)
      values
        (v_recipient, v_actor,
          case when new.status = 'done' then 'task_completed' else 'task_updated' end,
          new.workspace_id, v_request.id, new.id);
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.notify_workspace_task_changes() from public, anon, authenticated;
drop trigger if exists workspace_task_change_notifications on public.workspace_tasks;
create trigger workspace_task_change_notifications
after insert or update on public.workspace_tasks
for each row execute function public.notify_workspace_task_changes();

create or replace function public.notify_workspace_checklist_completion()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid := auth.uid();
  v_recipient uuid;
  v_request public.collaboration_requests%rowtype;
begin
  if tg_op <> 'UPDATE' or old.is_complete is true or new.is_complete is not true or v_actor is null then
    return new;
  end if;

  if exists (
    select 1 from public.workspace_task_checklist_items i
    where i.task_id = new.task_id and i.workspace_id = new.workspace_id and i.is_complete is false
  ) then
    return new;
  end if;

  select cr.* into v_request
  from public.collaboration_workspaces w
  join public.collaboration_requests cr on cr.id = w.collaboration_request_id
  where w.id = new.workspace_id and cr.status = 'accepted'
  limit 1;

  if not found or v_actor not in (v_request.requester_id, v_request.recipient_id) then
    return new;
  end if;

  if v_actor = v_request.requester_id then
    v_recipient := v_request.recipient_id;
  else
    v_recipient := v_request.requester_id;
  end if;

  if v_recipient is null or v_recipient = v_actor then
    return new;
  end if;

  -- Avoid duplicate completion notices if an item is toggled off and completed again shortly after.
  if exists (
    select 1 from public.notifications n
    where n.recipient_id = v_recipient
      and n.task_id = new.task_id
      and n.type = 'checklist_completed'
      and n.created_at > now() - interval '24 hours'
  ) then
    return new;
  end if;

  insert into public.notifications
    (recipient_id, actor_id, type, workspace_id, collaboration_request_id, task_id)
  values
    (v_recipient, v_actor, 'checklist_completed', new.workspace_id, v_request.id, new.task_id);

  return new;
end;
$$;

revoke all on function public.notify_workspace_checklist_completion() from public, anon, authenticated;
drop trigger if exists workspace_checklist_completion_notification on public.workspace_task_checklist_items;
create trigger workspace_checklist_completion_notification
after update of is_complete on public.workspace_task_checklist_items
for each row execute function public.notify_workspace_checklist_completion();
