-- Recipients only need to change a request's status and timestamp when
-- accepting or declining it. Prevent edits to requester_id, recipient_id,
-- message, primary key, and creation time through the Data API.
revoke update on table public.collaboration_requests from authenticated;
grant update (status, updated_at) on table public.collaboration_requests to authenticated;
