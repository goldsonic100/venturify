-- Prevent workspace tasks from being assigned to people outside the accepted collaboration.
-- This protects assignees and the notification trigger from arbitrary profile IDs.
create or replace function private.guard_workspace_task_assignee()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  requester uuid;
  recipient uuid;
begin
  if new.assigned_to is null then
    return new;
  end if;

  select r.requester_id, r.recipient_id
    into requester, recipient
  from public.collaboration_workspaces w
  join public.collaboration_requests r
    on r.id = w.collaboration_request_id
  where w.id = new.workspace_id
    and r.status = 'accepted';

  if not found then
    raise exception 'Workspace task requires an accepted collaboration'
      using errcode = '42501';
  end if;

  if new.assigned_to is distinct from requester
     and new.assigned_to is distinct from recipient then
    raise exception 'Workspace tasks can only be assigned to a collaborator'
      using errcode = '42501';
  end if;

  return new;
end;
$function$;

drop trigger if exists guard_workspace_task_assignee on public.workspace_tasks;
create trigger guard_workspace_task_assignee
before insert or update of assigned_to, workspace_id
on public.workspace_tasks
for each row
execute function private.guard_workspace_task_assignee();

revoke all on function private.guard_workspace_task_assignee() from public, anon, authenticated;
