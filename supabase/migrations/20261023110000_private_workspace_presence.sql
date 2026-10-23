-- Private Realtime Presence for accepted Venturify collaboration workspaces.
-- This migration is intentionally committed only; it is NOT applied to the live Supabase project.
-- The topic embeds the workspace UUID, and RLS validates current accepted membership.
drop policy if exists "Accepted collaborators can read workspace presence" on realtime.messages;
create policy "Accepted collaborators can read workspace presence"
on realtime.messages
for select
to authenticated
using (
  realtime.messages.extension = 'presence'
  and realtime.topic() like 'venturify-workspace-presence:%'
  and exists (
    select 1
    from public.collaboration_workspaces w
    join public.collaboration_requests r on r.id = w.collaboration_request_id
    where w.id = case
      when split_part(realtime.topic(), ':', 2) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then split_part(realtime.topic(), ':', 2)::uuid
      else null
    end
    and r.status = 'accepted'
    and ((select auth.uid()) = r.requester_id or (select auth.uid()) = r.recipient_id)
  )
);
drop policy if exists "Accepted collaborators can publish workspace presence" on realtime.messages;
create policy "Accepted collaborators can publish workspace presence"
on realtime.messages
for insert
to authenticated
with check (
  realtime.messages.extension = 'presence'
  and realtime.topic() like 'venturify-workspace-presence:%'
  and exists (
    select 1
    from public.collaboration_workspaces w
    join public.collaboration_requests r on r.id = w.collaboration_request_id
    where w.id = case
      when split_part(realtime.topic(), ':', 2) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then split_part(realtime.topic(), ':', 2)::uuid
      else null
    end
    and r.status = 'accepted'
    and ((select auth.uid()) = r.requester_id or (select auth.uid()) = r.recipient_id)
  )
);
