-- Preserve the identity and collaboration binding of an existing workspace.
-- Workspace title and goal remain editable by accepted collaborators.
create or replace function private.guard_workspace_identity_update()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $function$
begin
  if new.id is distinct from old.id
     or new.collaboration_request_id is distinct from old.collaboration_request_id
     or new.created_by is distinct from old.created_by
     or new.created_at is distinct from old.created_at then
    raise exception 'Workspace identity fields cannot be changed'
      using errcode = '42501';
  end if;

  new.updated_at := now();
  return new;
end;
$function$;

drop trigger if exists guard_workspace_identity_update on public.collaboration_workspaces;
create trigger guard_workspace_identity_update
before update on public.collaboration_workspaces
for each row
execute function private.guard_workspace_identity_update();

revoke all on function private.guard_workspace_identity_update() from public, anon, authenticated;
