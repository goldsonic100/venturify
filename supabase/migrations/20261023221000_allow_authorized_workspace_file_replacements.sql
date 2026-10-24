-- Allow authorized collaborators to replace an existing file via Storage upsert.
-- The existing SELECT policy limits visibility to accepted collaborators; this UPDATE
-- policy additionally requires ownership and the workspace folder to match.
drop policy if exists "Workspace collaborators can replace shared files" on storage.objects;

create policy "Workspace collaborators can replace shared files"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'workspace-files'
  and owner_id = (select auth.uid())::text
  and exists (
    select 1
    from public.collaboration_workspaces w
    join public.collaboration_requests r on r.id = w.collaboration_request_id
    where w.id::text = (storage.foldername(objects.name))[1]
      and r.status = 'accepted'
      and ((select auth.uid()) = r.requester_id or (select auth.uid()) = r.recipient_id)
  )
)
with check (
  bucket_id = 'workspace-files'
  and owner_id = (select auth.uid())::text
  and exists (
    select 1
    from public.collaboration_workspaces w
    join public.collaboration_requests r on r.id = w.collaboration_request_id
    where w.id::text = (storage.foldername(objects.name))[1]
      and r.status = 'accepted'
      and ((select auth.uid()) = r.requester_id or (select auth.uid()) = r.recipient_id)
  )
);