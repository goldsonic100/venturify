create table if not exists public.founder_match_impressions (
  viewer_id uuid not null references auth.users(id) on delete cascade,
  candidate_id uuid not null references public.profiles(id) on delete cascade,
  match_date date not null default (timezone('utc', now())::date),
  created_at timestamptz not null default now(),
  primary key (viewer_id, match_date, candidate_id),
  constraint founder_match_not_self check (viewer_id <> candidate_id)
);

alter table public.founder_match_impressions enable row level security;

drop policy if exists "Users read their own daily matches" on public.founder_match_impressions;
create policy "Users read their own daily matches"
  on public.founder_match_impressions
  for select to authenticated
  using ((select auth.uid()) = viewer_id);

drop policy if exists "Users record their own daily matches" on public.founder_match_impressions;
create policy "Users record their own daily matches"
  on public.founder_match_impressions
  for insert to authenticated
  with check ((select auth.uid()) = viewer_id);

create or replace function private.enforce_daily_founder_match_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_count integer;
begin
  if auth.uid() is null or new.viewer_id <> auth.uid() then
    raise exception 'You can only record your own founder matches.';
  end if;

  new.match_date := timezone('utc', now())::date;

  perform 1 from public.profiles where id = new.viewer_id for update;

  select count(*) into existing_count
  from public.founder_match_impressions
  where viewer_id = new.viewer_id
    and match_date = new.match_date;

  if existing_count >= 6 then
    raise exception 'You have reached your six free matches for today.';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_daily_founder_match_limit on public.founder_match_impressions;
create trigger enforce_daily_founder_match_limit
before insert on public.founder_match_impressions
for each row execute function private.enforce_daily_founder_match_limit();

revoke update, delete on public.founder_match_impressions from anon, authenticated;
grant select, insert on public.founder_match_impressions to authenticated;
