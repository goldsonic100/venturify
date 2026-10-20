-- Workspace activity notifications use the existing notification center.
-- Trigger functions run with a fixed search_path and never accept client-supplied recipients.

create or replace function public.notify_workspace_task_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  actor uuid := coalesce(auth.uid(), case when TG_OP = 'DELETE' then OLD.created_by else NEW.created_by end);
  wid uuid;
  task_id_value uuid;
  task_title text;
  assigned_value uuid;
  due_value date;
  req record;
  recipient uuid;
  notification_type text;
begin
  if TG_OP = 'DELETE' then
    wid := OLD.workspace_id; task_id_value := OLD.id; task_title := OLD.title;
    assigned_value := OLD.assigned_to; due_value := OLD.due_date;
  else
    wid := NEW.workspace_id; task_id_value := NEW.id; task_title := NEW.title;
    assigned_value := NEW.assigned_to; due_value := NEW.due_date;
  end if;

  select r.requester_id, r.recipient_id into req
  from public.collaboration_workspaces w
  join public.collaboration_requests r on r.id = w.collaboration_request_id
  where w.id = wid and r.status = 'accepted';

  if not found then
    return case when TG_OP = 'DELETE' then OLD else NEW end;
  end if;

  if TG_OP = 'INSERT' then
    if assigned_value is not null and assigned_value <> actor then
      insert into public.notifications(recipient_id, actor_id, type, workspace_id, task_id, deadline_date)
      values (assigned_value, actor, 'task_assigned', wid, task_id_value, due_value);
    end if;
  elsif TG_OP = 'UPDATE' then
    if NEW.assigned_to is distinct from OLD.assigned_to and NEW.assigned_to is not null and NEW.assigned_to <> actor then
      insert into public.notifications(recipient_id, actor_id, type, workspace_id, task_id, deadline_date)
      values (NEW.assigned_to, actor, 'task_assigned', wid, task_id_value, NEW.due_date);
    end if;

    if (NEW.title is distinct from OLD.title
        or NEW.status is distinct from OLD.status
        or NEW.due_date is distinct from OLD.due_date
        or NEW.details is distinct from OLD.details
        or NEW.milestone_id is distinct from OLD.milestone_id)
       and (NEW.assigned_to is not distinct from OLD.assigned_to) then
      recipient := case when req.requester_id = actor then req.recipient_id else req.requester_id end;
      if recipient is not null and recipient <> actor then
        insert into public.notifications(recipient_id, actor_id, type, workspace_id, task_id, deadline_date)
        values (recipient, actor, 'task_updated', wid, task_id_value, NEW.due_date);
      end if;
    end if;
  end if;

  return case when TG_OP = 'DELETE' then OLD else NEW end;
end;
$$;
revoke all on function public.notify_workspace_task_change() from public, anon, authenticated;

drop trigger if exists workspace_task_notifications on public.workspace_tasks;
create trigger workspace_task_notifications
after insert or update on public.workspace_tasks
for each row execute function public.notify_workspace_task_change();

create or replace function public.notify_workspace_message()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  req record;
  recipient uuid;
begin
  select r.requester_id, r.recipient_id into req
  from public.collaboration_workspaces w
  join public.collaboration_requests r on r.id = w.collaboration_request_id
  where w.id = NEW.workspace_id and r.status = 'accepted';

  if not found then return NEW; end if;
  recipient := case when req.requester_id = NEW.sender_id then req.recipient_id else req.requester_id end;

  if recipient is not null and recipient <> NEW.sender_id then
    insert into public.notifications(recipient_id, actor_id, type, workspace_id)
    values (recipient, NEW.sender_id, 'project_message', NEW.workspace_id);
  end if;
  return NEW;
end;
$$;
revoke all on function public.notify_workspace_message() from public, anon, authenticated;

drop trigger if exists workspace_message_notifications on public.workspace_messages;
create trigger workspace_message_notifications
after insert on public.workspace_messages
for each row execute function public.notify_workspace_message();

create index if not exists notifications_workspace_unread_idx
on public.notifications(recipient_id, created_at desc)
where read_at is null and workspace_id is not null;
