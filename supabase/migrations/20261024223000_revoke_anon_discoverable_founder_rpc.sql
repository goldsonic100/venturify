-- Keep founder discovery available to signed-in users only.
-- Anonymous visitors may browse public pages, but should not call this
-- SECURITY DEFINER RPC directly to enumerate eligible founder IDs.
REVOKE EXECUTE ON FUNCTION public.get_discoverable_founder_ids() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_discoverable_founder_ids() TO authenticated, service_role;
