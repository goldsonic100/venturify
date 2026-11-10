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

  -- Surface public tables that have RLS enabled but no policies at all.
  -- Such tables deny every row to API roles; this is safe by default but often
  -- indicates an incomplete feature migration that should be reviewed.
  with expected_tables(schema_name, table_name, private_only) as (
    values
      ('public','profiles',false),
      ('public','posts',false),
      ('public','comments',false),
      ('public','communities',false),
      ('public','community_members',false),
      ('public','content_reports',false),
      ('public','founder_postmortems',false),
      ('public','founder_postmortem_reviews',false)
  )
  select v_checks || coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'name','RLS policies: ' || e.schema_name || '.' || e.table_name,
        'status',case when c.oid is null then 'error' when coalesce(p.policy_count,0)=0 then 'warning' else 'ok' end,
        'detail',case
          when c.oid is null then 'Expected table is missing'
          when coalesce(p.policy_count,0)=0 then 'RLS is enabled but no policies exist; all row access is denied until policies are added'
          else p.policy_count || ' policy/policies found: ' || p.policy_names
        end
      ) order by e.table_name
    ), '[]'::jsonb
  ) into v_checks
  from expected_tables e
  left join pg_catalog.pg_namespace n on n.nspname=e.schema_name
  left join pg_catalog.pg_class c on c.relnamespace=n.oid and c.relname=e.table_name and c.relkind in ('r','p')
  left join lateral (
    select count(*)::integer as policy_count,
           coalesce(pg_catalog.string_agg(policyname, ', ' order by policyname),'') as policy_names
    from pg_catalog.pg_policies
    where schemaname=e.schema_name and tablename=e.table_name
  ) p on true;

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

  with definer_inventory as (
    select
      p.oid,
      p.proname,
      p.proconfig,
      pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
      pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute,
      pg_catalog.lower(pg_catalog.pg_get_functiondef(p.oid)) as definition,
      pg_catalog.lower(pg_catalog.pg_get_function_result(p.oid)) as result_definition
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef
  ),
  definer_summary as (
    select
      count(*)::integer as total_functions,
      count(*) filter (
        where not (coalesce(proconfig,array[]::text[]) @> array['search_path=""']::text[])
      )::integer as unpinned_functions,
      count(*) filter (
        where anon_execute and proname <> 'list_published_founder_postmortems'
      )::integer as unexpected_anon_grants,
      count(*) filter (
        where authenticated_execute
          and proname <> 'list_published_founder_postmortems'
          and pg_catalog.strpos(definition,'auth.uid()') = 0
          and pg_catalog.strpos(definition,'private.moderators') = 0
      )::integer as authenticated_functions_missing_guard,
      count(*) filter (
        where proname='list_published_founder_postmortems'
          and (
            pg_catalog.strpos(definition,'approved') = 0
            or pg_catalog.strpos(definition,'consent_to_publish') = 0
            or pg_catalog.strpos(definition,'anonymous founder') = 0
            or pg_catalog.strpos(result_definition,'author_id') > 0
            or pg_catalog.strpos(result_definition,'moderator_notes') > 0
          )
      )::integer as unsafe_public_projection,
      count(*) filter (where proname='list_published_founder_postmortems')::integer as public_projection_count
    from definer_inventory
  )
  select v_checks || pg_catalog.jsonb_build_array(
    pg_catalog.jsonb_build_object(
      'name','SECURITY DEFINER function inventory',
      'status',case
        when s.unpinned_functions > 0
          or s.unexpected_anon_grants > 0
          or s.authenticated_functions_missing_guard > 0
          or s.unsafe_public_projection > 0
          or s.public_projection_count <> 1 then 'error'
        else 'ok'
      end,
      'detail',s.total_functions || ' public SECURITY DEFINER functions inspected; '
        || s.unpinned_functions || ' missing empty search_path; '
        || s.unexpected_anon_grants || ' unexpected anonymous grants; '
        || s.authenticated_functions_missing_guard || ' authenticated RPCs missing user/moderator guards; '
        || s.unsafe_public_projection || ' unsafe public projections; '
        || case when s.public_projection_count=1 then 'the consent-filtered public library RPC is allowlisted' else 'the expected public library RPC is missing or duplicated' end
    )
  ) into v_checks
  from definer_summary s;

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
