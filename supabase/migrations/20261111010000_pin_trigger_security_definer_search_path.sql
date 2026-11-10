-- Pin every remaining SECURITY DEFINER trigger function to an empty search_path.
-- Qualify auth.uid() explicitly so auth helpers continue to resolve without a search path.
-- Public table references are already schema-qualified in these function bodies.

create or replace function public.log_workspace_activity_event()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  wid uuid; eid uuid; actor uuid := auth.uid(); kind text; etype text;
  summary_text text; detail_json jsonb := '{}'::jsonb;
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
  insert into public.workspace_activity_events(workspace_id,actor_id,event_type,entity_type,entity_id,summary,details)
  values(wid,actor,kind,etype,eid,summary_text,detail_json);
  if TG_OP='DELETE' then return OLD; end if;
  return NEW;
end;
$function$;

create or replace function public.log_workspace_task_checklist_activity()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  task_title text; action_type text; action_summary text; actor uuid:=auth.uid();
  wid uuid; tid uuid; item_title text; completed boolean;
begin
  if TG_OP='DELETE' then wid:=OLD.workspace_id; tid:=OLD.task_id; item_title:=OLD.title; completed:=OLD.is_complete;
  else wid:=NEW.workspace_id; tid:=NEW.task_id; item_title:=NEW.title; completed:=NEW.is_complete; end if;
  select t.title into task_title from public.workspace_tasks t where t.id=tid and t.workspace_id=wid;
  if TG_OP='INSERT' then action_type:='checklist_item_added'; action_summary:='Added checklist item to '||coalesce(task_title,'task');
  elsif TG_OP='DELETE' then action_type:='checklist_item_deleted'; action_summary:='Removed checklist item from '||coalesce(task_title,'task');
  elsif OLD.is_complete is distinct from NEW.is_complete then action_type:=case when NEW.is_complete then 'checklist_item_completed' else 'checklist_item_reopened' end; action_summary:=case when NEW.is_complete then 'Completed checklist item in ' else 'Reopened checklist item in ' end||coalesce(task_title,'task');
  elsif OLD.title is distinct from NEW.title then action_type:='checklist_item_renamed'; action_summary:='Renamed checklist item in '||coalesce(task_title,'task');
  else return NEW; end if;
  insert into public.workspace_activity_events(workspace_id,actor_id,event_type,entity_type,entity_id,summary,details)
  values(wid,actor,action_type,'task',tid,left(action_summary,240),jsonb_build_object('task_id',tid,'task_title',task_title,'item_title',item_title,'is_complete',completed));
  if TG_OP='DELETE' then return OLD; else return NEW; end if;
end;
$function$;

create or replace function public.notify_workspace_checklist_completion()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_recipient uuid;
  v_request public.collaboration_requests%rowtype;
begin
  if tg_op <> 'UPDATE' or old.is_complete is true or new.is_complete is not true or v_actor is null then return new; end if;
  if exists (select 1 from public.workspace_task_checklist_items i where i.task_id=new.task_id and i.workspace_id=new.workspace_id and i.is_complete is false) then return new; end if;
  select cr.* into v_request
  from public.collaboration_workspaces w
  join public.collaboration_requests cr on cr.id=w.collaboration_request_id
  where w.id=new.workspace_id and cr.status='accepted' limit 1;
  if not found or v_actor not in (v_request.requester_id,v_request.recipient_id) then return new; end if;
  if v_actor=v_request.requester_id then v_recipient:=v_request.recipient_id; else v_recipient:=v_request.requester_id; end if;
  if v_recipient is null or v_recipient=v_actor then return new; end if;
  if exists (select 1 from public.notifications n where n.recipient_id=v_recipient and n.task_id=new.task_id and n.type='checklist_completed' and n.created_at>now()-interval '24 hours') then return new; end if;
  insert into public.notifications(recipient_id,actor_id,type,workspace_id,collaboration_request_id,task_id)
  values(v_recipient,v_actor,'checklist_completed',new.workspace_id,v_request.id,new.task_id);
  return new;
end;
$function$;

create or replace function public.notify_workspace_task_change()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  actor uuid := coalesce(auth.uid(),case when TG_OP='DELETE' then OLD.created_by else NEW.created_by end);
  wid uuid; task_id_value uuid; task_title text; assigned_value uuid; due_value date;
  req record; recipient uuid;
begin
  if TG_OP='DELETE' then wid:=OLD.workspace_id; task_id_value:=OLD.id; task_title:=OLD.title; assigned_value:=OLD.assigned_to; due_value:=OLD.due_date;
  else wid:=NEW.workspace_id; task_id_value:=NEW.id; task_title:=NEW.title; assigned_value:=NEW.assigned_to; due_value:=NEW.due_date; end if;
  select r.requester_id,r.recipient_id into req
  from public.collaboration_workspaces w
  join public.collaboration_requests r on r.id=w.collaboration_request_id
  where w.id=wid and r.status='accepted';
  if not found then if TG_OP='DELETE' then return OLD; else return NEW; end if; end if;
  if TG_OP='INSERT' then
    if assigned_value is not null and assigned_value<>actor then
      insert into public.notifications(recipient_id,actor_id,type,workspace_id,task_id,deadline_date) values(assigned_value,actor,'task_assigned',wid,task_id_value,due_value);
    end if;
  elsif TG_OP='UPDATE' then
    if NEW.assigned_to is distinct from OLD.assigned_to and NEW.assigned_to is not null and NEW.assigned_to<>actor then
      insert into public.notifications(recipient_id,actor_id,type,workspace_id,task_id,deadline_date) values(NEW.assigned_to,actor,'task_assigned',wid,task_id_value,NEW.due_date);
    end if;
    if (NEW.title is distinct from OLD.title or NEW.status is distinct from OLD.status or NEW.due_date is distinct from OLD.due_date or NEW.details is distinct from OLD.details or NEW.milestone_id is distinct from OLD.milestone_id)
       and (NEW.assigned_to is not distinct from OLD.assigned_to) then
      recipient:=case when req.requester_id=actor then req.recipient_id else req.requester_id end;
      if recipient is not null and recipient<>actor then
        insert into public.notifications(recipient_id,actor_id,type,workspace_id,task_id,deadline_date) values(recipient,actor,'task_updated',wid,task_id_value,NEW.due_date);
      end if;
    end if;
  end if;
  if TG_OP='DELETE' then return OLD; else return NEW; end if;
end;
$function$;

create or replace function public.notify_workspace_task_changes()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid; v_request record; v_partner uuid; v_type text;
  v_task_changed boolean:=false; v_assignment_changed boolean:=false;
begin
  v_actor:=coalesce(auth.uid(),new.created_by);
  select r.requester_id,r.recipient_id,r.id into v_request
  from public.collaboration_workspaces w
  join public.collaboration_requests r on r.id=w.collaboration_request_id
  where w.id=new.workspace_id and r.status='accepted' limit 1;
  if not found or v_actor is null or (v_actor<>v_request.requester_id and v_actor<>v_request.recipient_id) then return new; end if;
  v_partner:=case when v_actor=v_request.requester_id then v_request.recipient_id else v_request.requester_id end;
  if tg_op='INSERT' then
    if new.assigned_to is not null and new.assigned_to<>v_actor then
      insert into public.notifications(recipient_id,actor_id,type,workspace_id,collaboration_request_id,task_id,deadline_date)
      values(new.assigned_to,v_actor,'task_assigned',new.workspace_id,v_request.id,new.id,new.due_date);
    elsif v_partner is not null and v_partner<>v_actor then
      insert into public.notifications(recipient_id,actor_id,type,workspace_id,collaboration_request_id,task_id,deadline_date)
      values(v_partner,v_actor,'task_updated',new.workspace_id,v_request.id,new.id,new.due_date);
    end if;
    return new;
  end if;
  v_assignment_changed:=new.assigned_to is distinct from old.assigned_to;
  v_task_changed:=new.status is distinct from old.status or new.title is distinct from old.title or new.details is distinct from old.details or new.due_date is distinct from old.due_date or new.milestone_id is distinct from old.milestone_id or v_assignment_changed;
  if v_assignment_changed and new.assigned_to is not null and new.assigned_to<>v_actor and new.assigned_to in (v_request.requester_id,v_request.recipient_id) then
    insert into public.notifications(recipient_id,actor_id,type,workspace_id,collaboration_request_id,task_id,deadline_date)
    values(new.assigned_to,v_actor,'task_assigned',new.workspace_id,v_request.id,new.id,new.due_date);
  end if;
  if v_task_changed and v_partner is not null and v_partner<>v_actor and (not v_assignment_changed or v_partner is distinct from new.assigned_to) then
    v_type:=case when new.status is distinct from old.status and new.status='done' then 'task_completed' else 'task_updated' end;
    insert into public.notifications(recipient_id,actor_id,type,workspace_id,collaboration_request_id,task_id,deadline_date)
    values(v_partner,v_actor,v_type,new.workspace_id,v_request.id,new.id,new.due_date);
  end if;
  return new;
end;
$function$;

-- These three trigger functions use only schema-qualified public objects and pg_catalog
-- built-ins, so pinning an empty path requires no body changes.
alter function public.notify_workspace_message() set search_path = '';
alter function public.notify_workspace_task_comment() set search_path = '';
alter function public.rls_auto_enable() set search_path = '';
