create or replace function private.verify_daily_founder_match_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  checked_viewer uuid;
  existing_count integer;
begin
  for checked_viewer in
    select distinct viewer_id from inserted_matches
  loop
    select count(*) into existing_count
    from public.founder_match_impressions
    where viewer_id = checked_viewer
      and match_date = timezone('utc', now())::date;

    if existing_count > 6 then
      raise exception 'You can only receive six free founder matches per day.';
    end if;
  end loop;
  return null;
end;
$$;

drop trigger if exists verify_daily_founder_match_limit on public.founder_match_impressions;
create trigger verify_daily_founder_match_limit
after insert on public.founder_match_impressions
referencing new table as inserted_matches
for each statement
execute function private.verify_daily_founder_match_limit();
