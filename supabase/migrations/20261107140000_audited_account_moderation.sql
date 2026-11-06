-- Audited account warnings and narrow posting restrictions for moderators.
-- This intentionally does not alter authentication credentials, sessions, or private messages.

create table if not exists private.account_moderation_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'clear'
    check (status in ('clear', 'warning', 'posting_restricted')),
  reason text not null default '',
  expires_at timestamptz,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint account_moderation_expiry_only_for_restrictions
    check (status = 'posting_restricted' or expires_at is null)
);

create table if not exists private.account_moderation_audit (
  event_id bigint generated always as identity primary key,
  target_user_id uuid not null references auth.users(id) on delete cascade,
  moderator_id uuid not null references auth.users(id) on delete restrict,
  action text not null check (action in ('warning', 'posting_restricted', 'restore')),
  previous_status text not null check (previous_status in ('clear', 'warning', 'posting_restricted')),
  new_status text not null check (new_status in ('clear', 'warning', 'posting_restricted')),
  reason text not null check (char_length(reason) between 8 and 1000),
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists account_moderation_audit_target_created_idx
  on private.account_moderation_audit (target_user_id, created_at desc);

alter table private.account_moderation_state enable row level security;
alter table private.account_moderation_audit enable row level security;
revoke all on table private.account_moderation_state from public, anon, authenticated;
revoke all on table private.account_moderation_audit from public, anon, authenticated;
revoke all on sequence private.account_moderation_audit_event_id_seq from public, anon, authenticated;

create or replace function private.account_can_publish(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select
    p_user_id is not null
    and p_user_id = (select auth.uid())
    and not exists (
      select 1
      from private.account_moderation_state s
      where s.user_id = p_user_id
        and s.status = 'posting_restricted'
        and (s.expires_at is null or s.expires_at > now())
    );
$function$;

revoke execute on function private.account_can_publish(uuid) from public, anon;
grant execute on function private.account_can_publish(uuid) to authenticated;

drop policy if exists "Moderator posting restriction guard: posts" on public.posts;
create policy "Moderator posting restriction guard: posts"
  on public.posts as restrictive
  for insert to authenticated
  with check (private.account_can_publish((select auth.uid())));

drop policy if exists "Moderator posting restriction guard: comments" on public.comments;
create policy "Moderator posting restriction guard: comments"
  on public.comments as restrictive
  for insert to authenticated
  with check (private.account_can_publish((select auth.uid())));

create or replace function public.moderator_list_account_moderation(p_user_ids uuid[])
returns table (
  user_id uuid,
  status text,
  reason text,
  expires_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if (select auth.uid()) is null or not exists (
    select 1 from private.moderators m where m.user_id = (select auth.uid())
  ) then
    raise exception 'Moderator access required' using errcode = '42501';
  end if;

  if p_user_ids is null or cardinality(p_user_ids) > 50 then
    raise exception 'Provide at most 50 account IDs' using errcode = '22023';
  end if;

  return query
    select requested.user_id,
           case when s.status = 'posting_restricted'
                     and s.expires_at is not null
                     and s.expires_at <= now()
                then 'clear'
                else coalesce(s.status, 'clear')
           end,
           coalesce(s.reason, ''),
           s.expires_at,
           s.updated_at
    from (select distinct unnest(p_user_ids) as user_id) requested
    left join private.account_moderation_state s on s.user_id = requested.user_id;
end;
$function$;

create or replace function public.moderator_get_account_moderation_history(p_target_user_id uuid)
returns table (
  event_id bigint,
  action text,
  previous_status text,
  new_status text,
  reason text,
  expires_at timestamptz,
  moderator_id uuid,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if (select auth.uid()) is null or not exists (
    select 1 from private.moderators m where m.user_id = (select auth.uid())
  ) then
    raise exception 'Moderator access required' using errcode = '42501';
  end if;

  if p_target_user_id is null then
    raise exception 'Target account is required' using errcode = '22023';
  end if;

  return query
    select a.event_id, a.action, a.previous_status, a.new_status,
           a.reason, a.expires_at, a.moderator_id, a.created_at
    from private.account_moderation_audit a
    where a.target_user_id = p_target_user_id
    order by a.created_at desc, a.event_id desc
    limit 100;
end;
$function$;

create or replace function public.moderator_set_account_action(
  p_target_user_id uuid,
  p_action text,
  p_reason text,
  p_duration_hours integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_moderator_id uuid := (select auth.uid());
  v_previous_status text;
  v_new_status text;
  v_expires_at timestamptz := null;
  v_reason text := left(trim(coalesce(p_reason, '')), 1000);
begin
  if v_moderator_id is null or not exists (
    select 1 from private.moderators m where m.user_id = v_moderator_id
  ) then
    raise exception 'Moderator access required' using errcode = '42501';
  end if;

  if p_target_user_id is null or p_target_user_id = v_moderator_id then
    raise exception 'Choose another account to moderate' using errcode = '22023';
  end if;

  if not exists (select 1 from public.profiles p where p.id = p_target_user_id) then
    raise exception 'Account not found' using errcode = 'P0002';
  end if;

  if exists (select 1 from private.moderators m where m.user_id = p_target_user_id) then
    raise exception 'Moderator accounts cannot be actioned from this workflow' using errcode = '42501';
  end if;

  if p_action not in ('warning', 'posting_restricted', 'restore') then
    raise exception 'Invalid account action' using errcode = '22023';
  end if;

  if char_length(v_reason) < 8 then
    raise exception 'A reason of at least 8 characters is required' using errcode = '22023';
  end if;

  if p_action = 'posting_restricted' then
    if p_duration_hours not in (0, 24, 168) then
      raise exception 'Restriction duration must be 24 hours, 7 days, or until manually restored' using errcode = '22023';
    end if;
    if p_duration_hours = 0 then
      v_expires_at := null;
    else
      v_expires_at := now() + make_interval(hours => p_duration_hours);
    end if;
    v_new_status := 'posting_restricted';
  elsif p_action = 'warning' then
    v_new_status := 'warning';
  else
    v_new_status := 'clear';
  end if;

  select case
           when s.status = 'posting_restricted'
                and (s.expires_at is null or s.expires_at > now())
             then 'posting_restricted'
           else coalesce(s.status, 'clear')
         end
    into v_previous_status
  from (select 1) seed
  left join private.account_moderation_state s on s.user_id = p_target_user_id;

  if p_action = 'warning' and v_previous_status = 'posting_restricted' then
    raise exception 'Restore or let the active posting restriction expire before issuing a warning' using errcode = '22023';
  end if;

  insert into private.account_moderation_state (user_id, status, reason, expires_at, updated_by, updated_at)
  values (p_target_user_id, v_new_status, v_reason, v_expires_at, v_moderator_id, now())
  on conflict (user_id) do update
    set status = excluded.status,
        reason = excluded.reason,
        expires_at = excluded.expires_at,
        updated_by = excluded.updated_by,
        updated_at = now();

  insert into private.account_moderation_audit (
    target_user_id, moderator_id, action, previous_status, new_status, reason, expires_at
  ) values (
    p_target_user_id, v_moderator_id, p_action, v_previous_status, v_new_status, v_reason, v_expires_at
  );

  return jsonb_build_object(
    'user_id', p_target_user_id,
    'status', v_new_status,
    'expires_at', v_expires_at,
    'updated_at', now()
  );
end;
$function$;

revoke execute on function public.moderator_list_account_moderation(uuid[]) from public, anon;
revoke execute on function public.moderator_get_account_moderation_history(uuid) from public, anon;
revoke execute on function public.moderator_set_account_action(uuid, text, text, integer) from public, anon;
grant execute on function public.moderator_list_account_moderation(uuid[]) to authenticated;
grant execute on function public.moderator_get_account_moderation_history(uuid) to authenticated;
grant execute on function public.moderator_set_account_action(uuid, text, text, integer) to authenticated;
