drop policy if exists "Users create their own posts" on public.posts;
create policy "Users create their own posts" on public.posts
for insert to authenticated
with check (
 user_id = (select auth.uid())
 and (
  community_id is null
  or exists (
   select 1 from public.community_members m
   where m.community_id = posts.community_id
     and m.user_id = (select auth.uid())
  )
 )
);
