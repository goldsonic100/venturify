-- Attach collaboration context to notifications so clicks can open the right place.
alter table public.notifications
 add column if not exists workspace_id uuid references public.collaboration_workspaces(id) on delete cascade,
 add column if not exists collaboration_request_id uuid references public.collaboration_requests(id) on delete cascade;
create index if not exists notifications_workspace_id_idx on public.notifications(workspace_id) where workspace_id is not null;
create index if not exists notifications_collaboration_request_id_idx on public.notifications(collaboration_request_id) where collaboration_request_id is not null;

create or replace function private.notify_collaboration_request_activity()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
 if tg_op='INSERT' then
  if new.requester_id <> new.recipient_id then
   insert into public.notifications(recipient_id,actor_id,type,collaboration_request_id) values(new.recipient_id,new.requester_id,'collaboration_request',new.id);
  end if;
 elsif tg_op='UPDATE' and old.status is distinct from new.status then
  if new.status in ('accepted','declined') and new.requester_id <> new.recipient_id then
   insert into public.notifications(recipient_id,actor_id,type,collaboration_request_id) values(new.requester_id,new.recipient_id,case when new.status='accepted' then 'collaboration_accepted' else 'collaboration_declined' end,new.id);
  end if;
 end if;
 return new;
end;
$function$;
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
  if req.requester_id <> actor then insert into public.notifications(recipient_id,actor_id,type,workspace_id,collaboration_request_id) values(req.requester_id,actor,'workspace_created',new.id,new.collaboration_request_id); end if;
  if req.recipient_id <> actor then insert into public.notifications(recipient_id,actor_id,type,workspace_id,collaboration_request_id) values(req.recipient_id,actor,'workspace_created',new.id,new.collaboration_request_id); end if;
 elsif tg_op='UPDATE' and (old.title is distinct from new.title or old.goal is distinct from new.goal) then
  if req.requester_id <> actor then insert into public.notifications(recipient_id,actor_id,type,workspace_id,collaboration_request_id) values(req.requester_id,actor,'workspace_updated',new.id,new.collaboration_request_id); end if;
  if req.recipient_id <> actor then insert into public.notifications(recipient_id,actor_id,type,workspace_id,collaboration_request_id) values(req.recipient_id,actor,'workspace_updated',new.id,new.collaboration_request_id); end if;
 end if;
 return new;
end;
$function$;
revoke all on function private.notify_workspace_activity() from public,anon,authenticated;

create or replace function private.notify_workspace_task_activity()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare req record; actor uuid; recipient uuid; collab_id uuid;
begin
 actor:=coalesce((select auth.uid()),new.created_by);
 select r.requester_id,r.recipient_id,r.id into req from public.collaboration_workspaces w join public.collaboration_requests r on r.id=w.collaboration_request_id where w.id=new.workspace_id and r.status='accepted';
 if not found then return new; end if;
 collab_id:=req.id;
 if tg_op='INSERT' then
  if new.assigned_to is not null and new.assigned_to <> actor then
   insert into public.notifications(recipient_id,actor_id,type,workspace_id,collaboration_request_id) values(new.assigned_to,actor,'task_assigned',new.workspace_id,collab_id);
  else
   recipient:=case when req.requester_id=actor then req.recipient_id else req.requester_id end;
   if recipient is distinct from actor then insert into public.notifications(recipient_id,actor_id,type,workspace_id,collaboration_request_id) values(recipient,actor,'task_updated',new.workspace_id,collab_id); end if;
  end if;
 elsif tg_op='UPDATE' then
  if new.assigned_to is distinct from old.assigned_to and new.assigned_to is not null and new.assigned_to <> actor then
   insert into public.notifications(recipient_id,actor_id,type,workspace_id,collaboration_request_id) values(new.assigned_to,actor,'task_assigned',new.workspace_id,collab_id);
  end if;
  if new.status is distinct from old.status or new.title is distinct from old.title or new.details is distinct from old.details then
   recipient:=case when req.requester_id=actor then req.recipient_id else req.requester_id end;
   if recipient is distinct from actor then insert into public.notifications(recipient_id,actor_id,type,workspace_id,collaboration_request_id) values(recipient,actor,'task_updated',new.workspace_id,collab_id); end if;
  end if;
 end if;
 return new;
end;
$function$;
revoke all on function private.notify_workspace_task_activity() from public,anon,authenticated;
