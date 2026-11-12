-- Enforce block and pending-request rules for proposal discussions at the database layer.
-- Existing permissive participant policies remain in place; these restrictive policies
-- ensure neither participant can bypass a block through a direct API request or realtime.
create or replace function private.can_access_pending_collaboration_discussion(p_request_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.collaboration_requests r
    where r.id = p_request_id
      and r.status = 'pending'
      and (select auth.uid()) in (r.requester_id, r.recipient_id)
      and not exists (
        select 1
        from public.user_blocks b
        where (b.blocker_id = r.requester_id and b.blocked_id = r.recipient_id)
           or (b.blocker_id = r.recipient_id and b.blocked_id = r.requester_id)
      )
  );
$function$;

revoke all on function private.can_access_pending_collaboration_discussion(uuid) from public, anon;
grant execute on function private.can_access_pending_collaboration_discussion(uuid) to authenticated;

drop policy if exists "Proposal discussion block and status restriction: select" on public.collaboration_request_messages;
create policy "Proposal discussion block and status restriction: select"
on public.collaboration_request_messages
as restrictive
for select
to authenticated
using (private.can_access_pending_collaboration_discussion(request_id));

drop policy if exists "Proposal discussion block and status restriction: insert" on public.collaboration_request_messages;
create policy "Proposal discussion block and status restriction: insert"
on public.collaboration_request_messages
as restrictive
for insert
to authenticated
with check (private.can_access_pending_collaboration_discussion(request_id));

create or replace function private.guard_collaboration_request_message()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $function$
begin
  if new.sender_id is distinct from (select auth.uid())
     or not private.can_access_pending_collaboration_discussion(new.request_id) then
    raise exception 'This proposal discussion is unavailable'
      using errcode = '42501';
  end if;
  return new;
end;
$function$;

revoke all on function private.guard_collaboration_request_message() from public, anon, authenticated;
