-- Enforce the free-plan community membership limit in the database.
-- A trigger prevents bypassing the UI and serializes joins per user.
create or replace function private.enforce_free_community_membership_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_count integer;
begin
  if auth.uid() is null or new.user_id <> auth.uid() then
    raise exception 'You can only join communities as yourself.';
  end if;

  -- Serialize joins for this user so simultaneous requests cannot bypass the cap.
  perform 1 from public.profiles where id = new.user_id for update;

  select count(*) into existing_count
  from public.community_members
  where user_id = new.user_id;

  if existing_count >= 3 then
    raise exception 'Free accounts can join up to three communities.';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_free_community_membership_limit on public.community_members;
create trigger enforce_free_community_membership_limit
before insert on public.community_members
for each row execute function private.enforce_free_community_membership_limit();

revoke all on function private.enforce_free_community_membership_limit() from public, anon, authenticated;
