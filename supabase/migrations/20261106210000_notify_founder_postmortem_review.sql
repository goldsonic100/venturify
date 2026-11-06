-- Notify founders when a moderator changes the review status of their submission.
alter table public.notifications add column if not exists founder_postmortem_id uuid references public.founder_postmortems(id) on delete cascade;
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check check (type = any (array['follow','like','comment','message','mention','collaboration_request','collaboration_accepted','collaboration_declined','workspace_created','workspace_updated','task_assigned','task_updated','project_message','task_due_soon','task_overdue','task_comment','task_completed','checklist_completed','postmortem_review']::text[]));
create index if not exists notifications_founder_postmortem_id_idx on public.notifications (founder_postmortem_id) where founder_postmortem_id is not null;
create or replace function public.moderator_review_founder_postmortem(p_story_id uuid,p_status text,p_moderator_notes text default '') returns boolean language plpgsql security definer set search_path = '' as $function$
declare v_author_id uuid;
begin
 if (select auth.uid()) is null or not exists (select 1 from private.moderators m where m.user_id=(select auth.uid())) then raise exception 'Moderator access required' using errcode='42501'; end if;
 if p_status not in ('needs_edits','approved','rejected') then raise exception 'Review status must be needs_edits, approved, or rejected' using errcode='22023'; end if;
 if char_length(coalesce(p_moderator_notes,''))>2000 then raise exception 'Moderator notes must be 2000 characters or fewer' using errcode='22001'; end if;
 select s.author_id into v_author_id from public.founder_postmortems s where s.id=p_story_id and s.status in ('pending','needs_edits') for update;
 if not found then raise exception 'Submission not found or no longer reviewable' using errcode='P0002'; end if;
 update public.founder_postmortems set status=p_status,moderator_notes=coalesce(p_moderator_notes,''),reviewed_at=now(),reviewed_by=(select auth.uid()),updated_at=now() where id=p_story_id and status in ('pending','needs_edits');
 if not found then raise exception 'Submission not found or no longer reviewable' using errcode='P0002'; end if;
 if v_author_id<>(select auth.uid()) then insert into public.notifications(recipient_id,actor_id,type,founder_postmortem_id) values(v_author_id,(select auth.uid()),'postmortem_review',p_story_id); end if;
 return true;
end;
$function$;
revoke all on function public.moderator_review_founder_postmortem(uuid,text,text) from public,anon;
grant execute on function public.moderator_review_founder_postmortem(uuid,text,text) to authenticated;
