-- Venturify public handles: allow a username change once every 30 days.
-- Existing users may change their handle once after this migration; the database
-- then enforces the cooldown for all future changes.

alter table public.profiles
  add column if not exists username_changed_at timestamptz;

create or replace function public.enforce_profile_username_cooldown()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.username is distinct from old.username then
    if new.username !~ '^[a-z0-9_]{3,24}$' then
      raise exception 'Handle must be 3–24 characters and use only lowercase letters, numbers, or underscores.';
    end if;

    if old.username_changed_at is not null
       and old.username_changed_at > now() - interval '30 days' then
      raise exception 'You can change your handle once every 30 days. Your next change is available after %.',
        to_char(old.username_changed_at + interval '30 days', 'Mon DD, YYYY');
    end if;

    new.username_changed_at := now();
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_username_cooldown on public.profiles;
create trigger profiles_username_cooldown
before update of username on public.profiles
for each row
execute function public.enforce_profile_username_cooldown();
