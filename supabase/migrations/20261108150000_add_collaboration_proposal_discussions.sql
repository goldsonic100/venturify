-- Private, append-only discussion messages for pending collaboration proposals.
create table if not exists public.collaboration_request_messages (
 id uuid primary key default gen_random_uuid(),
 request_id uuid not null references public.collaboration_requests(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 message text not null check (length(btrim(message)) between 1 and 500),
 created_at timestamptz not null default now()
);
create index if not exists collaboration_request_messages_request_created_idx on public.collaboration_request_messages(request_id,created_at);
alter table public.collaboration_request_messages enable row level security;
revoke all on table public.collaboration_request_messages from anon,authenticated;
grant select,insert on table public.collaboration_request_messages to authenticated;
drop policy if exists "Participants can read pending collaboration discussions" on public.collaboration_request_messages;
create policy "Participants can read pending collaboration discussions" on public.collaboration_request_messages for select to authenticated using (
 exists(select 1 from public.collaboration_requests r where r.id=request_id and (select auth.uid()) in (r.requester_id,r.recipient_id))
);
drop policy if exists "Participants can write pending collaboration discussions" on public.collaboration_request_messages;
create policy "Participants can write pending collaboration discussions" on public.collaboration_request_messages for insert to authenticated with check (
 sender_id=(select auth.uid()) and exists(select 1 from public.collaboration_requests r where r.id=request_id and r.status='pending' and (select auth.uid()) in (r.requester_id,r.recipient_id))
);
create or replace function private.guard_collaboration_request_message()
returns trigger language plpgsql security invoker set search_path=''
as $function$
begin
 if new.sender_id is distinct from (select auth.uid()) or not exists(select 1 from public.collaboration_requests r where r.id=new.request_id and r.status='pending' and (select auth.uid()) in (r.requester_id,r.recipient_id)) then
  raise exception 'Only proposal participants may discuss a pending collaboration request';
 end if;
 return new;
end;
$function$;
drop trigger if exists guard_collaboration_request_message on public.collaboration_request_messages;
create trigger guard_collaboration_request_message before insert on public.collaboration_request_messages for each row execute function private.guard_collaboration_request_message();
revoke all on function private.guard_collaboration_request_message() from public,anon,authenticated;
-- Notify the other participant when a proposal discussion message is added.
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check check (type = any (array['follow','like','comment','message','mention','collaboration_request','collaboration_accepted','collaboration_declined','workspace_created','workspace_updated','task_assigned','task_updated','project_message','task_due_soon','task_overdue','collaboration_message']::text[]));
create or replace function private.notify_collaboration_request_message()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare recipient uuid;
begin
 select case when r.requester_id=new.sender_id then r.recipient_id else r.requester_id end into recipient from public.collaboration_requests r where r.id=new.request_id and r.status='pending' and new.sender_id in (r.requester_id,r.recipient_id);
 if recipient is not null and recipient<>new.sender_id then
  insert into public.notifications(recipient_id,actor_id,type,collaboration_request_id) values(recipient,new.sender_id,'collaboration_message',new.request_id);
 end if;
 return new;
end;
$function$;
drop trigger if exists notify_collaboration_request_message on public.collaboration_request_messages;
create trigger notify_collaboration_request_message after insert on public.collaboration_request_messages for each row execute function private.notify_collaboration_request_message();
revoke all on function private.notify_collaboration_request_message() from public,anon,authenticated;
-- Enable realtime for open negotiation threads without duplicating publication membership.
do $publication$
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='collaboration_request_messages') then
  alter publication supabase_realtime add table public.collaboration_request_messages;
 end if;
end;
$publication$;
