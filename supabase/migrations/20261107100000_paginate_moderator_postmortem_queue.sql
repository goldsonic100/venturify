-- Cursor-style pagination for the private moderator queue.
-- This separate RPC preserves the original two-argument function contract.
create or replace function public.moderator_list_founder_postmortems_page(
  p_status text default 'pending',
  p_limit integer default 50,
  p_offset integer default 0
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
     order by s.created_at asc, s.id asc
     limit greatest(1, least(coalesce(p_limit, 50), 100))
    offset greatest(0, least(coalesce(p_offset, 0), 100000));
end;
$function$;

revoke all on function public.moderator_list_founder_postmortems_page(text, integer, integer) from public, anon;
grant execute on function public.moderator_list_founder_postmortems_page(text, integer, integer) to authenticated;
comment on function public.moderator_list_founder_postmortems_page(text, integer, integer) is
  'Returns bounded pages of private founder post-mortem submissions only to users in private.moderators.';
