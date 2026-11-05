-- Founder post-mortem submissions are private until an explicitly allowlisted moderator approves them.
-- Public access is provided only through a narrow RPC that returns approved, consented fields.

create table if not exists public.founder_postmortems (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  company_name text not null default '' check (char_length(company_name) <= 120),
  industry text not null check (char_length(industry) between 1 and 100),
  company_stage text not null check (company_stage in ('idea', 'pre-seed', 'seed', 'series-a', 'series-b-plus', 'bootstrapped', 'other')),
  primary_lesson text not null check (primary_lesson in ('market', 'cash-runway', 'growth', 'operations', 'team', 'timing', 'fundraising', 'other')),
  summary text not null check (char_length(summary) between 40 and 1000),
  what_happened text not null check (char_length(what_happened) between 40 and 5000),
  lessons_learned text not null check (char_length(lessons_learned) between 20 and 3000),
  financial_context text not null default '' check (char_length(financial_context) <= 500),
  author_display_mode text not null check (author_display_mode in ('anonymous', 'profile')),
  company_visibility text not null check (company_visibility in ('hidden', 'public')),
  consent_to_publish boolean not null default false check (consent_to_publish),
  consent_version text not null check (consent_version = 'postmortem-consent-v1'),
  consent_at timestamptz not null default now(),
  status text not null default 'pending' check (status in ('pending', 'needs_edits', 'approved', 'rejected', 'withdrawn')),
  moderator_notes text not null default '' check (char_length(moderator_notes) <= 2000),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists founder_postmortems_author_created_idx
  on public.founder_postmortems (author_id, created_at desc);
create index if not exists founder_postmortems_status_created_idx
  on public.founder_postmortems (status, created_at asc);

alter table public.founder_postmortems enable row level security;
revoke all on table public.founder_postmortems from public, anon, authenticated;
grant select, insert on table public.founder_postmortems to authenticated;

create policy "Authors can view their own post-mortem submissions"
  on public.founder_postmortems for select to authenticated
  using (author_id = (select auth.uid()));

create policy "Authors can submit consented post-mortems as themselves"
  on public.founder_postmortems for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and consent_to_publish is true
    and status = 'pending'
    and moderator_notes = ''
    and reviewed_at is null
    and reviewed_by is null
  );

-- A contributor may withdraw their own submission, including a published one.
-- Direct UPDATE is intentionally not granted to browser roles.
create or replace function public.withdraw_my_founder_postmortem(p_story_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in required' using errcode = '42501';
  end if;
  update public.founder_postmortems
     set status = 'withdrawn', updated_at = now()
   where id = p_story_id and author_id = (select auth.uid());
  if not found then
    raise exception 'Story not found or unavailable' using errcode = 'P0002';
  end if;
  return true;
end;
$function$;

-- Public library projection: never returns author IDs, hidden company names,
-- private moderator notes, or stories lacking explicit consent and approval.
create or replace function public.list_published_founder_postmortems(p_limit integer default 50)
returns table (
  id uuid,
  company_name text,
  industry text,
  company_stage text,
  primary_lesson text,
  summary text,
  what_happened text,
  lessons_learned text,
  financial_context text,
  founder_name text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $function$
  select s.id,
         case when s.company_visibility = 'public' then s.company_name else '' end,
         s.industry, s.company_stage, s.primary_lesson, s.summary,
         s.what_happened, s.lessons_learned, s.financial_context,
         case when s.author_display_mode = 'profile' then coalesce(nullif(p.display_name, ''), nullif(p.username, ''), 'Founder') else 'Anonymous founder' end,
         s.created_at
    from public.founder_postmortems s
    left join public.profiles p on p.id = s.author_id
   where s.status = 'approved' and s.consent_to_publish is true
   order by s.created_at desc
   limit greatest(1, least(coalesce(p_limit, 50), 100));
$function$;

-- Moderator-only review queue, protected by the same private allowlist used by
-- the existing moderation tools. Do not grant direct table access for review.
create or replace function public.moderator_list_founder_postmortems(
  p_status text default 'pending',
  p_limit integer default 50
)
returns table (
  id uuid,
  author_id uuid,
  author_username text,
  author_display_name text,
  company_name text,
  industry text,
  company_stage text,
  primary_lesson text,
  summary text,
  what_happened text,
  lessons_learned text,
  financial_context text,
  author_display_mode text,
  company_visibility text,
  consent_to_publish boolean,
  consent_version text,
  consent_at timestamptz,
  status text,
  moderator_notes text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if (select auth.uid()) is null or not exists (
    select 1 from private.moderators m where m.user_id = (select auth.uid())
  ) then
    raise exception 'Moderator access required' using errcode = '42501';
  end if;
  if p_status is not null and p_status not in ('pending', 'needs_edits', 'approved', 'rejected', 'withdrawn') then
    raise exception 'Invalid post-mortem status' using errcode = '22023';
  end if;
  return query
    select s.id, s.author_id, coalesce(p.username, ''), coalesce(p.display_name, ''),
           s.company_name, s.industry, s.company_stage, s.primary_lesson,
           s.summary, s.what_happened, s.lessons_learned, s.financial_context,
           s.author_display_mode, s.company_visibility, s.consent_to_publish,
           s.consent_version, s.consent_at, s.status, s.moderator_notes, s.created_at
      from public.founder_postmortems s
      left join public.profiles p on p.id = s.author_id
     where p_status is null or s.status = p_status
     order by s.created_at asc
     limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$function$;

create or replace function public.moderator_review_founder_postmortem(
  p_story_id uuid,
  p_status text,
  p_moderator_notes text default ''
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if (select auth.uid()) is null or not exists (
    select 1 from private.moderators m where m.user_id = (select auth.uid())
  ) then
    raise exception 'Moderator access required' using errcode = '42501';
  end if;
  if p_status not in ('needs_edits', 'approved', 'rejected') then
    raise exception 'Review status must be needs_edits, approved, or rejected' using errcode = '22023';
  end if;
  if char_length(coalesce(p_moderator_notes, '')) > 2000 then
    raise exception 'Moderator notes must be 2000 characters or fewer' using errcode = '22001';
  end if;
  update public.founder_postmortems
     set status = p_status,
         moderator_notes = coalesce(p_moderator_notes, ''),
         reviewed_at = now(), reviewed_by = (select auth.uid()), updated_at = now()
   where id = p_story_id and status in ('pending', 'needs_edits');
  if not found then
    raise exception 'Submission not found or no longer reviewable' using errcode = 'P0002';
  end if;
  return true;
end;
$function$;

revoke all on function public.withdraw_my_founder_postmortem(uuid) from public, anon;
revoke all on function public.list_published_founder_postmortems(integer) from public;
revoke all on function public.moderator_list_founder_postmortems(text, integer) from public, anon;
revoke all on function public.moderator_review_founder_postmortem(uuid, text, text) from public, anon;
grant execute on function public.withdraw_my_founder_postmortem(uuid) to authenticated;
grant execute on function public.list_published_founder_postmortems(integer) to anon, authenticated;
grant execute on function public.moderator_list_founder_postmortems(text, integer) to authenticated;
grant execute on function public.moderator_review_founder_postmortem(uuid, text, text) to authenticated;

comment on table public.founder_postmortems is
  'Private founder post-mortem submissions. Only explicitly consented and moderator-approved stories appear in the public library RPC.';
comment on function public.list_published_founder_postmortems(integer) is
  'Public projection of approved, consented stories; omits author IDs and hidden company names.';
comment on function public.moderator_list_founder_postmortems(text, integer) is
  'Returns private story submissions only to users provisioned in private.moderators.';
comment on function public.moderator_review_founder_postmortem(uuid, text, text) is
  'Allows allowlisted moderators to approve, request edits, or reject reviewable story submissions.';
