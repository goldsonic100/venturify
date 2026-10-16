-- Add notifications for collaboration requests, workspace creation/updates, and task activity.
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
check (type = any (array['follow','like','comment','message','mention','collaboration_request','collaboration_accepted','collaboration_declined','workspace_created','workspace_updated','task_assigned','task_updated']::text[]));

create or replace function private.notify_collaboration_request_activity()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
 if tg_op='INSERT' then
  if new.requester_id <> new.recipient_id then
   insert into public.notifications(recipient_id,actor_id,type) values(new.recipient_id,new.requester_id,'collaboration_request');
  end if;
 elsif tg_op='UPDATE' and old.status is distinct from new.status then
  if new.status in ('accepted','declined') and new.requester_id <> new.recipient_id then
   insert into public.notifications(recipient_id,actor_id,type) values(new.requester_id,new.recipient_id,case when new.status='accepted' then 'collaboration_accepted' else 'collaboration_declined' end);
  end if;
 end if;
 return new;
end;
$function$;
drop trigger if exists notify_collaboration_request_activity on public.collaboration_requests;
create trigger notify_collaboration_request_activity after insert or update of status on public.collaboration_requests for each row execute function private.notify_collaboration_request_activity();
revoke all on function private.notify_collaboration_request_activity() from public,anon,authenticated;

create or replace function private.notify_workspace_activity()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare req record; actor uuid;
begin
 actor:=coalesce((select auth.uid()),new.created_by);
 select r.requester_id,r.recipient_id into req from public.collaboration_requests r where r.id=new.collaboration_request_id and r.status='accepted';
 if not found then return new; end if;
 if tg_op='INSERT' then
  if req.requester_id <> actor then insert into public.notifications(recipient_id,actor_id,type) values(req.requester_id,actor,'workspace_created'); end if;
  if req.recipient_id <> actor then insert into public.notifications(recipient_id,actor_id,type) values(req.recipient_id,actor,'workspace_created'); end if;
 elsif tg_op='UPDATE' and (old.title is distinct from new.title or old.goal is distinct from new.goal) then
  if req.requester_id <> actor then insert into public.notifications(recipient_id,actor_id,type) values(req.requester_id,actor,'workspace_updated'); end if;
  if req.recipient_id <> actor then insert into public.notifications(recipient_id,actor_id,type) values(req.recipient_id,actor,'workspace_updated'); end if;
 end if;
 return new;
end;
$function$;
drop trigger if exists notify_workspace_activity on public.collaboration_workspaces;
create trigger notify_workspace_activity after insert or update of title,goal on public.collaboration_workspaces for each row execute function private.notify_workspace_activity();
revoke all on function private.notify_workspace_activity() from public,anon,authenticated;

create or replace function private.notify_workspace_task_activity()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare req record; actor uuid; recipient uuid;
begin
 actor:=coalesce((select auth.uid()),new.created_by);
 select r.requester_id,r.recipient_id into req from public.collaboration_workspaces w join public.collaboration_requests r on r.id=w.collaboration_request_id where w.id=new.workspace_id and r.status='accepted';
 if not found then return new; end if;
 if tg_op='INSERT' then
  if new.assigned_to is not null and new.assigned_to <> actor then
   insert into public.notifications(recipient_id,actor_id,type) values(new.assigned_to,actor,'task_assigned');
  else
   recipient:=case when req.requester_id=actor then req.recipient_id else req.requester_id end;
   if recipient is distinct from actor then insert into public.notifications(recipient_id,actor_id,type) values(recipient,actor,'task_updated'); end if;
  end if;
 elsif tg_op='UPDATE' then
  if new.assigned_to is distinct from old.assigned_to and new.assigned_to is not null and new.assigned_to <> actor then
   insert into public.notifications(recipient_id,actor_id,type) values(new.assigned_to,actor,'task_assigned');
  end if;
  if new.status is distinct from old.status then
   recipient:=case when req.requester_id=actor then req.recipient_id else req.requester_id end;
   if recipient is distinct from actor then insert into public.notifications(recipient_id,actor_id,type) values(recipient,actor,'task_updated'); end if;
  end if;
 end if;
 return new;
end;
$function$;
drop trigger if exists notify_workspace_task_activity on public.workspace_tasks;
create trigger notify_workspace_task_activity after insert or update of assigned_to,status,title,details on public.workspace_tasks for each row execute function private.notify_workspace_task_activity();
revoke all on function private.notify_workspace_task_activity() from public,anon,authenticated;
