-- Moderator-only timeline of restriction appeals and their recorded events.
create index if not exists account_moderation_appeals_user_created_idx
  on private.account_moderation_appeals (user_id, created_at desc, appeal_id desc);

create or replace function public.moderator_get_account_appeal_history(
  p_target_user_id uuid
)
returns table (
  appeal_id bigint,
  status text,
  statement text,
  moderator_message text,
  event_type text,
  event_message text,
  actor_id uuid,
  event_created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if (select auth.uid()) is null or not exists (
    select 1 from private.moderators m
    where m.user_id = (select auth.uid())
  ) then
    raise exception 'Moderator access required' using errcode = '42501';
  end if;

  if p_target_user_id is null then
    raise exception 'Target account is required' using errcode = '22023';
  end if;

  return query
    select a.appeal_id, a.status, a.statement,
           coalesce(a.moderator_message, ''),
           e.event_type, e.message, e.actor_id, e.created_at
    from private.account_moderation_appeals a
    join private.account_moderation_appeal_events e
      on e.appeal_id = a.appeal_id
    where a.user_id = p_target_user_id
    order by e.created_at desc, e.event_id desc
    limit 100;
end;
$function$;

revoke all on function public.moderator_get_account_appeal_history(uuid)
  from public, anon;
grant execute on function public.moderator_get_account_appeal_history(uuid)
  to authenticated;

comment on function public.moderator_get_account_appeal_history(uuid) is
  'Returns up to 100 appeal timeline events for a target account to allowlisted moderators only.';
