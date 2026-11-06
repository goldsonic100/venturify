-- Preserve every moderator decision so authors can understand the review lifecycle.
create table if not exists public.founder_postmortem_reviews (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references public.founder_postmortems(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  reviewer_id uuid references auth.users(id) on delete set null,
  status text not null check (status in ('needs_edits','approved','rejected')),
  moderator_notes text not null default '' check (char_length(moderator_notes) <= 2000),
  created_at timestamptz not null default now()
);

alter table public.founder_postmortem_reviews enable row level security;
revoke all on table public.founder_postmortem_reviews from public, anon, authenticated;
grant select on table public.founder_postmortem_reviews to authenticated;

drop policy if exists "Authors and moderators can view post-mortem review history" on public.founder_postmortem_reviews;
create policy "Authors and moderators can view post-mortem review history"
on public.founder_postmortem_reviews
for select to authenticated
using (
  author_id = (select auth.uid())
  or exists (select 1 from private.moderators m where m.user_id = (select auth.uid()))
);

create index if not exists founder_postmortem_reviews_story_created_idx
  on public.founder_postmortem_reviews (story_id, created_at desc);
create index if not exists founder_postmortem_reviews_author_created_idx
  on public.founder_postmortem_reviews (author_id, created_at desc);

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
declare
  v_author_id uuid;
  v_notes text := coalesce(p_moderator_notes, '');
begin
  if (select auth.uid()) is null or not exists (
    select 1 from private.moderators m where m.user_id = (select auth.uid())
  ) then
    raise exception 'Moderator access required' using errcode = '42501';
  end if;
  if p_status not in ('needs_edits', 'approved', 'rejected') then
    raise exception 'Review status must be needs_edits, approved, or rejected' using errcode = '22023';
  end if;
  if char_length(v_notes) > 2000 then
    raise exception 'Moderator notes must be 2000 characters or fewer' using errcode = '22001';
  end if;

  select s.author_id into v_author_id
    from public.founder_postmortems s
   where s.id = p_story_id and s.status in ('pending', 'needs_edits')
   for update;
  if not found then
    raise exception 'Submission not found or no longer reviewable' using errcode = 'P0002';
  end if;

  update public.founder_postmortems
     set status = p_status,
         moderator_notes = v_notes,
         reviewed_at = now(),
         reviewed_by = (select auth.uid()),
         updated_at = now()
   where id = p_story_id and status in ('pending', 'needs_edits');
  if not found then
    raise exception 'Submission not found or no longer reviewable' using errcode = 'P0002';
  end if;

  insert into public.founder_postmortem_reviews
    (story_id, author_id, reviewer_id, status, moderator_notes)
  values
    (p_story_id, v_author_id, (select auth.uid()), p_status, v_notes);

  if v_author_id <> (select auth.uid()) then
    insert into public.notifications (recipient_id, actor_id, type, founder_postmortem_id)
    values (v_author_id, (select auth.uid()), 'postmortem_review', p_story_id);
  end if;
  return true;
end;
$function$;

revoke all on function public.moderator_review_founder_postmortem(uuid, text, text) from public, anon;
grant execute on function public.moderator_review_founder_postmortem(uuid, text, text) to authenticated;
