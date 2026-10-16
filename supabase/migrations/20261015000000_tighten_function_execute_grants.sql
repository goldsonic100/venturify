-- Restrict direct RPC access to privileged functions.
-- The activity-notification function is invoked by table triggers, so clients do not
-- need permission to call it directly.
revoke all on function public.create_activity_notification() from public, anon, authenticated;

-- Poll totals are available to signed-in users only; anonymous clients should not
-- be able to call this SECURITY DEFINER function to bypass table RLS.
revoke all on function public.get_poll_results(uuid[]) from public, anon;
grant execute on function public.get_poll_results(uuid[]) to authenticated;
