\set ON_ERROR_STOP on

-- Apply the candidate migration only inside the disposable CI database.
\i supabase/migrations/20261017000000_enforce_user_blocks.sql

-- Alice is the blocker: Bob is hidden, Charlie remains visible.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);
do $$
begin
  if exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-000000000002') then raise exception 'FAIL: blocker can still read blocked profile'; end if;
  if not exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-000000000003') then raise exception 'FAIL: unrelated profile became invisible'; end if;
  if exists (select 1 from public.posts where id = '10000000-0000-0000-0000-000000000001') then raise exception 'FAIL: blocked post is visible'; end if;
  if not exists (select 1 from public.posts where id = '10000000-0000-0000-0000-000000000002') then raise exception 'FAIL: unrelated post became invisible'; end if;
  if exists (select 1 from public.comments where id = '20000000-0000-0000-0000-000000000001') then raise exception 'FAIL: blocked comment is visible'; end if;
  if exists (select 1 from public.messages where id = '40000000-0000-0000-0000-000000000001') then raise exception 'FAIL: blocked conversation message is visible'; end if;
  if not exists (select 1 from public.messages where id = '40000000-0000-0000-0000-000000000002') then raise exception 'FAIL: unrelated conversation message became invisible'; end if;
  if exists (select 1 from public.likes where post_id = '10000000-0000-0000-0000-000000000001') then raise exception 'FAIL: like on blocked author's post is visible'; end if;
  if exists (select 1 from public.likes where user_id = '00000000-0000-0000-0000-000000000002') then raise exception 'FAIL: blocked user's likes are visible'; end if;
  if not exists (select 1 from public.likes where post_id = '10000000-0000-0000-0000-000000000002' and user_id = '00000000-0000-0000-0000-000000000003') then raise exception 'FAIL: unrelated like became invisible'; end if;
  if exists (select 1 from public.follows where follower_id = '00000000-0000-0000-0000-000000000002' or following_id = '00000000-0000-0000-0000-000000000002') then raise exception 'FAIL: follow edge involving blocked account is visible'; end if;
  if not exists (select 1 from public.follows where follower_id = '00000000-0000-0000-0000-000000000003' and following_id = '00000000-0000-0000-0000-000000000001') then raise exception 'FAIL: unrelated follow became invisible'; end if;
end $$;

-- INSERT checks must reject comments on blocked users' posts and messages to blocked members.
do $$
begin
  begin
    insert into public.comments (id, post_id, author_id, body) values
      ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Should fail');
    raise exception 'FAIL: comment on blocked account post was accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.messages (id, conversation_id, sender_id, body) values
      ('40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Should fail');
    raise exception 'FAIL: message to blocked account was accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.likes (post_id, user_id) values
      ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001');
    raise exception 'FAIL: like on blocked account post was accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.follows (follower_id, following_id) values
      ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');
    raise exception 'FAIL: follow to blocked account was accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.follows (follower_id, following_id) values
      ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001');
    raise exception 'FAIL: blocked account could follow blocker';
  exception when insufficient_privilege then null;
  end;
end $;
reset role;

-- Bob (the blocked party) must also be unable to read Alice's content/messages.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', false);
do $$
begin
  if exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-000000000001') then raise exception 'FAIL: blocked party can still read blocker profile'; end if;
  if exists (select 1 from public.messages where id = '40000000-0000-0000-0000-000000000001') then raise exception 'FAIL: blocked party can still read conversation messages'; end if;
end $$;
reset role;

\echo 'PASS: disposable PostgreSQL RLS integration checks'
