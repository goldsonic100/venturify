-- Allow founders to send and respond to collaboration requests with participant-only access.
create table if not exists public.collaboration_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  message text not null default '',
  status text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint collaboration_requests_not_self check (requester_id <> recipient_id)
);

create index if not exists collaboration_requests_recipient_status_created_idx
  on public.collaboration_requests (recipient_id, status, created_at desc);
create index if not exists collaboration_requests_requester_created_idx
  on public.collaboration_requests (requester_id, created_at desc);

create unique index if not exists collaboration_requests_one_pending_pair_idx
  on public.collaboration_requests (requester_id, recipient_id)
  where status = 'pending';

alter table public.collaboration_requests enable row level security;

revoke all on table public.collaboration_requests from anon, authenticated;
grant select, insert, update on table public.collaboration_requests to authenticated;

drop policy if exists "Participants can read collaboration requests" on public.collaboration_requests;
create policy "Participants can read collaboration requests"
on public.collaboration_requests for select to authenticated
using ((select auth.uid()) = requester_id or (select auth.uid()) = recipient_id);

drop policy if exists "Users can request collaboration" on public.collaboration_requests;
create policy "Users can request collaboration"
on public.collaboration_requests for insert to authenticated
with check (
  (select auth.uid()) = requester_id
  and requester_id <> recipient_id
  and status = 'pending'
  and length(message) <= 500
);

drop policy if exists "Recipients can respond to collaboration requests" on public.collaboration_requests;
create policy "Recipients can respond to collaboration requests"
on public.collaboration_requests for update to authenticated
using ((select auth.uid()) = recipient_id and status = 'pending')
with check (
  (select auth.uid()) = recipient_id
  and status in ('accepted','declined')
);

create or replace function private.guard_collaboration_request_update()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $function$
begin
  if new.id is distinct from old.id
     or new.requester_id is distinct from old.requester_id
     or new.recipient_id is distinct from old.recipient_id
     or new.message is distinct from old.message
     or new.created_at is distinct from old.created_at
     or old.status <> 'pending'
     or new.status not in ('accepted','declined') then
    raise exception 'Only the recipient may accept or decline a pending collaboration request';
  end if;
  new.updated_at := now();
  return new;
end;
$function$;

drop trigger if exists guard_collaboration_request_update on public.collaboration_requests;
create trigger guard_collaboration_request_update
before update on public.collaboration_requests
for each row execute function private.guard_collaboration_request_update();

revoke all on function private.guard_collaboration_request_update() from public, anon, authenticated;
