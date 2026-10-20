-- Persistent workspace activity audit trail.
create table if not exists public.workspace_activity_events (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.collaboration_workspaces(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  event_type text not null check (char_length(event_type) <= 60),
  entity_type text not null check (entity_type in ('task','milestone','project')),
  entity_id uuid,
  summary text not null check (char_length(summary) <= 240),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists workspace_activity_events_workspace_created_idx on public.workspace_activity_events(workspace_id, created_at desc);
alter table public.workspace_activity_events enable row level security;
drop policy if exists "Accepted collaborators can view workspace activity" on public.workspace_activity_events;
create policy "Accepted collaborators can view workspace activity" on public.workspace_activity_events for select to authenticated using (
 exists (select 1 from public.collaboration_workspaces w join public.collaboration_requests r on r.id=w.collaboration_request_id
 where w.id=workspace_activity_events.workspace_id and r.status='accepted' and (auth.uid()=r.requester_id or auth.uid()=r.recipient_id))
);
revoke insert, update, delete on public.workspace_activity_events from anon, authenticated;
grant select on public.workspace_activity_events to authenticated;

create or replace function public.log_workspace_activity_event()
returns trigger language plpgsql security definer set search_path = pg_catalog, public
as $$
declare
  wid uuid; eid uuid; actor uuid := auth.uid(); kind text; etype text; summary_text text; detail_json jsonb := '{}'::jsonb;
begin
  if TG_TABLE_NAME='workspace_tasks' then
    wid := case when TG_OP='DELETE' then OLD.workspace_id else NEW.workspace_id end;
    eid := case when TG_OP='DELETE' then OLD.id else NEW.id end; etype := 'task';
    if TG_OP='INSERT' then
      kind := 'task_created'; summary_text := 'Created task: '||coalesce(NEW.title,'Untitled task');
      detail_json := jsonb_build_object('title',NEW.title,'status',NEW.status,'assigned_to',NEW.assigned_to,'due_date',NEW.due_date,'milestone_id',NEW.milestone_id);
    elsif TG_OP='DELETE' then
      kind := 'task_deleted'; summary_text := 'Deleted task: '||coalesce(OLD.title,'Untitled task');
      detail_json := jsonb_build_object('title',OLD.title,'status',OLD.status);
    else
      if OLD.title is distinct from NEW.title then kind:='task_edited'; summary_text:='Renamed task: '||coalesce(NEW.title,'Untitled task'); detail_json:=jsonb_build_object('old_title',OLD.title,'title',NEW.title);
      elsif OLD.status is distinct from NEW.status then kind:=case when NEW.status='done' then 'task_completed' else 'task_status_changed' end; summary_text:=case when NEW.status='done' then 'Completed task: ' else 'Changed task status: ' end||coalesce(NEW.title,'Untitled task'); detail_json:=jsonb_build_object('title',NEW.title,'old_status',OLD.status,'status',NEW.status);
      elsif OLD.assigned_to is distinct from NEW.assigned_to then kind:='task_reassigned'; summary_text:='Changed task assignment: '||coalesce(NEW.title,'Untitled task'); detail_json:=jsonb_build_object('title',NEW.title,'old_assigned_to',OLD.assigned_to,'assigned_to',NEW.assigned_to);
      elsif OLD.due_date is distinct from NEW.due_date then kind:='task_due_date_changed'; summary_text:='Changed task deadline: '||coalesce(NEW.title,'Untitled task'); detail_json:=jsonb_build_object('title',NEW.title,'old_due_date',OLD.due_date,'due_date',NEW.due_date);
      elsif OLD.milestone_id is distinct from NEW.milestone_id then kind:='task_milestone_changed'; summary_text:='Updated task milestone: '||coalesce(NEW.title,'Untitled task'); detail_json:=jsonb_build_object('title',NEW.title,'old_milestone_id',OLD.milestone_id,'milestone_id',NEW.milestone_id);
      elsif OLD.details is distinct from NEW.details then kind:='task_notes_changed'; summary_text:='Updated task notes: '||coalesce(NEW.title,'Untitled task'); detail_json:=jsonb_build_object('title',NEW.title);
      else return NEW; end if;
    end if;
  elsif TG_TABLE_NAME='workspace_milestones' then
    wid := case when TG_OP='DELETE' then OLD.workspace_id else NEW.workspace_id end;
    eid := case when TG_OP='DELETE' then OLD.id else NEW.id end; etype:='milestone';
    if TG_OP='INSERT' then kind:='milestone_created'; summary_text:='Created milestone: '||coalesce(NEW.title,'Untitled milestone'); detail_json:=jsonb_build_object('title',NEW.title,'target_date',NEW.target_date);
    elsif TG_OP='DELETE' then kind:='milestone_deleted'; summary_text:='Deleted milestone: '||coalesce(OLD.title,'Untitled milestone'); detail_json:=jsonb_build_object('title',OLD.title,'target_date',OLD.target_date);
    else
      if OLD.title is distinct from NEW.title then kind:='milestone_edited'; summary_text:='Renamed milestone: '||coalesce(NEW.title,'Untitled milestone'); detail_json:=jsonb_build_object('old_title',OLD.title,'title',NEW.title);
      elsif OLD.target_date is distinct from NEW.target_date then kind:='milestone_deadline_changed'; summary_text:='Changed milestone deadline: '||coalesce(NEW.title,'Untitled milestone'); detail_json:=jsonb_build_object('title',NEW.title,'old_target_date',OLD.target_date,'target_date',NEW.target_date);
      elsif OLD.description is distinct from NEW.description then kind:='milestone_edited'; summary_text:='Updated milestone details: '||coalesce(NEW.title,'Untitled milestone'); detail_json:=jsonb_build_object('title',NEW.title);
      else return NEW; end if;
    end if;
  elsif TG_TABLE_NAME='collaboration_workspaces' then
    wid:=NEW.id; eid:=NEW.id; etype:='project';
    if OLD.title is distinct from NEW.title or OLD.goal is distinct from NEW.goal then kind:='project_edited'; summary_text:='Updated project details'; detail_json:=jsonb_build_object('old_title',OLD.title,'title',NEW.title,'goal_changed',OLD.goal is distinct from NEW.goal);
    else return NEW; end if;
  else return case when TG_OP='DELETE' then OLD else NEW end;
  end if;
  insert into public.workspace_activity_events(workspace_id,actor_id,event_type,entity_type,entity_id,summary,details) values(wid,actor,kind,etype,eid,summary_text,detail_json);
  if TG_OP='DELETE' then return OLD; end if; return NEW;
end;
$$;
revoke all on function public.log_workspace_activity_event() from public, anon, authenticated;
drop trigger if exists workspace_tasks_activity_event on public.workspace_tasks;
create trigger workspace_tasks_activity_event after insert or update or delete on public.workspace_tasks for each row execute function public.log_workspace_activity_event();
drop trigger if exists workspace_milestones_activity_event on public.workspace_milestones;
create trigger workspace_milestones_activity_event after insert or update or delete on public.workspace_milestones for each row execute function public.log_workspace_activity_event();
drop trigger if exists collaboration_workspaces_activity_event on public.collaboration_workspaces;
create trigger collaboration_workspaces_activity_event after update on public.collaboration_workspaces for each row execute function public.log_workspace_activity_event();
do $$ begin alter publication supabase_realtime add table public.workspace_activity_events; exception when duplicate_object then null; when undefined_object then null; end $$;
