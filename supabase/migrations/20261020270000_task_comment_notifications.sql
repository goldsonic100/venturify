alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check check (type = any (array[
'follow','like','comment','message','mention','collaboration_request','collaboration_accepted','collaboration_declined',
'workspace_created','workspace_updated','task_assigned','task_updated','project_message','task_due_soon','task_overdue','task_comment'
]::text[]));

create or replace function public.notify_workspace_task_comment()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  request_row public.collaboration_requests%rowtype;
  recipient uuid;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  select cr.* into request_row
  from public.collaboration_workspaces w
  join public.collaboration_requests cr on cr.id = w.collaboration_request_id
  where w.id = new.workspace_id
    and cr.status = 'accepted'
  limit 1;

  if not found then
    return new;
  end if;

  if new.author_id = request_row.requester_id then
    recipient := request_row.recipient_id;
  elsif new.author_id = request_row.recipient_id then
    recipient := request_row.requester_id;
  else
    return new;
  end if;

  if recipient is not null and recipient <> new.author_id then
    insert into public.notifications (recipient_id, actor_id, type, workspace_id, collaboration_request_id, task_id)
    values (recipient, new.author_id, 'task_comment', new.workspace_id, request_row.id, new.task_id);
  end if;
  return new;
end;
$$;

revoke all on function public.notify_workspace_task_comment() from public, anon, authenticated;
drop trigger if exists workspace_task_comment_notify on public.workspace_task_comments;
create trigger workspace_task_comment_notify
after insert on public.workspace_task_comments
for each row execute function public.notify_workspace_task_comment();