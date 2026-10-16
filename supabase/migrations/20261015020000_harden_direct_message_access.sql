-- Harden direct-message access: restrict table grants and RPC exposure.
-- Limit direct-message table privileges to the operations the app actually uses.
-- RLS remains the row-level boundary; table grants prevent anonymous access and
-- avoid exposing unused UPDATE/DELETE/TRUNCATE paths.
revoke all on table public.conversations from anon, authenticated;
revoke all on table public.conversation_members from anon, authenticated;
revoke all on table public.messages from anon, authenticated;

grant select on table public.conversations to authenticated;
grant select, insert on table public.conversation_members to authenticated;
grant select, insert on table public.messages to authenticated;

-- Keep the direct-message creation RPC available only to signed-in users.
revoke all on function public.get_or_create_direct_conversation(uuid) from public, anon;
grant execute on function public.get_or_create_direct_conversation(uuid) to authenticated;

-- Helper functions are private implementation details, not client-facing RPCs.
revoke all on function private.is_conversation_member(uuid) from public, anon;
grant execute on function private.is_conversation_member(uuid) to authenticated;
revoke all on function private.conversation_is_empty(uuid) from public, anon;
grant execute on function private.conversation_is_empty(uuid) to authenticated;
