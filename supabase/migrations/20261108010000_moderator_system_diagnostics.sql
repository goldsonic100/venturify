create or replace function public.moderator_system_diagnostics()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_checks jsonb;
begin
  if (select auth.uid()) is null or not exists (
    select 1 from private.moderators m where m.user_id = (select auth.uid())
  ) then
    raise exception 'Moderator access required' using errcode = '42501';
  end if;

  with expected_tables(schema_name, table_name, private_only) as (
    values
      ('public','profiles',false),
      ('public','posts',false),
      ('public','comments',false),
      ('public','communities',false),
      ('public','community_members',false),
      ('public','content_reports',false),
      ('public','founder_postmortems',false),
      ('public','founder_postmortem_reviews',false),
      ('private','moderators',true),
      ('private','account_moderation_state',true),
      ('private','account_moderation_audit',true),
      ('private','account_moderation_appeals',true),
      ('private','account_moderation_appeal_events',true)
  )
  select pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'name', case when e.private_only then 'Private table: ' else 'RLS: ' end || e.schema_name || '.' || e.table_name,
      'status', case
        when c.oid is null then 'error'
        when not c.relrowsecurity then 'error'
        when e.private_only and (
          pg_catalog.has_table_privilege('anon',c.oid,'SELECT')
          or pg_catalog.has_table_privilege('authenticated',c.oid,'SELECT')
        ) then 'error'
        else 'ok'
      end,
      'detail', case
        when c.oid is null then 'Expected table is missing'
        when not c.relrowsecurity then 'Row Level Security is disabled'
        when e.private_only and (
          pg_catalog.has_table_privilege('anon',c.oid,'SELECT')
          or pg_catalog.has_table_privilege('authenticated',c.oid,'SELECT')
        ) then 'Direct table SELECT is granted to an API role; review the private-table boundary'
        when e.private_only then 'RLS is enabled and direct API-role SELECT is not granted'
        else 'RLS is enabled'
      end
    ) order by e.schema_name, e.table_name
  ) into v_checks
  from expected_tables e
  left join pg_catalog.pg_namespace n on n.nspname=e.schema_name
  left join pg_catalog.pg_class c on c.relnamespace=n.oid and c.relname=e.table_name and c.relkind in ('r','p');

  with expected_functions(function_name, signature) as (
    values
      ('Dashboard overview','public.moderator_dashboard_overview()'),
      ('System diagnostics endpoint','public.moderator_system_diagnostics()'),
      ('Trust & safety analytics','public.moderator_dashboard_analytics(integer)'),
      ('Founder & community analytics','public.moderator_growth_analytics(integer)'),
      ('Filtered report queue','public.moderator_list_reports_filtered_page(text,text,text,integer,integer)'),
      ('Account appeals queue','public.moderator_list_account_appeals(text,integer,integer)'),
      ('Account appeal decisions','public.moderator_review_account_appeal(bigint,text,text)'),
      ('Account restriction status','public.get_my_account_moderation_status()'),
      ('Submit account appeal','public.submit_account_moderation_appeal(text)'),
      ('Founder post-mortem review queue','public.moderator_list_founder_postmortems_page(text,integer,integer)')
  )
  select v_checks || coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'name', e.function_name,
        'status', case
          when p.oid is null then 'error'
          when not p.prosecdef then 'error'
          when not (coalesce(p.proconfig, array[]::text[]) @> array['search_path=""']::text[]) then 'error'
          when pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE') then 'error'
          when not pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE') then 'error'
          else 'ok'
        end,
        'detail', case
          when p.oid is null then 'Expected function signature is missing'
          when not p.prosecdef then 'Function is not SECURITY DEFINER as expected by this moderator-only endpoint'
          when not (coalesce(p.proconfig, array[]::text[]) @> array['search_path=""']::text[]) then 'Function does not pin an empty search_path'
          when pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE') then 'Anonymous EXECUTE is granted; review function permissions'
          when not pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE') then 'Authenticated EXECUTE is missing'
          else 'SECURITY DEFINER, empty search_path, authenticated EXECUTE, and no anon EXECUTE verified'
        end
      ) order by e.function_name
    ), '[]'::jsonb
  ) into v_checks
  from expected_functions e
  left join pg_catalog.pg_proc p on p.oid=pg_catalog.to_regprocedure(e.signature);

  with expected_indexes(index_name, table_name) as (
    values
      ('account_moderation_appeal_events_actor_id_idx','account_moderation_appeal_events'),
      ('account_moderation_appeals_reviewed_by_idx','account_moderation_appeals'),
      ('account_moderation_audit_moderator_id_idx','account_moderation_audit'),
      ('account_moderation_state_updated_by_idx','account_moderation_state')
  )
  select v_checks || coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'name','Moderation index: ' || e.index_name,
        'status',case when i.indexname is null then 'warning' else 'ok' end,
        'detail',case when i.indexname is null then 'Expected foreign-key support index is missing' else 'Expected index exists' end
      ) order by e.index_name
    ), '[]'::jsonb
  ) into v_checks
  from expected_indexes e
  left join pg_catalog.pg_indexes i
    on i.schemaname='private' and i.tablename=e.table_name and i.indexname=e.index_name;

  return pg_catalog.jsonb_build_object(
    'generated_at', pg_catalog.now(),
    'checks', coalesce(v_checks,'[]'::jsonb),
    'scope_note','Read-only checks of selected tables, moderator RPC permissions, and moderation indexes. This is not a complete security audit or hosting/uptime check.'
  );
end;
$function$;

revoke all on function public.moderator_system_diagnostics() from public;
revoke all on function public.moderator_system_diagnostics() from anon;
grant execute on function public.moderator_system_diagnostics() to authenticated;
