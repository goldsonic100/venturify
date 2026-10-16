-- Private chat for accepted collaboration workspaces.
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
check (type = any (array['follow','like','comment','message','mention','collaboration_request','collaboration_accepted','collaboration_declined','workspace_created','workspace_updated','task_assigned','task_updated','project_message']::text[]));

alter table public.notifications
 add column if not exists workspace_id uuid references public.collaboration_workspaces(id) on delete cascade,
 add column if not exists collaboration_request_id uuid references public.collaboration_requests(id) on delete cascade;
create index if not exists notifications_workspace_id_idx on public.notifications(workspace_id) where workspace_id is not null;
create index if not exists notifications_collaboration_request_id_idx on public.notifications(collaboration_request_id) where collaboration_request_id is not null;

create table if not exists public.workspace_messages (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.collaboration_workspaces(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 content text not null check (length(trim(content)) between 1 and 4000),
 created_at timestamptz not null default now()
);
create index if not exists workspace_messages_history_idx on public.workspace_messages(workspace_id, created_at desc);
alter table public.workspace_messages enable row level security;
revoke all on table public.workspace_messages from anon,authenticated;
grant select,insert on table public.workspace_messages to authenticated;
create policy "Accepted collaborators can read project chat" on public.workspace_messages for select to authenticated
using (exists(select 1 from public.collaboration_workspaces w join public.collaboration_requests r on r.id=w.collaboration_request_id where w.id=workspace_id and r.status='accepted' and ((select auth.uid())=r.requester_id or (select auth.uid())=r.recipient_id)));
create policy "Accepted collaborators can send project chat" on public.workspace_messages for insert to authenticated
with check (sender_id=(select auth.uid()) and exists(select 1 from public.collaboration_workspaces w join public.collaboration_requests r on r.id=w.collaboration_request_id where w.id=workspace_id and r.status='accepted' and ((select auth.uid())=r.requester_id or (select auth.uid())=r.recipient_id)));

create or replace function private.notify_project_chat_message()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare req record;
begin
 select r.requester_id,r.recipient_id,r.id into req
 from public.collaboration_workspaces w
 join public.collaboration_requests r on r.id=w.collaboration_request_id
 where w.id=new.workspace_id and r.status='accepted';
 if not found then return new; end if;
 if req.requester_id <> new.sender_id then
  insert into public.notifications(recipient_id,actor_id,type,workspace_id,collaboration_request_id)
  values(req.requester_id,new.sender_id,'project_message',new.workspace_id,req.id);
 end if;
 if req.recipient_id <> new.sender_id then
  insert into public.notifications(recipient_id,actor_id,type,workspace_id,collaboration_request_id)
  values(req.recipient_id,new.sender_id,'project_message',new.workspace_id,req.id);
 end if;
 return new;
end;
$function$;
drop trigger if exists notify_project_chat_message on public.workspace_messages;
create trigger notify_project_chat_message after insert on public.workspace_messages for each row execute function private.notify_project_chat_message();
revoke all on function private.notify_project_chat_message() from public,anon,authenticated;

do $publication$
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime')
 and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='workspace_messages') then
  alter publication supabase_realtime add table public.workspace_messages;
 end if;
end;
$publication$;
