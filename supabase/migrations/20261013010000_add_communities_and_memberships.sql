create table if not exists public.communities (
 id uuid primary key default gen_random_uuid(),
 name text not null check (char_length(trim(name)) between 2 and 60),
 slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{1,49}$'),
 topic text not null check (char_length(trim(topic)) between 2 and 40),
 description text not null default '' check (char_length(description) <= 400),
 created_by uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
create table if not exists public.community_members (
 community_id uuid not null references public.communities(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key (community_id,user_id)
);
alter table public.posts add column if not exists community_id uuid references public.communities(id) on delete set null;
create index if not exists communities_created_at_idx on public.communities(created_at desc);
create index if not exists community_members_user_idx on public.community_members(user_id,community_id);
create index if not exists posts_community_created_idx on public.posts(community_id,created_at desc);
alter table public.communities enable row level security;
alter table public.community_members enable row level security;
grant select, insert, update, delete on public.communities to authenticated;
grant select, insert, delete on public.community_members to authenticated;
grant select on public.communities to anon;
grant select on public.community_members to anon;
drop policy if exists "Communities are publicly readable" on public.communities;
create policy "Communities are publicly readable" on public.communities for select to anon, authenticated using (true);
drop policy if exists "Signed-in users create communities as themselves" on public.communities;
create policy "Signed-in users create communities as themselves" on public.communities for insert to authenticated with check (created_by = (select auth.uid()));
drop policy if exists "Creators update their communities" on public.communities;
create policy "Creators update their communities" on public.communities for update to authenticated using (created_by = (select auth.uid())) with check (created_by = (select auth.uid()));
drop policy if exists "Creators delete their communities" on public.communities;
create policy "Creators delete their communities" on public.communities for delete to authenticated using (created_by = (select auth.uid()));
drop policy if exists "Community memberships are publicly readable" on public.community_members;
create policy "Community memberships are publicly readable" on public.community_members for select to anon, authenticated using (true);
drop policy if exists "Users join communities as themselves" on public.community_members;
create policy "Users join communities as themselves" on public.community_members for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Users leave communities as themselves" on public.community_members;
create policy "Users leave communities as themselves" on public.community_members for delete to authenticated using (user_id = (select auth.uid()));
