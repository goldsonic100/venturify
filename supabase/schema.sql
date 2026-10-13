-- Venturify Supabase starter schema
-- Run in Supabase Dashboard -> SQL Editor. Never expose a service-role key in browser code.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique,
 display_name text not null default 'Founder' check (char_length(display_name) between 1 and 50),
 bio text not null default '' check (char_length(bio) <= 240),
 avatar_url text,
 startup_name text check (startup_name is null or char_length(startup_name) <= 100),
 industry text check (industry is null or char_length(industry) <= 60),
 stage text check (stage is null or char_length(stage) <= 60),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint username_format check (username is null or username ~ '^[a-zA-Z0-9_]{3,24}$')
);
create table if not exists public.posts (
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check (char_length(trim(body)) between 1 and 2000),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists posts_created_at_idx on public.posts (created_at desc);
create index if not exists posts_author_created_idx on public.posts (author_id, created_at desc);

create table if not exists public.comments (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.posts(id) on delete cascade,
 author_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check (char_length(trim(body)) between 1 and 1000),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists comments_post_created_idx on public.comments (post_id, created_at asc);

create table if not exists public.likes (
 post_id uuid not null references public.posts(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key (post_id, user_id)
);
create table if not exists public.follows (
 follower_id uuid not null references public.profiles(id) on delete cascade,
 following_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key (follower_id, following_id),
 constraint no_self_follow check (follower_id <> following_id)
);
create index if not exists follows_following_idx on public.follows (following_id);
create index if not exists follows_follower_idx on public.follows (follower_id);

create table if not exists public.notifications (
 id uuid primary key default gen_random_uuid(),
 recipient_id uuid not null references public.profiles(id) on delete cascade,
 actor_id uuid references public.profiles(id) on delete set null,
 kind text not null check (kind in ('follow', 'like', 'comment')),
 post_id uuid references public.posts(id) on delete cascade,
 comment_id uuid references public.comments(id) on delete cascade,
 is_read boolean not null default false,
 created_at timestamptz not null default now()
);
create index if not exists notifications_recipient_created_idx on public.notifications (recipient_id, created_at desc);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare chosen_name text;
begin
 chosen_name := coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
                         nullif(split_part(coalesce(new.email, 'Founder'), '@', 1), ''), 'Founder');
 insert into public.profiles (id, display_name)
 values (new.id, left(chosen_name, 50)) on conflict (id) do nothing;
 return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = ''
as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();
drop trigger if exists posts_set_updated_at on public.posts;
create trigger posts_set_updated_at before update on public.posts for each row execute procedure public.set_updated_at();
drop trigger if exists comments_set_updated_at on public.comments;
create trigger comments_set_updated_at before update on public.comments for each row execute procedure public.set_updated_at();

create or replace function public.notify_new_follow()
returns trigger language plpgsql security definer set search_path = ''
as $$ begin
 insert into public.notifications (recipient_id, actor_id, kind) values (new.following_id, new.follower_id, 'follow');
 return new;
end; $$;
drop trigger if exists follows_notify on public.follows;
create trigger follows_notify after insert on public.follows for each row execute procedure public.notify_new_follow();

create or replace function public.notify_new_like()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare post_author uuid;
begin
 select author_id into post_author from public.posts where id = new.post_id;
 if post_author is not null and post_author <> new.user_id then
  insert into public.notifications (recipient_id, actor_id, kind, post_id) values (post_author, new.user_id, 'like', new.post_id);
 end if;
 return new;
end; $$;
drop trigger if exists likes_notify on public.likes;
create trigger likes_notify after insert on public.likes for each row execute procedure public.notify_new_like();

create or replace function public.notify_new_comment()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare post_author uuid;
begin
 select author_id into post_author from public.posts where id = new.post_id;
 if post_author is not null and post_author <> new.author_id then
  insert into public.notifications (recipient_id, actor_id, kind, post_id, comment_id) values (post_author, new.author_id, 'comment', new.post_id, new.id);
 end if;
 return new;
end; $$;
drop trigger if exists comments_notify on public.comments;
create trigger comments_notify after insert on public.comments for each row execute procedure public.notify_new_comment();

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.likes enable row level security;
alter table public.follows enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "Profiles are visible to everyone" on public.profiles;
create policy "Profiles are visible to everyone" on public.profiles for select using (true);
drop policy if exists "Users create their own profile" on public.profiles;
create policy "Users create their own profile" on public.profiles for insert to authenticated with check (auth.uid() = id);
drop policy if exists "Users update their own profile" on public.profiles;
create policy "Users update their own profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "Posts are public" on public.posts;
create policy "Posts are public" on public.posts for select using (true);
drop policy if exists "Signed-in users create posts as themselves" on public.posts;
create policy "Signed-in users create posts as themselves" on public.posts for insert to authenticated with check (auth.uid() = author_id);
drop policy if exists "Authors update their own posts" on public.posts;
create policy "Authors update their own posts" on public.posts for update to authenticated using (auth.uid() = author_id) with check (auth.uid() = author_id);
drop policy if exists "Authors delete their own posts" on public.posts;
create policy "Authors delete their own posts" on public.posts for delete to authenticated using (auth.uid() = author_id);

drop policy if exists "Comments are public" on public.comments;
create policy "Comments are public" on public.comments for select using (true);
drop policy if exists "Signed-in users create comments as themselves" on public.comments;
create policy "Signed-in users create comments as themselves" on public.comments for insert to authenticated with check (auth.uid() = author_id);
drop policy if exists "Authors update their own comments" on public.comments;
create policy "Authors update their own comments" on public.comments for update to authenticated using (auth.uid() = author_id) with check (auth.uid() = author_id);
drop policy if exists "Authors delete their own comments" on public.comments;
create policy "Authors delete their own comments" on public.comments for delete to authenticated using (auth.uid() = author_id);

drop policy if exists "Likes are public" on public.likes;
create policy "Likes are public" on public.likes for select using (true);
drop policy if exists "Users like as themselves" on public.likes;
create policy "Users like as themselves" on public.likes for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Users remove their own likes" on public.likes;
create policy "Users remove their own likes" on public.likes for delete to authenticated using (auth.uid() = user_id);

drop policy if exists "Follows are public" on public.follows;
create policy "Follows are public" on public.follows for select using (true);
drop policy if exists "Users follow as themselves" on public.follows;
create policy "Users follow as themselves" on public.follows for insert to authenticated with check (auth.uid() = follower_id and follower_id <> following_id);
drop policy if exists "Users unfollow as themselves" on public.follows;
create policy "Users unfollow as themselves" on public.follows for delete to authenticated using (auth.uid() = follower_id);

drop policy if exists "Recipients read their notifications" on public.notifications;
create policy "Recipients read their notifications" on public.notifications for select to authenticated using (auth.uid() = recipient_id);
drop policy if exists "Recipients mark their notifications read" on public.notifications;
create policy "Recipients mark their notifications read" on public.notifications for update to authenticated using (auth.uid() = recipient_id) with check (auth.uid() = recipient_id);
drop policy if exists "Recipients delete their notifications" on public.notifications;
create policy "Recipients delete their notifications" on public.notifications for delete to authenticated using (auth.uid() = recipient_id);

-- Example public feed:
-- select posts.*, profiles.username, profiles.display_name, profiles.avatar_url
-- from public.posts join public.profiles on profiles.id = posts.author_id
-- order by posts.created_at desc limit 30;
