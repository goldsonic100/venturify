-- Disposable PostgreSQL fixture for block-enforcement RLS integration tests.
-- This is not a production schema and must never be applied to the live Supabase project.
\set ON_ERROR_STOP on

create schema if not exists auth;
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
end $$;

create or replace function auth.uid()
returns uuid language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

create table public.profiles (
  id uuid primary key,
  display_name text not null default 'Founder'
);
create table public.posts (
  id uuid primary key,
  author_id uuid not null references public.profiles(id),
  body text not null
);
create table public.comments (
  id uuid primary key,
  post_id uuid not null references public.posts(id),
  author_id uuid not null references public.profiles(id),
  body text not null
);
create table public.likes (
  post_id uuid not null references public.posts(id),
  user_id uuid not null references public.profiles(id),
  primary key (post_id, user_id)
);
create table public.follows (
  follower_id uuid not null references public.profiles(id),
  following_id uuid not null references public.profiles(id),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);
create table public.user_blocks (
  blocker_id uuid not null references public.profiles(id),
  blocked_id uuid not null references public.profiles(id),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create table public.conversations (id uuid primary key);
create table public.conversation_members (
  conversation_id uuid not null references public.conversations(id),
  user_id uuid not null references public.profiles(id),
  primary key (conversation_id, user_id)
);
create table public.messages (
  id uuid primary key,
  conversation_id uuid not null references public.conversations(id),
  sender_id uuid not null references public.profiles(id),
  body text not null
);

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.user_blocks enable row level security;
alter table public.likes enable row level security;
alter table public.follows enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

create policy "Profiles are visible to everyone" on public.profiles for select using (true);
create policy "Posts are public" on public.posts for select using (true);
create policy "Comments are public" on public.comments for select using (true);
create policy "Signed-in users create comments as themselves" on public.comments for insert to authenticated with check (auth.uid() = author_id);
create policy "Users like as themselves" on public.likes for insert to authenticated with check (auth.uid() = user_id);
create policy "Users follow as themselves" on public.follows for insert to authenticated with check (auth.uid() = follower_id and follower_id <> following_id);
create policy "Users can view blocks involving them" on public.user_blocks for select to authenticated using (auth.uid() = blocker_id or auth.uid() = blocked_id);
create policy "Users can see their own membership rows" on public.conversation_members for select to authenticated using (auth.uid() = user_id);
create policy "Members can read messages" on public.messages for select to authenticated using (
  exists (select 1 from public.conversation_members cm where cm.conversation_id = messages.conversation_id and cm.user_id = auth.uid())
);
create policy "Members can send messages as themselves" on public.messages for insert to authenticated with check (
  sender_id = auth.uid()
  and exists (select 1 from public.conversation_members cm where cm.conversation_id = messages.conversation_id and cm.user_id = auth.uid())
);

grant usage on schema public, auth to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
grant select on public.profiles, public.posts, public.comments to authenticated, anon;
grant insert on public.comments, public.messages, public.likes, public.follows to authenticated;
grant select on public.user_blocks, public.conversation_members, public.messages to authenticated;
create schema if not exists private;
grant usage on schema private to authenticated;

insert into public.profiles (id, display_name) values
 ('00000000-0000-0000-0000-000000000001', 'Alice'),
 ('00000000-0000-0000-0000-000000000002', 'Bob'),
 ('00000000-0000-0000-0000-000000000003', 'Charlie');
insert into public.posts (id, author_id, body) values
 ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'Bob post'),
 ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 'Charlie post');
insert into public.comments (id, post_id, author_id, body) values
 ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'Bob comment'),
 ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 'Charlie comment');
insert into public.user_blocks values
 ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');
insert into public.conversations values
 ('30000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002');
insert into public.conversation_members values
 ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002'),
 ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003');
insert into public.messages values
 ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'Blocked conversation'),
 ('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 'Unblocked conversation');
