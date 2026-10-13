create or replace function public.venturify_notify_follow()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null or auth.uid() is distinct from new.follower_id then return new; end if;
  if new.follower_id <> new.following_id then
    insert into public.notifications (recipient_id, actor_id, type) values (new.following_id, new.follower_id, 'follow');
  end if;
  return new;
end;
$$;

create or replace function public.venturify_notify_like()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare owner_id uuid;
begin
  if auth.uid() is null or auth.uid() is distinct from new.user_id then return new; end if;
  select p.user_id into owner_id from public.posts p where p.id = new.post_id;
  if owner_id is not null and owner_id <> new.user_id then
    insert into public.notifications (recipient_id, actor_id, type, post_id) values (owner_id, new.user_id, 'like', new.post_id);
  end if;
  return new;
end;
$$;

create or replace function public.venturify_notify_comment()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare owner_id uuid;
begin
  if auth.uid() is null or auth.uid() is distinct from new.user_id then return new; end if;
  select p.user_id into owner_id from public.posts p where p.id = new.post_id;
  if owner_id is not null and owner_id <> new.user_id then
    insert into public.notifications (recipient_id, actor_id, type, post_id) values (owner_id, new.user_id, 'comment', new.post_id);
  end if;
  return new;
end;
$$;

create or replace function public.venturify_notify_message()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null or auth.uid() is distinct from new.sender_id then return new; end if;
  insert into public.notifications (recipient_id, actor_id, type)
  select cm.user_id, new.sender_id, 'message'
  from public.conversation_members cm
  where cm.conversation_id = new.conversation_id and cm.user_id <> new.sender_id;
  return new;
end;
$$;

drop trigger if exists venturify_notify_follow on public.follows;
create trigger venturify_notify_follow after insert on public.follows for each row execute function public.venturify_notify_follow();
drop trigger if exists venturify_notify_like on public.likes;
create trigger venturify_notify_like after insert on public.likes for each row execute function public.venturify_notify_like();
drop trigger if exists venturify_notify_comment on public.comments;
create trigger venturify_notify_comment after insert on public.comments for each row execute function public.venturify_notify_comment();
drop trigger if exists venturify_notify_message on public.messages;
create trigger venturify_notify_message after insert on public.messages for each row execute function public.venturify_notify_message();

revoke execute on function public.venturify_notify_follow() from public, anon, authenticated;
revoke execute on function public.venturify_notify_like() from public, anon, authenticated;
revoke execute on function public.venturify_notify_comment() from public, anon, authenticated;
revoke execute on function public.venturify_notify_message() from public, anon, authenticated;
