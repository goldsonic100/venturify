-- Message reactions are private to authenticated conversation members.
-- Remove broad default grants, then allow only the operations used by the UI.
REVOKE ALL PRIVILEGES ON TABLE public.message_reactions FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.message_reactions FROM authenticated;
GRANT SELECT, INSERT, DELETE ON TABLE public.message_reactions TO authenticated;
