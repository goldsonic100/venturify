-- Use the protected message lookup for read-receipt inserts too.
-- A normal SELECT can be filtered by message RLS, making it an unreliable
-- source for a block check when the message itself is hidden.

drop policy if exists "Blocked accounts cannot create message read receipts" on public.message_reads;
create policy "Blocked accounts cannot create message read receipts"
on public.message_reads as restrictive for insert to authenticated
with check (
  not private.is_message_in_blocked_conversation(message_id)
);
