\set ON_ERROR_STOP on
\i supabase/migrations/20261018150000_add_moderator_review_workflow.sql

-- A normal signed-in user must not be able to enumerate all reports or update moderation fields.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);
do $$
declare visible_count integer;
begin
  select count(*) into visible_count from public.content_reports;
  if visible_count <> 1 then raise exception 'FAIL: reporter should see only their own report'; end if;

  begin
    perform * from public.moderator_list_reports('pending', 50);
    raise exception 'FAIL: non-moderator could list private reports';
  exception when insufficient_privilege then null;
  end;

  begin
    perform public.moderator_update_report('10000000-0000-0000-0000-000000000001', 'resolved', 'not allowed');
    raise exception 'FAIL: non-moderator could update report';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- Only a database administrator provisions a moderator. The moderator can review
-- all reports, update a valid status, and record bounded private notes.
insert into private.moderators (user_id) values ('00000000-0000-0000-0000-000000000003');
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', false);
do $$
declare visible_count integer;
declare updated_status text;
declare updated_notes text;
declare updated_by uuid;
begin
  select count(*) into visible_count from public.moderator_list_reports(null, 100);
  if visible_count <> 2 then raise exception 'FAIL: moderator should see all reports'; end if;

  if not public.moderator_update_report(
    '10000000-0000-0000-0000-000000000001', 'resolved', 'Reviewed; action taken'
  ) then raise exception 'FAIL: moderator update returned false'; end if;

  select status, moderator_notes, reviewed_by
    into updated_status, updated_notes, updated_by
    from public.moderator_list_reports(null, 100)
    where id = '10000000-0000-0000-0000-000000000001';
  if updated_status <> 'resolved' then raise exception 'FAIL: report status was not updated'; end if;
  if updated_notes <> 'Reviewed; action taken' then raise exception 'FAIL: moderator notes were not saved'; end if;
  if updated_by <> '00000000-0000-0000-0000-000000000003' then raise exception 'FAIL: reviewer identity was not saved'; end if;

  begin
    perform public.moderator_update_report('10000000-0000-0000-0000-000000000001', 'invalid', '');
    raise exception 'FAIL: invalid report status was accepted';
  exception when invalid_parameter_value then null;
  end;

  begin
    perform public.moderator_update_report('10000000-0000-0000-0000-000000000001', 'resolved', repeat('x', 2001));
    raise exception 'FAIL: oversized moderator notes were accepted';
  exception when string_data_right_truncation then null;
  end;
end $$;
reset role;

\echo 'PASS: moderator report review integration checks'
