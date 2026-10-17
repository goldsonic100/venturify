-- Venturify trust & safety foundation.
-- Additive migration: does not alter existing posts, profiles, communities, or messages.
-- Moderator review tooling is intentionally separate from public client permissions.

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self_block check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocked_idx
  on public.user_blocks (blocked_id, blocker_id);

create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid references public.profiles(id) on delete set null,
  post_id uuid references public.posts(id) on delete set null,
  comment_id uuid references public.comments(id) on delete set null,
  reason text not null check (reason in (
    'spam', 'harassment', 'fake_or_misleading', 'scam', 'privacy',
    'inappropriate_content', 'other'
  )),
  details text not null default '' check (char_length(details) <= 1000),
  status text not null default 'pending'
    check (status in ('pending', 'reviewing', 'resolved', 'dismissed')),
  moderator_notes text not null default '' check (char_length(moderator_notes) <= 2000),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint content_reports_exactly_one_target
    check (num_nonnulls(reported_user_id, post_id, comment_id) = 1),
  constraint content_reports_no_self_report
    check (reported_user_id is null or reported_user_id <> reporter_id)
);

create index if not exists content_reports_status_created_idx
  on public.content_reports (status, created_at asc);
create index if not exists content_reports_reporter_created_idx
  on public.content_reports (reporter_id, created_at desc);

alter table public.user_blocks enable row level security;
alter table public.content_reports enable row level security;

-- A user can manage only blocks they created. Either side can see that a block
-- exists so clients can suppress interactions in both directions.
drop policy if exists "Users can view blocks involving them" on public.user_blocks;
create policy "Users can view blocks involving them"
  on public.user_blocks for select to authenticated
  using (auth.uid() = blocker_id or auth.uid() = blocked_id);

drop policy if exists "Users can block accounts as themselves" on public.user_blocks;
create policy "Users can block accounts as themselves"
  on public.user_blocks for insert to authenticated
  with check (auth.uid() = blocker_id);

drop policy if exists "Users can unblock accounts as themselves" on public.user_blocks;
create policy "Users can unblock accounts as themselves"
  on public.user_blocks for delete to authenticated
  using (auth.uid() = blocker_id);

-- Reporters can submit a report and inspect only their own submissions.
-- No client-facing UPDATE/DELETE policy is granted, so users cannot alter
-- moderation status or notes. A trusted server-side moderator workflow is
-- required to review reports; do not add a public client policy for this.
drop policy if exists "Users can submit reports as themselves" on public.content_reports;
create policy "Users can submit reports as themselves"
  on public.content_reports for insert to authenticated
  with check (auth.uid() = reporter_id);

drop policy if exists "Users can view their own reports" on public.content_reports;
create policy "Users can view their own reports"
  on public.content_reports for select to authenticated
  using (auth.uid() = reporter_id);

-- Blocked-account content must also be filtered in frontend queries and
-- interaction policies. This migration establishes block records but does not
-- silently change existing post/comment/message behavior.
