-- Keep checklist item ownership and task scope immutable after creation.
create or replace function public.guard_workspace_task_checklist_item()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if TG_OP = 'UPDATE' then
    new.workspace_id := old.workspace_id;
    new.task_id := old.task_id;
    new.created_by := old.created_by;
    new.created_at := old.created_at;
    new.updated_at := now();
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_workspace_task_checklist_item() from public, anon, authenticated;
drop trigger if exists workspace_task_checklist_item_guard on public.workspace_task_checklist_items;
create trigger workspace_task_checklist_item_guard
before update on public.workspace_task_checklist_items
for each row execute function public.guard_workspace_task_checklist_item();