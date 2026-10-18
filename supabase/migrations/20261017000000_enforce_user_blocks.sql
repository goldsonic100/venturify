-- Enforce user blocks at the database layer so hiding blocked accounts is not only a UI behavior.
-- Restrictive policies are combined with existing permissive policies using AND,
-- preserving the existing visibility rules while filtering relationships between blocked accounts.

create policy "Blocked accounts cannot view each other's profiles"
on public.profiles
as restrictive
for select
to authenticated
using (
  not exists (
    select 1
    from public.user_blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = profiles.id)
       or (b.blocked_id = (select auth.uid()) and b.blocker_id = profiles.id)
  )
);

create policy "Blocked accounts cannot view each other's posts"
on public.posts
as restrictive
for select
to authenticated
using (
  not exists (
    select 1
    from public.user_blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = posts.user_id)
       or (b.blocked_id = (select auth.uid()) and b.blocker_id = posts.user_id)
  )
);

create policy "Blocked accounts cannot view each other's comments"
on public.comments
as restrictive
for select
to authenticated
using (
  not exists (
    select 1
    from public.user_blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = comments.user_id)
       or (b.blocked_id = (select auth.uid()) and b.blocker_id = comments.user_id)
  )
);

-- A normal policy subquery would be filtered by the restrictive post SELECT
-- policy and could fail to see a blocked author's post. Use a narrowly scoped
-- SECURITY DEFINER predicate to check the target post's author without exposing
-- hidden post data to the caller.
create schema if not exists private;

-- Function EXECUTE alone is insufficient: callers also need schema USAGE.
grant usage on schema private to authenticated;

create or replace function private.is_post_author_blocked(p_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $block$
  select exists (
    select 1
    from public.posts p
    join public.user_blocks b
      on (b.blocker_id = (select auth.uid()) and b.blocked_id = p.user_id)
      or (b.blocked_id = (select auth.uid()) and b.blocker_id = p.user_id)
    where p.id = p_post_id
  );
$block$;

revoke all on function private.is_post_author_blocked(uuid) from public, anon;
grant execute on function private.is_post_author_blocked(uuid) to authenticated;

create or replace function private.is_conversation_blocked(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $block$
  select exists (
    select 1
    from public.conversation_members cm
    join public.user_blocks b
      on (b.blocker_id = (select auth.uid()) and b.blocked_id = cm.user_id)
      or (b.blocked_id = (select auth.uid()) and b.blocker_id = cm.user_id)
    where cm.conversation_id = p_conversation_id
      and cm.user_id <> (select auth.uid())
  );
$block$;

revoke all on function private.is_conversation_blocked(uuid) from public, anon;
grant execute on function private.is_conversation_blocked(uuid) to authenticated;

create policy "Blocked accounts cannot comment on each other's posts"
on public.comments
as restrictive
for insert
to authenticated
with check (
  not private.is_post_author_blocked(comments.post_id)
);

create policy "Blocked accounts cannot read conversation messages"
on public.messages
as restrictive
for select
to authenticated
using (
  not private.is_conversation_blocked(messages.conversation_id)
);

create policy "Blocked accounts cannot send conversation messages"
on public.messages
as restrictive
for insert
to authenticated
with check (
  sender_id = (select auth.uid())
  and not private.is_conversation_blocked(messages.conversation_id)
);


-- Blocked users cannot create new likes on one another's posts.
create policy "Blocked accounts cannot like each other's posts"
on public.likes
as restrictive
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and not private.is_post_author_blocked(likes.post_id)
);

-- A follow is disallowed in either direction when a block exists.
create policy "Blocked accounts cannot follow each other"
on public.follows
as restrictive
for insert
to authenticated
with check (
  follower_id = (select auth.uid())
  and not exists (
    select 1
    from public.user_blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = follows.following_id)
       or (b.blocked_id = (select auth.uid()) and b.blocker_id = follows.following_id)
  )
);


-- Hide likes involving a blocked account or a blocked post from signed-in viewers.
create policy "Blocked accounts cannot view each other's likes"
on public.likes
as restrictive
for select
to authenticated
using (
  not private.is_post_author_blocked(likes.post_id)
  and not exists (
    select 1
    from public.user_blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = likes.user_id)
       or (b.blocked_id = (select auth.uid()) and b.blocker_id = likes.user_id)
  )
);

-- Hide follow edges involving an account blocked by or blocking the signed-in viewer.
create policy "Blocked accounts cannot view each other's follows"
on public.follows
as restrictive
for select
to authenticated
using (
  not exists (
    select 1
    from public.user_blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = follows.follower_id)
       or (b.blocked_id = (select auth.uid()) and b.blocker_id = follows.follower_id)
       or (b.blocker_id = (select auth.uid()) and b.blocked_id = follows.following_id)
       or (b.blocked_id = (select auth.uid()) and b.blocker_id = follows.following_id)
  )
);
