-- Notifications are created by trusted server-side flows. Clients may only
-- change the read marker on notifications they are authorized to update via RLS.
REVOKE UPDATE ON TABLE public.notifications FROM anon, authenticated;
GRANT UPDATE (read_at) ON TABLE public.notifications TO authenticated;
