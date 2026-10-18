-- Protected moderator review workflow for private content reports.
-- Moderators are provisioned only by a trusted database administrator.
-- Never use user-editable auth metadata to grant moderation privileges.

create schema if not exists private;

create table if not exists private.moderators (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table private.moderators enable row level security;
revoke all on table private.moderators from public, anon, authenticated;

alter table public.content_reports
  add column if not exists reviewed_by uuid references public.profiles(id) on delete set null;

create or replace function public.moderator_list_reports(
  p_status text default 'pending',
  p_limit integer default 50
)
returns table (
  id uuid,
  reporter_id uuid,
  reported_user_id uuid,
  post_id uuid,
  comment_id uuid,
  reason text,
  details text,
  status text,
  created_at timestamptz,
  moderator_notes text,
  reviewed_at timestamptz,
  reviewed_by uuid
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

  if p_status is not null and p_status not in ('pending', 'reviewing', 'resolved', 'dismissed') then
    raise exception 'Invalid report status' using errcode = '22023';
  end if;

  return query
    select r.id, r.reporter_id, r.reported_user_id, r.post_id, r.comment_id,
           r.reason, r.details, r.status, r.created_at, r.moderator_notes,
           r.reviewed_at, r.reviewed_by
    from public.content_reports r
    where p_status is null or r.status = p_status
    order by r.created_at asc
    limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$function$;

create or replace function public.moderator_update_report(
  p_report_id uuid,
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

  if p_status not in ('pending', 'reviewing', 'resolved', 'dismissed') then
    raise exception 'Invalid report status' using errcode = '22023';
  end if;

  if char_length(coalesce(p_moderator_notes, '')) > 2000 then
    raise exception 'Moderator notes must be 2000 characters or fewer' using errcode = '22001';
  end if;

  update public.content_reports
  set status = p_status,
      moderator_notes = coalesce(p_moderator_notes, ''),
      reviewed_at = now(),
      reviewed_by = (select auth.uid())
  where content_reports.id = p_report_id;

  if not found then
    raise exception 'Report not found' using errcode = 'P0002';
  end if;

  return true;
end;
$function$;

revoke all on function public.moderator_list_reports(text, integer) from public, anon;
revoke all on function public.moderator_update_report(uuid, text, text) from public, anon;
grant execute on function public.moderator_list_reports(text, integer) to authenticated;
grant execute on function public.moderator_update_report(uuid, text, text) to authenticated;

comment on table private.moderators is
  'Trusted moderator allowlist. Provision with SQL Editor as database owner; never expose to client roles.';
comment on function public.moderator_list_reports(text, integer) is
  'Returns private reports only to users in private.moderators.';
comment on function public.moderator_update_report(uuid, text, text) is
  'Updates report status and notes only for users in private.moderators.';
