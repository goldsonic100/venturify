-- Ensure block checks cannot be bypassed by overlapping permissive RLS policies.
-- PostgreSQL combines permissive policies with OR; restrictive policies add an AND guard.
-- These guards apply only to authenticated users, leaving public read access unchanged for anonymous visitors.

drop policy if exists "Block enforcement guard: posts select" on public.posts;
create policy "Block enforcement guard: posts select"
on public.posts as restrictive for select to authenticated
using (not exists (
  select 1 from public.user_blocks b
  where (b.blocker_id = (select auth.uid()) and b.blocked_id = posts.user_id)
     or (b.blocked_id = (select auth.uid()) and b.blocker_id = posts.user_id)
));

drop policy if exists "Block enforcement guard: comments select" on public.comments;
create policy "Block enforcement guard: comments select"
on public.comments as restrictive for select to authenticated
using (
  not private.is_post_author_blocked(post_id)
  and not exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = comments.user_id)
       or (b.blocked_id = (select auth.uid()) and b.blocker_id = comments.user_id)
  )
);

drop policy if exists "Block enforcement guard: comments insert" on public.comments;
create policy "Block enforcement guard: comments insert"
on public.comments as restrictive for insert to authenticated
with check (user_id = (select auth.uid()) and not private.is_post_author_blocked(post_id));

drop policy if exists "Block enforcement guard: follows select" on public.follows;
create policy "Block enforcement guard: follows select"
on public.follows as restrictive for select to authenticated
using (not exists (
  select 1 from public.user_blocks b
  where (b.blocker_id = (select auth.uid()) and b.blocked_id in (follows.follower_id, follows.following_id))
     or (b.blocked_id = (select auth.uid()) and b.blocker_id in (follows.follower_id, follows.following_id))
));

drop policy if exists "Block enforcement guard: follows insert" on public.follows;
create policy "Block enforcement guard: follows insert"
on public.follows as restrictive for insert to authenticated
with check (
  follower_id = (select auth.uid())
  and not exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = follows.following_id)
       or (b.blocked_id = (select auth.uid()) and b.blocker_id = follows.following_id)
  )
);

drop policy if exists "Block enforcement guard: likes select" on public.likes;
create policy "Block enforcement guard: likes select"
on public.likes as restrictive for select to authenticated
using (
  not private.is_post_author_blocked(post_id)
  and not exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = likes.user_id)
       or (b.blocked_id = (select auth.uid()) and b.blocker_id = likes.user_id)
  )
);

drop policy if exists "Block enforcement guard: likes insert" on public.likes;
create policy "Block enforcement guard: likes insert"
on public.likes as restrictive for insert to authenticated
with check (user_id = (select auth.uid()) and not private.is_post_author_blocked(post_id));

drop policy if exists "Block enforcement guard: messages select" on public.messages;
create policy "Block enforcement guard: messages select"
on public.messages as restrictive for select to authenticated
using (not private.is_conversation_blocked(conversation_id));

drop policy if exists "Block enforcement guard: messages insert" on public.messages;
create policy "Block enforcement guard: messages insert"
on public.messages as restrictive for insert to authenticated
with check (sender_id = (select auth.uid()) and not private.is_conversation_blocked(conversation_id));

drop policy if exists "Block enforcement guard: conversations select" on public.conversations;
create policy "Block enforcement guard: conversations select"
on public.conversations as restrictive for select to authenticated
using (not private.is_conversation_blocked(id));

drop policy if exists "Block enforcement guard: conversation members select" on public.conversation_members;
create policy "Block enforcement guard: conversation members select"
on public.conversation_members as restrictive for select to authenticated
using (not private.is_conversation_blocked(conversation_id));

drop policy if exists "Block enforcement guard: typing all" on public.conversation_typing;
create policy "Block enforcement guard: typing all"
on public.conversation_typing as restrictive for all to authenticated
using (not private.is_conversation_blocked(conversation_id))
with check (not private.is_conversation_blocked(conversation_id));

drop policy if exists "Block enforcement guard: message reads select" on public.message_reads;
create policy "Block enforcement guard: message reads select"
on public.message_reads as restrictive for select to authenticated
using (not private.is_message_in_blocked_conversation(message_id));

drop policy if exists "Block enforcement guard: message reads insert" on public.message_reads;
create policy "Block enforcement guard: message reads insert"
on public.message_reads as restrictive for insert to authenticated
with check (
  user_id = (select auth.uid())
  and not private.is_message_in_blocked_conversation(message_id)
);
