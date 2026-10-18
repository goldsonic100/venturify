-- Disposable fixture for moderator RPC integration tests only. Never run on production.
\set ON_ERROR_STOP on
create schema if not exists auth;
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
end $$;
create or replace function auth.uid()
returns uuid language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create table auth.users (id uuid primary key);
create table public.profiles (id uuid primary key references auth.users(id) on delete cascade);
create table public.content_reports (
  id uuid primary key,
  reporter_id uuid not null references public.profiles(id),
  reported_user_id uuid references public.profiles(id),
  post_id uuid,
  comment_id uuid,
  reason text not null check (reason in ('spam','harassment','fake_or_misleading','scam','privacy','inappropriate_content','other')),
  details text not null default '',
  status text not null default 'pending' check (status in ('pending','reviewing','resolved','dismissed')),
  moderator_notes text not null default '',
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint report_one_target check (num_nonnulls(reported_user_id, post_id, comment_id) = 1)
);
alter table public.content_reports enable row level security;
create policy "Reporter reads own report" on public.content_reports
  for select to authenticated using (reporter_id = (select auth.uid()));
grant usage on schema public, auth to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
grant select on public.content_reports to authenticated;
insert into auth.users values
 ('00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000002'),
 ('00000000-0000-0000-0000-000000000003');
insert into public.profiles values
 ('00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000002'),
 ('00000000-0000-0000-0000-000000000003');
insert into public.content_reports (id, reporter_id, reported_user_id, reason, details, created_at) values
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','spam','Report one',now()-interval '2 minutes'),
 ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','harassment','Report two',now()-interval '1 minute');
