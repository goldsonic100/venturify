-- Consolidate collaboration task notifications and allow completion event types.
-- One task trigger owns task notifications so collaborators don't receive duplicates.

alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check check (
    type = any (array[
      'follow','like','comment','message','mention',
      'collaboration_request','collaboration_accepted','collaboration_declined',
      'workspace_created','workspace_updated','task_assigned','task_updated',
      'project_message','task_due_soon','task_overdue','task_comment',
      'task_completed','checklist_completed'
    ]::text[])
  );

create or replace function public.notify_workspace_task_changes()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid;
  v_request record;
  v_partner uuid;
  v_type text;
  v_task_changed boolean := false;
  v_assignment_changed boolean := false;
begin
  v_actor := coalesce(auth.uid(), new.created_by);

  select r.requester_id, r.recipient_id, r.id
    into v_request
  from public.collaboration_workspaces w
  join public.collaboration_requests r on r.id = w.collaboration_request_id
  where w.id = new.workspace_id
    and r.status = 'accepted'
  limit 1;

  if not found or v_actor is null
     or (v_actor <> v_request.requester_id and v_actor <> v_request.recipient_id) then
    return new;
  end if;

  v_partner := case
    when v_actor = v_request.requester_id then v_request.recipient_id
    else v_request.requester_id
  end;

  if tg_op = 'INSERT' then
    if new.assigned_to is not null and new.assigned_to <> v_actor then
      insert into public.notifications
        (recipient_id, actor_id, type, workspace_id, collaboration_request_id, task_id, deadline_date)
      values
        (new.assigned_to, v_actor, 'task_assigned', new.workspace_id, v_request.id, new.id, new.due_date);
    elsif v_partner is not null and v_partner <> v_actor then
      insert into public.notifications
        (recipient_id, actor_id, type, workspace_id, collaboration_request_id, task_id, deadline_date)
      values
        (v_partner, v_actor, 'task_updated', new.workspace_id, v_request.id, new.id, new.due_date);
    end if;
    return new;
  end if;

  v_assignment_changed := new.assigned_to is distinct from old.assigned_to;
  v_task_changed :=
       new.status is distinct from old.status
    or new.title is distinct from old.title
    or new.details is distinct from old.details
    or new.due_date is distinct from old.due_date
    or new.milestone_id is distinct from old.milestone_id
    or v_assignment_changed;

  if v_assignment_changed
     and new.assigned_to is not null
     and new.assigned_to <> v_actor
     and new.assigned_to in (v_request.requester_id, v_request.recipient_id) then
    insert into public.notifications
      (recipient_id, actor_id, type, workspace_id, collaboration_request_id, task_id, deadline_date)
    values
      (new.assigned_to, v_actor, 'task_assigned', new.workspace_id, v_request.id, new.id, new.due_date);
  end if;

  if v_task_changed and v_partner is not null and v_partner <> v_actor
     and (not v_assignment_changed or v_partner is distinct from new.assigned_to) then
    v_type := case
      when new.status is distinct from old.status and new.status = 'done' then 'task_completed'
      else 'task_updated'
    end;
    insert into public.notifications
      (recipient_id, actor_id, type, workspace_id, collaboration_request_id, task_id, deadline_date)
    values
      (v_partner, v_actor, v_type, new.workspace_id, v_request.id, new.id, new.due_date);
  end if;

  return new;
end;
$$;

revoke all on function public.notify_workspace_task_changes() from public, anon, authenticated;

-- These older triggers overlap with the canonical notification trigger above.
drop trigger if exists notify_workspace_task_activity on public.workspace_tasks;
drop trigger if exists workspace_task_notifications on public.workspace_tasks;

-- Ensure exactly one canonical task notification trigger exists.
drop trigger if exists workspace_task_change_notifications on public.workspace_tasks;
create trigger workspace_task_change_notifications
after insert or update on public.workspace_tasks
for each row execute function public.notify_workspace_task_changes();

-- The checklist completion trigger remains the single source of checklist-complete notices.
revoke all on function public.notify_workspace_checklist_completion() from public, anon, authenticated;
