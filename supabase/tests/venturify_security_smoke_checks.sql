-- Read-only Venturify security/regression smoke checks.
-- Run in Supabase SQL Editor after migrations. Every row should return passed = true.
WITH public_tables AS (
  SELECT c.relname, c.relrowsecurity
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind IN ('r','p')
),
checks AS (
  SELECT
    'all_public_tables_have_rls'::text AS check_name,
    NOT EXISTS (SELECT 1 FROM public_tables WHERE NOT relrowsecurity) AS passed,
    (SELECT count(*)::text FROM public_tables) || ' public tables inspected' AS detail
  UNION ALL
  SELECT
    'symmetric_pending_collaboration_index',
    EXISTS (
      SELECT 1 FROM pg_catalog.pg_indexes
      WHERE schemaname='public'
        AND indexname='collaboration_requests_one_pending_pair_symmetric_idx'
    ),
    'One pending request per founder pair, either direction'
  UNION ALL
  SELECT
    'no_duplicate_pending_collaboration_pairs',
    NOT EXISTS (
      SELECT 1
      FROM public.collaboration_requests
      WHERE status='pending'
      GROUP BY LEAST(requester_id, recipient_id), GREATEST(requester_id, recipient_id)
      HAVING count(*) > 1
    ),
    'No founder pair has multiple pending requests'
  UNION ALL
  SELECT
    'message_reactions_rls_enabled',
    COALESCE((
      SELECT c.relrowsecurity
      FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname='message_reactions' AND c.relkind IN ('r','p')
    ), false),
    'Message reactions table has row-level security enabled'
  UNION ALL
  SELECT
    'block_guards_for_messages',
    (
      SELECT count(*) = 2
      FROM pg_catalog.pg_policies
      WHERE schemaname='public'
        AND tablename='messages'
        AND permissive='RESTRICTIVE'
        AND policyname IN ('Block enforcement guard: messages select','Block enforcement guard: messages insert')
    ),
    'Restrictive read and insert block guards are present'
  UNION ALL
  SELECT
    'sensitive_rpc_not_executable_by_anon',
    NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public'
        AND p.proname = ANY (ARRAY[
          'get_or_create_direct_conversation',
          'create_group_conversation',
          'get_poll_results',
          'moderator_dashboard_overview',
          'moderator_list_recent_posts',
          'moderator_list_recent_posts_page',
          'moderator_list_reports',
          'moderator_list_reports_page',
          'moderator_list_users',
          'moderator_update_report'
        ])
        AND pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE')
    ),
    'Sensitive RPCs are not executable by anon'
)
SELECT check_name, passed, detail
FROM checks
ORDER BY check_name;
