-- Private, audited account restriction appeal workflow.
create table if not exists private.account_moderation_appeals (
 appeal_id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 statement text not null check(char_length(statement) between 30 and 2000),
 status text not null default 'submitted' check(status in ('submitted','under_review','accepted','denied')),
 moderator_message text,
 reviewed_by uuid references auth.users(id) on delete set null,
 reviewed_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint account_moderation_appeal_review_fields check(
  (status in ('submitted','under_review') and reviewed_at is null) or
  (status in ('accepted','denied') and reviewed_at is not null))
);
create unique index if not exists account_moderation_one_open_appeal_per_user on private.account_moderation_appeals(user_id) where status in ('submitted','under_review');
create index if not exists account_moderation_appeals_status_created_idx on private.account_moderation_appeals(status,created_at desc);
create table if not exists private.account_moderation_appeal_events(
 event_id bigint generated always as identity primary key,
 appeal_id bigint not null references private.account_moderation_appeals(appeal_id) on delete cascade,
 actor_id uuid not null references auth.users(id) on delete restrict,
 event_type text not null check(event_type in ('submitted','under_review','accepted','denied')),
 message text not null check(char_length(message) between 1 and 2000),
 created_at timestamptz not null default now()
);
create index if not exists account_moderation_appeal_events_appeal_created_idx on private.account_moderation_appeal_events(appeal_id,created_at desc);
alter table private.account_moderation_appeals enable row level security;
alter table private.account_moderation_appeal_events enable row level security;
revoke all on table private.account_moderation_appeals from public,anon,authenticated;
revoke all on table private.account_moderation_appeal_events from public,anon,authenticated;
revoke all on sequence private.account_moderation_appeals_appeal_id_seq from public,anon,authenticated;
revoke all on sequence private.account_moderation_appeal_events_event_id_seq from public,anon,authenticated;
alter table private.account_moderation_audit drop constraint if exists account_moderation_audit_action_check;
alter table private.account_moderation_audit add constraint account_moderation_audit_action_check check(action in ('warning','posting_restricted','restore','appeal_accepted'));

create or replace function public.get_my_account_moderation_status()
returns table(status text,reason text,expires_at timestamptz,appeal_id bigint,appeal_status text,appeal_statement text,appeal_submitted_at timestamptz,appeal_decision_message text,appeal_reviewed_at timestamptz)
language plpgsql security definer set search_path=''
as $$
declare v_user_id uuid := (select auth.uid());
begin
 if v_user_id is null then raise exception 'Sign in required' using errcode='42501'; end if;
 return query select case when s.status='posting_restricted' and s.expires_at is not null and s.expires_at<=now() then 'clear' else coalesce(s.status,'clear') end,
 coalesce(s.reason,''),s.expires_at,a.appeal_id,a.status,a.statement,a.created_at,a.moderator_message,a.reviewed_at
 from (select 1) seed left join private.account_moderation_state s on s.user_id=v_user_id
 left join lateral(select x.* from private.account_moderation_appeals x where x.user_id=v_user_id order by x.created_at desc,x.appeal_id desc limit 1)a on true;
end $$;

create or replace function public.submit_account_moderation_appeal(p_statement text)
returns bigint language plpgsql security definer set search_path=''
as $$
declare v_user_id uuid := (select auth.uid()); v_appeal_id bigint; v_statement text := trim(coalesce(p_statement,''));
begin
 if v_user_id is null then raise exception 'Sign in required' using errcode='42501'; end if;
 if char_length(v_statement)<30 or char_length(v_statement)>2000 then raise exception 'Appeal must be between 30 and 2000 characters' using errcode='22023'; end if;
 if not exists(select 1 from private.account_moderation_state s where s.user_id=v_user_id and s.status='posting_restricted' and (s.expires_at is null or s.expires_at>now())) then raise exception 'No active posting restriction is eligible for appeal' using errcode='22023'; end if;
 if exists(select 1 from private.account_moderation_appeals a where a.user_id=v_user_id and a.status in ('submitted','under_review')) then raise exception 'You already have an open appeal' using errcode='23505'; end if;
 insert into private.account_moderation_appeals(user_id,statement) values(v_user_id,v_statement) returning appeal_id into v_appeal_id;
 insert into private.account_moderation_appeal_events(appeal_id,actor_id,event_type,message) values(v_appeal_id,v_user_id,'submitted','Appeal submitted by account owner.');
 return v_appeal_id;
end $$;

create or replace function public.moderator_list_account_appeals(p_status text default 'submitted',p_limit integer default 50,p_offset integer default 0)
returns table(appeal_id bigint,user_id uuid,username text,display_name text,statement text,status text,moderator_message text,created_at timestamptz,reviewed_at timestamptz)
language plpgsql security definer set search_path=''
as $$
begin
 if (select auth.uid()) is null or not exists(select 1 from private.moderators m where m.user_id=(select auth.uid())) then raise exception 'Moderator access required' using errcode='42501'; end if;
 if p_status is null or p_status not in ('submitted','under_review','accepted','denied','all') or p_limit is null or p_limit<1 or p_limit>100 or p_offset is null or p_offset<0 or p_offset>1000000 then raise exception 'Invalid appeal filter or pagination' using errcode='22023'; end if;
 return query select a.appeal_id,a.user_id,p.username,p.display_name,a.statement,a.status,a.moderator_message,a.created_at,a.reviewed_at
 from private.account_moderation_appeals a left join public.profiles p on p.id=a.user_id
 where p_status='all' or a.status=p_status
 order by case when a.status='submitted' then 0 when a.status='under_review' then 1 else 2 end,a.created_at asc,a.appeal_id asc limit p_limit offset p_offset;
end $$;

create or replace function public.moderator_review_account_appeal(p_appeal_id bigint,p_decision text,p_moderator_message text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_moderator_id uuid := (select auth.uid()); v_appeal private.account_moderation_appeals%rowtype; v_message text := trim(coalesce(p_moderator_message,'')); v_previous_status text;
begin
 if v_moderator_id is null or not exists(select 1 from private.moderators m where m.user_id=v_moderator_id) then raise exception 'Moderator access required' using errcode='42501'; end if;
 if p_appeal_id is null or p_decision is null or p_decision not in ('under_review','accepted','denied') or char_length(v_message)<8 or char_length(v_message)>1000 then raise exception 'Choose a valid decision and provide a response of 8–1000 characters' using errcode='22023'; end if;
 select * into v_appeal from private.account_moderation_appeals where appeal_id=p_appeal_id for update;
 if not found then raise exception 'Appeal not found' using errcode='P0002'; end if;
 if v_appeal.status in ('accepted','denied') then raise exception 'This appeal has already received a final decision' using errcode='22023'; end if;
 if p_decision='under_review' and v_appeal.status='under_review' then raise exception 'This appeal is already under review' using errcode='22023'; end if;
 if p_decision='accepted' then
  select case when s.status='posting_restricted' and s.expires_at is not null and s.expires_at<=now() then 'clear' else coalesce(s.status,'clear') end into v_previous_status
  from (select 1) seed left join private.account_moderation_state s on s.user_id=v_appeal.user_id;
  insert into private.account_moderation_state(user_id,status,reason,expires_at,updated_by,updated_at)
  values(v_appeal.user_id,'clear','Appeal accepted: '||v_message,null,v_moderator_id,now())
  on conflict(user_id) do update set status='clear',reason=excluded.reason,expires_at=null,updated_by=v_moderator_id,updated_at=now();
  insert into private.account_moderation_audit(target_user_id,moderator_id,action,previous_status,new_status,reason,expires_at)
  values(v_appeal.user_id,v_moderator_id,'appeal_accepted',v_previous_status,'clear',left('Appeal accepted: '||v_message,1000),null);
 end if;
 update private.account_moderation_appeals set status=p_decision,moderator_message=v_message,reviewed_by=v_moderator_id,
 reviewed_at=case when p_decision in ('accepted','denied') then now() else null end,updated_at=now() where appeal_id=p_appeal_id;
 insert into private.account_moderation_appeal_events(appeal_id,actor_id,event_type,message) values(p_appeal_id,v_moderator_id,p_decision,v_message);
 return jsonb_build_object('appeal_id',p_appeal_id,'status',p_decision);
end $$;

revoke execute on function public.get_my_account_moderation_status() from public,anon;
revoke execute on function public.submit_account_moderation_appeal(text) from public,anon;
revoke execute on function public.moderator_list_account_appeals(text,integer,integer) from public,anon;
revoke execute on function public.moderator_review_account_appeal(bigint,text,text) from public,anon;
grant execute on function public.get_my_account_moderation_status() to authenticated;
grant execute on function public.submit_account_moderation_appeal(text) to authenticated;
grant execute on function public.moderator_list_account_appeals(text,integer,integer) to authenticated;
grant execute on function public.moderator_review_account_appeal(bigint,text,text) to authenticated;
