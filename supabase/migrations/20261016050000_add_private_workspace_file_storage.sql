-- Private storage for files shared inside accepted Venturify collaboration workspaces.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('workspace-files','workspace-files',false,10485760,array[
 'application/pdf','text/plain','text/markdown','image/png','image/jpeg','image/webp','image/gif',
 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
 'application/msword','application/vnd.ms-excel','application/vnd.ms-powerpoint'
])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "Workspace collaborators can view shared files" on storage.objects;
create policy "Workspace collaborators can view shared files" on storage.objects for select to authenticated
using (bucket_id='workspace-files' and exists (
 select 1 from public.collaboration_workspaces w join public.collaboration_requests r on r.id=w.collaboration_request_id
 where w.id::text=(storage.foldername(name))[1] and r.status='accepted'
 and ((select auth.uid())=r.requester_id or (select auth.uid())=r.recipient_id)
));

drop policy if exists "Workspace collaborators can upload shared files" on storage.objects;
create policy "Workspace collaborators can upload shared files" on storage.objects for insert to authenticated
with check (bucket_id='workspace-files' and exists (
 select 1 from public.collaboration_workspaces w join public.collaboration_requests r on r.id=w.collaboration_request_id
 where w.id::text=(storage.foldername(name))[1] and r.status='accepted'
 and ((select auth.uid())=r.requester_id or (select auth.uid())=r.recipient_id)
));

drop policy if exists "Uploaders can delete shared files" on storage.objects;
create policy "Uploaders can delete shared files" on storage.objects for delete to authenticated
using (bucket_id='workspace-files' and owner_id=(select auth.uid())::text and exists (
 select 1 from public.collaboration_workspaces w join public.collaboration_requests r on r.id=w.collaboration_request_id
 where w.id::text=(storage.foldername(name))[1] and r.status='accepted'
 and ((select auth.uid())=r.requester_id or (select auth.uid())=r.recipient_id)
));
