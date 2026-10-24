-- Enforce block checks as RESTRICTIVE RLS policies.
-- PostgreSQL ORs permissive policies together; a separate permissive "block guard"
-- cannot veto a broader membership policy. These restrictive policies AND with all
-- applicable permissive policies, so membership alone cannot bypass a block.
drop policy if exists "Messaging block restriction: conversations select" on public.conversations;
create policy "Messaging block restriction: conversations select"
on public.conversations as restrictive for select to authenticated
using (not private.is_conversation_blocked(id));

drop policy if exists "Messaging block restriction: conversation members select" on public.conversation_members;
create policy "Messaging block restriction: conversation members select"
on public.conversation_members as restrictive for select to authenticated
using (not private.is_conversation_blocked(conversation_id));

drop policy if exists "Messaging block restriction: messages select" on public.messages;
create policy "Messaging block restriction: messages select"
on public.messages as restrictive for select to authenticated
using (not private.is_conversation_blocked(conversation_id));

drop policy if exists "Messaging block restriction: messages insert" on public.messages;
create policy "Messaging block restriction: messages insert"
on public.messages as restrictive for insert to authenticated
with check (not private.is_conversation_blocked(conversation_id));

drop policy if exists "Messaging block restriction: message reads select" on public.message_reads;
create policy "Messaging block restriction: message reads select"
on public.message_reads as restrictive for select to authenticated
using (not private.is_message_in_blocked_conversation(message_id));

drop policy if exists "Messaging block restriction: message reads insert" on public.message_reads;
create policy "Messaging block restriction: message reads insert"
on public.message_reads as restrictive for insert to authenticated
with check (not private.is_message_in_blocked_conversation(message_id));
