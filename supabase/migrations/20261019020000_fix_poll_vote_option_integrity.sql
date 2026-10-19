-- Ensure a vote's selected option belongs to the same poll_id recorded on the vote.
-- This fixes a tautological comparison in the existing INSERT policy.
-- Apply after merging; no existing vote rows are modified.

drop policy if exists "Users vote as themselves" on public.post_poll_votes;

create policy "Users vote as themselves"
on public.post_poll_votes
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.post_poll_options o
    where o.id = post_poll_votes.option_id
      and o.poll_id = post_poll_votes.poll_id
  )
);
