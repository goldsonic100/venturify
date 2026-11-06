-- Let authors respond to moderator edit requests without granting direct UPDATE access.
-- The RPC only permits revisions of the caller's own needs_edits submission.

create or replace function public.revise_my_founder_postmortem(
  p_story_id uuid,
  p_company_name text,
  p_industry text,
  p_company_stage text,
  p_primary_lesson text,
  p_summary text,
  p_what_happened text,
  p_lessons_learned text,
  p_financial_context text,
  p_author_display_mode text,
  p_company_visibility text,
  p_consent_to_publish boolean
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in required' using errcode = '42501';
  end if;

  if p_consent_to_publish is distinct from true then
    raise exception 'Explicit publication consent is required' using errcode = '22023';
  end if;

  update public.founder_postmortems
     set company_name = coalesce(p_company_name, ''),
         industry = p_industry,
         company_stage = p_company_stage,
         primary_lesson = p_primary_lesson,
         summary = p_summary,
         what_happened = p_what_happened,
         lessons_learned = p_lessons_learned,
         financial_context = coalesce(p_financial_context, ''),
         author_display_mode = p_author_display_mode,
         company_visibility = p_company_visibility,
         consent_to_publish = true,
         consent_version = 'postmortem-consent-v1',
         consent_at = now(),
         status = 'pending',
         moderator_notes = '',
         reviewed_at = null,
         reviewed_by = null,
         updated_at = now()
   where id = p_story_id
     and author_id = (select auth.uid())
     and status = 'needs_edits';

  if not found then
    raise exception 'Submission is not available for revision' using errcode = 'P0002';
  end if;
  return true;
end;
$function$;

revoke all on function public.revise_my_founder_postmortem(uuid,text,text,text,text,text,text,text,text,text,text,boolean) from public, anon;
grant execute on function public.revise_my_founder_postmortem(uuid,text,text,text,text,text,text,text,text,text,text,boolean) to authenticated;

comment on function public.revise_my_founder_postmortem(uuid,text,text,text,text,text,text,text,text,text,text,boolean) is
  'Allows an author to revise only their own needs_edits post-mortem, re-confirm publication consent, and resubmit it to the private moderator queue.';
