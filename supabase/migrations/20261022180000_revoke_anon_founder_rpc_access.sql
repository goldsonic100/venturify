-- These RPCs intentionally return discovery/messageable IDs to signed-in users only.
-- Keep authenticated access and service-role access intact; remove anonymous execution.
REVOKE EXECUTE ON FUNCTION public.get_discoverable_founder_ids() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_discoverable_founder_ids() TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.get_messageable_founder_ids() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_messageable_founder_ids() TO authenticated, service_role;
