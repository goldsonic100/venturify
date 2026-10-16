create or replace function private.notify_workspace_task_activity()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
 req record;
 actor uuid;
 recipient uuid;
 collab_id uuid;
begin
 actor := coalesce((select auth.uid()), new.created_by);

 select r.requester_id, r.recipient_id, r.id
 into req
 from public.collaboration_workspaces w
 join public.collaboration_requests r on r.id = w.collaboration_request_id
 where w.id = new.workspace_id and r.status = 'accepted';

 if not found then
  return new;
 end if;

 collab_id := req.id;

 if tg_op = 'INSERT' then
  if new.assigned_to is not null and new.assigned_to <> actor then
   insert into public.notifications(recipient_id, actor_id, type, workspace_id, collaboration_request_id, task_id)
   values(new.assigned_to, actor, 'task_assigned', new.workspace_id, collab_id, new.id);
  else
   recipient := case when req.requester_id = actor then req.recipient_id else req.requester_id end;
   if recipient is distinct from actor then
    insert into public.notifications(recipient_id, actor_id, type, workspace_id, collaboration_request_id, task_id)
    values(recipient, actor, 'task_updated', new.workspace_id, collab_id, new.id);
   end if;
  end if;
 elsif tg_op = 'UPDATE' then
  if new.assigned_to is distinct from old.assigned_to
     and new.assigned_to is not null
     and new.assigned_to <> actor then
   insert into public.notifications(recipient_id, actor_id, type, workspace_id, collaboration_request_id, task_id)
   values(new.assigned_to, actor, 'task_assigned', new.workspace_id, collab_id, new.id);
  end if;

  if new.status is distinct from old.status
     or new.title is distinct from old.title
     or new.details is distinct from old.details
     or new.due_date is distinct from old.due_date then
   recipient := case when req.requester_id = actor then req.recipient_id else req.requester_id end;
   if recipient is distinct from actor
      and recipient is distinct from new.assigned_to then
    insert into public.notifications(recipient_id, actor_id, type, workspace_id, collaboration_request_id, task_id)
    values(recipient, actor, 'task_updated', new.workspace_id, collab_id, new.id);
   elsif recipient is distinct from actor
      and new.assigned_to is not distinct from old.assigned_to then
    insert into public.notifications(recipient_id, actor_id, type, workspace_id, collaboration_request_id, task_id)
    values(recipient, actor, 'task_updated', new.workspace_id, collab_id, new.id);
   end if;
  end if;
 end if;

 return new;
end;
$function$;
