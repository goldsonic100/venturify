-- Authorize private Realtime presence only for participants in accepted workspaces.
-- Topic format is venturify-workspace-presence:<workspace UUID>.
-- This migration is committed for review and is not applied to the live database by the PR.

alter table realtime.messages enable row level security;

drop policy if exists "Accepted collaborators can read workspace presence" on realtime.messages;
create policy "Accepted collaborators can read workspace presence"
on realtime.messages for select to authenticated
using (
  realtime.topic() ~ '^venturify-workspace-presence:[0-9a-fA-F-]{36}$'
  and exists (
    select 1
    from public.collaboration_workspaces w
    join public.collaboration_requests r on r.id = w.collaboration_request_id
    where w.id::text = split_part(realtime.topic(), ':', 2)
      and r.status = 'accepted'
      and ((select auth.uid()) = r.requester_id or (select auth.uid()) = r.recipient_id)
  )
);

drop policy if exists "Accepted collaborators can publish workspace presence" on realtime.messages;
create policy "Accepted collaborators can publish workspace presence"
on realtime.messages for insert to authenticated
with check (
  realtime.topic() ~ '^venturify-workspace-presence:[0-9a-fA-F-]{36}$'
  and exists (
    select 1
    from public.collaboration_workspaces w
    join public.collaboration_requests r on r.id = w.collaboration_request_id
    where w.id::text = split_part(realtime.topic(), ':', 2)
      and r.status = 'accepted'
      and ((select auth.uid()) = r.requester_id or (select auth.uid()) = r.recipient_id)
  )
);
